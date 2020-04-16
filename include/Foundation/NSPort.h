#import <Foundation/NSObject.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSNotification.h>

typedef int NSSocketNativeHandle;

typedef NS_OPTIONS(NSUInteger, NSMachPortOptions) {
    NSMachPortDeallocateNone = 0,
    NSMachPortDeallocateSendRight = (1UL << 0),
    NSMachPortDeallocateReceiveRight = (1UL << 1)
};

@class NSRunLoop, NSMutableArray, NSDate, NSConnection, NSPortMessage, NSData;

@protocol NSMachPortDelegate;

@protocol NSPortDelegate <NSObject>
@optional

- (void) handlePortMessage: (NSPortMessage *) message;

@end

@protocol NSMachPortDelegate <NSPortDelegate>
@optional

- (void) handleMachMessage: (void *) msg;

@end

FOUNDATION_EXPORT const NSNotificationName NSPortDidBecomeInvalidNotification;

@interface NSPort : NSObject <NSCopying, NSCoding>

@property (assign) id<NSPortDelegate> delegate;

+ (NSPort *) port;
- (void) invalidate;
- (BOOL) isValid;

- (void) scheduleInRunLoop: (NSRunLoop *) runLoop forMode: (NSRunLoopMode) mode;
- (void) removeFromRunLoop: (NSRunLoop *) runLoop forMode: (NSRunLoopMode) mode;

- (NSUInteger) reservedSpaceLength;

- (BOOL) sendBeforeDate: (NSDate *) limitDate
             components: (NSMutableArray *) components
                   from: (NSPort *) receivePort
               reserved: (NSUInteger) headerSpaceReserved;

- (BOOL) sendBeforeDate: (NSDate *) limitDate
                  msgid: (NSUInteger) msgID
             components: (NSMutableArray *) components
                   from: (NSPort *) receivePort
               reserved: (NSUInteger) headerSpaceReserved;

@end

NS_AUTOMATED_REFCOUNT_WEAK_UNAVAILABLE

@interface NSMachPort : NSPort
{
    id _delegate;
    NSUInteger _flags;
    uint32_t _machPort;
    NSUInteger _reserved;
}

+ (NSPort *) portWithMachPort: (uint32_t) machPort;
+ (NSPort *)portWithMachPort: (uint32_t) machPort options:(NSMachPortOptions) options;
- (id) initWithMachPort: (uint32_t) machPort NS_DESIGNATED_INITIALIZER;
- (id) initWithMachPort: (uint32_t) machPort options: (NSMachPortOptions) options;
- (uint32_t) machPort;

- (void) setDelegate: (id<NSMachPortDelegate>) anObject;
- (id <NSMachPortDelegate>)delegate;
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
- (void)removeFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

@end

NS_AUTOMATED_REFCOUNT_WEAK_UNAVAILABLE

@interface NSMessagePort : NSPort
@end


// For compatibility, also import concrete port types.
#import <Foundation/NSSocketPort.h>
