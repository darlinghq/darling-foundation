/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * A class may keep its key-value observation info in its own instance variable by overriding
 * -observationInfo and -setObservationInfo: with a plain pointer. Observing such an object must
 * keep working: the info has to stay alive for as long as observers are registered.
 * Observed on macOS 10.14.4 (x86_64, i386) and macOS 26.7.3.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

@interface Own : NSObject {
    void *_observationInfo;
    NSString *_name;
    int _count;
}
@property (copy) NSString *name;
@property int count;
@end

@implementation Own
@synthesize name = _name, count = _count;
- (void *)observationInfo { return _observationInfo; }
- (void)setObservationInfo:(void *)value { _observationInfo = value; }
@end

@interface Watcher : NSObject {
    @public
    int changes;
    NSString *lastNew;
}
@end

@implementation Watcher
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    changes++;
    lastNew = [change objectForKey:NSKeyValueChangeNewKey];
}
@end

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

int main(void) {
    @autoreleasepool {
        Own *object = [[Own alloc] init];
        Watcher *first = [[Watcher alloc] init];
        Watcher *second = [[Watcher alloc] init];
        CHECK([object observationInfo] == NULL);

        [object addObserver:first forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:NULL];
        CHECK([object observationInfo] != NULL);
        object.name = @"a";
        CHECK(first->changes == 1 && [first->lastNew isEqual:@"a"]);

        /* a second observer reuses the stored info */
        [object addObserver:second forKeyPath:@"count" options:NSKeyValueObservingOptionNew context:NULL];
        object.count = 3;
        object.name = @"b";
        CHECK(first->changes == 2 && second->changes == 1);

        [object removeObserver:first forKeyPath:@"name"];
        object.name = @"c";
        CHECK(first->changes == 2);
        [object removeObserver:second forKeyPath:@"count"];
        CHECK([object observationInfo] == NULL);

        /* registrations and removals can repeat on the same object */
        for (int i = 0; i < 50; i++) {
            [object addObserver:first forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:NULL];
            object.name = [NSString stringWithFormat:@"n%d", i];
            [object removeObserver:first forKeyPath:@"name"];
        }
        CHECK(first->changes == 52);
    }
    if (failures)
        return 1;
    puts("PASS_KVO_POINTER_OBSERVATION_INFO");
    return 0;
}
