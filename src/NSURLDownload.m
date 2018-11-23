/* Darling, Andrew Hyatt, 2018 */

#import <Foundation/NSURLDownload.h>
#import <Foundation/NSObjCRuntime.h>

@implementation NSURLDownload

+ (BOOL) canResumeDownloadDecodedWithEncodingMIMEType: (NSString *)MIMEType
{
	NSLog(@"NSURLDownload canResumeDownloadDecodedWithEncodingMIMEType:");
	return NO;
}

- (void) cancel
{
	NSLog(@"NSURLDownload cancel");
}

- (BOOL) deletesFileUponFailure
{
	NSLog(@"NSURLDownload deletesFileUponFailure");
	return YES;
}

- (id) initWithRequest: (NSURLRequest *)request delegate: (id)delegate
{
	NSLog(@"NSURLDownload initWithRequest");
	return [super init];
}

- (id) initWithResumeData: (NSData *)resumeData
		 delegate: (id)delegate
		     path: (NSString *)path
{
	NSLog(@"NSURLDownload initWithResumeData");
	return [super init];
}

- (NSURLRequest *) request
{
	NSLog(@"NSURLDownload request");
	return nil;
}

- (NSData *) resumeData
{
	NSLog(@"NSURLDownload resumeData");
	return nil;
}

- (void) setDeletesFileUponFailure: (BOOL)deletesFileUponFailure
{
	NSLog(@"NSURLDownload setDeletesFileUponFailure");
}

- (void) setDestination: (NSString *)path allowOverwrite: (BOOL)allowOverwrite
{
	NSLog(@"NSURLDownload setDestination");
}

@end
