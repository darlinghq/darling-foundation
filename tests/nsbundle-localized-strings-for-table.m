#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

@interface NSBundle (LocalizedStringsForTable)
- (NSDictionary *)localizedStringsForTable:(NSString *)tableName localization:(NSString *)localizationName;
@end

static int failures;

static void expect(const char *label, id actual, id expected) {
    BOOL ok = (actual == expected) || [actual isEqual:expected];
    printf("%s %s: got %s\n", ok ? "PASS" : "FAIL", label, [[actual description] UTF8String]);
    failures += !ok;
}

static void writePlist(id plist, NSString *path, NSPropertyListFormat format) {
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist format:format options:0 error:&error];
    if (![data writeToFile:path options:0 error:&error]) {
        printf("cannot write %s: %s\n", [path UTF8String], [[error description] UTF8String]);
        exit(2);
    }
}

int main(void) {
    @autoreleasepool {
        char temp[] = "/tmp/darling-strings-table-XXXXXX";
        if (!mkdtemp(temp)) return 2;
        NSString *root = [NSString stringWithUTF8String:temp];
        NSString *bundlePath = [root stringByAppendingPathComponent:@"Tables.bundle"];
        NSString *resources = [bundlePath stringByAppendingPathComponent:@"Contents/Resources"];
        for (NSString *dir in @[@"Tables.bundle", @"Tables.bundle/Contents", @"Tables.bundle/Contents/Resources",
                                @"Tables.bundle/Contents/Resources/en.lproj", @"Tables.bundle/Contents/Resources/de.lproj"])
            if (mkdir([[root stringByAppendingPathComponent:dir] fileSystemRepresentation], 0700) != 0) return 2;

        writePlist(@{@"CFBundleIdentifier": @"org.darlinghq.strings-table-test", @"CFBundleDevelopmentRegion": @"en"},
                   [bundlePath stringByAppendingPathComponent:@"Contents/Info.plist"], NSPropertyListXMLFormat_v1_0);
        [@"\"GREETING\" = \"Hello\";\n" writeToFile:[resources stringByAppendingPathComponent:@"en.lproj/Localizable.strings"]
                                          atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        [@"\"GREETING\" = \"Hallo\";\n" writeToFile:[resources stringByAppendingPathComponent:@"de.lproj/Localizable.strings"]
                                          atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        writePlist(@{@"LocProvenance": @{}, @"en": @{@"KEY": @"Key"}, @"de": @{@"KEY": @"Taste"}},
                   [resources stringByAppendingPathComponent:@"keys.loctable"], NSPropertyListBinaryFormat_v1_0);

        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        if (!bundle) return 2;

        expect("strings table, en", [bundle localizedStringsForTable:@"Localizable" localization:@"en"], @{@"GREETING": @"Hello"});
        expect("strings table, de", [bundle localizedStringsForTable:@"Localizable" localization:@"de"], @{@"GREETING": @"Hallo"});
        expect("strings table, nil name", [bundle localizedStringsForTable:nil localization:@"de"], @{@"GREETING": @"Hallo"});
        expect("loctable, per-key lookup", [bundle localizedStringForKey:@"KEY" value:nil table:@"keys"], @"Key");
        expect("loctable table, en", [bundle localizedStringsForTable:@"keys" localization:@"en"], @{@"KEY": @"Key"});
        expect("loctable table, de", [bundle localizedStringsForTable:@"keys" localization:@"de"], @{@"KEY": @"Taste"});

        [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];
    }
    printf("failures=%d\n", failures);
    return failures ? 1 : 0;
}
