// Copyright (C) 2026 Lubos Dolezel
//
// NSXMLDocument, NSXMLElement and NSXMLNode: parsing, navigation, string values,
// XPath, serialization and editing. Expected values are what macOS 26.7.3 and
// Mac OS X 10.14.4 return for the same calls (black-box observation, both alike).
// MRC; runs on i386 too.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(cond, label) do { if (!(cond)) { printf("FAIL %s (line %d)\n", label, __LINE__); failures++; } } while (0)
#define EQ(a, b, label) do { id _a = (a), _b = (b); if (!(_a == _b || [_a isEqual:_b])) { printf("FAIL %s: got [%s] want [%s] (line %d)\n", label, [[_a description] UTF8String], [[_b description] UTF8String], __LINE__); failures++; } } while (0)

static NSString *names(NSArray *nodes)
{
    NSMutableArray *a = [NSMutableArray array];
    for (NSXMLNode *n in nodes)
        [a addObject:[NSString stringWithFormat:@"%lu:%@=%@", (unsigned long)[n kind], [n name], [n stringValue]]];
    return [a componentsJoinedByString:@" | "];
}

static NSArray *xpath(NSXMLNode *node, NSString *query)
{
    return [node nodesForXPath:query error:NULL];
}

static void testParsing(void)
{
    NSString *xml = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!-- top -->\n<syntax version=\"2\" a=\"1\">\n  <head>\n"
        "    <name>Default</name>\n    <chars><![CDATA[_<&>]]></chars>\n    <opt flag=\"yes\" z=\"last\"/>\n  </head>\n"
        "  <states>\n    <default id=\"Base\"><state id=\"s1\"><begin><regex>a</regex></begin></state><state-link id=\"l1\"/><state id=\"s2\"/></default>\n  </states>\n"
        "  <mixed>one<b>two</b>three<?pi data?></mixed>\n</syntax>\n";
    NSError *err = nil;
    NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithData:[xml dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&err] autorelease];
    CHECK(doc != nil && err == nil, "document parsed");
    CHECK([doc kind] == NSXMLDocumentKind, "document kind");
    CHECK([doc childCount] == 2, "comment and root element are the document's children");
    EQ([doc version], @"1.0", "version");
    EQ([doc characterEncoding], @"UTF-8", "encoding");
    CHECK([doc isStandalone], "standalone quirk: declaration without standalone attribute");
    CHECK([[doc childAtIndex:0] kind] == NSXMLCommentKind, "first child is the comment");
    EQ([[doc childAtIndex:0] stringValue], @" top ", "comment value");

    NSXMLElement *root = [doc rootElement];
    EQ([root name], @"syntax", "root name");
    CHECK([root parent] == doc && [root rootDocument] == doc, "root's parent is the document");
    CHECK([root level] == 1 && [root index] == 1, "root level and index");
    EQ(names([root children]), @"2:head=Default_<&> | 2:states=a | 2:mixed=onetwothreedata", "whitespace-only text is left out; stringValue concatenates");
    EQ(names([root attributes]), @"3:version=2 | 3:a=1", "attributes in order");

    NSXMLElement *head = [[root elementsForName:@"head"] firstObject];
    NSXMLElement *chars = [[head elementsForName:@"chars"] firstObject];
    EQ([chars stringValue], @"_<&>", "CDATA content");
    CHECK([chars childCount] == 1 && [[chars childAtIndex:0] kind] == NSXMLTextKind, "CDATA becomes text");
    EQ([chars XMLString], @"<chars>_&lt;&amp;&gt;</chars>", "text is escaped");
    NSXMLElement *opt = [[head elementsForName:@"opt"] firstObject];
    NSXMLNode *flag = [opt attributeForName:@"flag"];
    CHECK([flag kind] == NSXMLAttributeKind && [flag parent] == opt, "attribute kind and parent");
    EQ([flag stringValue], @"yes", "attribute value");
    EQ([opt XMLString], @"<opt flag=\"yes\" z=\"last\"></opt>", "empty element is written with an end tag");
    EQ([opt description], [opt XMLString], "description is the XML string");

    NSXMLElement *mixed = [[root elementsForName:@"mixed"] firstObject];
    EQ(names([mixed children]), @"7:(null)=one | 2:b=two | 7:(null)=three | 5:pi=data", "mixed content");
    NSXMLNode *name = [head childAtIndex:0];
    EQ([[name nextSibling] name], @"chars", "nextSibling");
    EQ([[chars previousSibling] name], @"name", "previousSibling");
    CHECK([[name nextNode] kind] == NSXMLTextKind && [[[name nextNode] stringValue] isEqual:@"Default"], "nextNode goes into the children");
    EQ([chars XPath], @"/syntax[1]/head[1]/chars[1]", "XPath of an element");
    CHECK([chars level] == 3 && [chars index] == 1, "level and index");

    // XPath queries
    EQ(names(xpath(doc, @"/syntax/head/opt/@flag")), @"3:flag=yes", "attribute step");
    EQ(names(xpath(doc, @"//state")), @"2:state=a | 2:state=", "descendant axis");
    CHECK([xpath(doc, @"/syntax/nothing") count] == 0 && xpath(doc, @"/syntax/nothing") != nil, "no match gives an empty array");
    EQ(names(xpath(doc, @"//state[@id='s2']")), @"2:state=", "predicate");
    EQ(names(xpath(doc, @"/syntax/mixed/text()")), @"7:(null)=one | 7:(null)=three", "text()");
    EQ(names(xpath(root, @"/syntax/head/name")), @"2:name=Default", "absolute path from an element of a document");
    EQ(names(xpath(root, @"head/name")), @"2:name=Default", "relative path");
    NSXMLElement *def = [xpath(doc, @"/syntax/states/default") firstObject];
    EQ(names(xpath(def, @"./state-link | ./state")), @"2:state=a | 2:state-link= | 2:state=", "union in document order");
    EQ(names(xpath(def, @"./state/begin/regex")), @"2:regex=a", "nested relative path");
    EQ(names(xpath(def, @"..")), @"2:states=a", "parent step");
    err = nil;
    CHECK([doc nodesForXPath:@"count(//state)" error:&err] == nil && err == nil, "non-node result: nil without error");
    err = nil;
    CHECK([doc nodesForXPath:@"/syntax[" error:&err] == nil && [[err domain] isEqual:@"XQueryErrorDomain"], "bad expression: nil and an XQuery error");

    // serialization of a parsed document
    NSXMLDocument *nows = [[[NSXMLDocument alloc] initWithXMLString:@"<a>\n  <b/>\n  <c>  x  </c>\n</a>" options:0 error:NULL] autorelease];
    CHECK([[nows rootElement] childCount] == 2, "whitespace between elements left out");
    EQ([nows XMLString], @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><a><b></b><c>  x  </c></a>", "document XML string");
    NSXMLDocument *nd = [[[NSXMLDocument alloc] initWithData:[@"<z/>" dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL] autorelease];
    CHECK([[nd version] isEqual:@"1.0"] && [nd characterEncoding] == nil, "data without declaration: version 1.0, no encoding");
    CHECK(![nd isStandalone], "standalone quirk: no declaration");
    EQ([nd XMLString], @"<?xml version=\"1.0\"?><z></z>", "declaration written for a parsed document");

    NSXMLDocument *ed = [[[NSXMLDocument alloc] initWithXMLString:@"<!DOCTYPE z [<!ENTITY e \"ent\">]><z>&e;&amp;&#65;</z>" options:0 error:NULL] autorelease];
    CHECK([ed childCount] == 1, "the DTD is not a child");
    EQ([[ed rootElement] stringValue], @"ent&A", "entities replaced");
    CHECK([[ed rootElement] childCount] == 1, "replaced entities merge into one text node");

    NSXMLElement *ws = [[[NSXMLElement alloc] initWithXMLString:@"<p>a <b>x</b> <i>y</i></p>" error:NULL] autorelease];
    CHECK([ws childCount] == 3, "whitespace-only text between elements left out");
    NSXMLElement *wsonly = [[[NSXMLElement alloc] initWithXMLString:@"<p>   </p>" error:NULL] autorelease];
    CHECK([wsonly childCount] == 0, "whitespace-only element content left out");
}

static void testErrors(void)
{
    NSError *e = nil;
    NSXMLDocument *broken = [[NSXMLDocument alloc] initWithXMLString:@"<a><b></a>" options:0 error:&e];
    CHECK(broken == nil && [[e domain] isEqual:NSXMLParserErrorDomain] && [e code] == NSXMLParserTagNameMismatchError, "mismatched tag");
    e = nil;
    broken = [[NSXMLDocument alloc] initWithData:[NSData data] options:0 error:&e];
    CHECK(broken == nil && [[e domain] isEqual:NSXMLParserErrorDomain] && [e code] == NSXMLParserEmptyDocumentError, "empty data");
}

static void testBuilding(void)
{
    NSXMLElement *r = [NSXMLElement elementWithName:@"r"];
    NSXMLDocument *d = [NSXMLDocument documentWithRootElement:r];
    EQ([d XMLString], @"<r></r>", "built document without version has no declaration");
    [d setVersion:@"1.0"];
    [r addAttribute:[NSXMLNode attributeWithName:@"k" stringValue:@"v&\""]];
    [r addChild:[NSXMLElement elementWithName:@"x" stringValue:@"1<2"]];
    [r addChild:[NSXMLNode commentWithStringValue:@"c"]];
    NSXMLElement *y = [NSXMLElement elementWithName:@"y"];
    [r insertChild:y atIndex:0];
    EQ([d XMLString], @"<?xml version=\"1.0\"?><r k=\"v&amp;&quot;\"><y></y><x>1&lt;2</x><!--c--></r>", "built document");
    CHECK([r childCount] == 3 && [y index] == 0, "inserted child index");
    EQ([[[NSString alloc] initWithData:[d XMLData] encoding:NSUTF8StringEncoding] autorelease], [d XMLString], "XMLData");
    [y detach];
    CHECK([y parent] == nil, "detached node has no parent");
    EQ([r XMLString], @"<r k=\"v&amp;&quot;\"><x>1&lt;2</x><!--c--></r>", "after detach");
    [r setStringValue:@"plain"];
    CHECK([r childCount] == 1, "setStringValue replaces the children");
    [r removeAttributeForName:@"k"];
    [r setAttributesWithDictionary:@{@"p": @"1"}];
    EQ([r XMLString], @"<r p=\"1\">plain</r>", "attributes replaced");

    NSXMLElement *e = [NSXMLElement elementWithName:@"e"];
    [e addAttribute:[NSXMLNode attributeWithName:@"k" stringValue:@"1"]];
    [e addAttribute:[NSXMLNode attributeWithName:@"k" stringValue:@"2"]];
    [e addAttribute:[NSXMLNode attributeWithName:@"a" stringValue:@"3"]];
    EQ([e XMLString], @"<e k=\"2\" a=\"3\"></e>", "an attribute of the same name is replaced in place");
    CHECK([[e attributeForName:@"a"] index] == 1, "attribute index");

    NSXMLElement *p = [NSXMLElement elementWithName:@"p"];
    NSXMLElement *c = [NSXMLElement elementWithName:@"c"];
    [p addChild:c];
    NSString *exception = nil;
    @try { [e addChild:c]; }
    @catch (NSException *x) { exception = [x name]; }
    EQ(exception, NSInternalInconsistencyException, "adding a child that has a parent raises");
    CHECK([c parent] == p, "the child stays where it was");

    [e addChild:[NSXMLNode textWithStringValue:@"t1"]];
    [e addChild:[NSXMLNode textWithStringValue:@"t2"]];
    CHECK([e childCount] == 2, "adjacent text nodes are not merged");
    EQ([e XMLString], @"<e k=\"2\" a=\"3\">t1t2</e>", "two text nodes");

    NSXMLDocument *empty = [NSXMLDocument document];
    CHECK([empty version] == nil && [empty childCount] == 0, "new document");
    EQ([empty XMLString], @"", "empty document XML string");

    EQ([NSXMLNode prefixForName:@"a"], @"", "no prefix");
    EQ([NSXMLNode prefixForName:@"p:a"], @"p", "prefix");
    EQ([NSXMLNode localNameForName:@"p:a"], @"a", "local name");

    NSXMLElement *m = [[[NSXMLElement alloc] initWithXMLString:@"<m>x<!--cm-->y<?pi z?></m>" error:NULL] autorelease];
    EQ([m stringValue], @"xcmyz", "stringValue includes comments and processing instructions");
    CHECK([m parent] == nil && [m rootDocument] == nil, "element made from a string has no document");
    CHECK([[NSXMLElement elementWithName:@"es" stringValue:@""] childCount] == 1, "empty string value is a text child");
    [m setStringValue:@""];
    CHECK([m childCount] == 1, "setStringValue empty leaves a text child");
    EQ([m XMLString], @"<m></m>", "empty text");

    NSXMLElement *q = [[[NSXMLElement alloc] initWithXMLString:@"<q><a/><b>t</b></q>" error:NULL] autorelease];
    NSXMLNode *a = [[[q childAtIndex:0] retain] autorelease];
    [q removeChildAtIndex:0];
    CHECK([a parent] == nil && [a index] == 0, "removed child");
    EQ([q XMLString], @"<q><b>t</b></q>", "after removal");
    EQ([a XMLString], @"<a></a>", "a removed child stays usable");

    NSXMLDocument *d2 = [[[NSXMLDocument alloc] initWithXMLString:@"<r x=\"1\"><s>t<u/>v</s></r>" options:0 error:NULL] autorelease];
    NSXMLNode *txt = [[[[d2 rootElement] childAtIndex:0] children] lastObject];
    EQ([txt XPath], @"/r[1]/s[1]/node()[3]", "XPath of a text node");
    EQ([[[d2 rootElement] attributeForName:@"x"] XPath], @"/r[1]/@x", "XPath of an attribute");
    EQ([d2 XPath], @"", "XPath of the document");
    CHECK(![d2 isStandalone], "standalone quirk: no declaration in a string");

    NSXMLElement *det = [[[NSXMLElement alloc] initWithXMLString:@"<x><y/></x>" error:NULL] autorelease];
    NSError *err = nil;
    CHECK([det nodesForXPath:@"/x/y" error:&err] == nil && [[err domain] isEqual:@"XQueryErrorDomain"], "absolute path on an element without a document");
    CHECK([xpath(det, @"y") count] == 1, "relative path on an element without a document");

    NSXMLElement *pp = [[[NSXMLElement alloc] initWithXMLString:@"<a><b><c/></b><d>t</d><!--k--></a>" error:NULL] autorelease];
    EQ([pp XMLStringWithOptions:NSXMLNodeCompactEmptyElement], @"<a><b><c/></b><d>t</d><!--k--></a>", "compact empty elements");
    NSXMLDocument *pd = [[[NSXMLDocument alloc] initWithRootElement:[[pp copy] autorelease]] autorelease];
    EQ([pd XMLStringWithOptions:NSXMLNodePrettyPrint], @"\n<a>\n    <b>\n        <c></c>\n    </b>\n    <d>t</d>\n    <!--k-->\n</a>", "pretty printed document");
    EQ([pd XMLString], @"<a><b><c></c></b><d>t</d><!--k--></a>", "copy into a new document");
    CHECK([pp childCount] == 3, "the original is unchanged by the copy");

    EQ([[NSXMLNode attributeWithName:@"w" stringValue:@"a<b>\"c\"\n"] XMLString], @"w=\"a&lt;b&gt;&quot;c&quot;\n\"", "attribute escaping");
    EQ([[NSXMLNode textWithStringValue:@"a<b>&\"'"] XMLString], @"a&lt;b&gt;&amp;\"'", "text escaping");
    EQ([[NSXMLNode processingInstructionWithName:@"t" stringValue:@""] XMLString], @"<?t?>", "processing instruction");
    EQ([[NSXMLNode commentWithStringValue:@"x"] XMLString], @"<!--x-->", "comment");
}

// Nodes handed out stay valid as long as they are retained, whatever happens to the tree.
static void testLifetime(void)
{
    NSXMLNode *kept;
    NSXMLElement *keptElement;
    @autoreleasepool {
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:@"<r><a x=\"1\"><b>t</b></a><c/></r>" options:0 error:NULL];
        kept = [[(NSXMLElement *)[[doc rootElement] childAtIndex:0] attributeForName:@"x"] retain];
        keptElement = (NSXMLElement *)[[[doc rootElement] childAtIndex:1] retain];
        [doc release];
    }
    EQ([kept stringValue], @"1", "attribute outlives its document");
    @autoreleasepool {
        [keptElement detach];
        EQ([keptElement XMLString], @"<c></c>", "detached element outlives its document");
    }
    [kept release];
    [keptElement release];

    @autoreleasepool {
        NSXMLElement *r = [[[NSXMLElement alloc] initWithXMLString:@"<r><a><b/></a></r>" error:NULL] autorelease];
        NSXMLNode *b = [[[r childAtIndex:0] childAtIndex:0] retain];
        [r setChildren:nil];
        CHECK([r childCount] == 0, "setChildren nil");
        EQ([b XMLString], @"<b></b>", "a node inside a removed subtree stays usable");
        [b release];
    }
}

int main(void)
{
    @autoreleasepool {
        testParsing();
        testErrors();
        testBuilding();
        testLifetime();
    }
    if (failures == 0)
        printf("PASS nsxml-tree\n");
    return failures != 0;
}
