#import <Foundation/NSObject.h>

@interface NSUserScriptTask : NSObject {}
@end

@interface NSUserAppleScriptTask : NSUserScriptTask {}
@end

@interface NSUserUnixTask : NSUserScriptTask {}
@end

@interface NSUserAutomatorTask : NSUserScriptTask {}
@end
