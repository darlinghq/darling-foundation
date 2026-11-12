// Copyright (C) 2026 Lubos Dolezel
//
// NSBackgroundActivityScheduler: defaults, argument validation, shouldDefer
// outside an activity, and the scheduling behaviour (one run per interval
// within the tolerance, repeats, deferral, invalidation).
//
// macOS hands the timing to a system scheduler that may run a short-interval
// activity tens of seconds late, so by default (as on macOS) only the
// contract that holds there is checked: the validation and the lower bound
// of the first run. With the argument "strict" the run-time window, repeats
// and deferral are checked too (Darling's scheduler is a plain timer).
#import <Foundation/Foundation.h>
#include <sys/qos.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;
static BOOL strict;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

static NSString *raised(void (^block)(void)) {
    @try { block(); } @catch (NSException *e) { return e.name; }
    return nil;
}

static NSBackgroundActivityScheduler *make(NSString *suffix) {
    return [[[NSBackgroundActivityScheduler alloc] initWithIdentifier:[@"org.darlinghq.test.bgactivity." stringByAppendingString:suffix]] autorelease];
}

static double now(void) { return CFAbsoluteTimeGetCurrent(); }

static void test_defaults(void) {
    NSBackgroundActivityScheduler *s = make(@"defaults");
    CHECK([s.identifier isEqualToString:@"org.darlinghq.test.bgactivity.defaults"]);
    CHECK(s.qualityOfService == NSQualityOfServiceBackground);
    CHECK(s.repeats == NO);
    CHECK(s.interval == 0);
    CHECK(s.tolerance == 0);
    s.interval = 10;
    CHECK(s.tolerance == 0); // the default tolerance is not derived from the interval
    s.repeats = YES; s.tolerance = 3; s.qualityOfService = NSQualityOfServiceUtility;
    CHECK(s.repeats && s.tolerance == 3 && s.qualityOfService == NSQualityOfServiceUtility);
    NSMutableString *m = [NSMutableString stringWithString:@"org.darlinghq.test.bgactivity.copy"];
    NSBackgroundActivityScheduler *c = [[[NSBackgroundActivityScheduler alloc] initWithIdentifier:m] autorelease];
    [m appendString:@"X"];
    CHECK([c.identifier isEqualToString:@"org.darlinghq.test.bgactivity.copy"]); // copied
}

static void test_argument_validation(void) {
    id nilId = nil;
    CHECK([raised(^{ [[NSBackgroundActivityScheduler alloc] initWithIdentifier:nilId]; }) isEqual:NSInvalidArgumentException]);
    CHECK([raised(^{ [[NSBackgroundActivityScheduler alloc] initWithIdentifier:@""]; }) isEqual:NSInvalidArgumentException]);
    CHECK([raised(^{ [[NSBackgroundActivityScheduler alloc] init]; }) isEqual:NSInvalidArgumentException]);

    NSBackgroundActivityScheduler *s = make(@"validation");
    s.interval = 20;
    CHECK([raised(^{ s.interval = 0; }) isEqual:NSInvalidArgumentException]);
    CHECK([raised(^{ s.interval = -5; }) isEqual:NSInvalidArgumentException]);
    CHECK([raised(^{ s.interval = 0.5; }) isEqual:NSInvalidArgumentException]);
    CHECK(s.interval == 20); // a refused value changes nothing
    s.interval = 1;
    CHECK(s.interval == 1);
    s.tolerance = 3;
    CHECK([raised(^{ s.tolerance = -1; }) isEqual:NSInvalidArgumentException]);
    CHECK(s.tolerance == 3);
    s.tolerance = 5; // larger than the interval: refused only when scheduling
    CHECK(s.tolerance == 5);

    CHECK([raised(^{ (void)s.shouldDefer; }) isEqual:NSRangeException]);
    CHECK([raised(^{ [s scheduleWithBlock:nil]; }) isEqual:NSInvalidArgumentException]);
    [s invalidate];
    [s invalidate]; // repeated invalidation is harmless
}

static void test_quirk_tolerance_must_leave_half_second(void) {
    // The tolerance must leave half a second of the interval; 0 means unset.
    double cases[][2] = { {10, 9.5}, {100, 99.5}, {2, 1.49}, {1, 0.2}, {1, 0}, {0, 1}, {0, 0}, {10, 9.51}, {2, 1.9}, {1, 0.51}, {1, 1}, {3, 5} };
    BOOL expectRaise[] = { NO, NO, NO, NO, NO, NO, NO, YES, YES, YES, YES, YES };
    for (size_t i = 0; i < sizeof cases / sizeof cases[0]; i++) {
        NSBackgroundActivityScheduler *s = make(@"quirk");
        if (cases[i][0] > 0) s.interval = cases[i][0];
        s.tolerance = cases[i][1];
        NSString *name = raised(^{ [s scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) { done(NSBackgroundActivityResultFinished); }]; });
        if (expectRaise[i] != (name != nil) || (name && ![name isEqual:NSInvalidArgumentException])) {
            printf("FAIL quirk case interval=%g tolerance=%g raised=%s\n", cases[i][0], cases[i][1], name.UTF8String);
            failures++;
        }
        [s invalidate];
    }
}

static void test_runs_once(void) {
    NSBackgroundActivityScheduler *s = make(@"once");
    s.interval = 1; s.tolerance = 0.2;
    dispatch_semaphore_t ran = dispatch_semaphore_create(0);
    __block int runs = 0, deferNo = 0, onMain = 1, doubleOk = 1;
    __block qos_class_t qos = QOS_CLASS_UNSPECIFIED;
    __block double at = 0;
    double start = now();
    [s scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) {
        runs++;
        at = now() - start;
        onMain = [NSThread isMainThread];
        deferNo = !s.shouldDefer;
        qos = qos_class_self(); // -[NSThread qualityOfService] does not report the dispatch QoS in Darling
        done(NSBackgroundActivityResultFinished);
        @try { done(NSBackgroundActivityResultFinished); } @catch (NSException *e) { doubleOk = 0; }
        CHECK([raised(^{ (void)s.shouldDefer; }) isEqual:NSRangeException]); // the activity is over
        dispatch_semaphore_signal(ran);
    }];
    CHECK(dispatch_semaphore_wait(ran, dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_SEC)) == 0);
    CHECK(at >= 0.8 - 0.05); // never earlier than interval - tolerance
    CHECK(!onMain && deferNo && doubleOk);
    if (strict) {
        CHECK(at <= 1.2 + 0.4); // within the tolerance of the nominal time (plus timer slack)
        CHECK(qos == QOS_CLASS_BACKGROUND);
        [NSThread sleepForTimeInterval:3];
        CHECK(runs == 1); // not repeating
    }
    [s invalidate];
}

static void test_invalidate_before_run(void) {
    NSBackgroundActivityScheduler *s = make(@"invalidate");
    s.interval = 1; s.tolerance = 0.2;
    __block int runs = 0;
    [s scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) { runs++; done(NSBackgroundActivityResultFinished); }];
    [s invalidate];
    [NSThread sleepForTimeInterval:2.5];
    CHECK(runs == 0);
}

static void test_strict_repeat_defer(void) {
    // Repeating: each run one interval (within tolerance) after the previous completion.
    NSBackgroundActivityScheduler *s = make(@"repeat");
    s.interval = 1; s.tolerance = 0.2; s.repeats = YES;
    dispatch_semaphore_t three = dispatch_semaphore_create(0);
    __block int runs = 0;
    double *times = calloc(4, sizeof(double));
    double start = now();
    [s scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) {
        int n = runs++;
        if (n < 4) times[n] = now() - start;
        done(NSBackgroundActivityResultFinished);
        if (n == 2) dispatch_semaphore_signal(three);
    }];
    CHECK(dispatch_semaphore_wait(three, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0);
    CHECK(times[1] - times[0] >= 0.75 && times[1] - times[0] <= 1.6);
    CHECK(times[2] - times[1] >= 0.75 && times[2] - times[1] <= 1.6);
    [s invalidate];
    int seen = runs;
    [NSThread sleepForTimeInterval:2.5];
    CHECK(runs == seen); // invalidated: no further runs

    // A deferred activity is run again even when it does not repeat; the block can adjust the interval first.
    NSBackgroundActivityScheduler *d = make(@"deferred");
    d.interval = 5; d.tolerance = 0;
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    __block int druns = 0;
    start = now();
    [d scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) {
        druns++;
        if (druns < 3) { d.interval = 1; done(NSBackgroundActivityResultDeferred); }
        else { done(NSBackgroundActivityResultFinished); dispatch_semaphore_signal(finished); }
    }];
    CHECK(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)) == 0);
    CHECK(druns == 3);
    CHECK(now() - start < 9); // the adjusted interval was honoured
    [NSThread sleepForTimeInterval:2.5];
    CHECK(druns == 3); // finished, not repeating

    // Without a completion handler call the activity is not rescheduled.
    NSBackgroundActivityScheduler *n = make(@"nocompletion");
    n.interval = 1; n.tolerance = 0.2; n.repeats = YES;
    __block int nruns = 0;
    [n scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) { nruns++; }];
    [NSThread sleepForTimeInterval:4];
    CHECK(nruns == 1);
    [n invalidate];

    // Invalidating while the activity runs lets it finish but stops rescheduling.
    NSBackgroundActivityScheduler *v = make(@"invalidate-in-block");
    v.interval = 1; v.tolerance = 0.2; v.repeats = YES;
    __block int vruns = 0;
    [v scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) { vruns++; [v invalidate]; done(NSBackgroundActivityResultFinished); }];
    [NSThread sleepForTimeInterval:3.5];
    CHECK(vruns == 1);

    // Scheduling again replaces the pending activity; so does scheduling after invalidation.
    NSBackgroundActivityScheduler *r = make(@"replace");
    r.interval = 1; r.tolerance = 0.2;
    __block int r1 = 0, r2 = 0;
    [r scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) { r1++; done(NSBackgroundActivityResultFinished); }];
    [r scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) { r2++; done(NSBackgroundActivityResultFinished); }];
    [NSThread sleepForTimeInterval:2.5];
    CHECK(r1 == 0 && r2 == 1);
    [r invalidate];
    [r scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) { r1++; done(NSBackgroundActivityResultFinished); }];
    [NSThread sleepForTimeInterval:2.5];
    CHECK(r1 == 1);

    // A user-initiated activity runs at the requested quality of service.
    NSBackgroundActivityScheduler *q = make(@"qos");
    q.interval = 1; q.tolerance = 0.2; q.qualityOfService = NSQualityOfServiceUserInitiated;
    dispatch_semaphore_t qran = dispatch_semaphore_create(0);
    __block qos_class_t qq = QOS_CLASS_UNSPECIFIED;
    [q scheduleWithBlock:^(NSBackgroundActivityCompletionHandler done) { qq = qos_class_self(); done(NSBackgroundActivityResultFinished); dispatch_semaphore_signal(qran); }];
    CHECK(dispatch_semaphore_wait(qran, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0);
    CHECK(qq == QOS_CLASS_USER_INITIATED);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        strict = argc > 1 && strcmp(argv[1], "strict") == 0;
        test_defaults();
        test_argument_validation();
        test_quirk_tolerance_must_leave_half_second();
        test_invalidate_before_run();
        test_runs_once();
        if (strict) test_strict_repeat_defer();
        if (failures) { printf("%d failure(s)\n", failures); return 1; }
        printf("PASS: NSBackgroundActivityScheduler\n");
    }
    return 0;
}
