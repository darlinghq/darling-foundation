/* Copyright (c) 2007 Dirk Theisen

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

// 01/08/2007 original - Dirk Theisen

#import <Foundation/NSFileWrapper.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSException.h>
#import <Foundation/NSError.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/FoundationErrors.h>
#include <errno.h>
#include <math.h>
#include <sys/stat.h>

@interface NSFileWrapperFile : NSFileWrapper {
	NSData* contentData;
    NSFileWrapperReadingOptions readingOptions;
	NSDate* madeAt;
}

- (void) setReadingPath: (NSString*) path options: (NSFileWrapperReadingOptions) options;
@end

@interface NSFileWrapperDirectory : NSFileWrapper {
	NSMutableDictionary* contentDictionary;
	NSDate* madeAt;
}

@end

@interface NSFileWrapperLink : NSFileWrapper {	
	NSString* linkDestination;
}

@end

@interface NSFileWrapper (URLNodes)
// Take the contents of, or compare them with, the node at url. attributes are those of that node, whose kind is the receiver's.
- (BOOL) readContentsFromURL: (NSURL*) url attributes: (NSDictionary*) attributes options: (NSFileWrapperReadingOptions) options error: (NSError**) outError;
- (BOOL) matchesNodeAtURL: (NSURL*) url attributes: (NSDictionary*) attributes;
// The modification date the wrapper stands for: the one recorded from a node it was read from or given with
// -setFileAttributes:, else the moment a wrapper made from data was created.
- (NSDate*) recordedModificationDate;
- (NSDate*) madeAt;
@end

// The kind comparison below (directory, regular file, link, in that order), the error code for a node of another
// kind and the error for writing to a URL that is not a file URL have the same shape as SiliconForest's
// NSFileWrapperURL.m (MIT, Copyright (c) 2026 Chris Kearney and the SiliconForest contributors,
// https://github.com/chriskearney/siliconforest). The rest was written from the public documentation.
static BOOL fileWrapperHasKind(NSFileWrapper* wrapper, NSString* type)
{
	return ([wrapper isDirectory] && [type isEqualToString: NSFileTypeDirectory]) ||
	       ([wrapper isRegularFile] && [type isEqualToString: NSFileTypeRegular]) ||
	       ([wrapper isSymbolicLink] && [type isEqualToString: NSFileTypeSymbolicLink]);
}

// QUIRK: a node on disk counts as the one a wrapper recorded when the whole second of the node's modification
// date is the whole second of the recorded date or the one after it; the reference only says that the dates are
// compared. Evidence: black-box observation on macOS 26.7.3 and 10.14.4 (tier 2), identical on both, with
// recorded dates at several fractions of a second and offsets from -1.5 s to +2 s. The data and the permissions of a
// regular file are not looked at. Test: nsfilewrapper-read-match-url (the date tolerance cases).
static BOOL modificationDatesMatch(NSDate* recorded, NSDate* onDisk)
{
	if (!recorded || !onDisk) return NO;
	double recordedSecond = floor([recorded timeIntervalSince1970]);
	double diskSecond = floor([onDisk timeIntervalSince1970]);
	return diskSecond == recordedSecond || diskSecond == recordedSecond + 1;
}

// QUIRK: with NSFileWrapperWritingWithNameUpdating the descendants of a written directory record the names they
// were written under, but the wrapper written (data-built or read from elsewhere) keeps its own filename. The
// reference says the wrapper's filename is updated. Evidence: black-box observation on macOS 26.7.3 and 10.14.4
// (tier 2): the filename of a wrapper read from a file, and of a data-built one, was unchanged by a write under
// another name, while the children of a directory wrapper had theirs set. Test: nsfilewrapper-write-url (name updating).
static void recordChildNames(NSFileWrapper* wrapper)
{
	NSDictionary* children = [wrapper isDirectory] ? [wrapper fileWrappers] : nil;
	for (NSString* key in children) {
		NSFileWrapper* child = [children objectForKey: key];
		[child setFilename: key];
		recordChildNames(child);
	}
}

// Gives what was written at url the permissions (as a file created by the process would get them, that is with
// the umask applied) and the modification date recorded in the wrapper's attributes. Observed on macOS 26.7.3 and
// 10.14.4: a file written from a wrapper with permissions 0666 is 0644 under umask 022; with 0 it is 0.
// The umask can only be read by setting it, which is brief but process-wide.
static void applyRecordedAttributes(NSDictionary* recorded, NSURL* url)
{
	NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
	NSNumber* permissions = [recorded objectForKey: NSFilePosixPermissions];
	NSDate* date = [recorded objectForKey: NSFileModificationDate];
	if (permissions) {
		mode_t mask = umask(0);
		umask(mask);
		[attributes setObject: [NSNumber numberWithUnsignedShort: [permissions unsignedShortValue] & ~mask & 07777]
		               forKey: NSFilePosixPermissions];
	}
	if (date) [attributes setObject: date forKey: NSFileModificationDate];
	if ([attributes count]) [[NSFileManager defaultManager] setAttributes: attributes ofItemAtPath: [url path] error: NULL];
}

// The error for a child name that cannot be a place inside the destination. "." and ".." name the directory
// itself and its parent: macOS fails to write them as the unknown write error with EISDIR as the cause (observed
// on macOS 26.7.3 and 10.14.4). A name with a ".." component anywhere would leave the destination, which macOS
// follows (observed: "a/b" is only refused because a does not exist); that is refused here with
// NSFileWriteInvalidFileNameError, deliberately stricter than macOS. Pinned by tests/nsfilewrapper-write-url.m.
static NSError* childNameError(NSString* name, NSURL* target)
{
	if ([name isEqualToString: @"."] || [name isEqualToString: @".."]) {
		NSError* cause = [NSError errorWithDomain: NSPOSIXErrorDomain code: EISDIR userInfo: nil];
		return [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileWriteUnknownError
		                       userInfo: @{ NSURLErrorKey: target, NSUnderlyingErrorKey: cause }];
	}
	if ([[name pathComponents] containsObject: @".."]) {
		return [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileWriteInvalidFileNameError
		                       userInfo: @{ NSURLErrorKey: target }];
	}
	return nil;
}

// NSFileManager and NSData report the failure of a write as a POSIX error. The write methods of NSFileWrapper
// report a Cocoa error with that POSIX error as its cause, as macOS does (observed on macOS 26.7.3 and 10.14.4: a
// missing parent is NSFileNoSuchFileError, an existing item NSFileWriteFileExistsError, a refused write
// NSFileWriteNoPermissionError, anything else NSFileWriteUnknownError).
static NSError* cocoaWriteError(NSError* error, NSURL* url)
{
	if (![[error domain] isEqualToString: NSPOSIXErrorDomain]) return error;
	NSInteger code;
	switch ([error code]) {
		case ENOENT: code = NSFileNoSuchFileError; break;
		case EEXIST: code = NSFileWriteFileExistsError; break;
		case EACCES:
		case EPERM: code = NSFileWriteNoPermissionError; break;
		case ENOSPC: code = NSFileWriteOutOfSpaceError; break;
		case EROFS: code = NSFileWriteVolumeReadOnlyError; break;
		default: code = NSFileWriteUnknownError; break;
	}
	NSMutableDictionary* info = [NSMutableDictionary dictionaryWithObject: error forKey: NSUnderlyingErrorKey];
	if (url) [info setObject: url forKey: NSURLErrorKey];
	return [NSError errorWithDomain: NSCocoaErrorDomain code: code userInfo: info];
}

// Writes a directory or link wrapper by calling write with url. With NSFileWrapperWritingAtomic it is called
// with a temporary name next to url, which is moved over url afterwards, so that url is replaced completely or
// not at all.
static BOOL writeNode(NSFileWrapper* wrapper, NSURL* url, NSFileWrapperWritingOptions options, NSError** outError,
                      BOOL (^write)(NSURL* target, NSError** error))
{
	NSError* error = nil;
	BOOL done = NO;
	if (![url isFileURL]) {
		error = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileWriteUnsupportedSchemeError
		                        userInfo: url ? @{ NSURLErrorKey: url } : nil];
	} else if (!(options & NSFileWrapperWritingAtomic)) {
		done = write(url, &error);
	} else {
		NSString* temporaryName = [NSString stringWithFormat: @".%@.%@", [url lastPathComponent],
		                           [[NSProcessInfo processInfo] globallyUniqueString]];
		NSURL* temporary = [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent: temporaryName];
		done = write(temporary, &error) && [[NSFileManager defaultManager] replaceItemAtURL: url withItemAtURL: temporary
		                                                                     backupItemName: nil options: 0
		                                                                   resultingItemURL: NULL error: &error];
		if (!done) [[NSFileManager defaultManager] removeItemAtURL: temporary error: NULL];
	}
	if (done && (options & NSFileWrapperWritingWithNameUpdating)) recordChildNames(wrapper);
	if (!done && outError) {
		// Every failure above carries an error; this only covers one that did not.
		*outError = error ? cocoaWriteError(error, url) :
		            [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileWriteUnknownError userInfo: url ? @{ NSURLErrorKey: url } : nil];
	}
	return done;
}

static NSDataReadingOptions dataReadingOptions(NSFileWrapperReadingOptions options)
{
	return (options & NSFileWrapperReadingWithoutMapping) ? 0 : NSDataReadingMappedIfSafe;
}

// The error for a failed read of the node at url (path is nil for a URL that is not a file URL).
static NSError* fileWrapperReadError(NSURL* url, NSString* path, NSError* cause)
{
	if (!path) {
		return [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileReadUnsupportedSchemeError
		                       userInfo: url ? @{ NSURLErrorKey: url } : nil];
	}
	// Preserve the existing missing-file Cocoa error while retaining its cause.
	if ([[cause domain] isEqualToString: NSPOSIXErrorDomain] && [cause code] == ENOENT) {
		return [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileReadNoSuchFileError
		                       userInfo: @{ NSURLErrorKey: url, NSUnderlyingErrorKey: cause }];
	}
	return cause ?: [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileReadUnknownError
	                                userInfo: @{ NSURLErrorKey: url, NSFilePathErrorKey: path }];
}

@implementation NSFileWrapper

+ (id) alloc
{
	static NSFileWrapper* sharedInstance = nil;
	if (!sharedInstance) sharedInstance = [super alloc];
	return sharedInstance;
}

- (BOOL) updateFromPath: (NSString*) path attributes: (NSDictionary*) attrs
{
    [_path release];
    _path = [path copy];
    _fileAttributes = [[attrs mutableCopy] retain];
    return attrs != nil;
}

- (BOOL) updateFromPath: (NSString*) path
{
	if ([self needsToBeUpdatedFromPath: path]) {
		[_fileAttributes release];
		_fileAttributes = nil;
		NSDictionary* attrs = [[NSFileManager defaultManager] fileAttributesAtPath: path traverseLink: NO];
		return [self updateFromPath: path attributes: attrs];
	}
	return NO;
}

/**
 * Init an instance from the file, directory, or symbolic link at the given absolute path.<br /> 
 */
- (id) initWithPath: (NSString*)path
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSFileManager* fm = [NSFileManager defaultManager];
	
	if (NSDebugEnabled) NSLog(@"NSFileWrapper", @"initWithPath: %@", path);
	NSDictionary* attrs = [[fm fileAttributesAtPath: path traverseLink: NO] retain];
	
	NSString* fileType = [attrs fileType];
	if ([fileType isEqualToString: NSFileTypeDirectory]) {
		self = [self initDirectoryWithFileWrappers: nil];
    } else if ([fileType isEqualToString: NSFileTypeRegular]) {
		self = [self initRegularFileWithContents: nil];
    } else if ([fileType isEqualToString: NSFileTypeSymbolicLink]) {
		self = [self initSymbolicLinkWithDestination: 
			nil];
    } else {
		self = nil; // should never happen
	}
	[self updateFromPath: path attributes: attrs];

	// Store the full path in filename, the specification is unclear in this point
	[self setFilename: [path lastPathComponent]];
	[self setPreferredFilename: [self filename]];
	
	[pool release];
	return self;
}

- (id) initWithURL: (NSURL*) url options: (NSFileWrapperReadingOptions) options error: (NSError**) outError
{
	NSString* path = [url isFileURL] ? [url path] : nil;
    NSError* error = nil;
    NSFileWrapper* result = nil;
    NSFileManager* manager = [NSFileManager defaultManager];
    if (path) {
        NSDictionary* attributes = [manager attributesOfItemAtPath: path error: &error];
        NSString* type = [attributes objectForKey: NSFileType];
        if ([type isEqualToString: NSFileTypeDirectory]) {
            NSArray* names = [manager contentsOfDirectoryAtPath: path error: &error];
            if (names) {
                NSMutableDictionary* children = [NSMutableDictionary dictionary];
                BOOL complete = YES;
                for (NSString* name in names) {
                    NSFileWrapper* child = [[NSFileWrapper alloc]
                        initWithURL: [url URLByAppendingPathComponent: name] options: options error: &error];
                    if (!child) { complete = NO; break; }
                    [children setObject: child forKey: name];
                    [child release];
                }
                if (complete) result = [self initDirectoryWithFileWrappers: children];
            }
        } else if ([type isEqualToString: NSFileTypeRegular]) {
            NSData* data = nil;
            if (options & NSFileWrapperReadingImmediate) {
                data = [NSData dataWithContentsOfURL: url options: dataReadingOptions(options) error: &error];
            }
            if (!(options & NSFileWrapperReadingImmediate) || data) {
                result = [self initRegularFileWithContents: data];
                [(NSFileWrapperFile*)result setReadingPath: path options: options];
            }
        } else if ([type isEqualToString: NSFileTypeSymbolicLink]) {
            NSString* destination = [manager destinationOfSymbolicLinkAtPath: path error: &error];
            if (destination) result = [self initSymbolicLinkWithDestination: destination];
        }
        if (result) {
            [result setFileAttributes: attributes];
            [result setFilename: [path lastPathComponent]];
            [result setPreferredFilename: [result filename]];
            return result;
        }
    }
    if (outError) *outError = fileWrapperReadError(url, path, error);
    // self is the shared +alloc placeholder, which must never be released.
    return nil;
}

- (BOOL) readFromURL: (NSURL*) url options: (NSFileWrapperReadingOptions) options error: (NSError**) outError
{
	NSString* path = [url isFileURL] ? [url path] : nil;
	NSError* error = nil;
	NSDictionary* attributes = path ? [[NSFileManager defaultManager] attributesOfItemAtPath: path error: &error] : nil;
	// DEVIATION from macOS, which this cannot follow: a wrapper cannot change its kind here, so a node of another
	// kind is reported as the unknown read error and the wrapper is left as it was. On macOS 26.7.3 and 10.14.4 a
	// regular, directory or link wrapper becomes the kind of a regular file or link it reads, and reading a directory
	// into a wrapper that is not one raises. Pinned by tests/nsfilewrapper-read-match-url.m.
	if (attributes && fileWrapperHasKind(self, [attributes objectForKey: NSFileType])) {
		// The contents are read only when the wrapper no longer matches the node (see modificationDatesMatch); the
		// recorded attributes are brought up to date either way (a permissions-only change is picked up).
		BOOL read = [self matchesNodeAtURL: url attributes: attributes] ||
		            [self readContentsFromURL: url attributes: attributes options: options error: &error];
		if (read) {
			[_fileAttributes release];
			_fileAttributes = nil;
			[self setFileAttributes: attributes];
			return YES;
		}
	}
	if (outError) *outError = fileWrapperReadError(url, path, error);
	return NO;
}

- (BOOL) matchesContentsOfURL: (NSURL*) url
{
	NSDictionary* attributes = [url isFileURL] ?
		[[NSFileManager defaultManager] attributesOfItemAtPath: [url path] error: NULL] : nil;
	return attributes && fileWrapperHasKind(self, [attributes objectForKey: NSFileType]) &&
	       [self matchesNodeAtURL: url attributes: attributes];
}

// A regular file or link wrapper matches the node when the dates match. Observed on macOS 26.7.3 and 10.14.4: the
// contents, the permissions and a link's destination are not compared, and a link wrapper made from a destination
// has no date and matches nothing.
- (BOOL) matchesNodeAtURL: (NSURL*) url attributes: (NSDictionary*) attributes
{
	return modificationDatesMatch([self recordedModificationDate], [attributes objectForKey: NSFileModificationDate]);
}

- (NSDate*) recordedModificationDate
{
	return [[self fileAttributes] objectForKey: NSFileModificationDate] ?: [self madeAt];
}

- (NSDate*) madeAt
{
	return nil;
}

- (NSData*) regularFileContents
{
	[NSException raise: NSInternalInconsistencyException format: @"Try to access regular file content of something not regular file."];
	return nil;
}

- (NSString*) symbolicLinkDestination
{
	[NSException raise: NSInternalInconsistencyException format: @"Try to access symbolic link destination of something not a link wrapper."];
	return nil;
}

- (NSURL*) symbolicLinkDestinationURL
{
	return [NSURL fileURLWithPath: [self symbolicLinkDestination]];
}


// Init and return an instance for a regular file type
- (id) initRegularFileWithContents: (NSData*) data
{
	return [[NSFileWrapperFile alloc] initRegularFileWithContents: data];
}

// Init and return an instance for a directory type
- (id) initDirectoryWithFileWrappers: (NSDictionary*) docs;
{	
	return [[NSFileWrapperDirectory alloc] initDirectoryWithFileWrappers: docs];
}

// Init and return an instance for a symbolic link type
- (id) initSymbolicLinkWithDestination: (NSString*) path
{
	return [[NSFileWrapperLink alloc] initSymbolicLinkWithDestination: path];
}

- (id) initSymbolicLinkWithDestinationURL: (NSURL*) url
{
	return [self initSymbolicLinkWithDestination: [url path]];
}

- (NSString *)filename
{
	return _filename;
}

- (void) setFilename: (NSString*) filename 
{
	if ([filename length]) {
		if (filename != _filename) {
			[_filename autorelease];
			_filename = [filename retain];
		}
		return;
	}	
	[NSException raise: NSInternalInconsistencyException format: @"-[NSFileWrapper setFilename:] filename may not be nil or empty."];
}

- (NSString*) preferredFilename
{
	return _preferredFilename;
}


- (void) setPreferredFilename: (NSString*) preferredFilename 
{
	if ([preferredFilename length]) {
		if (preferredFilename != _preferredFilename) {
			[_preferredFilename autorelease];
			_preferredFilename = [preferredFilename retain];
		}
		return;
	}
	[NSException raise: NSInternalInconsistencyException format: @"-[NSFileWrapper setPreferredFilename:] preferredFilename may not be nil or empty."];
}

- (void) setFileAttributes: (NSDictionary*) attributes
{
	if (! _fileAttributes) {
		_fileAttributes = [[NSMutableDictionary alloc] init];
    }
	
	[_fileAttributes addEntriesFromDictionary: attributes];
}

- (NSDictionary*) fileAttributes
{
	return _fileAttributes;
}

- (BOOL) isRegularFile
{
	return NO;
}

- (BOOL) isDirectory
{
	return NO;
}

- (BOOL) isSymbolicLink
{
	return NO;
}

- (void)removeFileWrapper: (NSFileWrapper *)wrapper
{
	[NSException raise: NSInternalInconsistencyException format: @"-[NSFileWrapper %@] sent to a non directory file wrapper.", NSStringFromSelector(_cmd)];
}


- (NSString*) addFileWrapper: (NSFileWrapper*) wrapper
{
	[NSException raise: NSInternalInconsistencyException format: @"-[NSFileWrapper %@] sent to a non directory file wrapper.", NSStringFromSelector(_cmd)];
	return nil;
}

- (NSString*) addRegularFileWithContents: (NSData*) data preferredFilename: (NSString*) filename
{
	// The receiver is checked before the arguments: a non directory raises this, whatever the name is.
	[NSException raise: NSInternalInconsistencyException format: @"-[NSFileWrapper %@] sent to a non directory file wrapper.", NSStringFromSelector(_cmd)];
	return nil;
}

- (NSString*) keyForFileWrapper: (NSFileWrapper*) child
{
	[NSException raise: NSInternalInconsistencyException format: @"-[NSFileWrapper %@] sent to a non directory file wrapper.", NSStringFromSelector(_cmd)];
	return nil;
}

- (NSDictionary*) fileWrappers
{
	[NSException raise: NSInternalInconsistencyException format: @"-[NSFileWrapper %@] sent to a non directory file wrapper.", NSStringFromSelector(_cmd)];
	return nil;
}

- (BOOL) writeToFile: (NSString*) path
         atomically: (BOOL) atomicFlag
    updateFilenames: (BOOL) updateFilenamesFlag
{
	NSAssert(NO, @"Implemented in concrete subclasses.");
	return NO;
}


- (BOOL) needsToBeUpdatedFromPath: (NSString*) path
{
	NSDate* changeDateSelf = [[self fileAttributes] fileModificationDate];
	NSDate* changeDatePath = [[[NSFileManager defaultManager] fileAttributesAtPath: path 
																	  traverseLink: NO] fileModificationDate];
	return [changeDatePath compare: changeDateSelf] > 0;
}


- (void) dealloc
{
    [_path release];
	[_fileAttributes release];
	[_preferredFilename release];
	[_filename release];
	[super dealloc];
}


@end

@implementation NSFileWrapperFile

- (void) setReadingPath: (NSString*) path options: (NSFileWrapperReadingOptions) options
{
    [_path release];
    _path = [path copy];
    readingOptions = options;
}

+ (id) alloc
{
	return NSAllocateObject(self, 0, NULL);
}

// Init instance of regular file type
- (id) initRegularFileWithContents: (NSData*) data
{	
	if ((self = [self init])!=nil) {
		contentData = [data copy];
		madeAt = [[NSDate alloc] init];
	} 
	return self;
}

- (NSDate*) madeAt
{
	return madeAt;
}


- (BOOL) updateFromPath: (NSString*) path attributes: (NSDictionary*) attrs
{
	if ([super updateFromPath: path attributes: attrs]) {
		[contentData release];
        contentData = nil;
		
		return YES;
	}
	return NO;
}

- (BOOL) readContentsFromURL: (NSURL*) url attributes: (NSDictionary*) attributes options: (NSFileWrapperReadingOptions) options error: (NSError**) outError
{
	NSData* data = nil;
	if (options & NSFileWrapperReadingImmediate) {
		data = [NSData dataWithContentsOfURL: url options: dataReadingOptions(options) error: outError];
		if (!data) return NO;
	}
	[contentData release];
	contentData = [data copy];
	[self setReadingPath: [url path] options: options];
	return YES;
}

- (BOOL) isRegularFile
{
	return YES;
}

- (NSData*) regularFileContents
{
    if (contentData == nil) {
        contentData = [[NSData alloc] initWithContentsOfFile: _path options: dataReadingOptions(readingOptions) error: NULL];
    }
	return contentData;
}

- (BOOL) writeToFile: (NSString*) path
		  atomically: (BOOL) atomicFlag
	 updateFilenames: (BOOL) updateFilenamesFlag
{
	BOOL result = [[self regularFileContents] writeToFile: path 
											   atomically: atomicFlag];
	if ([self fileAttributes]) {
		[[NSFileManager defaultManager] changeFileAttributes: [self fileAttributes]
													  atPath: path];
	}
	if (updateFilenamesFlag) {
		[self setFilename: [path lastPathComponent]];
	}
	return result;
}

- (BOOL)   writeToURL: (NSURL *) url
              options: (NSFileWrapperWritingOptions) options
  originalContentsURL: (NSURL *) originalContentsURL
                error: (NSError **)error
{
	NSFileManager* manager = [NSFileManager defaultManager];
	BOOL atomic = (options & NSFileWrapperWritingAtomic) != 0;
	// Contents that have not changed are those that still match the earlier revision (matchesContentsOfURL:). They
	// are hard-linked to it instead of written; the earlier revision is also the destination when a wrapper is
	// saved over its own file, and then, observed on macOS 26.7.3 and 10.14.4, a non-atomic write leaves the file
	// alone (same inode) while an atomic one replaces it.
	BOOL unchanged = originalContentsURL && [url isFileURL] && [self matchesContentsOfURL: originalContentsURL];
	BOOL sameFile = unchanged && [[originalContentsURL path] isEqualToString: [url path]];
	BOOL result = (sameFile && !atomic) ||
	              (unchanged && !sameFile && [manager linkItemAtURL: originalContentsURL toURL: url error: NULL]);
	if (!result) {
		NSError* cause = nil;
		result = [[self regularFileContents] writeToURL: url options: atomic ? NSDataWritingAtomic : 0 error: &cause];
		if (result) applyRecordedAttributes([self fileAttributes], url);
		else if (error) *error = cocoaWriteError(cause, url);
	}
	return result;
}

- (void) dealloc
{
	[madeAt release];
	[contentData release];
	[super dealloc];
}

@end

@implementation NSFileWrapperDirectory

- (id) initDirectoryWithFileWrappers: (NSDictionary*) docs;
{
	if ((self = [self init])!=nil) {
		madeAt = [[NSDate alloc] init];
		contentDictionary = [docs mutableCopy];
		
		NSEnumerator* ke = [contentDictionary keyEnumerator];
		NSString* name;
		while ((name = [ke nextObject])!=nil) {
			NSFileWrapper* wrapper = [contentDictionary objectForKey: name];
			if ([[wrapper preferredFilename] length] == 0) {
				[wrapper setPreferredFilename: name];
			}
		}
	}	
	return self;
}

- (BOOL) isDirectory
{
	return YES;
}

- (NSDate*) madeAt
{
	return madeAt;
}

- (NSDictionary*) fileWrappers
{
		return contentDictionary;
}

- (NSString*) keyForFileWrapper: (NSFileWrapper*) child
{
	// A nil or foreign child has no key. A child stored under two keys gives one of them; which one is unspecified.
	// Observed by black-box test on macOS 26.7.3 and 10.14.4, pinned by tests/nsfilewrapper-key-and-add-regular-file.m.
	return child ? [[contentDictionary allKeysForObject: child] firstObject] : nil;
}

- (NSString*) addRegularFileWithContents: (NSData*) data preferredFilename: (NSString*) filename
{
	if (![filename length]) {
		[NSException raise: NSInvalidArgumentException format: @"-[NSFileWrapper %@] filename may not be nil or empty.", NSStringFromSelector(_cmd)];
	}
	NSFileWrapper* child = [[[NSFileWrapper alloc] initRegularFileWithContents: data] autorelease];
	[child setPreferredFilename: filename];
	return [self addFileWrapper: child];
}

- (NSString*) addFileWrapper: (NSFileWrapper*) wrapper
{
	if (!contentDictionary) {
		contentDictionary = [[NSMutableDictionary alloc] init]; 
	}
	NSParameterAssert([[wrapper preferredFilename] length]>0);
	NSString* name = [wrapper preferredFilename];
	while ([contentDictionary objectForKey: name]) {
		// append random number to prefered name:
		name = [NSString stringWithFormat: @"%@-%x", [wrapper preferredFilename], rand()];
	}
	[contentDictionary setObject: wrapper forKey: name];
	return name;
}


- (BOOL) writeToFile: (NSString*) path
		  atomically: (BOOL) atomicFlag
	 updateFilenames: (BOOL) updateFilenamesFlag
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSDictionary* wrappers = [self fileWrappers];
	NSEnumerator* enumerator = [wrappers keyEnumerator];
	NSString* key;
	BOOL result = YES;
	
	[fm createDirectoryAtPath: path attributes: [self fileAttributes]];
	if ([self fileAttributes]) {
		[[NSFileManager defaultManager] changeFileAttributes: [self fileAttributes]
													  atPath: path];
	}
	while ((key = [enumerator nextObject])) {
		NSString* newPath = [path stringByAppendingPathComponent: key];
		result &= [[wrappers objectForKey: key] writeToFile: newPath
												 atomically: atomicFlag
											updateFilenames: updateFilenamesFlag];
	}
	
	if (updateFilenamesFlag) {
		[self setFilename: [path lastPathComponent]];
	}
	return result;
}


- (BOOL) readContentsFromURL: (NSURL*) url attributes: (NSDictionary*) attributes options: (NSFileWrapperReadingOptions) options error: (NSError**) outError
{
	NSFileManager* manager = [NSFileManager defaultManager];
	NSArray* names = [manager contentsOfDirectoryAtPath: [url path] error: outError];
	if (!names) return NO;
	// Children are added and removed to match the directory. If a later child cannot be created the receiver's own
	// list is unchanged, while the children that were reread stay reread.
	NSMutableDictionary* children = [NSMutableDictionary dictionaryWithCapacity: [names count]];
	for (NSString* name in names) {
		NSURL* childURL = [url URLByAppendingPathComponent: name];
		NSFileWrapper* child = [contentDictionary objectForKey: name];
		if (child) {
			NSString* type = [[manager attributesOfItemAtPath: [childURL path] error: NULL] objectForKey: NSFileType];
			if (fileWrapperHasKind(child, type)) {
				// Observed on macOS 26.7.3 and 10.14.4: a child that cannot be reread (an unreadable file) does not
				// fail the read of the directory and keeps what it had.
				[child readFromURL: childURL options: options error: NULL];
			} else {
				// DEVIATION from macOS: a child whose node changed kind is replaced by a new wrapper here, where
				// macOS turns the same wrapper into the new kind (and raises when a directory replaced a file).
				child = nil;
			}
		}
		if (!child) {
			child = [[[NSFileWrapper alloc] initWithURL: childURL options: options error: outError] autorelease];
			if (!child) return NO;
		}
		[children setObject: child forKey: name];
	}
	[contentDictionary release];
	contentDictionary = [children retain];
	return YES;
}

// A directory wrapper matches when its own date matches and every child it has matches the entry of that name;
// entries the wrapper lacks are not looked at (observed on macOS 26.7.3 and 10.14.4: adding an entry on disk does
// not break the match, removing one the wrapper has does).
- (BOOL) matchesNodeAtURL: (NSURL*) url attributes: (NSDictionary*) attributes
{
	if (![super matchesNodeAtURL: url attributes: attributes]) return NO;
	for (NSString* name in contentDictionary) {
		if (![[contentDictionary objectForKey: name] matchesContentsOfURL: [url URLByAppendingPathComponent: name]]) return NO;
	}
	return YES;
}

- (BOOL) writeToURL: (NSURL*) url options: (NSFileWrapperWritingOptions) options
 originalContentsURL: (NSURL*) originalContentsURL error: (NSError**) outError
{
	NSDictionary* children = contentDictionary;
	NSDictionary* recorded = [self fileAttributes];
	return writeNode(self, url, options, outError, ^BOOL(NSURL* target, NSError** error) {
		// The directory has to be new. Observed on macOS 26.7.3 and 10.14.4: without the atomic option, writing a
		// directory where anything exists fails with NSFileWriteFileExistsError, so the directory is not written
		// into, a link in the way is not followed, and the atomic option is what replaces. DEVIATION: macOS also
		// removes what it found there before failing; this does not.
		if (![[NSFileManager defaultManager] createDirectoryAtURL: target withIntermediateDirectories: NO attributes: nil error: error]) {
			return NO;
		}
		for (NSString* name in children) {
			NSError* nameError = childNameError(name, target);
			if (nameError) {
				if (error) *error = nameError;
				return NO;
			}
			NSFileWrapper* child = [children objectForKey: name];
			// The earlier revision of a child is where its filename says it was.
			NSURL* original = ([child filename] && originalContentsURL) ?
				[originalContentsURL URLByAppendingPathComponent: [child filename]] : nil;
			// The directory is new, so nothing is in the way of its children and they need no atomic write.
			if (![child writeToURL: [target URLByAppendingPathComponent: name] options: 0
			   originalContentsURL: original error: error]) {
				return NO;
			}
		}
		applyRecordedAttributes(recorded, target);
		return YES;
	});
}

- (void) removeFileWrapper: (NSFileWrapper*) wrapper
{
	NSArray* keys = [contentDictionary allKeysForObject: wrapper];
	if ([keys count]) {
		[contentDictionary removeObjectsForKeys: keys];
	}
}

- (BOOL) updateFromPath: (NSString*) path attributes: (NSDictionary*) attrs
{	
	if ([super updateFromPath: path attributes: attrs]) {
		
		NSMutableDictionary* newContentDictionary = [[NSMutableDictionary alloc] init];
		NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager] enumeratorAtPath: path];
		NSString* filename;
		
		while ((filename = [enumerator nextObject]) != nil) {
			[enumerator skipDescendents];
			NSString* absolutePath = [path stringByAppendingPathComponent: filename];
			// Try to recycle an old wrapper (and data!)
			NSFileWrapper* wrapper = [contentDictionary objectForKey: filename];
			if (wrapper) {
				// The old dictionary owns the recycled wrapper; the new one takes its own reference.
				[wrapper updateFromPath: absolutePath];
				[newContentDictionary setObject: wrapper forKey: filename];
			} else {
				// Only a wrapper created here carries a reference of ours to give up.
				wrapper = [[[NSFileWrapper class] alloc] initWithPath: absolutePath];
				[newContentDictionary setObject: wrapper forKey: filename];
				[wrapper release];
			}
		}	
		
		[contentDictionary release];
		contentDictionary = newContentDictionary;
		return YES;
	}
	return NO;
}

+ (id) alloc
{
	return NSAllocateObject(self, 0, NULL);
}

- (void) dealloc
{
	[madeAt release];
	[contentDictionary release];
	[super dealloc];
}


@end

@implementation NSFileWrapperLink

- (id) initSymbolicLinkWithDestination: (NSString*) path
{	
	if ((self = [self init])!=nil) {
		linkDestination = [path copy];
	}	
	return self;
}

- (BOOL) isSymbolicLink
{
	return YES;
}

- (NSString*) symbolicLinkDestination
{
	return linkDestination;
}

- (BOOL) writeToFile: (NSString*) path
		  atomically: (BOOL) atomicFlag
	 updateFilenames: (BOOL) updateFilenamesFlag
{
	BOOL result = [[NSFileManager defaultManager] createSymbolicLinkAtPath: path 
															   pathContent: [self symbolicLinkDestination]];
	if ([self fileAttributes]) {
		[[NSFileManager defaultManager] changeFileAttributes: [self fileAttributes]
													  atPath: path];
	}
	if (updateFilenamesFlag) {
		[self setFilename: [path lastPathComponent]];
	}
	return result;
}

- (BOOL) writeToURL: (NSURL*) url options: (NSFileWrapperWritingOptions) options
 originalContentsURL: (NSURL*) originalContentsURL error: (NSError**) outError
{
	NSString* destination = linkDestination;
	// A link is not written over anything that exists, without the atomic option: that fails with the error of
	// creating the link (NSFileWriteFileExistsError), observed on macOS 26.7.3 and 10.14.4.
	return writeNode(self, url, options, outError, ^BOOL(NSURL* target, NSError** error) {
		return [[NSFileManager defaultManager] createSymbolicLinkAtPath: [target path] withDestinationPath: destination error: error];
	});
}

- (BOOL) readContentsFromURL: (NSURL*) url attributes: (NSDictionary*) attributes options: (NSFileWrapperReadingOptions) options error: (NSError**) outError
{
	NSString* destination = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath: [url path] error: outError];
	if (!destination) return NO;
	[linkDestination release];
	linkDestination = [destination copy];
	return YES;
}

- (BOOL) updateFromPath: (NSString*) path attributes: (NSDictionary*) attrs
{	
	if ([super updateFromPath: path attributes: attrs]) {
		[linkDestination release];
		linkDestination = [[[NSFileManager defaultManager] pathContentOfSymbolicLinkAtPath: path] copy];
		return YES;
	}
	return NO;
}

+ (id) alloc
{
	return NSAllocateObject(self, 0, NULL);
}

- (void) dealloc
{
	[linkDestination release];
	[super dealloc];
}


@end
