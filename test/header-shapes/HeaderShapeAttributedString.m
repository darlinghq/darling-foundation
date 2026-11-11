#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void)
{
    NSAttributedString *source = [[NSAttributedString alloc] initWithString:@"abc"];
    NSMutableAttributedString *copy = [[NSMutableAttributedString alloc] initWithAttributedString:source];
    BOOL ok = copy != nil && [copy.string isEqualToString:@"abc"];
    printf("%s NSMutableAttributedString initWithAttributedString: returns NSMutableAttributedString *\n", ok ? "PASS" : "FAIL");
    return !ok;
}
