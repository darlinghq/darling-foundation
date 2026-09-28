# Compile the entire wrapper implementation under renamed classes on GNUstep.
# NSData option adapters record flags but do not implement actual mmap behavior.
# Usage: ruby tests/file-wrapper-loading.rb GNUSTEP_ROOT
require 'tmpdir'
require 'open3'
sdk=ARGV.fetch(0)
root=File.expand_path('..', __dir__)
header=File.read("#{root}/include/Foundation/NSFileWrapper.h").gsub(/^#import.*\n/, '')
source=File.read("#{root}/src/NSFileWrapper.m").gsub(/^#import.*\n/, '')
wrapper=(header+source).gsub('NSFileWrapper', 'ProbeFileWrapper')
# Count concrete allocations and base deallocations without changing ownership.
wrapper.gsub!('return NSAllocateObject(self, 0, NULL);', 'liveWrappers++; return NSAllocateObject(self, 0, NULL);')
abort 'base dealloc unavailable' unless wrapper.sub!(/(- \(void\) dealloc\s*\{\s*)(\[_path release\];)/, '\1liveWrappers--; \2')
manager=File.read("#{root}/src/NSFileManager.m")
link_methods=%w[destinationOfSymbolicLinkAtPath pathContentOfSymbolicLinkAtPath].map do |name|
  manager[/^- \(NSString \*\)#{name}:.*?^\}/m] or abort "missing #{name}"
end.join("\n")
program=<<~'OBJC'
  #import <Foundation/Foundation.h>
  #include <assert.h>
  #include <errno.h>
  #include <sys/stat.h>
  #include <unistd.h>
  #include <limits.h>
  #include <string.h>
  #define NSDebugEnabled NO
  #define NSDataReadingMappedIfSafe 1
  #define NSDataWritingAtomic 1
  static NSUInteger reads, lastOptions;
  static NSInteger liveWrappers;
  static NSString *failedPath;
  static int failureKind;
  static NSError *injectedError;
  @interface NSData (ProbeOptions)
  + (id)dataWithContentsOfURL:(NSURL*)url options:(NSUInteger)options error:(NSError**)error;
  - (id)initWithContentsOfFile:(NSString*)path options:(NSUInteger)options error:(NSError**)error;
  @end
  @implementation NSData (ProbeOptions)
  + (id)dataWithContentsOfURL:(NSURL*)url options:(NSUInteger)options error:(NSError**)error {
    return [[[self alloc] initWithContentsOfFile:[url path] options:options error:error] autorelease];
  }
  - (id)initWithContentsOfFile:(NSString*)path options:(NSUInteger)options error:(NSError**)error {
    reads++; lastOptions=options;
    if (failureKind==3 && [path isEqual:failedPath]) {
      if (error) *error=injectedError;
      [self release]; return nil;
    }
    id result=[self initWithContentsOfFile:path];
    if (!result && error) *error=[NSError errorWithDomain:NSPOSIXErrorDomain code:EIO userInfo:nil];
    return result;
  }
  @end
  @interface ProbeManager : NSFileManager @end
  @implementation ProbeManager
  + (id)defaultManager { static id manager; if (!manager) manager=[self new]; return manager; }
  - (NSDictionary*)attributesOfItemAtPath:(NSString*)path error:(NSError**)error {
    if (failureKind==1 && [path isEqual:failedPath]) {
      if (error) *error=injectedError; return nil;
    }
    return [super attributesOfItemAtPath:path error:error];
  }
  - (NSArray*)contentsOfDirectoryAtPath:(NSString*)path error:(NSError**)error {
    if (failureKind==2 && [path isEqual:failedPath]) {
      if (error) *error=injectedError; return nil;
    }
    return [[super contentsOfDirectoryAtPath:path error:error] sortedArrayUsingSelector:@selector(compare:)];
  }
  LINK_METHODS
  @end
  #define NSFileManager ProbeManager
  WRAPPER
  #undef NSFileManager
  static ProbeFileWrapper* load(NSString *path, NSUInteger options, NSError **error) {
    return [[ProbeFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:path] options:options error:error];
  }
  int main(int argc,char **argv) {
    @autoreleasepool {
      NSString *root=[NSString stringWithUTF8String:argv[1]];
      NSString *file=[root stringByAppendingPathComponent:@"file"];
      NSData *before=[@"before" dataUsingEncoding:NSUTF8StringEncoding];
      NSData *after=[@"after" dataUsingEncoding:NSUTF8StringEncoding];
      assert([before writeToFile:file atomically:NO]);
      NSError *error=nil;
      id placeholder=[ProbeFileWrapper alloc];
      ProbeFileWrapper *snapshot=load(file,3,&error);
      assert(snapshot && !error && lastOptions==0 && reads==1);
      assert([after writeToFile:file atomically:NO]);
      assert([[snapshot regularFileContents] isEqual:before]);
      [snapshot release];
      NSUInteger oldReads=reads;
      ProbeFileWrapper *lazy=load(file,2,&error);
      assert(lazy && reads==oldReads);
      assert([[lazy regularFileContents] isEqual:after] && lastOptions==0);
      [lazy release];
      lazy=load(file,0,&error);
      assert([[lazy regularFileContents] isEqual:after] && lastOptions==1);
      [lazy release];
      NSString *dir=[root stringByAppendingPathComponent:@"package"];
      assert(mkdir([dir fileSystemRepresentation],0700)==0);
      NSString *child=[dir stringByAppendingPathComponent:@"child"];
      assert([before writeToFile:child atomically:NO]);
      NSString *link=[dir stringByAppendingPathComponent:@"dangling"];
      assert(symlink("missing",[link fileSystemRepresentation])==0);
      snapshot=load(dir,3,&error);
      assert(snapshot && [[snapshot fileWrappers] count]==2);
      assert(unlink([child fileSystemRepresentation])==0);
      assert([[[[snapshot fileWrappers] objectForKey:@"child"] regularFileContents] isEqual:before]);
      assert([[[[snapshot fileWrappers] objectForKey:@"dangling"] symbolicLinkDestination] isEqual:@"missing"]);
      [snapshot release];
      NSString *fifo=[dir stringByAppendingPathComponent:@"fifo"];
      assert(mkfifo([fifo fileSystemRepresentation],0600)==0);
      for (int i=0;i<3;i++) {
        error=nil; assert(load(dir,3,&error)==nil && error!=nil);
        assert([ProbeFileWrapper alloc]==placeholder);
        error=nil; assert(load(fifo,0,&error)==nil && error!=nil);
        error=nil; assert(load(child,0,&error)==nil && error!=nil);
        assert(load(child,0,NULL)==nil);
        ProbeFileWrapper *valid=load(file,3,NULL); assert(valid); [valid release];
      }
      error=nil;
      assert([[ProbeFileWrapper alloc] initWithURL:[NSURL URLWithString:@"https://example.invalid/file"] options:0 error:&error]==nil);
      assert([error code]==NSFileReadUnsupportedSchemeError);
      // Sorted child names guarantee a complete first child before the failure.
      NSString *faultDir=[root stringByAppendingPathComponent:@"faults"];
      assert(mkdir([faultDir fileSystemRepresentation],0700)==0);
      NSString *first=[faultDir stringByAppendingPathComponent:@"a-good"];
      NSString *second=[faultDir stringByAppendingPathComponent:@"b-failing"];
      assert([before writeToFile:first atomically:NO]);
      assert([before writeToFile:second atomically:NO]);
      injectedError=[NSError errorWithDomain:NSPOSIXErrorDomain code:EACCES userInfo:nil];
      for (failureKind=1;failureKind<=3;failureKind++) {
        NSInteger baseline=liveWrappers;
        @autoreleasepool {
          failedPath=failureKind==2 ? faultDir : second;
          error=nil;
          assert(load(faultDir,3,&error)==nil && error==injectedError);
          assert(load(faultDir,3,NULL)==nil);
          assert([ProbeFileWrapper alloc]==placeholder);
        }
        assert(liveWrappers==baseline);
      }
      failureKind=0; failedPath=nil;
      snapshot=load(faultDir,3,NULL); assert(snapshot); [snapshot release];
      puts("PASS: actual wrapper class cluster; snapshots; deferred option forwarding; recursive failure; repeated placeholder reuse");
    }
  }
OBJC
program.sub!('WRAPPER') { wrapper }
program.sub!('LINK_METHODS') { link_methods }
gcc,status=Open3.capture2('gcc','-print-file-name=include'); abort unless status.success?
Dir.mktmpdir('wrapper-loading') do |dir|
  input="#{dir}/probe.m"; output="#{dir}/probe"; File.write(input,program)
  log,status=Open3.capture2e('clang','-fobjc-runtime=gcc','-fconstant-string-class=NSConstantString',
    "-I#{sdk}/usr/include/GNUstep","-I#{gcc.strip}",input,"-L#{sdk}/usr/lib",
    "-Wl,-rpath,#{sdk}/usr/lib",'-lgnustep-base','-lobjc','-o',output)
  abort log unless status.success?
  abort 'probe failed' unless system(output,dir,rlimit_core:0)
end
