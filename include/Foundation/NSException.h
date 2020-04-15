#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <stdarg.h>
#import <setjmp.h>

@class NSString, NSDictionary, NSArray, NSAssertionHandler, NSException;

#define NS_DURING @try {
#define NS_HANDLER } @catch (NSException *localException) {
#define NS_ENDHANDLER }
#define NS_VALUERETURN(v,t) return (v)
#define NS_VOIDRETURN return

typedef void NSUncaughtExceptionHandler(NSException *exception);

FOUNDATION_EXPORT NSUncaughtExceptionHandler *NSGetUncaughtExceptionHandler(void);
FOUNDATION_EXPORT void NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *);

#if __clang__
#define __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Wformat-extra-args\"")
#define __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS _Pragma("clang diagnostic pop")
#else
#define __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS
#define __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS
#endif

#if (defined(__STDC_VERSION__) && (199901L <= __STDC_VERSION__)) || (defined(__cplusplus) && (201103L <= __cplusplus))

#if !defined(NS_BLOCK_ASSERTIONS)

#if !defined(_NSAssertBody)
#define NSAssert(condition, desc, ...) do { \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    if (!(condition)) { \
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd \
            object:self file:[NSString stringWithUTF8String:__FILE__] \
            lineNumber:__LINE__ description:(desc), ##__VA_ARGS__]; \
    } \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS \
} while(0)
#endif

#if !defined(_NSCAssertBody)
#define NSCAssert(condition, desc, ...) do { \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    if (!(condition)) { \
        [[NSAssertionHandler currentHandler] handleFailureInFunction:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] \
            file:[NSString stringWithUTF8String:__FILE__] \
            lineNumber:__LINE__ description:(desc), ##__VA_ARGS__]; \
    } \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS \
} while(0)
#endif

#else

#if !defined(_NSAssertBody)
#define NSAssert(condition, desc, ...) do {} while (0)
#endif

#if !defined(_NSCAssertBody)
#define NSCAssert(condition, desc, ...) do {} while (0)
#endif

#endif

#if !defined(_NSAssertBody)
#define NSAssert1(condition, desc, arg1) NSAssert((condition), (desc), (arg1))
#define NSAssert2(condition, desc, arg1, arg2) NSAssert((condition), (desc), (arg1), (arg2))
#define NSAssert3(condition, desc, arg1, arg2, arg3) NSAssert((condition), (desc), (arg1), (arg2), (arg3))
#define NSAssert4(condition, desc, arg1, arg2, arg3, arg4) NSAssert((condition), (desc), (arg1), (arg2), (arg3), (arg4))
#define NSAssert5(condition, desc, arg1, arg2, arg3, arg4, arg5) NSAssert((condition), (desc), (arg1), (arg2), (arg3), (arg4), (arg5))
#define NSParameterAssert(condition) NSAssert((condition), @"Invalid parameter not satisfying: %s", #condition)
#endif

#if !defined(_NSCAssertBody)
#define NSCAssert1(condition, desc, arg1) NSCAssert((condition), (desc), (arg1))
#define NSCAssert2(condition, desc, arg1, arg2) NSCAssert((condition), (desc), (arg1), (arg2))
#define NSCAssert3(condition, desc, arg1, arg2, arg3) NSCAssert((condition), (desc), (arg1), (arg2), (arg3))
#define NSCAssert4(condition, desc, arg1, arg2, arg3, arg4) NSCAssert((condition), (desc), (arg1), (arg2), (arg3), (arg4))
#define NSCAssert5(condition, desc, arg1, arg2, arg3, arg4, arg5) NSCAssert((condition), (desc), (arg1), (arg2), (arg3), (arg4), (arg5))
#define NSCParameterAssert(condition) NSCAssert((condition), @"Invalid parameter not satisfying: %s", #condition)
#endif

#endif

/* Non-vararg implementation of asserts (ignore) */
#if !defined(NS_BLOCK_ASSERTIONS)
#if !defined(_NSAssertBody)
#define _NSAssertBody(condition, desc, arg1, arg2, arg3, arg4, arg5) do { \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    if (!(condition)) { \
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:[NSString stringWithUTF8String:__FILE__] \
            lineNumber:__LINE__ description:(desc), (arg1), (arg2), (arg3), (arg4), (arg5)]; \
    } \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS \
} while(0)
#endif
#if !defined(_NSCAssertBody)
#define _NSCAssertBody(condition, desc, arg1, arg2, arg3, arg4, arg5) do { \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    if (!(condition)) { \
        [[NSAssertionHandler currentHandler] handleFailureInFunction:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] file:[NSString stringWithUTF8String:__FILE__] \
            lineNumber:__LINE__ description:(desc), (arg1), (arg2), (arg3), (arg4), (arg5)]; \
    } \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS \
} while(0)
#endif
#else
#if !defined(_NSAssertBody)
#define _NSAssertBody(condition, desc, arg1, arg2, arg3, arg4, arg5)
#endif
#if !defined(_NSCAssertBody)
#define _NSCAssertBody(condition, desc, arg1, arg2, arg3, arg4, arg5)
#endif
#endif

#if !defined(NSAssert)
#define NSAssert5(condition, desc, arg1, arg2, arg3, arg4, arg5) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSAssertBody((condition), (desc), (arg1), (arg2), (arg3), (arg4), (arg5)) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS

#define NSAssert4(condition, desc, arg1, arg2, arg3, arg4) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSAssertBody((condition), (desc), (arg1), (arg2), (arg3), (arg4), 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS

#define NSAssert3(condition, desc, arg1, arg2, arg3) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSAssertBody((condition), (desc), (arg1), (arg2), (arg3), 0, 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS

#define NSAssert2(condition, desc, arg1, arg2) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSAssertBody((condition), (desc), (arg1), (arg2), 0, 0, 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS

#define NSAssert1(condition, desc, arg1) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSAssertBody((condition), (desc), (arg1), 0, 0, 0, 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS

#define NSAssert(condition, desc) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSAssertBody((condition), (desc), 0, 0, 0, 0, 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS
#endif

#if !defined(NSParameterAssert)
#define NSParameterAssert(condition) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSAssertBody((condition), @"Invalid parameter not satisfying: %s", #condition, 0, 0, 0, 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS
#endif

#if !defined(NSCAssert)
#define NSCAssert5(condition, desc, arg1, arg2, arg3, arg4, arg5) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSCAssertBody((condition), (desc), (arg1), (arg2), (arg3), (arg4), (arg5)) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS

#define NSCAssert4(condition, desc, arg1, arg2, arg3, arg4) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSCAssertBody((condition), (desc), (arg1), (arg2), (arg3), (arg4), 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS

#define NSCAssert3(condition, desc, arg1, arg2, arg3) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSCAssertBody((condition), (desc), (arg1), (arg2), (arg3), 0, 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS

#define NSCAssert2(condition, desc, arg1, arg2) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSCAssertBody((condition), (desc), (arg1), (arg2), 0, 0, 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS

#define NSCAssert1(condition, desc, arg1) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSCAssertBody((condition), (desc), (arg1), 0, 0, 0, 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS

#define NSCAssert(condition, desc) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSCAssertBody((condition), (desc), 0, 0, 0, 0, 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS
#endif

#if !defined(NSCParameterAssert)
#define NSCParameterAssert(condition) \
    __PRAGMA_PUSH_NO_EXTRA_ARG_WARNINGS \
    _NSCAssertBody((condition), @"Invalid parameter not satisfying: %s", #condition, 0, 0, 0, 0) \
    __PRAGMA_POP_NO_EXTRA_ARG_WARNINGS
#endif

typedef NSString *NSExceptionName;

FOUNDATION_EXPORT const NSExceptionName NSGenericException;
FOUNDATION_EXPORT const NSExceptionName NSRangeException;
FOUNDATION_EXPORT const NSExceptionName NSInvalidArgumentException;
FOUNDATION_EXPORT const NSExceptionName NSInternalInconsistencyException;
FOUNDATION_EXPORT const NSExceptionName NSMallocException;
FOUNDATION_EXPORT const NSExceptionName NSObjectInaccessibleException;
FOUNDATION_EXPORT const NSExceptionName NSObjectNotAvailableException;
FOUNDATION_EXPORT const NSExceptionName NSDestinationInvalidException;
FOUNDATION_EXPORT const NSExceptionName NSPortTimeoutException;
FOUNDATION_EXPORT const NSExceptionName NSInvalidSendPortException;
FOUNDATION_EXPORT const NSExceptionName NSInvalidReceivePortException;
FOUNDATION_EXPORT const NSExceptionName NSPortSendException;
FOUNDATION_EXPORT const NSExceptionName NSPortReceiveException;
FOUNDATION_EXPORT const NSExceptionName NSOldStyleException;
FOUNDATION_EXPORT const NSExceptionName NSAssertionHandlerKey;

__attribute__((__objc_exception__))
@interface NSException : NSObject <NSCopying, NSCoding> {
    NSExceptionName _name;
    NSString *_reason;
    NSDictionary *_userInfo;
    id _reserved;
}

+ (NSException *) exceptionWithName: (NSExceptionName) name
                             reason: (NSString *) reason
                           userInfo: (NSDictionary *) userInfo;

- (instancetype) initWithName: (NSExceptionName) name
                       reason: (NSString *) reason
                     userInfo: (NSDictionary *) userInfo;

- (NSExceptionName) name;
- (NSString *) reason;
- (NSDictionary *) userInfo;
- (NSArray *) callStackReturnAddresses;
- (NSArray *) callStackSymbols;
- (void) raise;

@end

@interface NSException (NSExceptionRaisingConveniences)

+ (void) raise: (NSExceptionName) name
        format: (NSString *) format, ... NS_FORMAT_FUNCTION(2,3);

+ (void) raise: (NSExceptionName) name
        format: (NSString *) format
     arguments: (va_list) argList NS_FORMAT_FUNCTION(2,0);

@end

@interface NSAssertionHandler : NSObject

+ (NSAssertionHandler *) currentHandler;
- (void) handleFailureInMethod: (SEL) selector
                        object: (id) object
                          file: (NSString *) fileName
                    lineNumber: (NSInteger) line
                   description: (NSString *) format,... NS_FORMAT_FUNCTION(5,6);

- (void) handleFailureInFunction: (NSString *) functionName
                            file: (NSString *) fileName
                      lineNumber: (NSInteger) line
                     description: (NSString *) format,... NS_FORMAT_FUNCTION(4,5);

@end
