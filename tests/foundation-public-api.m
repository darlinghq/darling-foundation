/*
 * This file is part of Darling.
 *
 * Copyright (C) 2026 Lubos Dolezel
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.

/*
 * Foundation API used by applications, checked against macOS 10.14.4 and 26.7.3:
 *  - NSFileManager temporaryDirectory and containerURLForSecurityApplicationGroupIdentifier:
 *    (the latter returns ~/Library/Group Containers/<id> without creating it, nil for nil);
 *  - CoreFoundation calls on NSDictionary, NSMutableDictionary and NSSet instances that are not
 *    CoreFoundation's own (subclasses, as Swift's bridged collections are);
 *  - +[NSBundle bundleForClass:] for a root class whose class object cannot be copied;
 *  - copying a key-path NSExpression keeps it a key-path expression;
 *  - NSKeyValueChangeKey types the keys of the change dictionary.
 */
#import <Foundation/Foundation.h>
#include <objc/runtime.h>

@interface NSFileManager (Probe)
@property (readonly, copy) NSURL *temporaryDirectory;
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier;
@end

__attribute__((objc_root_class)) @interface ProbeRoot { Class isa; } @end
@implementation ProbeRoot @end

@interface ProbeDict : NSDictionary { NSDictionary *d; } @end
@implementation ProbeDict
- (instancetype)initWithObjects:(const id [])o forKeys:(const id<NSCopying> [])k count:(NSUInteger)n { self = [super init]; d = [[NSDictionary alloc] initWithObjects:o forKeys:k count:n]; return self; }
- (NSUInteger)count { return d.count; }
- (id)objectForKey:(id)k { return [d objectForKey:k]; }
- (NSEnumerator *)keyEnumerator { return [d keyEnumerator]; }
@end

@interface ProbeSet : NSSet { NSSet *s; } @end
@implementation ProbeSet
- (instancetype)initWithObjects:(const id [])o count:(NSUInteger)n { self = [super init]; s = [[NSSet alloc] initWithObjects:o count:n]; return self; }
- (NSUInteger)count { return s.count; }
- (id)member:(id)o { return [s member:o]; }
- (NSEnumerator *)objectEnumerator { return [s objectEnumerator]; }
@end

@interface Observed : NSObject { @public int value; } @end
@implementation Observed @end
@interface Observer : NSObject { @public NSMutableArray<NSKeyValueChangeKey> *keys; } @end
@implementation Observer
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context
{
	NSKeyValueChangeKey k = NSKeyValueChangeNewKey;
	if (change[k] != nil) [keys addObject:k];
	[keys addObject:NSKeyValueChangeKindKey];
}
@end

static int failures;
#define CHECK(cond, ...) do { if (cond) printf("PASS "); else { printf("FAIL "); failures++; } printf(__VA_ARGS__); printf("\n"); } while (0)

static void applier(const void *k, const void *v, void *ctx) { (*(int *)ctx)++; }
static void setApplier(const void *v, void *ctx) { (*(int *)ctx)++; }

int main(void)
{
	@autoreleasepool {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSURL *tmp = fm.temporaryDirectory;
		CHECK([tmp isFileURL] && [[tmp.path stringByStandardizingPath] isEqual:[NSTemporaryDirectory() stringByStandardizingPath]] &&
		      [[tmp absoluteString] hasSuffix:@"/"], "temporaryDirectory is the temporary directory as a directory file URL");

		NSString *base = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Group Containers"];
		NSString *gid = @"group.org.example.foundation-api-test";
		NSURL *u = [fm containerURLForSecurityApplicationGroupIdentifier:gid];
		CHECK(u != nil && [u isFileURL] && [u.path isEqual:[base stringByAppendingPathComponent:gid]], "container URL is ~/Library/Group Containers/<id>");
		CHECK(![fm fileExistsAtPath:u.path], "the container directory is not created by the call");
		CHECK([fm containerURLForSecurityApplicationGroupIdentifier:nil] == nil, "a nil identifier gives nil");

		ProbeDict *pd = [[ProbeDict alloc] initWithObjects:(id[]){ @"1", @"2" } forKeys:(id[]){ @"a", @"b" } count:2];
		const void *val = NULL; int n = 0;
		CHECK(CFDictionaryGetValueIfPresent((CFDictionaryRef)pd, @"a", &val) && [(__bridge id)val isEqual:@"1"], "CFDictionaryGetValueIfPresent on a dictionary subclass");
		CHECK(!CFDictionaryGetValueIfPresent((CFDictionaryRef)pd, @"zz", &val), "a missing key is not present");
		CHECK(CFDictionaryContainsKey((CFDictionaryRef)pd, @"b") && !CFDictionaryContainsKey((CFDictionaryRef)pd, @"zz"), "CFDictionaryContainsKey");
		CHECK(CFDictionaryGetCountOfKey((CFDictionaryRef)pd, @"a") == 1 && CFDictionaryGetCountOfKey((CFDictionaryRef)pd, @"zz") == 0, "CFDictionaryGetCountOfKey");
		CFDictionaryApplyFunction((CFDictionaryRef)pd, applier, &n);
		CHECK(n == 2, "CFDictionaryApplyFunction visits both entries");
		NSMutableDictionary *md = [NSMutableDictionary dictionaryWithObject:@"x" forKey:@"k"];
		CFDictionaryAddValue((CFMutableDictionaryRef)md, @"k", @"y");
		CFDictionaryAddValue((CFMutableDictionaryRef)md, @"j", @"z");
		CHECK([md[@"k"] isEqual:@"x"] && [md[@"j"] isEqual:@"z"], "CFDictionaryAddValue keeps an existing key and adds a new one");

		ProbeSet *ps = [[ProbeSet alloc] initWithObjects:(id[]){ @"p", @"q" } count:2];
		const void *m = NULL; n = 0;
		CHECK(CFSetGetValueIfPresent((CFSetRef)ps, @"p", &m) && [(__bridge id)m isEqual:@"p"], "CFSetGetValueIfPresent on a set subclass");
		CFSetApplyFunction((CFSetRef)ps, setApplier, &n);
		CHECK(n == 2 && CFSetContainsValue((CFSetRef)ps, @"q") && !CFSetContainsValue((CFSetRef)ps, @"zz"), "CFSetApplyFunction and CFSetContainsValue");

		NSBundle *b = nil; BOOL raised = NO;
		@try { b = [NSBundle bundleForClass:objc_getClass("ProbeRoot")]; } @catch (NSException *ex) { raised = YES; }
		CHECK(!raised && b != nil, "bundleForClass: accepts a root class");
		CHECK([NSBundle bundleForClass:objc_getClass("ProbeRoot")] == b, "and answers the same bundle again");

		NSExpression *kp = [NSExpression expressionForKeyPath:@"a.b"];
		NSExpression *cp = [kp copy];
		CHECK(cp.expressionType == NSKeyPathExpressionType && [cp.keyPath isEqual:@"a.b"], "a copy of a key-path expression is a key-path expression");

		Observed *o = [Observed new]; Observer *ob = [Observer new];
		ob->keys = [NSMutableArray new];
		[o addObserver:ob forKeyPath:@"description" options:NSKeyValueObservingOptionNew context:NULL];
		[o removeObserver:ob forKeyPath:@"description"];
		CHECK([ob->keys count] == 0, "NSKeyValueChangeKey-typed observer compiles and no stray callback");
		NSKeyValueChangeKey kk = NSKeyValueChangeKindKey;
		CHECK([kk isEqual:@"kind"] && [NSKeyValueChangeNewKey isEqual:@"new"] && [NSKeyValueChangeOldKey isEqual:@"old"] &&
		      [NSKeyValueChangeIndexesKey isEqual:@"indexes"] && [NSKeyValueChangeNotificationIsPriorKey isEqual:@"notificationIsPrior"], "the change keys keep their string values");
	}
	printf("%s\n", failures ? "FAILED" : "PASS: Foundation API");
	return failures != 0;
}
