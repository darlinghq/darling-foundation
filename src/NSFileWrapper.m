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
#import <Foundation/FoundationErrors.h>
#include <errno.h>

@interface NSFileWrapperFile : NSFileWrapper {
	NSData* contentData;
    NSFileWrapperReadingOptions readingOptions;
}

- (void) setReadingPath: (NSString*) path options: (NSFileWrapperReadingOptions) options;
@end

@interface NSFileWrapperDirectory : NSFileWrapper {
	NSMutableDictionary* contentDictionary;
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
@end

static BOOL fileWrapperHasKind(NSFileWrapper* wrapper, NSString* type)
{
	return ([wrapper isDirectory] && [type isEqualToString: NSFileTypeDirectory]) ||
	       ([wrapper isRegularFile] && [type isEqualToString: NSFileTypeRegular]) ||
	       ([wrapper isSymbolicLink] && [type isEqualToString: NSFileTypeSymbolicLink]);
}

// With NSFileWrapperWritingWithNameUpdating a written wrapper and its descendants record the names they were
// written under.
static void recordWrittenNames(NSFileWrapper* wrapper, NSString* name)
{
	[wrapper setFilename: name];
	NSDictionary* children = [wrapper isDirectory] ? [wrapper fileWrappers] : nil;
	for (NSString* key in children) recordWrittenNames([children objectForKey: key], key);
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
	if (done && (options & NSFileWrapperWritingWithNameUpdating)) recordWrittenNames(wrapper, [url lastPathComponent]);
	if (!done && outError) {
		// GUESS: a failure that gave no error is NSFileWriteUnknownError; the reference names no error.
		*outError = error ?: [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileWriteUnknownError
		                                     userInfo: @{ NSURLErrorKey: url }];
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
	// GUESS: the documentation does not say what a node of another kind than the receiver gives; it is
	// reported as the unknown read error, since a wrapper cannot change its kind.
	if (attributes && fileWrapperHasKind(self, [attributes objectForKey: NSFileType]) &&
	    [self readContentsFromURL: url attributes: attributes options: options error: &error]) {
		[_fileAttributes release];
		_fileAttributes = nil;
		[self setFileAttributes: attributes];
		return YES;
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
	} 
	return self;
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

// GUESS: a wrapper that records no modification date or permissions (one made from data) matches nothing, and the
// dates must be equal: a file older than the recorded date does not match either.
- (BOOL) matchesNodeAtURL: (NSURL*) url attributes: (NSDictionary*) attributes
{
	NSDictionary* own = [self fileAttributes];
	NSDate* date = [own objectForKey: NSFileModificationDate];
	NSNumber* permissions = [own objectForKey: NSFilePosixPermissions];
	return date && permissions &&
	       [date isEqualToDate: [attributes objectForKey: NSFileModificationDate]] &&
	       [permissions isEqualToNumber: [attributes objectForKey: NSFilePosixPermissions]];
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
	// GUESS: the contents are unchanged when they match the node at originalContentsURL (date and permissions);
	// that node is then linked instead of written, or already is the file when it is the destination itself.
	BOOL unchanged = originalContentsURL && [url isFileURL] && [self matchesContentsOfURL: originalContentsURL];
	BOOL result = unchanged && ([[originalContentsURL path] isEqualToString: [url path]] ||
	                            [[NSFileManager defaultManager] linkItemAtURL: originalContentsURL toURL: url error: NULL]);
	if (!result) {
		result = [[self regularFileContents] writeToURL: url
		                                        options: (options & NSFileWrapperWritingAtomic) != 0 ? NSDataWritingAtomic : 0
		                                          error: error];
	}
	if (result && (options & NSFileWrapperWritingWithNameUpdating) != 0) {
		recordWrittenNames(self, [url lastPathComponent]);
	}
	return result;
}

- (void) dealloc
{
	[contentData release];
	[super dealloc];
}

@end

@implementation NSFileWrapperDirectory

- (id) initDirectoryWithFileWrappers: (NSDictionary*) docs;
{
	if ((self = [self init])!=nil) {
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
	NSArray* names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: [url path] error: outError];
	if (!names) return NO;
	// GUESS: if a later child fails, the children already reread stay reread; the receiver's own list is unchanged.
	NSMutableDictionary* children = [NSMutableDictionary dictionaryWithCapacity: [names count]];
	for (NSString* name in names) {
		NSURL* childURL = [url URLByAppendingPathComponent: name];
		NSFileWrapper* child = [contentDictionary objectForKey: name];
		// GUESS: a child whose node was replaced by one of another kind (or cannot be re-read) is replaced too.
		if (!child || ![child readFromURL: childURL options: options error: NULL]) {
			child = [[[NSFileWrapper alloc] initWithURL: childURL options: options error: outError] autorelease];
			if (!child) return NO;
		}
		[children setObject: child forKey: name];
	}
	[contentDictionary release];
	contentDictionary = [children retain];
	return YES;
}

- (BOOL) matchesNodeAtURL: (NSURL*) url attributes: (NSDictionary*) attributes
{
	NSArray* names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: [url path] error: NULL];
	if (!names || [names count] != [contentDictionary count]) return NO;
	for (NSString* name in names) {
		if (![[contentDictionary objectForKey: name] matchesContentsOfURL: [url URLByAppendingPathComponent: name]]) return NO;
	}
	return YES;
}

- (BOOL) writeToURL: (NSURL*) url options: (NSFileWrapperWritingOptions) options
 originalContentsURL: (NSURL*) originalContentsURL error: (NSError**) outError
{
	NSDictionary* children = contentDictionary;
	return writeNode(self, url, options, outError, ^BOOL(NSURL* target, NSError** error) {
		NSFileManager* manager = [NSFileManager defaultManager];
		// GUESS: an existing directory at the destination is written into, keeping what else is in it, and
		// fileAttributes of the wrapper and its children are not applied to what is written.
		// The type is taken without following links: a link to a directory is not one, so it is not entered
		// (creating the directory then fails because the link is in the way). This is a check, not a lock: a
		// directory replaced by a link between this check and the writes below is written through.
		NSString* existingType = [[manager attributesOfItemAtPath: [target path] error: NULL] objectForKey: NSFileType];
		if (![existingType isEqualToString: NSFileTypeDirectory] &&
		    ![manager createDirectoryAtURL: target withIntermediateDirectories: NO attributes: nil error: error]) {
			return NO;
		}
		for (NSString* name in children) {
			// GUESS: a name that is not a single path component is refused rather than followed.
			if (![name length] || [name isEqualToString: @"."] || [name isEqualToString: @".."] ||
			    [name rangeOfString: @"/"].location != NSNotFound) {
				*error = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileWriteInvalidFileNameError
				                         userInfo: @{ NSURLErrorKey: target }];
				return NO;
			}
			NSFileWrapper* child = [children objectForKey: name];
			// The earlier revision of a child is where its filename says it was.
			NSURL* original = ([child filename] && originalContentsURL) ?
				[originalContentsURL URLByAppendingPathComponent: [child filename]] : nil;
			// GUESS: a regular file is written atomically whatever the options, so that it replaces what is there
			// instead of rewriting it: an existing entry may be a hard link to the earlier revision, or a link to a
			// file elsewhere. (NSData's atomic write still creates its temporary file without O_EXCL or O_NOFOLLOW.)
			NSFileWrapperWritingOptions childOptions = [child isRegularFile] ? NSFileWrapperWritingAtomic : 0;
			if (![child writeToURL: [target URLByAppendingPathComponent: name] options: childOptions
			   originalContentsURL: original error: error]) {
				return NO;
			}
		}
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
	// GUESS: a link is not written over an existing item of any kind (without atomic): that fails with the
	// error of creating the link, while a regular file replaces what is there and a directory is written into.
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

- (BOOL) matchesNodeAtURL: (NSURL*) url attributes: (NSDictionary*) attributes
{
	NSString* destination = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath: [url path] error: NULL];
	return [destination isEqualToString: linkDestination];
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
