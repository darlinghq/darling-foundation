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
#import <Foundation/NSRaise.h>
#import <Foundation/NSXMLDTD.h>

@implementation NSXMLDTD

+ (NSXMLDTDNode *) predefinedEntityDeclarationForName: (NSString *) name {
    NSUnimplementedMethod();
    return nil;
}

- initWithData: (NSData *) data
        options: (NSUInteger) options
          error: (NSError **) error
{
    NSUnimplementedMethod();
    return nil;
}

- initWithContentsOfURL: (NSURL *) url
                options: (NSUInteger) options
                  error: (NSError **) error
{
    NSUnimplementedMethod();
    return nil;
}

- (NSString *) publicID {
    return _publicID;
}

- (NSString *) systemID {
    return _systemID;
}

- (NSXMLDTDNode *) attributeDeclarationForName: (NSString *) attributeName
                                   elementName: (NSString *) elementName
{
    NSUnimplementedMethod();
    return nil;
}

- (NSXMLDTDNode *) elementDeclarationForName: (NSString *) name {
    NSUnimplementedMethod();
    return nil;
}

- (NSXMLDTDNode *) entityDeclarationForName: (NSString *) name {
    NSUnimplementedMethod();
    return nil;
}

- (NSXMLDTDNode *) notationDeclarationForName: (NSString *) name {
    NSUnimplementedMethod();
    return nil;
}

- (void) setPublicID: (NSString *) publicID {
    publicID = [publicID copy];
    [_publicID release];
    _publicID = publicID;
}

- (void) setSystemID: (NSString *) systemID {
    systemID = [systemID copy];
    [_systemID release];
    _systemID = systemID;
}

- initWithKind: (NSXMLNodeKind) kind options: (NSUInteger) options {
    self = [super initWithKind: NSXMLDTDKind options: options];
    if (self != nil)
        _dtdChildren = [[NSMutableArray alloc] init];
    return self;
}

- init {
    return [self initWithKind: NSXMLDTDKind options: NSXMLNodeOptionsNone];
}

- (void) dealloc {
    [_publicID release];
    [_systemID release];
    [_dtdChildren release];
    [super dealloc];
}

- copyWithZone: (NSZone *) zone {
    NSXMLDTD *copy = [[NSXMLDTD allocWithZone: zone] init];
    [copy setPublicID: _publicID];
    [copy setSystemID: _systemID];
    for (NSXMLNode *child in _dtdChildren)
        [copy->_dtdChildren addObject: [[child copy] autorelease]];
    return copy;
}

- (NSUInteger) childCount {
    return [_dtdChildren count];
}

- (NSArray *) children {
    return [[_dtdChildren copy] autorelease];
}

- (NSXMLNode *) childAtIndex: (NSUInteger) index {
    return [_dtdChildren objectAtIndex: index];
}

- (void) setChildren: (NSArray *) children {
    [_dtdChildren setArray: children ?: @[]];
}

- (void) addChild: (NSXMLNode *) node {
    [_dtdChildren addObject: node];
}

- (void) insertChild: (NSXMLNode *) child atIndex: (NSUInteger) index {
    [_dtdChildren insertObject: child atIndex: index];
}

- (void) insertChildren: (NSArray *) children atIndex: (NSUInteger) index {
    NSInteger i, count = [children count];

    for (i = 0; i < count; i++)
        [_dtdChildren insertObject: [children objectAtIndex: i]
                           atIndex: index + i];
}

- (void) removeChildAtIndex: (NSUInteger) index {
    [_dtdChildren removeObjectAtIndex: index];
}

- (void) replaceChildAtIndex: (NSUInteger) index withNode: (NSXMLNode *) node {
    [_dtdChildren replaceObjectAtIndex: index withObject: node];
}

@end
