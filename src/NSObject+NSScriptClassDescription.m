#import <Foundation/NSObject.h>
#import <Foundation/NSObjCRuntime.h>

 @implementation NSObject (NSScriptClassDescription)

 - (NSString *)className {
    return NSStringFromClass([self class]);
}

 @end