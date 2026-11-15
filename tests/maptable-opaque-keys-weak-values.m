// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: an NSMapTable with opaque-pointer keys and weakly held values looks keys up
// correctly when the lookup walks past non-matching nodes of a bucket chain.
#import <Foundation/Foundation.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    enum { COUNT = 512 };
    NSPointerFunctionsOptions keyOptions = NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality;
    NSMapTable *table = [[NSMapTable alloc] initWithKeyOptions: keyOptions
                                                  valueOptions: NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPersonality
                                                      capacity: 1];
    NSMutableArray *owners = [NSMutableArray array];
    static char keys[COUNT];
    for (int i = 0; i < COUNT; i++) {
        NSString *value = [NSString stringWithFormat: @"value %d", i];
        [owners addObject: value];
        [table setObject: value forKey: (id) &keys[i]];
    }
    BOOL allFound = YES;
    for (int i = 0; i < COUNT; i++)
        allFound = allFound && [table objectForKey: (id) &keys[i]] == [owners objectAtIndex: i];
    report("every opaque key finds its weakly held value", allFound);

    static char absent;
    report("an absent opaque key finds nothing", [table objectForKey: (id) &absent] == nil);
    report("the table counts every entry", [table count] == COUNT);

    [table release];
    [pool drain];
    puts(failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
