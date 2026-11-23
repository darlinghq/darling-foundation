// Copyright (C) 2026 Lubos Dolezel
// -[NSConnection independentConversationQueueing] and -setIndependentConversationQueueing: are documented
// (developer.apple.com/documentation/foundation/nsconnection/independentconversationqueueing) as a BOOL property: YES
// if the receiver handles remote messages atomically, NO otherwise, and the default is NO.
// Only the stored value (and its copy from a parent connection) is checked; no test depends on requests being queued.
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

    snprintf(label, sizeof label, "%s: responds to -independentConversationQueueing", k);
    report(label, [c respondsToSelector:@selector(independentConversationQueueing)]);
    snprintf(label, sizeof label, "%s: responds to -setIndependentConversationQueueing:", k);
    report(label, [c respondsToSelector:@selector(setIndependentConversationQueueing:)]);

    snprintf(label, sizeof label, "%s: default is NO", k);
    report(label, ![c independentConversationQueueing]);

    [c setIndependentConversationQueueing:YES];
    snprintf(label, sizeof label, "%s: set YES reads back YES", k);
    report(label, [c independentConversationQueueing] == YES);

    [c setIndependentConversationQueueing:NO];
    snprintf(label, sizeof label, "%s: set NO reads back NO", k);
    report(label, [c independentConversationQueueing] == NO);

    c.independentConversationQueueing = YES;
    snprintf(label, sizeof label, "%s: dot syntax set YES reads back YES", k);
    report(label, c.independentConversationQueueing);
    c.independentConversationQueueing = NO;
}

int main(void)
{
    @autoreleasepool
    {
        report("class responds to -independentConversationQueueing",
               [NSConnection instancesRespondToSelector:@selector(independentConversationQueueing)]);
        report("class responds to -setIndependentConversationQueueing:",
               [NSConnection instancesRespondToSelector:@selector(setIndependentConversationQueueing:)]);

        // No server is needed: a connection with two fresh local ports is never sent anything.
        NSPort *recv = [NSPort port];
        NSPort *send = [NSPort port];
        NSConnection *explicitPorts = [[NSConnection alloc] initWithReceivePort:recv sendPort:send];
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

        // The flag belongs to one connection: changing it on one does not change another.
        if (explicitPorts && serviceStyle)
        {
            [explicitPorts setIndependentConversationQueueing:YES];
            report("setting one connection leaves another at NO", ![serviceStyle independentConversationQueueing]);
            [explicitPorts setIndependentConversationQueueing:NO];
        }

        // Documented (initWithReceivePort:sendPort:): a connection that uses the receive port as both of its ports is
        // the parent of the new connection, and its configuration settings are applied to the new one. A takes P as both
        // ports (sendPort nil), B is then made with P and a different send port.
        NSPort *p = [NSPort port];
        NSConnection *parent = [[NSConnection alloc] initWithReceivePort:p sendPort:nil];
        [parent setIndependentConversationQueueing:YES];
        NSConnection *child = [[NSConnection alloc] initWithReceivePort:p sendPort:[NSPort port]];
        report("child is a new connection", child != nil && child != parent);
        report("child of a parent with the flag YES reads YES", [child independentConversationQueueing] == YES);
        // GUESS: the page says only that settings are "applied to" the new connection; that this happens once, at
        // creation, and is not a live link to the parent, is read from the existing copy of the timeouts.
        [parent setIndependentConversationQueueing:NO];
        report("GUESS: changing the parent afterwards leaves the child at YES", [child independentConversationQueueing] == YES);

        NSPort *p2 = [NSPort port];
        NSConnection *parent2 = [[NSConnection alloc] initWithReceivePort:p2 sendPort:nil];
        NSConnection *child2 = [[NSConnection alloc] initWithReceivePort:p2 sendPort:[NSPort port]];
        report("child of a parent with the flag NO reads NO", child2 != nil && ![child2 independentConversationQueueing]);

        // A connection with no parent starts at the documented default.
        NSConnection *orphan = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:[NSPort port]];
        report("a connection with no parent reads NO", orphan != nil && ![orphan independentConversationQueueing]);
        (void)parent2;

        printf("%d failure(s)\n", failures);
    }
    return failures ? 1 : 0;
}
