// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: NSExtensionItem
// (https://developer.apple.com/documentation/foundation/nsextensionitem).
// The user info is copied; the attachments, title and content text are kept
// in it under their keys, so setting the user info replaces them. Expected
// values were observed on macOS 26.7.3 (x86_64) with the same inputs.
#import <Foundation/Foundation.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

int main(void)
{
    @autoreleasepool {
        report("the keys", [NSExtensionItemAttributedTitleKey isEqualToString: @"NSExtensionItemAttributedTitleKey"]
               && [NSExtensionItemAttributedContentTextKey isEqualToString: @"NSExtensionItemAttributedContentTextKey"]
               && [NSExtensionItemAttachmentsKey isEqualToString: @"NSExtensionItemAttachmentsKey"]);

        NSExtensionItem *item = [[[NSExtensionItem alloc] init] autorelease];
        report("new: nothing", item.attachments == nil && item.attributedTitle == nil
               && item.attributedContentText == nil && [item.userInfo count] == 0);

        NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject: @1 forKey: @"a"];
        item.userInfo = info;
        [info setObject: @2 forKey: @"b"];
        report("userInfo: copied", [item.userInfo isEqual: @{ @"a": @1 }]);

        item.attachments = @[];
        report("attachments: in the user info", [item.attachments isEqual: @[]]
               && [[item.userInfo objectForKey: NSExtensionItemAttachmentsKey] isEqual: @[]]
               && [[item.userInfo objectForKey: @"a"] isEqual: @1]);

        NSAttributedString *title = [[[NSAttributedString alloc] initWithString: @"title"] autorelease];
        item.attributedTitle = title;
        report("attributedTitle", [item.attributedTitle.string isEqualToString: @"title"]
               && [item.userInfo objectForKey: NSExtensionItemAttributedTitleKey] != nil);
        NSAttributedString *text = [[[NSAttributedString alloc] initWithString: @"text"] autorelease];
        item.attributedContentText = text;
        report("attributedContentText", [item.attributedContentText.string isEqualToString: @"text"]
               && [item.userInfo objectForKey: NSExtensionItemAttributedContentTextKey] != nil);

        NSExtensionItem *copy = [[item copy] autorelease];
        report("copy: a new item with the same contents", copy != item
               && [copy.attributedContentText.string isEqualToString: @"text"] && [copy.attachments isEqual: @[]]);

        item.userInfo = @{ @"k": @"v" };
        report("userInfo: replaces the rest", item.attributedTitle == nil && item.attachments == nil
               && [item.userInfo isEqual: @{ @"k": @"v" }]);
        item.userInfo = nil;
        report("userInfo: nil", item.userInfo == nil);
    }
    return failures != 0;
}
