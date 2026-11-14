// Copyright (C) 2026 Lubos Dolezel
// valueForKey: on a getter that returns a struct boxes the value, for structs the ABI returns in
// registers and for those it returns through memory alike (on i386, a CGPoint or NSRange comes back
// in registers, a CGRect through a hidden pointer).
#import <Foundation/Foundation.h>

@interface Holder : NSObject
- (CGPoint)point;
- (CGSize)size;
- (CGRect)rect;
- (NSRange)range;
@end

@implementation Holder
- (CGPoint)point { return CGPointMake(3, 4); }
- (CGSize)size { return CGSizeMake(5, 6); }
- (CGRect)rect { return CGRectMake(1, 2, 3, 4); }
- (NSRange)range { return NSMakeRange(7, 8); }
@end

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL: %s (line %d)\n", #c, __LINE__); failures++; } } while (0)

int main(void) {
	@autoreleasepool {
		Holder *h = [[Holder alloc] init];
		CGPoint p; CGSize s; CGRect r; NSRange n;
		[[h valueForKey:@"point"] getValue:&p];
		[[h valueForKey:@"size"] getValue:&s];
		[[h valueForKey:@"rect"] getValue:&r];
		[[h valueForKey:@"range"] getValue:&n];
		CHECK(p.x == 3 && p.y == 4);
		CHECK(s.width == 5 && s.height == 6);
		CHECK(r.origin.x == 1 && r.origin.y == 2 && r.size.width == 3 && r.size.height == 4);
		CHECK(n.location == 7 && n.length == 8);
	}
	printf(failures ? "FAILED\n" : "PASS\n");
	return failures != 0;
}
