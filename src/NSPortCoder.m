#import <Foundation/NSPortCoder.h>
#import <Foundation/NSDistantObject.h>
#import <Foundation/NSConnection.h>
#import "NSConnectionInternal.h"
#import "NSUnkeyedPortCoder.h"
#import "NSObjectInternal.h"

@implementation NSPortCoder

+ (id) allocWithZone: (NSZone *) zone {
    if (self == [NSPortCoder class]) {
        return [NSUnkeyedPortCoder allocWithZone: zone];
    } else {
        return [super allocWithZone: zone];
    }
}

- (instancetype) initWithReceivePort: (NSPort *) recvPort
                            sendPort: (NSPort *) sendPort
                          components: (NSArray *) components
{
    NSRequestConcreteImplementation();
}

+ (instancetype) portCoderWithReceivePort: (NSPort *) recvPort
                                 sendPort: (NSPort *) sendPort
                               components: (NSArray *) components
{
    Class class = self;
    if (self == [NSPortCoder class]) {
        NSConnection *connection = [NSConnection lookUpConnectionWithReceivePort: recvPort
                                                                        sendPort: sendPort];
        if (connection) {
            class = [connection _portCoderClassWithComponents: components];
        }
    }
    return [[[class alloc] initWithReceivePort: recvPort
                                      sendPort: sendPort
                                    components: components]
               autorelease];
}

- (BOOL) isBycopy {
    NSRequestConcreteImplementation();
}

- (BOOL) isByref {
    NSRequestConcreteImplementation();
}

- (void) encodePortObject: (NSPort *) port {
    NSRequestConcreteImplementation();
}

- (NSPort *) decodePortObject {
    NSRequestConcreteImplementation();
}

- (NSConnection *) connection {
    NSRequestConcreteImplementation();
}

- (void) dispatch {
    NSRequestConcreteImplementation();
}

@end


@implementation NSObject (NSObjectPortCoding)

- (Class) classForPortCoder {
    return [self classForCoder];
}

- (id) replacementObjectForPortCoder: (NSPortCoder *) coder {
    id replacement = [self replacementObjectForCoder: coder];
    if (!replacement) {
        return nil;
    }
    return [NSDistantObject proxyWithLocal: replacement
                                connection: [coder connection]];
}

+ (id) replacementObjectForPortCoder: (NSPortCoder *) coder {
    return self;
}

@end

@implementation NSObject (NSDistantObjectAdditions)

+ (const char *) _localClassNameForClass {
    return object_getClassName(self);
}

- (const char *) _localClassNameForClass {
    return object_getClassName([self class]);
}

@end
