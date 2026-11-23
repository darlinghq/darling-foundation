// Copyright (C) 2026 Lubos Dolezel
// -[NSConnection multipleThreadsEnabled] is documented
// (developer.apple.com/documentation/foundation/nsconnection/multiplethreadsenabled) as a readonly BOOL, YES if the
// receiver supports requests from multiple threads, with YES as the default. -[NSConnection enableMultipleThreads]
// (.../nsconnection/enablemultiplethreads) is documented as doing nothing on macOS 10.5 and later because that support
// is already on. So the getter is YES before and after the call, and the call has no other observable effect.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void report(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

static void checkConnection(NSString *kind, NSConnection *c)
{
    const char *k = [kind UTF8String];
    char label[160];

    snprintf(label, sizeof label, "%s: responds to -multipleThreadsEnabled", k);
    report(label, [c respondsToSelector:@selector(multipleThreadsEnabled)]);
    snprintf(label, sizeof label, "%s: responds to -enableMultipleThreads", k);
    report(label, [c respondsToSelector:@selector(enableMultipleThreads)]);

    snprintf(label, sizeof label, "%s: default is YES", k);
    report(label, [c multipleThreadsEnabled] == YES);

    BOOL raised = NO;
    @try
    {
        [c enableMultipleThreads];
    }
    @catch (NSException *e)
    {
        raised = YES;
    }
    snprintf(label, sizeof label, "%s: -enableMultipleThreads does not raise", k);
    report(label, !raised);
    snprintf(label, sizeof label, "%s: still YES after -enableMultipleThreads", k);
    report(label, [c multipleThreadsEnabled] == YES);
    snprintf(label, sizeof label, "%s: dot syntax reads YES", k);
    report(label, c.multipleThreadsEnabled == YES);

    // GUESS: the page does not say what a repeated call does; "does nothing" implies it stays harmless.
    raised = NO;
    @try
    {
        [c enableMultipleThreads];
        [c enableMultipleThreads];
    }
    @catch (NSException *e)
    {
        raised = YES;
    }
    snprintf(label, sizeof label, "%s: GUESS: calling it again does not raise", k);
    report(label, !raised);
    snprintf(label, sizeof label, "%s: GUESS: still YES after repeated calls", k);
    report(label, [c multipleThreadsEnabled] == YES);
}

int main(void)
{
    @autoreleasepool
    {
        report("class responds to -multipleThreadsEnabled",
               [NSConnection instancesRespondToSelector:@selector(multipleThreadsEnabled)]);
        report("class responds to -enableMultipleThreads",
               [NSConnection instancesRespondToSelector:@selector(enableMultipleThreads)]);
        // The property is readonly: there is no setter.
        report("class does not respond to -setMultipleThreadsEnabled:",
               ![NSConnection instancesRespondToSelector:@selector(setMultipleThreadsEnabled:)]);

        // No server is needed: a connection with two fresh local ports is never sent anything.
        NSConnection *explicitPorts = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:[NSPort port]];
        report("initWithReceivePort:sendPort: returns a connection", explicitPorts != nil);
        if (explicitPorts)
            checkConnection(@"initWithReceivePort:sendPort:", explicitPorts);

        NSConnection *serviceStyle = [[NSConnection alloc] init];
        if (serviceStyle)
            checkConnection(@"init (service connection)", serviceStyle);

        NSConnection *def = [NSConnection defaultConnection];
        report("+defaultConnection returns a connection", def != nil);
        if (def)
            checkConnection(@"+defaultConnection", def);

        // GUESS: the page lists no condition under which the value changes, so an invalidated connection still reads YES.
        NSConnection *invalidated = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:[NSPort port]];
        [invalidated invalidate];
        report("GUESS: reads YES after -invalidate", [invalidated multipleThreadsEnabled] == YES);

        // A connection made after another one was sent -enableMultipleThreads is also YES from the start, and a
        // connection that was never sent it is unaffected by the call on another (the default holds for all of them).
        NSConnection *fresh = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:[NSPort port]];
        report("a connection that never received -enableMultipleThreads reads YES",
               fresh != nil && [fresh multipleThreadsEnabled] == YES);

        // A child connection (receive port shared with its parent, which the documentation says receives the
        // parent's configuration) also reports support. The value is constant, so this holds whether or not it is copied.
        NSPort *p = [NSPort port];
        NSConnection *parent = [[NSConnection alloc] initWithReceivePort:p sendPort:nil];
        NSConnection *child = [[NSConnection alloc] initWithReceivePort:p sendPort:[NSPort port]];
        report("child is a new connection", child != nil && child != parent);
        report("child connection reads YES", [child multipleThreadsEnabled] == YES);

        printf("%d failure(s)\n", failures);
    }
    return failures ? 1 : 0;
}
