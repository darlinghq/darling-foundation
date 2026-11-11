#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void)
{
    /* initRequiringSecureCoding: must return instancetype, so no cast to the subclass is needed */
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
    __typeof__([[NSKeyedArchiver alloc] initRequiringSecureCoding:YES]) typed = archiver;
    BOOL ok = typed != nil;
    printf("%s NSKeyedArchiver initRequiringSecureCoding: returns NSKeyedArchiver *\n", ok ? "PASS" : "FAIL");
    return !ok;
}
