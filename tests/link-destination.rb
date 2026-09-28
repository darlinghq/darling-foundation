# Host probe of actual NSFileManager methods; not a full Darling runtime test.
# Usage: ruby tests/link-destination.rb GNUSTEP_ROOT
require 'tmpdir'
require 'open3'
sdk = ARGV.fetch(0)
source = File.read(File.join(__dir__, '../src/NSFileManager.m'))
methods = %w[destinationOfSymbolicLinkAtPath pathContentOfSymbolicLinkAtPath].map do |name|
  source[/^- \(NSString \*\)#{name}:.*?^\}/m] or abort "missing #{name}"
end.join("\n")
program = <<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  #include <unistd.h>
  #include <errno.h>
  #include <limits.h>
  #include <string.h>
  @interface LinkManager : NSFileManager @end
  @implementation LinkManager
  METHODS
  @end
  static void check(LinkManager *fm, NSString *root, const char *name, const char *target) {
    NSString *path=[root stringByAppendingPathComponent:[NSString stringWithUTF8String:name]];
    assert(symlink(target,[path fileSystemRepresentation])==0);
    NSError *error=nil;
    NSString *expected=[NSString stringWithUTF8String:target];
    assert([[fm destinationOfSymbolicLinkAtPath:path error:&error] isEqual:expected]);
    assert(error==nil);
    assert([[fm pathContentOfSymbolicLinkAtPath:path] isEqual:expected]);
    assert([[fm destinationOfSymbolicLinkAtPath:path error:NULL] isEqual:expected]);
  }
  int main(int argc, char **argv) {
    @autoreleasepool {
      NSString *root=[NSString stringWithUTF8String:argv[1]];
      LinkManager *fm=[LinkManager new];
      NSString *file=[root stringByAppendingPathComponent:@"file"];
      assert([[@"content" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:file atomically:NO]);
      check(fm,root,"relative","file");
      check(fm,root,"absolute",[file fileSystemRepresentation]);
      check(fm,root,"dangling","missing");
      check(fm,root,"self","self");
      check(fm,root,"cycle-a","cycle-b");
      check(fm,root,"cycle-b","cycle-a");
      check(fm,root,"chain","relative");
      check(fm,root,"unnormalized","./nested/../file");
      check(fm,root,"unicode","caf\xc3\xa9");
      for (NSString *path in @[file, [root stringByAppendingPathComponent:@"absent"], root]) {
        NSError *error=nil;
        assert([fm destinationOfSymbolicLinkAtPath:path error:&error]==nil);
        assert([[error domain] isEqual:NSPOSIXErrorDomain]);
        assert([error code]==([path hasSuffix:@"absent"] ? ENOENT : EINVAL));
        assert([fm destinationOfSymbolicLinkAtPath:path error:NULL]==nil);
        assert([fm pathContentOfSymbolicLinkAtPath:path]==nil);
      }
      [fm release];
      puts("PASS: relative/absolute/dangling/cyclic/chained/raw/Unicode destinations; errors; legacy API");
    }
  }
OBJC
program.sub!('METHODS') { methods }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('link-destination') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,dir,rlimit_core:0)
end
