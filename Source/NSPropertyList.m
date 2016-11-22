#import <Foundation/NSPropertyList.h>
#include <CoreFoundation/CFPropertyList.h>

@implementation NSPropertyListSerialization
+ (NSData*) dataFromPropertyList: (id)aPropertyList
			  format: (NSPropertyListFormat)aFormat
		errorDescription: (NSString**)anErrorString
{
	CFDataRef data;
	CFErrorRef error = NULL;

	data = CFPropertyListCreateData(NULL, aPropertyList,
		aFormat, 0, &error);
	if (error != NULL)
	{
		if (anErrorString != NULL)
			*anErrorString = CFErrorCopyDescription(error);
		CFRelease(error);
	}

	AUTORELEASE(data);
	return (NSData*) data;
}

+ (BOOL) propertyList: (id)aPropertyList
     isValidForFormat: (NSPropertyListFormat)aFormat
{
	// TODO: examine aPropertyList and validate types
	return YES;
}

+ (id) propertyListFromData: (NSData*)data
	   mutabilityOption: (NSPropertyListMutabilityOptions)anOption
		     format: (NSPropertyListFormat*)aFormat
	   errorDescription: (NSString**)anErrorString
{
	CFPropertyListRef list;
	CFErrorRef error = NULL;

	list = CFPropertyListCreateWithData(NULL, (CFDataRef*) data,
		anOption, (CFPropertyListFormat*) aFormat, &error);
	
	if (error != NULL)
	{
		if (anErrorString != NULL)
			*anErrorString = CFErrorCopyDescription(error);
		CFRelease(error);
	}

	AUTORELEASE(list);
	return list;
}

+ (NSData *) dataWithPropertyList: (id)aPropertyList
                           format: (NSPropertyListFormat)aFormat
                          options: (NSPropertyListWriteOptions)anOption
                            error: (out NSError**)error
{
	CFDataRef data;

	data = CFPropertyListCreateData(NULL, aPropertyList,
		aFormat, anOption, (CFErrorRef*) error);

	AUTORELEASE(data);
	return (NSData*) data;
}

+ (id) propertyListWithData: (NSData*)data
                    options: (NSPropertyListReadOptions)anOption
                     format: (NSPropertyListFormat*)aFormat
                      error: (out NSError**)error
{
	CFPropertyListRef list;

	list = CFPropertyListCreateWithData(NULL, (CFDataRef*) data,
		anOption, (CFPropertyListFormat*) aFormat, (CFErrorRef*)error);
	
	AUTORELEASE(list);
	return list;
}

+ (id) propertyListWithStream: (NSInputStream*)stream
                      options: (NSPropertyListReadOptions)anOption
                       format: (NSPropertyListFormat*)aFormat
                        error: (out NSError**)error
{
	CFPropertyListRef list;

	list = CFPropertyListCreateWithStream(NULL,
		(CFReadStreamRef) stream, 0, anOption,
		(CFPropertyListFormat*) aFormat,
		(CFErrorRef*) error);
	
	AUTORELEASE(list);
	return list;
}

+ (NSInteger) writePropertyList: (id)aPropertyList
                       toStream: (NSOutputStream*)stream
                         format: (NSPropertyListFormat)aFormat
                        options: (NSPropertyListWriteOptions)anOption
                          error: (out NSError**)error
{
	CFIndex ret;

	ret = CFPropertyListWrite(aPropertyList, (CFWriteStreamRef) stream,
		(CFPropertyListFormat) aFormat, anOption,
		(CFErrorRef*) error);
	
	return ret;
}
@end

