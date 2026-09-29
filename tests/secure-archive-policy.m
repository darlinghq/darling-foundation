#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
static NSUInteger insecureEncodes;
@interface InsecureChild : NSObject <NSCoding>
@end
@implementation InsecureChild
- (void)encodeWithCoder:(NSCoder *)coder { ++insecureEncodes; }
- (id)initWithCoder:(NSCoder *)coder { return [super init]; }
@end
@interface SecureBox : NSObject <NSSecureCoding> { @public id child; }
@end
@implementation SecureBox
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeObject:child forKey:@"child"]; }
- (id)initWithCoder:(NSCoder *)coder { return [super init]; }
@end
@interface RefusingBox : SecureBox
@end
@implementation RefusingBox
+ (BOOL)supportsSecureCoding { return NO; }
@end
@interface SubstitutingChild : InsecureChild
@end
@implementation SubstitutingChild
- (Class)classForKeyedArchiver { return [SecureBox class]; }
@end
@interface ReplacingBox : SecureBox
@end
@implementation ReplacingBox
- (id)replacementObjectForKeyedArchiver:(NSKeyedArchiver *)archiver { return child; }
@end

int main(void) {
    @autoreleasepool {
        SecureBox *box = [[[SecureBox alloc] init] autorelease];
        InsecureChild *child = [[[InsecureChild alloc] init] autorelease];
        box->child = child;
        NSError *error = nil;
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:YES error:&error] == nil);
        assert(error != nil && insecureEncodes == 0);
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:YES error:NULL] == nil);
        assert(insecureEncodes == 0);
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:NO error:NULL] != nil);
        assert(insecureEncodes == 1);
        assert([NSKeyedArchiver archivedDataWithRootObject:box] != nil);
        assert(insecureEncodes == 2);
        box->child = nil;
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:YES error:NULL] != nil);
        assert([NSKeyedArchiver archivedDataWithRootObject:nil requiringSecureCoding:YES error:NULL] != nil);
        box->child = @"secure string";
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:YES error:NULL] != nil);
        box->child = [[[RefusingBox alloc] init] autorelease];
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:YES error:NULL] == nil);
        box->child = [[[SubstitutingChild alloc] init] autorelease];
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:YES error:NULL] == nil);
        ReplacingBox *replacement = [[[ReplacingBox alloc] init] autorelease];
        replacement->child = child;
        box->child = replacement;
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:YES error:NULL] == nil);
        assert(insecureEncodes == 2);
        replacement->child = @"replacement string";
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:YES error:NULL] != nil);
        box->child = @[@{ @"nested": child }];
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:YES error:NULL] == nil);
        assert(insecureEncodes == 2);
        box->child = @[@{ @"nested": @"allowed" }];
        assert([NSKeyedArchiver archivedDataWithRootObject:box requiringSecureCoding:YES error:NULL] != nil);
        for (NSUInteger secure = 0; secure < 2; ++secure) {
            NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:secure];
            assert([archiver requiresSecureCoding] == secure);
            BOOL rejected = NO;
            @try { [archiver encodeObject:child forKey:@"child"]; }
            @catch (NSException *exception) {
                rejected = [[exception name] isEqual:NSInvalidArchiveOperationException];
            }
            assert(rejected == secure);
            [archiver release];
        }
    }
    puts("PASS: secure archive policy covers nested objects and nil");
    return 0;
}
