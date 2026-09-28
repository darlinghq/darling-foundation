#import <Foundation/NSData.h>
#import <Foundation/NSError.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>

#include <string.h>
#include <unistd.h>

static int fail(const char* message, int status)
{
	write(STDERR_FILENO, message, strlen(message));
	return status;
}

static NSString* string_argument(const char* value)
{
	return [NSString stringWithUTF8String:value];
}

int main(int argc, const char* argv[])
{
	@autoreleasepool {
		if (argc == 3 && strcmp(argv[1], "-lint") == 0) {
			NSString* path = string_argument(argv[2]);
			NSError* error = nil;
			NSData* data = [NSData dataWithContentsOfFile:path options:0 error:&error];
			id plist = data ? [NSPropertyListSerialization propertyListWithData:data
				options:NSPropertyListImmutable format:NULL error:&error] : nil;
			if (!plist || error)
				return fail("plutil: invalid property list\n", 1);
			write(STDOUT_FILENO, argv[2], strlen(argv[2]));
			write(STDOUT_FILENO, ": OK\n", 5);
			return 0;
		}

		if (argc < 4 || strcmp(argv[1], "-convert") != 0)
			return fail("usage: plutil -lint file | -convert xml1|binary1 [-o output] file\n", 64);

		NSPropertyListFormat format;
		if (strcmp(argv[2], "xml1") == 0)
			format = NSPropertyListXMLFormat_v1_0;
		else if (strcmp(argv[2], "binary1") == 0)
			format = NSPropertyListBinaryFormat_v1_0;
		else
			return fail("plutil: unsupported conversion format\n", 64);

		const char* outputPath = NULL;
		const char* inputPath = NULL;
		if (argc == 6 && strcmp(argv[3], "-o") == 0) {
			outputPath = argv[4];
			inputPath = argv[5];
		} else if (argc == 4) {
			outputPath = argv[3];
			inputPath = argv[3];
		} else {
			return fail("plutil: invalid conversion arguments\n", 64);
		}

		NSError* error = nil;
		NSData* input = [NSData dataWithContentsOfFile:string_argument(inputPath)
			options:0 error:&error];
		id plist = input ? [NSPropertyListSerialization propertyListWithData:input
			options:NSPropertyListImmutable format:NULL error:&error] : nil;
		if (!plist || error)
			return fail("plutil: input is not a property list\n", 1);
		NSData* output = [NSPropertyListSerialization dataWithPropertyList:plist
			format:format options:0 error:&error];
		if (!output || error || ![output writeToFile:string_argument(outputPath) options:0 error:&error])
			return fail("plutil: conversion failed\n", 1);
		return 0;
	}
}
