/* Copyright (c) 2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSError.h>
#import <Foundation/FoundationErrors.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSXMLDTD.h>
#import <Foundation/NSXMLParser.h>
#import "NSXMLNodeInternal.h"

static xmlDocPtr docOf(NSXMLDocument *document)
{
    return (xmlDocPtr)_NSXMLNodeGetXMLNode(document);
}

static void setDocString(const xmlChar **field, NSString *value)
{
    if (*field != NULL)
        xmlFree((xmlChar *)*field);
    *field = value ? xmlStrdup((const xmlChar *)[value UTF8String]) : NULL;
}

@implementation NSXMLDocument

+ (Class) replacementClassForClass: (Class) class {
    return class;
}

- init {
    return [super initWithKind: NSXMLDocumentKind options: NSXMLNodeOptionsNone];
}

- initWithKind: (NSXMLNodeKind) kind options: (NSUInteger) options {
    return [super initWithKind: NSXMLDocumentKind options: options];
}

- initWithRootElement: (NSXMLElement *) element {
    self = [self init];
    if (self != nil && element != nil)
        [self setRootElement: element];
    return self;
}

- _initWithParsedData: (NSData *) data
             encoding: (const char *) encoding
              options: (NSUInteger) options
                error: (NSError **) error
{
    if (error != NULL)
        *error = nil;
    xmlDocPtr doc = _NSXMLParseData(data ?: [NSData data], options, encoding, error);
    if (doc == NULL) {
        [self release];
        return nil;
    }
    // a document read without an XML declaration still has version 1.0
    if (doc->version == NULL)
        doc->version = xmlStrdup(BAD_CAST "1.0");
    [self release];
    self = [[NSXMLDocument alloc] _initWithXMLNode: (xmlNodePtr)doc];
    _options = options;
    _contentKind = NSXMLDocumentXMLKind;
    return self;
}

- initWithXMLString: (NSString *) string
            options: (NSUInteger) options
              error: (NSError **) error
{
    NSData *data = [string dataUsingEncoding: NSUTF8StringEncoding];
    self = [self _initWithParsedData: data encoding: "UTF-8" options: options error: error];
    xmlDocPtr doc = docOf(self);
    if (doc != NULL && doc->encoding == NULL)
        doc->encoding = xmlStrdup(BAD_CAST "UTF-8");
    return self;
}

- initWithData: (NSData *) data
        options: (NSUInteger) options
          error: (NSError **) error
{
    return [self _initWithParsedData: data encoding: NULL options: options error: error];
}

- initWithContentsOfURL: (NSURL *) url
                options: (NSUInteger) options
                  error: (NSError **) error
{
    NSData *data = [NSData dataWithContentsOfURL: url options: 0 error: error];
    if (data == nil) {
        [self release];
        return nil;
    }
    self = [self initWithData: data options: options error: error];
    xmlDocPtr doc = docOf(self);
    if (doc != NULL)
        setDocString(&doc->URL, [url absoluteString]);
    return self;
}

- (void) dealloc {
    [_mimeType release];
    [_dtd release];
    [super dealloc];
}

- copyWithZone: (NSZone *) zone {
    NSXMLDocument *copy = [super copyWithZone: zone];
    copy->_contentKind = _contentKind;
    copy->_mimeType = [_mimeType copy];
    copy->_dtd = [_dtd copy];
    return copy;
}

- (NSXMLDocumentContentKind) documentContentKind {
    return _contentKind;
}

- (NSString *) version {
    xmlDocPtr doc = docOf(self);
    return doc && doc->version ? [NSString stringWithUTF8String: (const char *)doc->version] : nil;
}

- (NSString *) characterEncoding {
    xmlDocPtr doc = docOf(self);
    return doc && doc->encoding ? [NSString stringWithUTF8String: (const char *)doc->encoding] : nil;
}

- (NSString *) MIMEType {
    return _mimeType;
}

- (BOOL) isStandalone {
    xmlDocPtr doc = docOf(self);
    if (doc == NULL)
        return NO;
    // QUIRK: a document read from XML whose declaration has no standalone
    // attribute reports YES; one read without a declaration reports NO.
    // Not documented. Evidence: black-box observation on macOS 26.7.3 and
    // Mac OS X 10.14.4 (tier 2).
    // Test: tests/nsxml-tree.m, the "standalone quirk" checks.
    return doc->standalone == 1 || doc->standalone == -2;
}

- (NSXMLElement *) rootElement {
    xmlDocPtr doc = docOf(self);
    return doc ? (NSXMLElement *)_NSXMLNodeForXMLNode(xmlDocGetRootElement(doc)) : nil;
}

- (NSXMLDTD *) DTD {
    return _dtd;
}

- (NSString *) URI {
    xmlDocPtr doc = docOf(self);
    return doc && doc->URL ? [NSString stringWithUTF8String: (const char *)doc->URL] : nil;
}

- (void) setDocumentContentKind: (NSXMLDocumentContentKind) kind {
    _contentKind = kind;
}

- (void) setCharacterEncoding: (NSString *) encoding {
    xmlDocPtr doc = docOf(self);
    if (doc != NULL)
        setDocString(&doc->encoding, encoding);
}

- (void) setVersion: (NSString *) version {
    xmlDocPtr doc = docOf(self);
    if (doc != NULL)
        setDocString(&doc->version, version);
}

- (void) setMIMEType: (NSString *) mimeType {
    mimeType = [mimeType copy];
    [_mimeType release];
    _mimeType = mimeType;
}

- (void) setStandalone: (BOOL) flag {
    xmlDocPtr doc = docOf(self);
    if (doc != NULL)
        doc->standalone = flag ? 1 : -1;
}

- (void) setRootElement: (NSXMLNode *) element {
    // the document is left with the new root element as its only child
    _NSXMLRemoveAllChildren(self);
    if (element != nil)
        _NSXMLInsertChild(self, element, 0);
}

- (void) setDTD: (NSXMLDTD *) dtd {
    dtd = [dtd retain];
    [_dtd release];
    _dtd = dtd;
}

- (void) setURI: (NSString *) uri {
    xmlDocPtr doc = docOf(self);
    if (doc != NULL)
        setDocString(&doc->URL, uri);
}

- (void) setChildren: (NSArray *) children {
    _NSXMLRemoveAllChildren(self);
    for (NSXMLNode *child in children)
        [self addChild: child];
}

- (void) addChild: (NSXMLNode *) node {
    _NSXMLInsertChild(self, node, [self childCount]);
}

- (void) insertChild: (NSXMLNode *) child atIndex: (NSUInteger) index {
    _NSXMLInsertChild(self, child, index);
}

- (void) insertChildren: (NSArray *) children atIndex: (NSUInteger) index {
    for (NSXMLNode *child in children)
        _NSXMLInsertChild(self, child, index++);
}

- (void) removeChildAtIndex: (NSUInteger) index {
    _NSXMLRemoveChildAtIndex(self, index);
}

- (void) replaceChildAtIndex: (NSUInteger) index withNode: (NSXMLNode *) node {
    _NSXMLRemoveChildAtIndex(self, index);
    _NSXMLInsertChild(self, node, index);
}

- (BOOL) validateAndReturnError: (NSError **) error {
    if (error != NULL)
        *error = nil;
    return YES;
}

- (NSString *) XMLStringWithOptions: (NSUInteger) options {
    // an empty document has no declaration either
    if ([self childCount] == 0)
        return @"";
    return [super XMLStringWithOptions: options];
}

- (NSData *) XMLData {
    return [self XMLDataWithOptions: NSXMLNodeOptionsNone];
}

- (NSData *) XMLDataWithOptions: (NSUInteger) options {
    NSString *string = [self XMLStringWithOptions: options];
    return [string dataUsingEncoding: NSUTF8StringEncoding];
}

- objectByApplyingXSLT: (NSData *) xslt
             arguments: (NSDictionary *) arguments
                 error: (NSError **) error
{
    if (error != NULL)
        *error = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFeatureUnsupportedError userInfo: nil];
    return nil;
}

- objectByApplyingXSLTAtURL: (NSURL *) url
                  arguments: (NSDictionary *) arguments
                      error: (NSError **) error
{
    return [self objectByApplyingXSLT: nil arguments: arguments error: error];
}

- objectByApplyingXSLTString: (NSString *) string
                   arguments: (NSDictionary *) arguments
                       error: (NSError **) error
{
    return [self objectByApplyingXSLT: nil arguments: arguments error: error];
}

@end
