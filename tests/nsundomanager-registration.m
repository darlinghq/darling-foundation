// Copyright (C) 2026 Lubos Dolezel
//
// NSUndoManager: introspection of the manager and registration of undo actions with selectors that do not match the
// documented shape. Observed on macOS 10.14.4 and 26.7.3 (they agree; probe um1.m of batch11b). The manager's own
// methods have method signatures like those of any object; registerUndoWithTarget:selector:object: records the action
// whatever the selector: one that takes no argument is sent as it is, an unknown selector raises when the action runs
// (QUIRK), a nil target does nothing, the manager itself may be the target. Prints PASS/FAIL lines; the exit code is
// the number of failures.
#import <Foundation/Foundation.h>

static int failures;
static void expect(BOOL condition, const char *what) {
    printf("%s: %s\n", condition ? "PASS" : "FAIL", what);
    if (!condition)
        failures++;
}

@interface Recipient : NSObject {
@public
    int oneRuns, noneRuns;
    id seen;
}
- (void)one:(id)object;
- (void)none;
@end

@implementation Recipient
- (void)one:(id)object { oneRuns++; seen = object; }
- (void)none { noneRuns++; }
@end

int main(void) {
    @autoreleasepool {
        NSUndoManager *manager = [[NSUndoManager alloc] init];
        [manager setGroupsByEvent:NO];

        /* the manager's own methods have signatures, unknown selectors have none */
        NSMethodSignature *signature = [manager methodSignatureForSelector:@selector(undo)];
        expect(signature != nil && [signature numberOfArguments] == 2 && strcmp([signature methodReturnType], "v") == 0, "signature of -undo");
        signature = [manager methodSignatureForSelector:@selector(canUndo)];
        expect(signature != nil && strcmp([signature methodReturnType], "c") == 0, "signature of -canUndo");
        signature = [manager methodSignatureForSelector:@selector(prepareWithInvocationTarget:)];
        expect(signature != nil && [signature numberOfArguments] == 3, "signature of -prepareWithInvocationTarget:");
        expect([manager methodSignatureForSelector:NSSelectorFromString(@"noSuchSelectorAnywhere:")] == nil, "no signature for an unknown selector");
        expect([manager methodSignatureForSelector:@selector(one:)] == nil, "no signature for a selector of another class, nothing prepared");

        Recipient *recipient = [[Recipient alloc] init];

        /* the prepared form still works */
        [manager beginUndoGrouping];
        [[manager prepareWithInvocationTarget:recipient] one:@"prepared"];
        [manager endUndoGrouping];
        [manager undo];
        expect(recipient->oneRuns == 1 && [recipient->seen isEqual:@"prepared"], "prepareWithInvocationTarget: records the call");

        /* QUIRK: a selector without argument is recorded and sent; the object is dropped */
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:recipient selector:@selector(none) object:@"ignored"];
        [manager endUndoGrouping];
        expect([manager canUndo], "no-argument selector is recorded");
        [manager undo];
        expect(recipient->noneRuns == 1, "no-argument selector runs");
        [manager removeAllActions];
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:recipient selector:@selector(none) object:nil];
        [manager endUndoGrouping];
        [manager undo];
        expect(recipient->noneRuns == 2, "no-argument selector with a nil object runs");
        [manager removeAllActions];

        /* the normal case */
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:recipient selector:@selector(one:) object:@"normal"];
        [manager endUndoGrouping];
        [manager undo];
        expect(recipient->oneRuns == 2 && [recipient->seen isEqual:@"normal"], "one-argument selector runs with the object");
        [manager removeAllActions];

        /* QUIRK: a nil target is recorded and does nothing */
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:nil selector:@selector(one:) object:@"x"];
        [manager endUndoGrouping];
        expect([manager canUndo], "nil target is recorded");
        [manager undo];
        [manager removeAllActions];

        /* QUIRK: an unknown selector is recorded and raises when the action runs */
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:recipient selector:NSSelectorFromString(@"noSuchSelectorAnywhere:") object:nil];
        [manager endUndoGrouping];
        expect([manager canUndo], "unknown selector is recorded");
        BOOL raised = NO;
        @try {
            [manager undo];
        } @catch (NSException *exception) {
            raised = [[exception name] isEqualToString:NSInvalidArgumentException];
        }
        expect(raised, "unknown selector raises NSInvalidArgumentException when run");
        [manager removeAllActions];

        /* the manager as target of its own selector */
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:manager selector:@selector(setActionName:) object:@"named"];
        [manager endUndoGrouping];
        expect([manager canUndo], "the manager is a valid target");
        [manager undo];
    }
    printf(failures ? "%d failure(s)\n" : "ALL PASSED\n", failures);
    return failures;
}
