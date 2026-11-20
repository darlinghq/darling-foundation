#import <Foundation/NSObjCRuntime.h>

// Options for parsing, building and writing XML trees. The values are part of
// the binary interface: applications pass them as compiled-in constants.
typedef NS_OPTIONS(NSUInteger, NSXMLNodeOptions) {
    NSXMLNodeOptionsNone = 0,

    NSXMLNodeIsCDATA = 1UL << 0,
    NSXMLNodeExpandEmptyElement = 1UL << 1,
    NSXMLNodeCompactEmptyElement = 1UL << 2,
    NSXMLNodeUseSingleQuotes = 1UL << 3,
    NSXMLNodeUseDoubleQuotes = 1UL << 4,
    NSXMLNodeNeverEscapeContents = 1UL << 5,

    NSXMLDocumentTidyHTML = 1UL << 9,
    NSXMLDocumentTidyXML = 1UL << 10,
    NSXMLDocumentValidate = 1UL << 13,

    NSXMLNodeLoadExternalEntitiesAlways = 1UL << 14,
    NSXMLNodeLoadExternalEntitiesSameOriginOnly = 1UL << 15,
    NSXMLNodeLoadExternalEntitiesNever = 1UL << 19,

    NSXMLDocumentXInclude = 1UL << 16,
    NSXMLNodePrettyPrint = 1UL << 17,
    NSXMLDocumentIncludeContentTypeDeclaration = 1UL << 18,

    NSXMLNodePreserveNamespaceOrder = 1UL << 20,
    NSXMLNodePreserveAttributeOrder = 1UL << 21,
    NSXMLNodePreserveEntities = 1UL << 22,
    NSXMLNodePreservePrefixes = 1UL << 23,
    NSXMLNodePreserveCDATA = 1UL << 24,
    NSXMLNodePreserveWhitespace = 1UL << 25,
    NSXMLNodePreserveDTD = 1UL << 26,
    NSXMLNodePreserveCharacterReferences = 1UL << 27,
    NSXMLNodePromoteSignificantWhitespace = 1UL << 28,
    NSXMLNodePreserveEmptyElements = (NSXMLNodeExpandEmptyElement | NSXMLNodeCompactEmptyElement),
    NSXMLNodePreserveQuotes = (NSXMLNodeUseSingleQuotes | NSXMLNodeUseDoubleQuotes),
    NSXMLNodePreserveAll = (NSXMLNodePreserveNamespaceOrder | NSXMLNodePreserveAttributeOrder |
                            NSXMLNodePreserveEntities | NSXMLNodePreservePrefixes | NSXMLNodePreserveCDATA |
                            NSXMLNodePreserveEmptyElements | NSXMLNodePreserveQuotes | NSXMLNodePreserveWhitespace |
                            NSXMLNodePreserveDTD | NSXMLNodePreserveCharacterReferences | 0xFFF00000)
};
