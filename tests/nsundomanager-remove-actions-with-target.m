// Copyright (C) 2026 Lubos Dolezel
//
// -[NSUndoManager removeAllActionsWithTarget:] clears the undo and redo stacks of every action whose
// recipient is the target, as documented:
// https://developer.apple.com/documentation/foundation/undomanager/removeallactions(withtarget:)
// The cases need several actions of the target in one group and several groups, which is where
// removing an item while counting forward skips the item that moves into its place.
#import <Foundation/Foundation.h>

static int failures;

static void expect(BOOL condition, const char *what) {
    printf("%s: %s\n", condition ? "PASS" : "FAIL", what);
    if (!condition)
        failures++;
}

@interface Recipient : NSObject {
@public
    int runs;
    NSUndoManager *manager;
}
- (void)run:(id)ignored;
@end

@implementation Recipient
// Running as an undo registers the inverse, which is what puts actions on the redo stack.
- (void)run:(id)ignored {
    runs++;
    [manager registerUndoWithTarget:self selector:@selector(run:) object:nil];
}
@end

static void group(NSUndoManager *manager, id target, int actions) {
    [manager beginUndoGrouping];
    for (int i = 0; i < actions; i++)
        [manager registerUndoWithTarget:target selector:@selector(run:) object:nil];
    [manager endUndoGrouping];
}

int main(void) {
    @autoreleasepool {
        NSUndoManager *manager = [[NSUndoManager alloc] init];
        [manager setGroupsByEvent:NO];
        Recipient *a = [[Recipient alloc] init], *b = [[Recipient alloc] init];
        a->manager = b->manager = manager;

        /* two actions of the target in a row in one group, and a third of another target after them */
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:a selector:@selector(run:) object:nil];
        [manager registerUndoWithTarget:a selector:@selector(run:) object:nil];
        [manager registerUndoWithTarget:b selector:@selector(run:) object:nil];
        [manager endUndoGrouping];
        [manager removeAllActionsWithTarget:a];
        [manager undo];
        expect(a->runs == 0, "no action of the removed target runs, even when two were adjacent");
        expect(b->runs == 1, "the action of the other target stays");

        /* several groups, each only the target's: all must go, none may be skipped */
        [manager removeAllActions];
        group(manager, a, 1);
        group(manager, a, 1);
        group(manager, a, 1);
        [manager removeAllActionsWithTarget:a];
        expect(![manager canUndo], "three groups of one target are all removed");

        /* a group that becomes empty is dropped and its successor is still examined */
        group(manager, a, 1);
        group(manager, a, 2);
        group(manager, b, 1);
        [manager removeAllActionsWithTarget:a];
        [manager undo];
        expect(a->runs == 0 && b->runs == 2, "only the other target's group is left and it runs");
        expect(![manager canUndo], "and nothing else is left");

        /* open groups nest: an action registered before an inner group began is in the parent group */
        [manager removeAllActions];
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:a selector:@selector(run:) object:nil];
        [manager registerUndoWithTarget:b selector:@selector(run:) object:nil];
        [manager beginUndoGrouping];
        [manager registerUndoWithTarget:a selector:@selector(run:) object:nil];
        [manager removeAllActionsWithTarget:a];
        [manager endUndoGrouping];
        [manager endUndoGrouping];
        a->runs = 0;
        b->runs = 0;
        [manager undo];
        expect(a->runs == 0, "actions of the target in open parent groups are removed too");
        expect(b->runs == 1, "the other target's action in the parent group stays");

        /* the redo stack too */
        [manager removeAllActions];
        group(manager, a, 2);
        group(manager, a, 1);
        [manager undo];
        [manager undo];
        expect([manager canRedo], "the undone actions are on the redo stack");
        [manager removeAllActionsWithTarget:a];
        expect(![manager canRedo] && ![manager canUndo], "the redo stack is cleared of the target");
    }
    return failures;
}
