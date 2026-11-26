// NSLocalizedFileSizeDescription (private): the description of a file size as
// NSByteCountFormatter gives it in the file count style, for sizes from zero
// to beyond what a long long holds. Exits non-zero on failure.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>

int main(void)
{
    int failures = 0;

    @autoreleasepool {
        NSString *(*describe)(uint64_t, uint64_t, uint64_t) = dlsym(RTLD_DEFAULT, "NSLocalizedFileSizeDescription");
        if (describe == NULL)
        {
            printf("FAIL NSLocalizedFileSizeDescription missing\n");
            return 1;
        }

        long long sizes[] = {0, 1, 999, 1000, 12345, 1500000, 3000000000LL};
        for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i++)
        {
            NSString *got = describe((uint64_t)sizes[i], 0, 0);
            NSString *want = [NSByteCountFormatter stringFromByteCount:sizes[i] countStyle:NSByteCountFormatterCountStyleFile];
            if (got == nil || ![got isEqualToString:want])
            {
                printf("FAIL size %lld: got \"%s\", want \"%s\"\n", sizes[i], got ? [got UTF8String] : "(nil)", [want UTF8String]);
                failures++;
            }
        }

        // Sizes past LLONG_MAX still give a description.
        if ([describe(UINT64_MAX, 0, 0) length] == 0)
        {
            printf("FAIL UINT64_MAX\n");
            failures++;
        }
    }

    if (failures == 0)
        printf("PASS\n");
    return failures != 0;
}
