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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import "NSXMLNodeInternal.h"

static const xmlChar *xmlString(NSString *s)
{
    return (const xmlChar *)(s ? [s UTF8String] : "");
}

static BOOL nameMatches(xmlNodePtr node, NSString *name)
{
    NSString *prefix = [NSXMLNode prefixForName: name];
    NSString *local = [NSXMLNode localNameForName: name];
    if (!xmlStrEqual(node->name, xmlString(local))) {
        // a name given with its prefix may also be stored whole
        return xmlStrEqual(node->name, xmlString(name)) && (node->ns == NULL || node->ns->prefix == NULL);
    }
    if ([prefix length] == 0)
        return node->ns == NULL || node->ns->prefix == NULL;
    return node->ns != NULL && node->ns->prefix != NULL && xmlStrEqual(node->ns->prefix, xmlString(prefix));
}

static BOOL localNameAndURIMatch(xmlNodePtr node, NSString *localName, NSString *uri)
{
    if (!xmlStrEqual(node->name, xmlString(localName)))
        return NO;
    if (uri == nil)
        return node->ns == NULL || node->ns->href == NULL;
    return node->ns != NULL && xmlStrEqual(node->ns->href, xmlString(uri));
}

static BOOL namespaceIsUsed(xmlNodePtr node, xmlNsPtr ns)
{
    if (node->ns == ns)
        return YES;
    for (xmlAttrPtr a = node->properties; a != NULL; a = a->next)
        if (a->ns == ns)
            return YES;
    for (xmlNodePtr c = node->children; c != NULL; c = c->next)
        if (c->type == XML_ELEMENT_NODE && namespaceIsUsed(c, ns))
            return YES;
    return NO;
}

@implementation NSXMLElement

- init {
    return [self initWithName: @""];
}

- initWithName: (NSString *) name {
    self = [super initWithKind: NSXMLElementKind options: NSXMLNodeOptionsNone];
    [self setName: name];
    return self;
}

- initWithName: (NSString *) name stringValue: (NSString *) string {
    self = [self initWithName: name];
    [self setStringValue: string];
    return self;
}

- initWithName: (NSString *) name URI: (NSString *) uri {
    self = [self initWithName: [NSXMLNode localNameForName: name]];
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    if (node != NULL && uri != nil) {
        NSString *prefix = [NSXMLNode prefixForName: name];
        xmlNsPtr ns = xmlNewNs(node, xmlString(uri), [prefix length] ? xmlString(prefix) : NULL);
        if (ns != NULL)
            xmlSetNs(node, ns);
        else
            [self setName: name];
    }
    return self;
}

- initWithKind: (NSXMLNodeKind) kind options: (NSUInteger) options {
    return [super initWithKind: NSXMLElementKind options: options];
}

- initWithXMLString: (NSString *) string error: (NSError **) error {
    NSData *data = [string dataUsingEncoding: NSUTF8StringEncoding];
    xmlDocPtr doc = _NSXMLParseData(data, NSXMLNodeOptionsNone, "UTF-8", error);
    xmlNodePtr root = doc ? xmlDocGetRootElement(doc) : NULL;
    if (root == NULL) {
        if (doc != NULL)
            xmlFreeDoc(doc);
        [self release];
        return nil;
    }
    xmlUnlinkNode(root);
    xmlSetTreeDoc(root, NULL);
    xmlFreeDoc(doc);
    return [self _initWithXMLNode: root];
}

- (NSArray *) attributes {
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    if (node == NULL)
        return nil;
    NSMutableArray *attributes = [NSMutableArray array];
    for (xmlAttrPtr attr = node->properties; attr != NULL; attr = attr->next)
        [attributes addObject: _NSXMLNodeForXMLNode((xmlNodePtr)attr)];
    return attributes;
}

static xmlAttrPtr attributeNamed(xmlNodePtr node, NSString *name)
{
    for (xmlAttrPtr attr = node ? node->properties : NULL; attr != NULL; attr = attr->next)
        if (nameMatches((xmlNodePtr)attr, name))
            return attr;
    return NULL;
}

- (NSXMLNode *) attributeForLocalName: (NSString *) name URI: (NSString *) uri {
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    for (xmlAttrPtr attr = node ? node->properties : NULL; attr != NULL; attr = attr->next)
        if (localNameAndURIMatch((xmlNodePtr)attr, name, uri))
            return _NSXMLNodeForXMLNode((xmlNodePtr)attr);
    return nil;
}

- (NSXMLNode *) attributeForName: (NSString *) name {
    return _NSXMLNodeForXMLNode((xmlNodePtr)attributeNamed(_NSXMLNodeGetXMLNode(self), name));
}

- (NSArray *) elementsForLocalName: (NSString *) localName URI: (NSString *) uri {
    NSMutableArray *elements = [NSMutableArray array];
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    for (xmlNodePtr c = node ? node->children : NULL; c != NULL; c = c->next)
        if (c->type == XML_ELEMENT_NODE && localNameAndURIMatch(c, localName, uri))
            [elements addObject: _NSXMLNodeForXMLNode(c)];
    return elements;
}

- (NSArray *) elementsForName: (NSString *) name {
    NSMutableArray *elements = [NSMutableArray array];
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    for (xmlNodePtr c = node ? node->children : NULL; c != NULL; c = c->next)
        if (c->type == XML_ELEMENT_NODE && nameMatches(c, name))
            [elements addObject: _NSXMLNodeForXMLNode(c)];
    return elements;
}

- (NSArray *) namespaces {
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    if (node == NULL || node->nsDef == NULL)
        return nil;
    NSMutableArray *namespaces = [NSMutableArray array];
    for (xmlNsPtr ns = node->nsDef; ns != NULL; ns = ns->next)
        [namespaces addObject: _NSXMLNodeForXMLNode((xmlNodePtr)ns)];
    return namespaces;
}

- (NSXMLNode *) namespaceForPrefix: (NSString *) prefix {
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    for (xmlNsPtr ns = node ? node->nsDef : NULL; ns != NULL; ns = ns->next) {
        BOOL match = [prefix length] ? (ns->prefix && xmlStrEqual(ns->prefix, xmlString(prefix))) : ns->prefix == NULL;
        if (match)
            return _NSXMLNodeForXMLNode((xmlNodePtr)ns);
    }
    return nil;
}

- (void) setAttributes: (NSArray *) attributes {
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    if (node == NULL)
        return;
    while (node->properties != NULL) {
        xmlNodePtr attr = (xmlNodePtr)node->properties;
        xmlUnlinkNode(attr);
        xmlSetTreeDoc(attr, NULL);
        _NSXMLDisposeUnlinkedNode(attr);
    }
    for (NSXMLNode *attribute in attributes)
        [self addAttribute: attribute];
}

- (void) setAttributesWithDictionary: (NSDictionary *) attributes {
    [self setAttributes: nil];
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    if (node == NULL)
        return;
    for (NSString *key in attributes) {
        id value = [attributes objectForKey: key];
        NSString *string = [value isKindOfClass: [NSString class]] ? value : [value description];
        xmlNewProp(node, xmlString(key), xmlString(string));
    }
}

- (void) setAttributesAsDictionary: (NSDictionary *) attributes {
    [self setAttributesWithDictionary: attributes];
}

- (void) setChildren: (NSArray *) children {
    _NSXMLRemoveAllChildren(self);
    for (NSXMLNode *child in children)
        [self addChild: child];
}

- (void) setNamespaces: (NSArray *) namespaces {
    for (NSXMLNode *ns in [self namespaces])
        [self removeNamespaceForPrefix: [ns name]];
    for (NSXMLNode *ns in namespaces)
        [self addNamespace: ns];
}

- (void) addChild: (NSXMLNode *) child {
    _NSXMLInsertChild(self, child, [self childCount]);
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

- (void) addAttribute: (NSXMLNode *) attribute {
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    xmlNodePtr attr = _NSXMLNodeGetXMLNode(attribute);
    if (node == NULL || attr == NULL || attr->type != XML_ATTRIBUTE_NODE)
        return;
    if (attr->parent != NULL)
        [NSException raise: NSInternalInconsistencyException format: @"Cannot add an attribute with a parent; detach or copy first"];

    // an attribute of the same name is replaced, in its place
    xmlAttrPtr existing = attributeNamed(node, [attribute name]);
    xmlAttrPtr a = (xmlAttrPtr)attr;
    a->parent = node;
    if (existing != NULL) {
        a->prev = existing->prev;
        a->next = existing->next;
        if (existing->prev != NULL)
            existing->prev->next = a;
        else
            node->properties = a;
        if (existing->next != NULL)
            existing->next->prev = a;
        existing->parent = NULL;
        existing->next = existing->prev = NULL;
        xmlSetTreeDoc((xmlNodePtr)existing, NULL);
        _NSXMLDisposeUnlinkedNode((xmlNodePtr)existing);
    } else {
        a->next = NULL;
        a->prev = NULL;
        if (node->properties == NULL) {
            node->properties = a;
        } else {
            xmlAttrPtr last = node->properties;
            while (last->next != NULL)
                last = last->next;
            last->next = a;
            a->prev = last;
        }
    }
    if (attr->doc != node->doc)
        xmlSetTreeDoc(attr, node->doc);
    _NSXMLAdoptIntoTree(attribute, _NSXMLTopNode(node));
}

- (void) removeAttributeForName: (NSString *) name {
    xmlAttrPtr attr = attributeNamed(_NSXMLNodeGetXMLNode(self), name);
    if (attr == NULL)
        return;
    xmlUnlinkNode((xmlNodePtr)attr);
    xmlSetTreeDoc((xmlNodePtr)attr, NULL);
    _NSXMLDisposeUnlinkedNode((xmlNodePtr)attr);
}

- (void) addNamespace: (NSXMLNode *) aNamespace {
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    xmlNsPtr given = (xmlNsPtr)_NSXMLNodeGetXMLNode(aNamespace);
    if (node == NULL || given == NULL || given->type != XML_NAMESPACE_DECL)
        return;
    NSString *prefix = [aNamespace name];
    if ([self namespaceForPrefix: prefix] != nil)
        [self removeNamespaceForPrefix: prefix];
    // the element gets its own declaration with the same prefix and URI
    xmlNewNs(node, given->href, [prefix length] ? given->prefix : NULL);
}

- (void) removeNamespaceForPrefix: (NSString *) prefix {
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    if (node == NULL)
        return;
    xmlNsPtr previous = NULL;
    for (xmlNsPtr ns = node->nsDef; ns != NULL; previous = ns, ns = ns->next) {
        BOOL match = [prefix length] ? (ns->prefix && xmlStrEqual(ns->prefix, xmlString(prefix))) : ns->prefix == NULL;
        if (!match)
            continue;
        // a declaration still used by a name below stays
        BOOL used = namespaceIsUsed(node, ns);
        if (used)
            return;
        if (previous != NULL)
            previous->next = ns->next;
        else
            node->nsDef = ns->next;
        ns->next = NULL;
        _NSXMLDisposeUnlinkedNode((xmlNodePtr)ns);
        return;
    }
}

- (void) resolveNamespaceForName: (NSString *) name {
}

- (void) resolvePrefixForNamespaceURI: (NSString *) uri {
}

- (void) normalizeAdjacentTextNodesPreservingCDATA: (BOOL) preserve {
    xmlNodePtr node = _NSXMLNodeGetXMLNode(self);
    if (node == NULL)
        return;
    xmlNodePtr c = node->children;
    while (c != NULL) {
        BOOL isText = c->type == XML_TEXT_NODE || (!preserve && c->type == XML_CDATA_SECTION_NODE);
        xmlNodePtr next = c->next;
        while (isText && next != NULL && (next->type == XML_TEXT_NODE || (!preserve && next->type == XML_CDATA_SECTION_NODE))) {
            xmlNodeAddContent(c, next->content);
            xmlNodePtr after = next->next;
            xmlUnlinkNode(next);
            xmlSetTreeDoc(next, NULL);
            _NSXMLDisposeUnlinkedNode(next);
            next = after;
        }
        c = next;
    }
}

@end
