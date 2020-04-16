#import <Foundation/NSCoder.h>

@class NSConnection;
@class NSPort;

@interface NSPortCoder : NSCoder

- (instancetype) initWithReceivePort: (NSPort *) recvPort
                            sendPort: (NSPort *) sendPort
                          components: (NSArray *) components;

+ (instancetype) portCoderWithReceivePort: (NSPort *) recvPort
                                 sendPort: (NSPort *) sendPort
                               components: (NSArray *) components;

- (BOOL) isBycopy;
- (BOOL) isByref;

- (void) encodePortObject: (NSPort *) port;
- (NSPort *) decodePortObject;

- (NSConnection *) connection;
- (void) dispatch;

@end


@interface NSObject (NSDistributedObjects)

- (Class) classForPortCoder;
- (id) replacementObjectForPortCoder: (NSPortCoder *) coder;

@end
