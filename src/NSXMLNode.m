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
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLDTD.h>
#import <Foundation/NSXMLParser.h>
#import "NSXMLNodeInternal.h"
#include <dispatch/dispatch.h>
#include <libxml/parser.h>
#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>

void _NSXMLInitialize(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        xmlInitParser();
    });
}

#pragma mark - libxml2 node helpers

// xmlNs does not share the layout of the other node structures: its type and
// _private fields are at other offsets.
static BOOL isNamespace(xmlNodePtr node)
{
    return node->type == XML_NAMESPACE_DECL;
}

static NSXMLNode *privateObject(xmlNodePtr node)
{
    if (isNamespace(node))
        return (NSXMLNode *)((xmlNsPtr)node)->_private;
    return (NSXMLNode *)node->_private;
}

static void setPrivateObject(xmlNodePtr node, NSXMLNode *object)
{
    if (isNamespace(node))
        ((xmlNsPtr)node)->_private = object;
    else
        node->_private = object;
}

static xmlNodePtr parentOf(xmlNodePtr node)
{
    if (isNamespace(node) || node->type == XML_DOCUMENT_NODE || node->type == XML_HTML_DOCUMENT_NODE)
        return NULL;
    return node->parent;
}

static xmlNodePtr topOf(xmlNodePtr node)
{
    xmlNodePtr parent;
    while ((parent = parentOf(node)) != NULL)
        node = parent;
    return node;
}

xmlNodePtr _NSXMLTopNode(xmlNodePtr node)
{
    return topOf(node);
}

static NSXMLNodeKind kindOf(xmlNodePtr node)
{
    switch (node->type) {
    case XML_DOCUMENT_NODE:
    case XML_HTML_DOCUMENT_NODE:
        return NSXMLDocumentKind;
    case XML_ELEMENT_NODE:
        return NSXMLElementKind;
    case XML_ATTRIBUTE_NODE:
        return NSXMLAttributeKind;
    case XML_NAMESPACE_DECL:
        return NSXMLNamespaceKind;
    case XML_PI_NODE:
        return NSXMLProcessingInstructionKind;
    case XML_COMMENT_NODE:
        return NSXMLCommentKind;
    case XML_TEXT_NODE:
    case XML_CDATA_SECTION_NODE:
    case XML_ENTITY_REF_NODE:
        return NSXMLTextKind;
    case XML_DTD_NODE:
        return NSXMLDTDKind;
    case XML_ELEMENT_DECL:
        return NSXMLElementDeclarationKind;
    case XML_ATTRIBUTE_DECL:
        return NSXMLAttributeDeclarationKind;
    case XML_ENTITY_DECL:
        return NSXMLEntityDeclarationKind;
    default:
        return NSXMLInvalidKind;
    }
}

static Class classForKind(NSXMLNodeKind kind)
{
    switch (kind) {
    case NSXMLDocumentKind:
        return [NSXMLDocument class];
    case NSXMLElementKind:
        return [NSXMLElement class];
    default:
        return [NSXMLNode class];
    }
}

// Children shown by the API: everything but the DTD, which is a property of the document.
static BOOL isListedChild(xmlNodePtr node)
{
    return node->type != XML_DTD_NODE && node->type != XML_XINCLUDE_START && node->type != XML_XINCLUDE_END;
}

static BOOL hasChildList(xmlNodePtr node)
{
    return node->type == XML_ELEMENT_NODE || node->type == XML_DOCUMENT_NODE || node->type == XML_HTML_DOCUMENT_NODE;
}

NSUInteger _NSXMLChildCount(xmlNodePtr parent)
{
    if (parent == NULL || !hasChildList(parent))
        return 0;
    NSUInteger count = 0;
    for (xmlNodePtr c = parent->children; c != NULL; c = c->next)
        if (isListedChild(c))
            count++;
    return count;
}

xmlNodePtr _NSXMLChildAtIndex(xmlNodePtr parent, NSUInteger index)
{
    if (parent == NULL || !hasChildList(parent))
        return NULL;
    for (xmlNodePtr c = parent->children; c != NULL; c = c->next) {
        if (!isListedChild(c))
            continue;
        if (index == 0)
            return c;
        index--;
    }
    return NULL;
}

static xmlNodePtr nextListed(xmlNodePtr node)
{
    for (node = node->next; node != NULL && !isListedChild(node); node = node->next)
        ;
    return node;
}

static xmlNodePtr previousListed(xmlNodePtr node)
{
    for (node = node->prev; node != NULL && !isListedChild(node); node = node->prev)
        ;
    return node;
}

// Calls block for node and everything below it that can have an object:
// children, attributes and namespace declarations.
static void walk(xmlNodePtr node, void (^block)(xmlNodePtr))
{
    block(node);
    if (isNamespace(node))
        return;
    if (node->type == XML_ELEMENT_NODE) {
        for (xmlNsPtr ns = node->nsDef; ns != NULL; ns = ns->next)
            block((xmlNodePtr)ns);
        for (xmlAttrPtr attr = node->properties; attr != NULL; attr = attr->next)
            block((xmlNodePtr)attr);
    }
    if (node->type != XML_ATTRIBUTE_NODE && node->type != XML_ENTITY_REF_NODE) {
        for (xmlNodePtr c = node->children; c != NULL; c = c->next)
            walk(c, block);
    }
}

static BOOL subtreeHasObjects(xmlNodePtr node)
{
    __block BOOL found = NO;
    walk(node, ^(xmlNodePtr n) {
        if (privateObject(n) != nil)
            found = YES;
    });
    return found;
}

// libxml2 may copy _private along with a node; a copy must start without objects.
static void clearObjects(xmlNodePtr node)
{
    walk(node, ^(xmlNodePtr n) {
        setPrivateObject(n, nil);
    });
}

static void freeTree(xmlNodePtr node)
{
    switch (node->type) {
    case XML_DOCUMENT_NODE:
    case XML_HTML_DOCUMENT_NODE:
        xmlFreeDoc((xmlDocPtr)node);
        break;
    case XML_ATTRIBUTE_NODE:
        xmlFreeProp((xmlAttrPtr)node);
        break;
    case XML_NAMESPACE_DECL:
        xmlFreeNs((xmlNsPtr)node);
        break;
    default:
        xmlFreeNode(node);
        break;
    }
}

static NSString *stringFromXML(const xmlChar *s)
{
    if (s == NULL)
        return nil;
    return [NSString stringWithUTF8String:(const char *)s];
}

static const xmlChar *xmlFromString(NSString *s)
{
    return (const xmlChar *)(s ? [s UTF8String] : "");
}

static NSString *qualifiedName(xmlNodePtr node)
{
    if (node->name == NULL)
        return nil;
    NSString *name = stringFromXML(node->name);
    if ((node->type == XML_ELEMENT_NODE || node->type == XML_ATTRIBUTE_NODE) && node->ns != NULL && node->ns->prefix != NULL)
        return [NSString stringWithFormat:@"%s:%@", (const char *)node->ns->prefix, name];
    return name;
}

#pragma mark - ownership

static void setOwner(NSXMLNode *object, NSXMLNode *owner);

void _NSXMLDisposeUnlinkedNode(xmlNodePtr node)
{
    NSXMLNode *object = privateObject(node);
    if (object == nil && !subtreeHasObjects(node)) {
        freeTree(node);
        return;
    }
    if (object == nil)
        object = [[[classForKind(kindOf(node)) alloc] _initWithXMLNode:node] autorelease];
    [object retain];
    walk(node, ^(xmlNodePtr n) {
        NSXMLNode *o = privateObject(n);
        if (o != nil)
            setOwner(o, n == node ? nil : object);
    });
    [object autorelease];
}

void _NSXMLAdoptIntoTree(NSXMLNode *node, xmlNodePtr top)
{
    NSXMLNode *topObject = _NSXMLNodeForXMLNode(top);
    [node retain];
    [topObject retain];
    walk(_NSXMLNodeGetXMLNode(node), ^(xmlNodePtr n) {
        NSXMLNode *o = privateObject(n);
        if (o != nil)
            setOwner(o, topObject);
    });
    [topObject release];
    [node autorelease];
}

// Unlinks node from its parent and makes it the top of its own tree.
static void unlinkNode(xmlNodePtr node)
{
    xmlUnlinkNode(node);
    xmlSetTreeDoc(node, NULL);
}

// Links child into parent before sibling (at the end if sibling is NULL),
// without the merging of adjacent text nodes that xmlAddChild does.
static void linkChild(xmlNodePtr parent, xmlNodePtr child, xmlNodePtr sibling)
{
    child->parent = parent;
    child->next = sibling;
    if (sibling != NULL) {
        child->prev = sibling->prev;
        if (sibling->prev != NULL)
            sibling->prev->next = child;
        else
            parent->children = child;
        sibling->prev = child;
    } else {
        child->prev = parent->last;
        if (parent->last != NULL)
            parent->last->next = child;
        else
            parent->children = child;
        parent->last = child;
    }
    xmlDocPtr doc = (parent->type == XML_DOCUMENT_NODE || parent->type == XML_HTML_DOCUMENT_NODE) ? (xmlDocPtr)parent : parent->doc;
    if (child->doc != doc)
        xmlSetTreeDoc(child, doc);
}

void _NSXMLInsertChild(NSXMLNode *parentObject, NSXMLNode *childObject, NSUInteger index)
{
    xmlNodePtr parent = _NSXMLNodeGetXMLNode(parentObject);
    xmlNodePtr child = _NSXMLNodeGetXMLNode(childObject);
    if (child == NULL || parent == NULL)
        [NSException raise:NSInvalidArgumentException format:@"Cannot add a nil or empty child"];
    if (parentOf(child) != NULL)
        [NSException raise:NSInternalInconsistencyException format:@"Cannot add a child that has a parent; detach or copy first"];
    switch (child->type) {
    case XML_ELEMENT_NODE:
    case XML_TEXT_NODE:
    case XML_CDATA_SECTION_NODE:
    case XML_ENTITY_REF_NODE:
    case XML_COMMENT_NODE:
    case XML_PI_NODE:
        break;
    default:
        [NSException raise:NSInvalidArgumentException format:@"Cannot add a node of kind %lu as a child", (unsigned long)kindOf(child)];
    }
    if (topOf(parent) == child)
        [NSException raise:NSInvalidArgumentException format:@"Cannot add a node as a child of its own descendant"];
    NSUInteger count = _NSXMLChildCount(parent);
    if (index > count)
        [NSException raise:NSRangeException format:@"Index %lu out of bounds (%lu children)", (unsigned long)index, (unsigned long)count];

    linkChild(parent, child, _NSXMLChildAtIndex(parent, index));
    _NSXMLAdoptIntoTree(childObject, topOf(parent));
}

void _NSXMLRemoveChildAtIndex(NSXMLNode *parentObject, NSUInteger index)
{
    xmlNodePtr parent = _NSXMLNodeGetXMLNode(parentObject);
    xmlNodePtr child = _NSXMLChildAtIndex(parent, index);
    if (child == NULL)
        [NSException raise:NSRangeException format:@"Index %lu out of bounds (%lu children)", (unsigned long)index, (unsigned long)_NSXMLChildCount(parent)];
    unlinkNode(child);
    _NSXMLDisposeUnlinkedNode(child);
}

void _NSXMLRemoveAllChildren(NSXMLNode *parentObject)
{
    xmlNodePtr parent = _NSXMLNodeGetXMLNode(parentObject);
    if (parent == NULL || !hasChildList(parent))
        return;
    xmlNodePtr c = parent->children;
    while (c != NULL) {
        xmlNodePtr next = c->next;
        if (isListedChild(c)) {
            unlinkNode(c);
            _NSXMLDisposeUnlinkedNode(c);
        }
        c = next;
    }
}

NSXMLNode *_NSXMLNodeForXMLNode(xmlNodePtr node)
{
    if (node == NULL)
        return nil;
    NSXMLNode *object = privateObject(node);
    if (object != nil)
        return object;
    xmlNodePtr top = topOf(node);
    NSXMLNode *owner = nil;
    if (top != node)
        owner = _NSXMLNodeForXMLNode(top);
    object = [[classForKind(kindOf(node)) alloc] _initWithXMLNode:node];
    if (owner != nil)
        setOwner(object, owner);
    return [object autorelease];
}


#pragma mark - parsing

static BOOL isWhitespaceOnly(const xmlChar *s)
{
    if (s == NULL)
        return YES;
    for (; *s; s++)
        if (*s != ' ' && *s != '\t' && *s != '\n' && *s != '\r')
            return NO;
    return YES;
}

static void replaceEntityReferences(xmlNodePtr parent)
{
    xmlNodePtr c = parent->children;
    while (c != NULL) {
        xmlNodePtr next = c->next;
        if (c->type == XML_ENTITY_REF_NODE) {
            xmlEntityPtr ent = xmlGetDocEntity(c->doc, c->name);
            if (ent != NULL && ent->etype == XML_INTERNAL_GENERAL_ENTITY) {
                xmlNodePtr text = xmlNewDocText(c->doc, ent->content ? ent->content : BAD_CAST "");
                xmlReplaceNode(c, text);
                xmlFreeNode(c);
            }
        } else if (c->type == XML_ELEMENT_NODE) {
            replaceEntityReferences(c);
        }
        c = next;
    }
}

static void mergeAndTrimText(xmlNodePtr parent)
{
    xmlNodePtr c = parent->children;
    while (c != NULL) {
        if (c->type == XML_TEXT_NODE) {
            while (c->next != NULL && c->next->type == XML_TEXT_NODE) {
                xmlNodePtr next = c->next;
                xmlNodeAddContent(c, next->content);
                xmlUnlinkNode(next);
                xmlFreeNode(next);
            }
            xmlNodePtr next = c->next;
            if (isWhitespaceOnly(c->content)) {
                xmlUnlinkNode(c);
                xmlFreeNode(c);
            }
            c = next;
            continue;
        }
        if (c->type == XML_ELEMENT_NODE)
            mergeAndTrimText(c);
        c = c->next;
    }
}

// Brings a parsed tree into the shape NSXMLDocument presents: references to
// internal entities are replaced by their text, adjacent text is merged, and
// text that is only whitespace is left out.
static void normalizeParsedTree(xmlNodePtr doc, BOOL preserveEntities)
{
    if (!preserveEntities)
        replaceEntityReferences(doc);
    mergeAndTrimText(doc);
}

struct parseError {
    int code;
    int line;
    NSString *message;
};

static void recordParseError(void *userData, xmlErrorPtr error)
{
    xmlParserCtxtPtr ctxt = userData;
    struct parseError *first = ctxt ? ctxt->_private : NULL;
    if (first == NULL || error == NULL || first->code != 0 || error->level < XML_ERR_ERROR)
        return;
    first->code = error->code;
    first->line = error->line;
    if (error->message != NULL)
        first->message = [[stringFromXML(BAD_CAST error->message) stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] retain];
}

xmlDocPtr _NSXMLParseData(NSData *data, NSUInteger options, const char *encoding, NSError **error)
{
    _NSXMLInitialize();
    int flags = XML_PARSE_NODICT | XML_PARSE_NONET | XML_PARSE_NOERROR | XML_PARSE_NOWARNING;
    if (!(options & NSXMLNodePreserveCDATA))
        flags |= XML_PARSE_NOCDATA;
    if (options & (NSXMLDocumentTidyXML | NSXMLDocumentTidyHTML))
        flags |= XML_PARSE_RECOVER;
    if (options & NSXMLDocumentXInclude)
        flags |= XML_PARSE_XINCLUDE;

    if ([data length] == 0) {
        if (error != NULL)
            *error = [NSError errorWithDomain:NSXMLParserErrorDomain code:NSXMLParserEmptyDocumentError userInfo:nil];
        return NULL;
    }
    xmlParserCtxtPtr ctxt = xmlNewParserCtxt();
    if (ctxt == NULL)
        return NULL;
    struct parseError firstError = { 0 };
    ctxt->sax->serror = recordParseError;
    ctxt->_private = &firstError;
    xmlDocPtr doc = xmlCtxtReadMemory(ctxt, [data bytes], (int)[data length], NULL, encoding, flags);
    BOOL failed = doc == NULL || (!ctxt->wellFormed && !(flags & XML_PARSE_RECOVER));
    if (failed) {
        if (error != NULL) {
            // the codes of NSXMLParserError are those of libxml2; the first error is the cause
            NSInteger code = firstError.code ? firstError.code : XML_ERR_INTERNAL_ERROR;
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            if (firstError.message != nil)
                [info setObject:[NSString stringWithFormat:@"Line %d: %@", firstError.line, firstError.message] forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:NSXMLParserErrorDomain code:code userInfo:info];
        }
        [firstError.message release];
        if (doc != NULL)
            xmlFreeDoc(doc);
        xmlFreeParserCtxt(ctxt);
        return NULL;
    }
    [firstError.message release];
    xmlFreeParserCtxt(ctxt);
    normalizeParsedTree((xmlNodePtr)doc, (options & NSXMLNodePreserveEntities) != 0);
    return doc;
}

#pragma mark - string value

static void appendContent(NSMutableString *out, xmlNodePtr node)
{
    for (xmlNodePtr c = node->children; c != NULL; c = c->next) {
        switch (c->type) {
        case XML_TEXT_NODE:
        case XML_CDATA_SECTION_NODE:
        case XML_COMMENT_NODE:
        case XML_PI_NODE:
            if (c->content)
                [out appendString:stringFromXML(c->content)];
            break;
        case XML_ELEMENT_NODE:
            appendContent(out, c);
            break;
        default:
            break;
        }
    }
}

#pragma mark - serialization

static void appendEscaped(NSMutableString *out, const xmlChar *s, BOOL attribute)
{
    if (s == NULL)
        return;
    NSString *string = stringFromXML(s);
    NSUInteger length = [string length];
    NSUInteger start = 0;
    for (NSUInteger i = 0; i < length; i++) {
        unichar ch = [string characterAtIndex:i];
        NSString *entity = nil;
        switch (ch) {
        case '&': entity = @"&amp;"; break;
        case '<': entity = @"&lt;"; break;
        case '>': entity = @"&gt;"; break;
        case '"': entity = attribute ? @"&quot;" : nil; break;
        }
        if (entity != nil) {
            [out appendString:[string substringWithRange:NSMakeRange(start, i - start)]];
            [out appendString:entity];
            start = i + 1;
        }
    }
    [out appendString:[string substringFromIndex:start]];
}

static void appendNode(NSMutableString *out, xmlNodePtr node, NSUInteger options, NSUInteger level);

static BOOL onlyMarkupChildren(xmlNodePtr node)
{
    for (xmlNodePtr c = node->children; c != NULL; c = c->next)
        if (c->type == XML_TEXT_NODE || c->type == XML_CDATA_SECTION_NODE || c->type == XML_ENTITY_REF_NODE)
            return NO;
    return YES;
}

// Pretty printing indents a node by its level in its tree, the top level
// and the level below it not being indented.
static void appendIndent(NSMutableString *out, NSUInteger level)
{
    [out appendString:@"\n"];
    for (NSUInteger i = 1; i < level; i++)
        [out appendString:@"    "];
}

static void appendChildren(NSMutableString *out, xmlNodePtr node, NSUInteger options, NSUInteger level)
{
    BOOL pretty = (options & NSXMLNodePrettyPrint) && onlyMarkupChildren(node);
    for (xmlNodePtr c = node->children; c != NULL; c = c->next) {
        if (!isListedChild(c))
            continue;
        if (pretty)
            appendIndent(out, level + 1);
        appendNode(out, c, options, level + 1);
    }
    if (pretty && node->children != NULL)
        appendIndent(out, level);
}

static void appendQuotedID(NSMutableString *out, const xmlChar *s)
{
    [out appendFormat:(xmlStrchr(s, '"') ? @" '%s'" : @" \"%s\""), (const char *)s];
}

static void appendDTD(NSMutableString *out, xmlDtdPtr dtd)
{
    [out appendFormat:@"<!DOCTYPE %s", (const char *)(dtd->name ? dtd->name : BAD_CAST "")];
    if (dtd->ExternalID != NULL) {
        [out appendString:@" PUBLIC"];
        appendQuotedID(out, dtd->ExternalID);
        if (dtd->SystemID != NULL)
            appendQuotedID(out, dtd->SystemID);
    } else if (dtd->SystemID != NULL) {
        [out appendString:@" SYSTEM"];
        appendQuotedID(out, dtd->SystemID);
    }
    if (dtd->children != NULL) {
        [out appendString:@" ["];
        for (xmlNodePtr c = dtd->children; c != NULL; c = c->next) {
            xmlBufferPtr buffer = xmlBufferCreate();
            xmlNodeDump(buffer, dtd->doc, c, 0, 0);
            NSString *decl = stringFromXML(xmlBufferContent(buffer));
            xmlBufferFree(buffer);
            decl = [decl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([decl length])
                [out appendFormat:@"\n    %@", decl];
        }
        [out appendString:@"\n]"];
    }
    [out appendString:@">"];
}

static void appendAttribute(NSMutableString *out, xmlAttrPtr attr)
{
    [out appendString:qualifiedName((xmlNodePtr)attr)];
    [out appendString:@"=\""];
    xmlChar *value = xmlNodeGetContent((xmlNodePtr)attr);
    appendEscaped(out, value, YES);
    xmlFree(value);
    [out appendString:@"\""];
}

static void appendNamespace(NSMutableString *out, xmlNsPtr ns)
{
    if (ns->prefix != NULL)
        [out appendFormat:@"xmlns:%s=\"", (const char *)ns->prefix];
    else
        [out appendString:@"xmlns=\""];
    appendEscaped(out, ns->href, YES);
    [out appendString:@"\""];
}

static void appendNode(NSMutableString *out, xmlNodePtr node, NSUInteger options, NSUInteger level)
{
    NSXMLNode *object = privateObject(node);
    NSUInteger nodeOptions = object ? (options | [object _nodeOptions]) : options;
    switch (node->type) {
    case XML_DOCUMENT_NODE:
    case XML_HTML_DOCUMENT_NODE: {
        xmlDocPtr doc = (xmlDocPtr)node;
        if (doc->version != NULL) {
            [out appendFormat:@"<?xml version=\"%s\"", (const char *)doc->version];
            if (doc->encoding != NULL)
                [out appendFormat:@" encoding=\"%s\"", (const char *)doc->encoding];
            if (doc->standalone == 1)
                [out appendString:@" standalone=\"yes\""];
            [out appendString:@"?>"];
        }
        if (doc->intSubset != NULL) {
            if (doc->version != NULL)
                [out appendString:@"\n"];
            appendDTD(out, doc->intSubset);
            [out appendString:@"\n"];
        }
        BOOL pretty = (options & NSXMLNodePrettyPrint) != 0;
        for (xmlNodePtr c = node->children; c != NULL; c = c->next) {
            if (!isListedChild(c))
                continue;
            if (pretty)
                [out appendString:@"\n"];
            appendNode(out, c, options, level + 1);
        }
        break;
    }
    case XML_ELEMENT_NODE:
        [out appendString:@"<"];
        [out appendString:qualifiedName(node)];
        for (xmlNsPtr ns = node->nsDef; ns != NULL; ns = ns->next) {
            [out appendString:@" "];
            appendNamespace(out, ns);
        }
        for (xmlAttrPtr attr = node->properties; attr != NULL; attr = attr->next) {
            [out appendString:@" "];
            appendAttribute(out, attr);
        }
        if (node->children == NULL && (nodeOptions & NSXMLNodeCompactEmptyElement)) {
            [out appendString:@"/>"];
            break;
        }
        [out appendString:@">"];
        appendChildren(out, node, options, level);
        [out appendFormat:@"</%@>", qualifiedName(node)];
        break;
    case XML_ATTRIBUTE_NODE:
        appendAttribute(out, (xmlAttrPtr)node);
        break;
    case XML_NAMESPACE_DECL:
        appendNamespace(out, (xmlNsPtr)node);
        break;
    case XML_TEXT_NODE:
        if (nodeOptions & NSXMLNodeIsCDATA) {
            [out appendFormat:@"<![CDATA[%@]]>", stringFromXML(node->content) ?: @""];
        } else if (nodeOptions & NSXMLNodeNeverEscapeContents) {
            [out appendString:stringFromXML(node->content) ?: @""];
        } else {
            appendEscaped(out, node->content, NO);
        }
        break;
    case XML_CDATA_SECTION_NODE:
        [out appendFormat:@"<![CDATA[%@]]>", stringFromXML(node->content) ?: @""];
        break;
    case XML_ENTITY_REF_NODE:
        [out appendFormat:@"&%s;", (const char *)node->name];
        break;
    case XML_COMMENT_NODE:
        [out appendFormat:@"<!--%@-->", stringFromXML(node->content) ?: @""];
        break;
    case XML_PI_NODE:
        [out appendFormat:@"<?%s", (const char *)(node->name ? node->name : BAD_CAST "")];
        if (node->content != NULL && node->content[0] != 0)
            [out appendFormat:@" %@", stringFromXML(node->content)];
        [out appendString:@"?>"];
        break;
    default:
        break;
    }
}

#pragma mark - XPath

static void ignoreXPathError(void *userData, xmlErrorPtr error)
{
    if (userData != NULL && error != NULL)
        *(int *)userData = error->code;
}

@implementation NSXMLNode

// C functions inside the implementation, for access to the instance variables
xmlNodePtr _NSXMLNodeGetXMLNode(NSXMLNode *node)
{
    return node ? (xmlNodePtr)node->_xmlNode : NULL;
}

static void setOwner(NSXMLNode *object, NSXMLNode *owner)
{
    if (object == owner)
        owner = nil;
    if (object->_treeOwner == owner)
        return;
    [owner retain];
    NSXMLNode *old = object->_treeOwner;
    object->_treeOwner = owner;
    [old release];
}

+ document {
    return [[[NSXMLDocument alloc] init] autorelease];
}

+ documentWithRootElement: (NSXMLElement *) element {
    return [[[NSXMLDocument alloc] initWithRootElement: element] autorelease];
}

+ elementWithName: (NSString *) name {
    return [[[NSXMLElement alloc] initWithName: name] autorelease];
}

+ elementWithName: (NSString *) name
         children: (NSArray *) children
       attributes: (NSArray *) attributes
{
    NSXMLElement *element = [self elementWithName: name];
    [element setChildren: children];
    [element setAttributes: attributes];
    return element;
}

+ elementWithName: (NSString *) name stringValue: (NSString *) string {
    return [[[NSXMLElement alloc] initWithName: name stringValue: string] autorelease];
}

+ elementWithName: (NSString *) name URI: (NSString *) uri {
    return [[[NSXMLElement alloc] initWithName: name URI: uri] autorelease];
}

+ attributeWithName: (NSString *) name stringValue: (NSString *) string {
    NSXMLNode *node = [[[NSXMLNode alloc] initWithKind: NSXMLAttributeKind] autorelease];
    [node setName: name];
    [node setStringValue: string];
    return node;
}

+ attributeWithName: (NSString *) name URI: (NSString *) uri stringValue: (NSString *) string {
    // the namespace is declared by the element the attribute is added to
    return [self attributeWithName: name stringValue: string];
}

+ commentWithStringValue: (NSString *) string {
    NSXMLNode *node = [[[NSXMLNode alloc] initWithKind: NSXMLCommentKind] autorelease];
    [node setStringValue: string];
    return node;
}

+ textWithStringValue: (NSString *) string {
    NSXMLNode *node = [[[NSXMLNode alloc] initWithKind: NSXMLTextKind] autorelease];
    [node setStringValue: string];
    return node;
}

+ processingInstructionWithName: (NSString *) name
                    stringValue: (NSString *) string
{
    NSXMLNode *node = [[[NSXMLNode alloc] initWithKind: NSXMLProcessingInstructionKind] autorelease];
    [node setName: name];
    [node setStringValue: string];
    return node;
}

+ DTDNodeWithXMLString: (NSString *) string {
    return nil;
}

+ namespaceWithName: (NSString *) name stringValue: (NSString *) string {
    NSXMLNode *node = [[[NSXMLNode alloc] initWithKind: NSXMLNamespaceKind] autorelease];
    [node setName: name];
    [node setStringValue: string];
    return node;
}

+ (NSXMLNode *) predefinedNamespaceForPrefix: (NSString *) prefix {
    static NSDictionary *uris;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        uris = [@{
            @"xml": @"http://www.w3.org/XML/1998/namespace",
            @"xs": @"http://www.w3.org/2001/XMLSchema",
            @"xsi": @"http://www.w3.org/2001/XMLSchema-instance",
            @"fn": @"http://www.w3.org/2003/11/xpath-functions",
            @"local": @"http://www.w3.org/2003/11/xpath-local-functions",
        } retain];
    });
    NSString *uri = prefix ? uris[prefix] : nil;
    return uri ? [self namespaceWithName: prefix stringValue: uri] : nil;
}

+ (NSString *) prefixForName: (NSString *) name {
    NSRange colon = [name rangeOfString: @":"];
    return colon.location == NSNotFound ? @"" : [name substringToIndex: colon.location];
}

+ (NSString *) localNameForName: (NSString *) name {
    NSRange colon = [name rangeOfString: @":"];
    return colon.location == NSNotFound ? name : [name substringFromIndex: NSMaxRange(colon)];
}

- init {
    return [self initWithKind: NSXMLInvalidKind options: NSXMLNodeOptionsNone];
}

- initWithKind: (NSXMLNodeKind) kind {
    return [self initWithKind: kind options: NSXMLNodeOptionsNone];
}

- initWithKind: (NSXMLNodeKind) kind options: (NSUInteger) options {
    self = [super init];
    if (self == nil)
        return nil;
    _NSXMLInitialize();
    _kind = kind;
    _options = options;
    xmlNodePtr node = NULL;
    switch (kind) {
    case NSXMLDocumentKind: {
        xmlDocPtr doc = xmlNewDoc(NULL);
        // a new document has no XML declaration until it is given a version
        if (doc != NULL && doc->version != NULL) {
            xmlFree((xmlChar *)doc->version);
            doc->version = NULL;
        }
        node = (xmlNodePtr)doc;
        break;
    }
    case NSXMLElementKind:
        node = xmlNewNode(NULL, BAD_CAST "");
        break;
    case NSXMLAttributeKind:
        node = (xmlNodePtr)xmlNewProp(NULL, BAD_CAST "", NULL);
        break;
    case NSXMLNamespaceKind:
        node = (xmlNodePtr)xmlNewNs(NULL, BAD_CAST "", NULL);
        break;
    case NSXMLProcessingInstructionKind:
        node = xmlNewPI(BAD_CAST "", NULL);
        break;
    case NSXMLCommentKind:
        node = xmlNewComment(BAD_CAST "");
        break;
    case NSXMLTextKind:
        node = xmlNewText(BAD_CAST "");
        break;
    default:
        // DTD nodes are kept outside of the libxml2 tree
        break;
    }
    if (node != NULL) {
        _xmlNode = node;
        setPrivateObject(node, self);
    }
    return self;
}

- (instancetype) _initWithXMLNode: (xmlNodePtr) node {
    self = [super init];
    if (self == nil)
        return nil;
    _xmlNode = node;
    _kind = kindOf(node);
    setPrivateObject(node, self);
    return self;
}

- (NSUInteger) _nodeOptions {
    return _options;
}

- (void) dealloc {
    xmlNodePtr node = _xmlNode;
    if (node != NULL) {
        if (privateObject(node) == self)
            setPrivateObject(node, nil);
        if (_treeOwner == nil)
            freeTree(node);
    }
    [_treeOwner release];
    [super dealloc];
}

- copyWithZone: (NSZone *) zone {
    xmlNodePtr node = _xmlNode;
    if (node == NULL)
        return [[[self class] allocWithZone: zone] initWithKind: _kind options: _options];
    xmlNodePtr copy;
    switch (node->type) {
    case XML_DOCUMENT_NODE:
    case XML_HTML_DOCUMENT_NODE:
        copy = (xmlNodePtr)xmlCopyDoc((xmlDocPtr)node, 1);
        break;
    case XML_ATTRIBUTE_NODE:
        copy = (xmlNodePtr)xmlCopyProp(NULL, (xmlAttrPtr)node);
        break;
    case XML_NAMESPACE_DECL:
        copy = (xmlNodePtr)xmlCopyNamespace((xmlNsPtr)node);
        break;
    default:
        copy = xmlDocCopyNode(node, NULL, 1);
        break;
    }
    if (copy == NULL)
        return nil;
    clearObjects(copy);
    NSXMLNode *result = [[[self class] allocWithZone: zone] _initWithXMLNode: copy];
    result->_options = _options;
    return result;
}

- (NSUInteger) index {
    xmlNodePtr node = _xmlNode;
    if (node == NULL)
        return 0;
    xmlNodePtr parent = parentOf(node);
    if (parent == NULL)
        return 0;
    NSUInteger index = 0;
    if (node->type == XML_ATTRIBUTE_NODE) {
        for (xmlAttrPtr a = parent->properties; a != NULL && a != (xmlAttrPtr)node; a = a->next)
            index++;
        return index;
    }
    for (xmlNodePtr c = parent->children; c != NULL && c != node; c = c->next)
        if (isListedChild(c))
            index++;
    return index;
}

- (NSXMLNodeKind) kind {
    return _kind;
}

- (NSUInteger) level {
    NSUInteger level = 0;
    xmlNodePtr node = _xmlNode;
    while (node != NULL && (node = parentOf(node)) != NULL)
        level++;
    return level;
}

- (NSString *) localName {
    NSString *name = [self name];
    return name ? [NSXMLNode localNameForName: name] : nil;
}

- (NSString *) name {
    xmlNodePtr node = _xmlNode;
    if (node == NULL)
        return nil;
    switch (node->type) {
    case XML_ELEMENT_NODE:
    case XML_ATTRIBUTE_NODE:
        return qualifiedName(node);
    case XML_PI_NODE:
        return stringFromXML(node->name);
    case XML_NAMESPACE_DECL: {
        xmlNsPtr ns = (xmlNsPtr)node;
        return ns->prefix ? stringFromXML(ns->prefix) : @"";
    }
    default:
        return nil;
    }
}

- (NSXMLNode *) nextSibling {
    xmlNodePtr node = _xmlNode;
    if (node == NULL || parentOf(node) == NULL)
        return nil;
    if (node->type == XML_ATTRIBUTE_NODE)
        return _NSXMLNodeForXMLNode((xmlNodePtr)((xmlAttrPtr)node)->next);
    return _NSXMLNodeForXMLNode(nextListed(node));
}

- (NSXMLNode *) previousSibling {
    xmlNodePtr node = _xmlNode;
    if (node == NULL || parentOf(node) == NULL)
        return nil;
    if (node->type == XML_ATTRIBUTE_NODE)
        return _NSXMLNodeForXMLNode((xmlNodePtr)((xmlAttrPtr)node)->prev);
    return _NSXMLNodeForXMLNode(previousListed(node));
}

// Document order over the children tree; attributes and namespaces are not in it.
- (NSXMLNode *) nextNode {
    xmlNodePtr node = _xmlNode;
    if (node == NULL || isNamespace(node) || node->type == XML_ATTRIBUTE_NODE)
        return nil;
    if (hasChildList(node)) {
        xmlNodePtr first = _NSXMLChildAtIndex(node, 0);
        if (first != NULL)
            return _NSXMLNodeForXMLNode(first);
    }
    for (; node != NULL; node = parentOf(node)) {
        xmlNodePtr next = parentOf(node) ? nextListed(node) : NULL;
        if (next != NULL)
            return _NSXMLNodeForXMLNode(next);
    }
    return nil;
}

- (NSXMLNode *) previousNode {
    xmlNodePtr node = _xmlNode;
    if (node == NULL || isNamespace(node) || node->type == XML_ATTRIBUTE_NODE || parentOf(node) == NULL)
        return nil;
    xmlNodePtr previous = previousListed(node);
    if (previous == NULL)
        return _NSXMLNodeForXMLNode(parentOf(node));
    while (hasChildList(previous)) {
        NSUInteger count = _NSXMLChildCount(previous);
        if (count == 0)
            break;
        previous = _NSXMLChildAtIndex(previous, count - 1);
    }
    return _NSXMLNodeForXMLNode(previous);
}

- (NSString *) stringValue {
    xmlNodePtr node = _xmlNode;
    if (node == NULL)
        return nil;
    switch (node->type) {
    case XML_DOCUMENT_NODE:
    case XML_HTML_DOCUMENT_NODE:
    case XML_ELEMENT_NODE: {
        NSMutableString *out = [NSMutableString string];
        appendContent(out, node);
        return out;
    }
    case XML_ATTRIBUTE_NODE: {
        xmlChar *value = xmlNodeGetContent(node);
        NSString *s = stringFromXML(value) ?: @"";
        xmlFree(value);
        return s;
    }
    case XML_NAMESPACE_DECL:
        return stringFromXML(((xmlNsPtr)node)->href) ?: @"";
    case XML_ENTITY_REF_NODE:
        return @"";
    default:
        return stringFromXML(node->content) ?: @"";
    }
}

- (NSString *) URI {
    xmlNodePtr node = _xmlNode;
    if (node == NULL)
        return nil;
    switch (node->type) {
    case XML_DOCUMENT_NODE:
    case XML_HTML_DOCUMENT_NODE:
        return stringFromXML(((xmlDocPtr)node)->URL);
    case XML_ELEMENT_NODE:
    case XML_ATTRIBUTE_NODE:
        return node->ns ? stringFromXML(node->ns->href) : nil;
    default:
        return nil;
    }
}

- objectValue {
    return [self stringValue];
}

- (NSXMLNode *) parent {
    xmlNodePtr node = _xmlNode;
    return node ? _NSXMLNodeForXMLNode(parentOf(node)) : nil;
}

- (NSString *) prefix {
    NSString *name = [self name];
    return name ? [NSXMLNode prefixForName: name] : @"";
}

- (NSXMLDocument *) rootDocument {
    xmlNodePtr top = _xmlNode ? topOf(_xmlNode) : NULL;
    if (top == NULL || (top->type != XML_DOCUMENT_NODE && top->type != XML_HTML_DOCUMENT_NODE))
        return nil;
    return (NSXMLDocument *)_NSXMLNodeForXMLNode(top);
}

- (NSUInteger) childCount {
    return _NSXMLChildCount(_xmlNode);
}

- (NSArray *) children {
    xmlNodePtr node = _xmlNode;
    if (node == NULL || !hasChildList(node))
        return nil;
    NSMutableArray *children = [NSMutableArray array];
    for (xmlNodePtr c = node->children; c != NULL; c = c->next)
        if (isListedChild(c))
            [children addObject: _NSXMLNodeForXMLNode(c)];
    return children;
}

- (NSXMLNode *) childAtIndex: (NSUInteger) index {
    xmlNodePtr child = _NSXMLChildAtIndex(_xmlNode, index);
    if (child == NULL)
        [NSException raise: NSRangeException format: @"Index %lu out of bounds (%lu children)", (unsigned long)index, (unsigned long)[self childCount]];
    return _NSXMLNodeForXMLNode(child);
}

- (void) setName: (NSString *) name {
    xmlNodePtr node = _xmlNode;
    if (node == NULL)
        return;
    switch (node->type) {
    case XML_ELEMENT_NODE:
    case XML_ATTRIBUTE_NODE:
    case XML_PI_NODE:
        xmlNodeSetName(node, xmlFromString(name));
        break;
    case XML_NAMESPACE_DECL: {
        xmlNsPtr ns = (xmlNsPtr)node;
        if (ns->prefix != NULL)
            xmlFree((xmlChar *)ns->prefix);
        ns->prefix = [name length] ? xmlStrdup(xmlFromString(name)) : NULL;
        break;
    }
    default:
        break;
    }
}

- (void) setObjectValue: object {
    if (object == nil || [object isKindOfClass: [NSString class]])
        [self setStringValue: object];
    else
        [self setStringValue: [object description]];
}

- (void) setStringValue: (NSString *) string {
    xmlNodePtr node = _xmlNode;
    if (node == NULL)
        return;
    if (string == nil)
        string = @"";
    switch (node->type) {
    case XML_ELEMENT_NODE: {
        // the children are replaced by one text node
        _NSXMLRemoveAllChildren(self);
        xmlNodePtr text = xmlNewDocText(node->doc, xmlFromString(string));
        linkChild(node, text, NULL);
        break;
    }
    case XML_ATTRIBUTE_NODE:
        xmlFreeNodeList(node->children);
        node->children = node->last = NULL;
        linkChild(node, xmlNewDocText(node->doc, xmlFromString(string)), NULL);
        break;
    case XML_NAMESPACE_DECL: {
        xmlNsPtr ns = (xmlNsPtr)node;
        if (ns->href != NULL)
            xmlFree((xmlChar *)ns->href);
        ns->href = xmlStrdup(xmlFromString(string));
        break;
    }
    case XML_TEXT_NODE:
    case XML_CDATA_SECTION_NODE:
    case XML_COMMENT_NODE:
    case XML_PI_NODE:
        xmlNodeSetContent(node, xmlFromString(string));
        break;
    default:
        break;
    }
}

- (void) setStringValue: (NSString *) string
        resolvingEntities: (BOOL) resolveEntities
{
    xmlNodePtr node = _xmlNode;
    if (!resolveEntities || string == nil || node == NULL || isNamespace(node)) {
        [self setStringValue: string];
        return;
    }
    // entity and character references in the string are replaced by their text
    xmlDocPtr doc = node->type == XML_DOCUMENT_NODE ? (xmlDocPtr)node : node->doc;
    xmlNodePtr list = xmlStringGetNodeList(doc, xmlFromString(string));
    NSMutableString *plain = [NSMutableString string];
    for (xmlNodePtr n = list; n != NULL; n = n->next) {
        if (n->type == XML_TEXT_NODE && n->content != NULL) {
            [plain appendString: stringFromXML(n->content)];
        } else if (n->type == XML_ENTITY_REF_NODE) {
            xmlEntityPtr ent = xmlGetDocEntity(doc, n->name);
            if (ent != NULL && ent->content != NULL)
                [plain appendString: stringFromXML(ent->content)];
        }
    }
    xmlFreeNodeList(list);
    [self setStringValue: plain];
}

- (void) detach {
    xmlNodePtr node = _xmlNode;
    if (node == NULL || isNamespace(node) || parentOf(node) == NULL)
        return;
    [self retain];
    unlinkNode(node);
    _NSXMLDisposeUnlinkedNode(node);
    [self autorelease];
}

- (NSArray *) nodesForXPath: (NSString *) xpath error: (NSError **) error {
    xmlNodePtr node = _xmlNode;
    if (node == NULL || isNamespace(node))
        return nil;
    xmlDocPtr doc = (node->type == XML_DOCUMENT_NODE || node->type == XML_HTML_DOCUMENT_NODE) ? (xmlDocPtr)node : node->doc;
    int errorCode = 0;
    if (doc == NULL && [xpath hasPrefix: @"/"]) {
        // an absolute path needs a document to start from
        if (error != NULL)
            *error = [NSError errorWithDomain: @"XQueryErrorDomain" code: XPATH_INVALID_TYPE userInfo: @{NSLocalizedDescriptionKey: @"invalid type"}];
        return nil;
    }
    xmlXPathContextPtr ctxt = xmlXPathNewContext(doc);
    if (ctxt == NULL)
        return nil;
    ctxt->node = node;
    ctxt->error = ignoreXPathError;
    ctxt->userData = &errorCode;
    xmlXPathObjectPtr result = xmlXPathEvalExpression(xmlFromString(xpath), ctxt);
    xmlXPathFreeContext(ctxt);
    if (result == NULL) {
        if (error != NULL)
            *error = [NSError errorWithDomain: @"XQueryErrorDomain" code: errorCode >= XML_XPATH_EXPRESSION_OK ? errorCode - XML_XPATH_EXPRESSION_OK : errorCode userInfo: nil];
        return nil;
    }
    NSMutableArray *nodes = nil;
    if (result->type == XPATH_NODESET) {
        nodes = [NSMutableArray array];
        xmlNodeSetPtr set = result->nodesetval;
        for (int i = 0; set != NULL && i < set->nodeNr; i++) {
            xmlNodePtr found = set->nodeTab[i];
            // namespace nodes in a result are copies made for it
            if (found == NULL || found->type == XML_NAMESPACE_DECL)
                continue;
            [nodes addObject: _NSXMLNodeForXMLNode(found)];
        }
    }
    xmlXPathFreeObject(result);
    return nodes;
}

- (NSArray *) objectsForXQuery: (NSString *) xquery
                     constants: (NSDictionary *) constants
                         error: (NSError **) error
{
    return nil;
}

- (NSArray *) objectsForXQuery: (NSString *) xquery error: (NSError **) error {
    return [self objectsForXQuery: xquery constants: nil error: error];
}

- (NSString *) XMLString {
    return [self XMLStringWithOptions: NSXMLNodeOptionsNone];
}

- (NSString *) XMLStringWithOptions: (NSUInteger) options {
    NSMutableString *out = [NSMutableString string];
    if (_xmlNode != NULL)
        appendNode(out, _xmlNode, options, [self level]);
    return out;
}

// /a[1]/b[2]/@c, with node()[n] for other children; the document itself is "".
- (NSString *) XPath {
    xmlNodePtr node = _xmlNode;
    if (node == NULL || isNamespace(node))
        return nil;
    NSMutableArray *steps = [NSMutableArray array];
    for (; node != NULL && parentOf(node) != NULL; node = parentOf(node)) {
        xmlNodePtr parent = parentOf(node);
        if (node->type == XML_ATTRIBUTE_NODE) {
            [steps insertObject: [@"@" stringByAppendingString: qualifiedName(node)] atIndex: 0];
            continue;
        }
        NSUInteger position = 1;
        if (node->type == XML_ELEMENT_NODE) {
            for (xmlNodePtr c = parent->children; c != NULL && c != node; c = c->next)
                if (c->type == XML_ELEMENT_NODE && xmlStrEqual(c->name, node->name) && c->ns == node->ns)
                    position++;
            [steps insertObject: [NSString stringWithFormat: @"%@[%lu]", qualifiedName(node), (unsigned long)position] atIndex: 0];
        } else {
            for (xmlNodePtr c = parent->children; c != NULL && c != node; c = c->next)
                if (isListedChild(c))
                    position++;
            [steps insertObject: [NSString stringWithFormat: @"node()[%lu]", (unsigned long)position] atIndex: 0];
        }
    }
    if (node != NULL && node->type == XML_ELEMENT_NODE)
        [steps insertObject: [NSString stringWithFormat: @"%@[1]", qualifiedName(node)] atIndex: 0];
    if ([steps count] == 0)
        return @"";
    return [@"/" stringByAppendingString: [steps componentsJoinedByString: @"/"]];
}

- (NSString *) canonicalXMLStringPreservingComments: (BOOL) comments {
    return [self XMLString];
}

- (NSString *) description {
    return [self XMLString];
}

@end
