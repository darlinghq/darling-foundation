#import <Foundation/NSObject.h>
#import <Foundation/NSData.h>

@interface NSDeserializer : NSObject
+(id) deserializePropertyListFromData:(NSData*)data mutableContainers:(BOOL)mutableContainers;
+(id) deserializePropertyListFromData:(NSData*)data atCursor:(unsigned int*)cursor mutableContainers:(BOOL)mutableContainers;
@end

@interface NSData (SerializerAdditions)
-(int)deserializeIntAtCursor:(unsigned int*)cursor;
-(int)deserializeIntAtIndex:(unsigned int)index;
-(void)deserializeInts:(int*) array count:(unsigned int) count atCursor:(unsigned int*)cursor;
-(void)deserializeBytes: (void*)buffer length: (unsigned int)bytes atCursor: (unsigned int*)cursor;
-(unsigned)deserializeAlignedBytesLengthAtCursor:(unsigned int*)cursor;
@end
