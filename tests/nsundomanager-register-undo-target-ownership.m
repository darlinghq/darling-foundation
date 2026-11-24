// Copyright (C) 2026 Lubos Dolezel
//
// -[NSUndoManager registerUndoWithTarget:selector:object:] keeps an unowned reference to the target
// (to avoid retain cycles) and a strong reference to the object, as documented:
// https://developer.apple.com/documentation/foundation/undomanager/registerundo(withtarget:selector:object:)
// The target is released by its owner right after registering, and the manager must not keep it
// alive; the object is released by its owner and must still be there when the undo runs, and be let
// go of once the action is gone. The handler variant has the same contract
// (https://developer.apple.com/documentation/foundation/undomanager/registerundo(withtarget:handler:)).
// Built without ARC.
#import <Foundation/Foundation.h>

static int failures;
static BOOL targetDeallocated, payloadDeallocated;
static int payloadSeen;

static void expect(BOOL condition, const char *what) {
    printf("%s: %s\n", condition ? "PASS" : "FAIL", what);
    if (!condition)
        failures++;
}

@interface Target : NSObject
- (void)run:(id)payload;
@end

@implementation Target
- (void)run:(id)payload { payloadSeen = [payload intValue]; }
- (void)dealloc { targetDeallocated = YES; [super dealloc]; }
@end

@interface Payload : NSObject
- (int)intValue;
@end

@implementation Payload
- (int)intValue { return 42; }
- (void)dealloc { payloadDeallocated = YES; [super dealloc]; }
@end

int main(void) {
    @autoreleasepool {
        NSUndoManager *manager = [[NSUndoManager alloc] init];
        [manager setGroupsByEvent:NO];

        /* the target is not retained by the manager */
        Target *dying = [[Target alloc] init];
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:dying selector:@selector(run:) object:nil];
        [manager endUndoGrouping];
        [dying release];
        expect(targetDeallocated, "the manager does not keep the target alive");
        [manager removeAllActions];

        /* the object is retained until the action is gone */
        Target *target = [[Target alloc] init];
        Payload *payload = [[Payload alloc] init];
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:target selector:@selector(run:) object:payload];
        [manager endUndoGrouping];
        [payload release];
        expect(!payloadDeallocated, "the manager keeps the object alive");
        @autoreleasepool { [manager undo]; }
        expect(payloadSeen == 42, "the undo delivers the object");
        @autoreleasepool { [manager removeAllActions]; }
        expect(payloadDeallocated, "the object is let go of when the action is gone");
        /* removing the actions of the target lets go of the object too, and a nil object is fine */
        payloadDeallocated = NO;
        payload = [[Payload alloc] init];
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:target selector:@selector(run:) object:payload];
        [manager registerUndoWithTarget:target selector:@selector(run:) object:nil];
        [manager endUndoGrouping];
        [payload release];
        expect(!payloadDeallocated, "the object is held while its action is registered");
        @autoreleasepool { [manager removeAllActionsWithTarget:target]; }
        expect(payloadDeallocated && ![manager canUndo], "removing the target's actions lets go of the object");
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:target selector:@selector(run:) object:nil];
        [manager endUndoGrouping];
        payloadSeen = 7;
        [manager undo];
        expect(payloadSeen == 0, "a nil object does not crash the undo");
        [manager removeAllActions];
        [target release];

        /* registerUndoWithTarget:handler: keeps an unowned reference too */
        targetDeallocated = NO;
        Target *handlerTarget = [[Target alloc] init];
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:handlerTarget handler:^(id t) { [t run:nil]; }];
        [manager endUndoGrouping];
        [handlerTarget release];
        expect(targetDeallocated, "the handler variant does not keep the target alive");
        [manager removeAllActions];
    }
    return failures;
}
