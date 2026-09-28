# Host probe of actual NSFileManager methods; not a full Darling runtime test.
# Usage: ruby tests/link-destination.rb GNUSTEP_ROOT [BASELINE_REF]
# BASELINE_REF substitutes only the modern reader, retaining the new forwarding
# legacy method so the baseline fails on behavior rather than a missing method.
require 'tmpdir'
require 'open3'
sdk = ARGV.fetch(0)
source = File.read(File.join(__dir__, '../src/NSFileManager.m'))
if ARGV[1]
  baseline, status = Open3.capture2('git', '-C', File.join(__dir__, '..'), 'show', "#{ARGV[1]}:src/NSFileManager.m")
  abort 'baseline unavailable' unless status.success?
  original = baseline[/^- \(NSString \*\)destinationOfSymbolicLinkAtPath:.*?^\}/m] or abort 'baseline reader missing'
  source.sub!(/^- \(NSString \*\)destinationOfSymbolicLinkAtPath:.*?^\}/m) { original }
end
methods = %w[destinationOfSymbolicLinkAtPath pathContentOfSymbolicLinkAtPath].map do |name|
  source[/^- \(NSString \*\)#{name}:.*?^\}/m] or abort "missing #{name}"
end.join("\n")
wrapper = File.read(File.join(__dir__, '../src/NSFileWrapper.m')).split('@implementation NSFileWrapperLink').fetch(1)
wrapper_methods = [/^- \(BOOL\) updateFromPath:.*?^\}/m,
                   /^- \(NSString\*\) symbolicLinkDestination.*?^\}/m,
                   /^- \(void\) dealloc.*?^\}/m].map { |pattern| wrapper[pattern] or abort 'wrapper method missing' }.join("\n")
program = <<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  #include <unistd.h>
  #include <errno.h>
  #include <limits.h>
  #include <string.h>
  @interface LinkManager : NSFileManager @end
  @implementation LinkManager
  + (id)defaultManager { static id manager; if (!manager) manager=[self new]; return manager; }
  METHODS
  @end
  @interface WrapperBase : NSObject @end
  @implementation WrapperBase
  // Controlled metadata acceptance, not the Foundation class cluster.
  - (BOOL)updateFromPath:(NSString *)path attributes:(NSDictionary *)attrs { return attrs!=nil; }
  @end
  @interface LinkWrapper : WrapperBase { NSString *linkDestination; } @end
  @implementation LinkWrapper
  #define NSFileManager LinkManager
  WRAPPER_METHODS
  #undef NSFileManager
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
    LinkWrapper *wrapper=[LinkWrapper new];
    assert([wrapper updateFromPath:path attributes:@{}]);
    assert([[wrapper symbolicLinkDestination] isEqual:expected]);
    // Exercise release/replacement of the existing stored destination too.
    assert([wrapper updateFromPath:path attributes:@{}]);
    assert([[wrapper symbolicLinkDestination] isEqual:expected]);
    [wrapper release];
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
program.sub!('WRAPPER_METHODS') { wrapper_methods }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('link-destination') do |dir|
  input=File.join(dir,'probe.m'); output=File.join(dir,'probe'); File.write(input,program)
  abort 'compile failed' unless system('clang','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort 'probe failed' unless system(output,dir,rlimit_core:0)
end
