// NSPresentationIntent (Apple's NSPresentationIntent reference, macOS 12):
// each factory makes an intent of its kind that keeps its identity, its
// kind's own value and the intent it is nested in; intents are immutable, so
// a copy is the same object; equivalence ignores the identities.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(cond, what) do { if (!(cond)) { printf("FAIL: %s\n", what); failures++; } else printf("PASS: %s\n", what); } while (0)

int main(void)
{
    @autoreleasepool
    {
        CHECK([NSPresentationIntentAttributeName isEqualToString:@"NSPresentationIntent"],
              "the attribute key matches macOS");

        NSPresentationIntent *quote = [NSPresentationIntent blockQuoteIntentWithIdentity:1 nestedInsideIntent:nil];
        CHECK(quote.intentKind == NSPresentationIntentKindBlockQuote && quote.identity == 1 && quote.parentIntent == nil,
              "a block quote keeps its kind and identity, and has no parent");

        NSPresentationIntent *inner = [NSPresentationIntent blockQuoteIntentWithIdentity:2 nestedInsideIntent:quote];
        CHECK(inner.parentIntent == quote, "a nested intent keeps its parent");
        CHECK(quote.indentationLevel == 1 && inner.indentationLevel == 2,
              "each enclosing block quote indents one level more");

        NSPresentationIntent *header = [NSPresentationIntent headerIntentWithIdentity:3 level:2 nestedInsideIntent:nil];
        CHECK(header.intentKind == NSPresentationIntentKindHeader && header.headerLevel == 2,
              "a header keeps its level");
        CHECK(header.ordinal == 0 && header.row == 0 && header.column == 0 && header.columnCount == 0,
              "another kind's values are 0");

        NSPresentationIntent *list = [NSPresentationIntent orderedListIntentWithIdentity:4 nestedInsideIntent:nil];
        NSPresentationIntent *item = [NSPresentationIntent listItemIntentWithIdentity:5 ordinal:3 nestedInsideIntent:list];
        CHECK(item.intentKind == NSPresentationIntentKindListItem && item.ordinal == 3 && item.parentIntent == list,
              "a list item keeps its ordinal and its list");

        NSPresentationIntent *code = [NSPresentationIntent codeBlockIntentWithIdentity:6 languageHint:@"swift" nestedInsideIntent:nil];
        CHECK([code.languageHint isEqualToString:@"swift"], "a code block keeps its language hint");
        CHECK([NSPresentationIntent codeBlockIntentWithIdentity:7 languageHint:nil nestedInsideIntent:nil].languageHint == nil,
              "the language hint may be nil");

        NSArray *alignments = @[ @(NSPresentationIntentTableColumnAlignmentLeft), @(NSPresentationIntentTableColumnAlignmentRight) ];
        NSPresentationIntent *table = [NSPresentationIntent tableIntentWithIdentity:8 columnCount:2 alignments:alignments nestedInsideIntent:nil];
        NSPresentationIntent *row = [NSPresentationIntent tableRowIntentWithIdentity:9 row:1 nestedInsideIntent:table];
        NSPresentationIntent *cell = [NSPresentationIntent tableCellIntentWithIdentity:10 column:1 nestedInsideIntent:row];
        CHECK(table.columnCount == 2 && [table.columnAlignments isEqualToArray:alignments],
              "a table keeps its column count and alignments");
        CHECK(row.row == 1 && cell.column == 1 && cell.parentIntent.parentIntent == table,
              "a row keeps its row and a cell its column");
        CHECK([NSPresentationIntent tableHeaderRowIntentWithIdentity:11 nestedInsideIntent:table].intentKind == NSPresentationIntentKindTableHeaderRow,
              "a header row has its kind");
        CHECK([NSPresentationIntent paragraphIntentWithIdentity:12 nestedInsideIntent:nil].intentKind == NSPresentationIntentKindParagraph
              && [NSPresentationIntent thematicBreakIntentWithIdentity:13 nestedInsideIntent:nil].intentKind == NSPresentationIntentKindThematicBreak
              && [NSPresentationIntent unorderedListIntentWithIdentity:14 nestedInsideIntent:nil].intentKind == NSPresentationIntentKindUnorderedList,
              "paragraphs, thematic breaks and unordered lists have their kinds");

        CHECK([quote copy] == quote, "a copy of an intent is the intent itself");

        NSPresentationIntent *otherQuote = [NSPresentationIntent blockQuoteIntentWithIdentity:20 nestedInsideIntent:nil];
        NSPresentationIntent *otherInner = [NSPresentationIntent blockQuoteIntentWithIdentity:21 nestedInsideIntent:otherQuote];
        CHECK([inner isEquivalentToPresentationIntent:otherInner], "equivalence ignores the identities");
        CHECK(![inner isEqual:otherInner], "equality does not");
        CHECK(![inner isEquivalentToPresentationIntent:quote], "intents nested differently are not equivalent");
        CHECK(![header isEquivalentToPresentationIntent:[NSPresentationIntent headerIntentWithIdentity:3 level:1 nestedInsideIntent:nil]],
              "headers of different levels are not equivalent");
        CHECK([header isEqual:[NSPresentationIntent headerIntentWithIdentity:3 level:2 nestedInsideIntent:nil]],
              "intents with the same identity and values are equal");

        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:cell requiringSecureCoding:YES error:NULL];
        NSPresentationIntent *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSPresentationIntent class] fromData:archive error:NULL];
        CHECK(decoded != nil && [decoded isEqual:cell] && decoded.parentIntent.parentIntent.columnCount == 2,
              "an intent survives secure keyed archiving with its parents");

        NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] initWithString:@"quoted"] autorelease];
        [string addAttribute:NSPresentationIntentAttributeName value:inner range:NSMakeRange(0, 6)];
        CHECK([string attribute:NSPresentationIntentAttributeName atIndex:3 effectiveRange:NULL] == inner,
              "an attributed string carries the intent");
    }
    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures != 0;
}
