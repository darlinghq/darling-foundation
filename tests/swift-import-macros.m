/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * Build with -Wassign-enum -Werror=assign-enum -Werror=undef.
 *
 * NS_OPTIONS enums carry flag_enum, so OR-ed combinations of their members
 * are valid values (a plain enum would trigger -Wassign-enum); NS_ENUM enums
 * carry enum_extensibility(open). NS_HEADER_AUDIT_BEGIN/END open and close a
 * nullability-audited region, and NS_SWIFT_SENDABLE is defined.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)
@interface AuditProbe : NSObject
- (NSString *)echo:(NSString *)s;
@end
NS_HEADER_AUDIT_END(nullability, sendability)

@implementation AuditProbe
- (NSString *)echo:(NSString *)s { return s; }
@end

typedef NS_OPTIONS(NSUInteger, ProbeOptions) {
	ProbeOptionA = 1 << 0,
	ProbeOptionB = 1 << 1,
	ProbeOptionC = 1 << 2,
};

#ifndef NS_SWIFT_SENDABLE
#error NS_SWIFT_SENDABLE is not defined
#endif

int main(void)
{
	@autoreleasepool {
		int failures = 0;
		ProbeOptions o = ProbeOptionA | ProbeOptionC;
		NSDataReadingOptions r = NSDataReadingMappedIfSafe | NSDataReadingUncached;
		if (o != 5 || r != (NSDataReadingMappedIfSafe | NSDataReadingUncached)) {
			printf("FAIL: option combination\n");
			failures++;
		}
		if (!__has_attribute(flag_enum) || !__has_attribute(enum_extensibility)) {
			printf("FAIL: compiler lacks the attributes\n");
			failures++;
		}
		if (![[[AuditProbe new] echo:@"x"] isEqual:@"x"]) {
			printf("FAIL: audited interface\n");
			failures++;
		}
		if (failures == 0)
			printf("PASS: Swift-import macros compile and work\n");
		return failures != 0;
	}
}
