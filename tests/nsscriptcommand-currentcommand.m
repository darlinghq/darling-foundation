// +[NSScriptCommand currentCommand] is documented (developer.apple.com/documentation/foundation/nsscriptcommand/current(),
// Objective-C name currentCommand, macOS 10.0 and later) as returning the command that is being executed on the
// current thread by Cocoa scripting's built-in Apple event handling, and nil otherwise. A suspended command does not
// count. This Foundation has no way to execute an NSScriptCommand, so every call here is made outside command execution
// and the documented answer is nil. Every call is wrapped so that a raised exception is reported as a failure instead of
// ending the run: before the method existed the call raised "unrecognized selector".
#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdio.h>

static int failures;

static void report(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

// YES when +currentCommand on cls returned nil without raising.
static BOOL returnsNil(Class cls)
{
    @try
    {
        return [cls currentCommand] == nil;
    }
    @catch (NSException *e)
    {
        printf("  raised %s: %s\n", [[e name] UTF8String], [[e reason] UTF8String]);
        return NO;
    }
}

static void *threadBody(void *result)
{
    @autoreleasepool
    {
        *(BOOL *)result = returnsNil([NSScriptCommand class]);
    }
    return NULL;
}

int main(void)
{
    @autoreleasepool
    {
        report("NSScriptCommand responds to +currentCommand", [NSScriptCommand respondsToSelector:@selector(currentCommand)]);

        // Documented: nil when no command is being executed.
        report("main thread outside execution -> nil, no exception", returnsNil([NSScriptCommand class]));
        report("repeated calls stay nil", returnsNil([NSScriptCommand class]) && returnsNil([NSScriptCommand class]));

        // The failing call pattern: a secondary thread.
        BOOL threadResult = NO;
        pthread_t thread;
        BOOL started = pthread_create(&thread, NULL, threadBody, &threadResult) == 0;
        if (started)
            pthread_join(thread, NULL);
        report("secondary thread -> nil, no exception", started && threadResult);

        // The failing call pattern: a block dispatched asynchronously to the main queue, run by the main run loop.
        __block BOOL blockRan = NO;
        __block BOOL blockResult = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            blockResult = returnsNil([NSScriptCommand class]);
            blockRan = YES;
        });
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
        while (!blockRan && [deadline timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        report("dispatch_async main-queue block ran", blockRan);
        report("dispatch_async main-queue block -> nil, no exception", blockRan && blockResult);

        // GUESS: not stated on the page. The method is declared on NSScriptCommand, so a subclass inherits it and, with
        // no command executing, gets the same documented nil (the four subclasses this tree declares are checked).
        Class subclasses[] = { [NSCreateCommand class], [NSCloneCommand class], [NSDeleteCommand class], [NSMoveCommand class] };
        for (size_t i = 0; i < sizeof subclasses / sizeof *subclasses; i++)
        {
            const char *name = class_getName(subclasses[i]);
            char label[96];
            snprintf(label, sizeof label, "subclass %s responds to +currentCommand", name);
            report(label, [subclasses[i] respondsToSelector:@selector(currentCommand)]);
            snprintf(label, sizeof label, "subclass %s -> nil, no exception", name);
            report(label, returnsNil(subclasses[i]));
        }
    }
    return failures != 0;
}
