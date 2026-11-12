// Copyright (C) 2026 Lubos Dolezel
/* KVO: addObserver:forKeyPath: for plain, key-path, and dependent keys, and
   old/new values in the change dictionary. Must work on i386 as well as
   x86_64 (the legacy runtime does not synthesize properties implicitly). */
#import <Foundation/Foundation.h>

static int failures;
#define CHECK(c, ...) do { if (!(c)) { printf("FAIL: line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); failures++; } } while (0)

@interface Obs : NSObject { @public int hits; NSMutableDictionary *last; }
@end
@implementation Obs
- (void)observeValueForKeyPath:(NSString *)k ofObject:(id)o change:(NSDictionary *)c context:(void *)ctx {
	hits++;
	if (!last) last = [NSMutableDictionary new];
	id n = [c objectForKey:NSKeyValueChangeNewKey];
	if (n) [last setObject:n forKey:k];
}
@end

@interface Inner : NSObject { int _v; }
@property int v;
@end
@implementation Inner
@synthesize v = _v;
@end

@interface Sub : NSObject { int _w; Inner *_inner; }
@property int w;
@property (retain) Inner *inner;
@property (readonly) int sum;
@end
@implementation Sub
@synthesize w = _w;
@synthesize inner = _inner;
- (int)sum { return _w + _inner.v; }
+ (NSSet *)keyPathsForValuesAffectingSum { return [NSSet setWithObjects:@"w", @"inner.v", nil]; }
@end

int main(void) {
	@autoreleasepool {
		Sub *s = [Sub new];
		s.inner = [Inner new];
		Obs *o = [Obs new];
		@try {
			[s addObserver:o forKeyPath:@"w" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
			[s addObserver:o forKeyPath:@"inner.v" options:NSKeyValueObservingOptionNew context:NULL];
			[s addObserver:o forKeyPath:@"sum" options:NSKeyValueObservingOptionNew context:NULL];
		} @catch (id e) {
			printf("FAIL: addObserver threw %s\n", [[e description] UTF8String]);
			return 1;
		}
		s.w = 3;
		/* w itself, and sum which depends on it */
		CHECK(o->hits == 2, "hits=%d after w change, want 2", o->hits);
		s.w = 4;
		o->hits = 0;
		s.inner.v = 7;
		CHECK(o->hits == 2, "hits=%d after inner.v change, want 2 (inner.v, sum)", o->hits);
		CHECK([[o->last objectForKey:@"sum"] intValue] == 11, "sum new=%d, want 11", [[o->last objectForKey:@"sum"] intValue]);
		CHECK([[o->last objectForKey:@"w"] intValue] == 4, "w new");
		[s removeObserver:o forKeyPath:@"w"];
		[s removeObserver:o forKeyPath:@"inner.v"];
		[s removeObserver:o forKeyPath:@"sum"];
		o->hits = 0;
		s.w = 9;
		CHECK(o->hits == 0, "hits=%d after remove", o->hits);
	}
	if (failures) return 1;
	printf("PASS: kvo_basic\n");
	return 0;
}
