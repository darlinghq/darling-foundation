// Copyright (C) 2026 Lubos Dolezel
//
// NSArgumentDomain: how "-Key value" process arguments become defaults. The program runs
// itself as a child with various argument lists and compares the argument domain the child
// reports. Expected values were observed on macOS 26.7.3 and 10.14.4 (the same program
// is an oracle on a real Mac).
#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <spawn.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

static int failures;

// Child mode: the first argument is "child"; print the domain, one line per key.
static int child(void)
{
    @autoreleasepool {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSDictionary *d = [ud volatileDomainForName:NSArgumentDomain];
        for (NSString *k in [[d allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
            id v = d[k];
            NSString *kind = [v isKindOfClass:[NSString class]] ? @"string"
                : [v isKindOfClass:[NSArray class]] ? @"array"
                : [v isKindOfClass:[NSDictionary class]] ? @"dict"
                : [v isKindOfClass:[NSData class]] ? @"data"
                : [v isKindOfClass:[NSNumber class]] ? @"number" : @"other";
            NSString *text = [v isKindOfClass:[NSString class]] ? v : [v description];
            text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
            printf("[%s]=%s:%s\n", k.UTF8String, kind.UTF8String, text.UTF8String);
            if (![[ud objectForKey:k] isEqual:v]) printf("[%s] objectForKey differs\n", k.UTF8String);
        }
    }
    return 0;
}

static NSString *run(const char *self, const char **args)
{
    const char *argv[32];
    int n = 0;
    argv[n++] = self;
    argv[n++] = "child";
    for (; *args; args++) argv[n++] = *args;
    argv[n] = NULL;

    int fds[2];
    if (pipe(fds) != 0) return @"(pipe failed)";
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_adddup2(&fa, fds[1], 1);
    posix_spawn_file_actions_addclose(&fa, fds[0]);
    // the old-style plist parser logs its complaints; keep them out of the comparison
    posix_spawn_file_actions_addopen(&fa, 2, "/dev/null", O_WRONLY, 0);
    pid_t pid;
    int rc = posix_spawn(&pid, self, &fa, NULL, (char *const *)argv, environ);
    posix_spawn_file_actions_destroy(&fa);
    close(fds[1]);
    if (rc != 0) { close(fds[0]); return @"(spawn failed)"; }
    NSMutableData *out = [NSMutableData data];
    char buf[4096];
    ssize_t r;
    while ((r = read(fds[0], buf, sizeof buf)) > 0) [out appendBytes:buf length:r];
    close(fds[0]);
    int st;
    waitpid(pid, &st, 0);
    NSString *s = [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding];
    return s ?: @"(bad output)";
}

static void expectDomain(const char *self, const char *label, const char *expect, ...)
{
    // varargs: the arguments, NULL terminated
    const char *args[24];
    int n = 0;
    va_list ap;
    va_start(ap, expect);
    const char *a;
    while ((a = va_arg(ap, const char *)) != NULL) args[n++] = a;
    va_end(ap);
    args[n] = NULL;
    @autoreleasepool {
        NSString *got = run(self, args);
        NSString *want = [NSString stringWithUTF8String:expect];
        BOOL ok = [got isEqualToString:want];
        printf("%s %s\n", ok ? "PASS" : "FAIL", label);
        if (!ok) printf("  expected: %s  got: %s\n", expect, got.UTF8String);
        failures += !ok;
    }
}

int main(int argc, char **argv)
{
    if (argc > 1 && strcmp(argv[1], "child") == 0) return child();
    const char *self = argv[0];

    expectDomain(self, "plain pair", "[A]=string:b\n", "-A", "b", NULL);
    expectDomain(self, "several pairs and non-switch arguments", "[A]=string:b\n[C]=string:d\n", "x", "-A", "b", "y", "-C", "d", NULL);
    expectDomain(self, "later value wins", "[A]=string:c\n", "-A", "b", "-A", "c", NULL);
    expectDomain(self, "key without value", "", "-A", NULL);
    expectDomain(self, "-Key=value sets nothing", "", "-A=b", NULL);
    expectDomain(self, "value starting with - is not taken, scan goes on", "[x]=string:v\n", "-A", "-x", "v", NULL);
    expectDomain(self, "negative number is not a value", "", "-A", "-1", NULL);
    expectDomain(self, "-- does not stop parsing", "[A]=string:b\n[C]=string:d\n", "-A", "b", "--", "-C", "d", NULL);
    expectDomain(self, "-- followed by a value is a key", "[-]=string:x\n", "--", "x", NULL);
    expectDomain(self, "-psn_ is an ordinary key", "[psn_0_1]=string:x\n", "-psn_0_1", "x", NULL);
    expectDomain(self, "bare - with a value is the empty key", "[]=string:x\n", "-", "x", NULL);
    expectDomain(self, "keys are not trimmed", "[ A]=string:x\n[B ]=string:y\n", "- A", "x", "-B ", "y", NULL);
    expectDomain(self, "string values are not trimmed", "[A]=string:  x  \n", "-A", "  x  ", NULL);
    expectDomain(self, "empty value", "[A]=string:\n[B]=string:\n", "-A", "", "-B", "", NULL);
    expectDomain(self, "plain strings stay strings", "[A]=string:1.5\n[B]=string:YES\n[C]=string:a b\n[D]=string:a=b\n",
          "-A", "1.5", "-B", "YES", "-C", "a b", "-D", "a=b", NULL);
    expectDomain(self, "text starting with other punctuation stays a string", "[A]=string:'single'\n[B]=string:/* c */(x)\n[C]=string:$x\n",
          "-A", "'single'", "-B", "/* c */(x)", "-C", "$x", NULL);

    expectDomain(self, "array", "[A]=array:(\\n    de\\n)\n", "-A", "(de)", NULL);
    expectDomain(self, "array of two with spaces", "[A]=array:(\\n    a,\\n    b\\n)\n", "-A", " ( a , b ) ", NULL);
    expectDomain(self, "empty array", "[A]=array:(\\n)\n", "-A", "()", NULL);
    expectDomain(self, "array values are strings", "[A]=array:(\\n    1,\\n    2\\n)\n", "-A", "(1,2)", NULL);
    expectDomain(self, "nested array", "[A]=array:(\\n    a,\\n        (\\n        b,\\n        c\\n    )\\n)\n", "-A", "(a,(b,c))", NULL);
    expectDomain(self, "dictionary", "[A]=dict:{\\n    a = b;\\n}\n", "-A", "{a=b;}", NULL);
    expectDomain(self, "empty dictionary", "[A]=dict:{\\n}\n", "-A", "{}", NULL);
    expectDomain(self, "data", "[A]=data:<0a0b>\n", "-A", "<0A 0b>", NULL);
    expectDomain(self, "quoted string loses its quotes", "[A]=string:quoted str\n", "-A", "\"quoted str\"", NULL);
    expectDomain(self, "quoted string with an escape", "[A]=string:A\n", "-A", "\"\\U0041\"", NULL);
    expectDomain(self, "quoted empty string", "[A]=string:\n", "-A", "\"\"", NULL);
    expectDomain(self, "quoted text that looks like an array stays a string", "[A]=string:(a)\n", "-A", "\"(a)\"", NULL);
    expectDomain(self, "XML property list", "[A]=number:5\n",
          "-A", "<?xml version=\"1.0\"?><plist version=\"1.0\"><integer>5</integer></plist>", NULL);
    expectDomain(self, "XML fragment: array", "[A]=array:(\\n    x\\n)\n", "-A", "<array><string>x</string></array>", NULL);
    expectDomain(self, "XML fragment: true", "[A]=number:1\n", "-A", "<true/>", NULL);

    // A value that starts like a property list but does not parse sets nothing
    expectDomain(self, "unterminated array sets nothing", "[C]=string:y\n", "-A", "(a", "-C", "y", NULL);
    expectDomain(self, "dictionary without semicolon sets nothing", "", "-A", "{a=b}", NULL);
    expectDomain(self, "text after the array sets nothing", "", "-A", "(a) x", NULL);
    expectDomain(self, "odd data length sets nothing", "", "-A", "<0a0>", NULL);
    expectDomain(self, "unterminated quote sets nothing", "", "-A", "\"a", NULL);
    expectDomain(self, "bracket sets nothing", "", "-A", "[a]", NULL);

    printf(failures ? "FAIL (%d)\n" : "PASS\n", failures);
    return failures != 0;
}
