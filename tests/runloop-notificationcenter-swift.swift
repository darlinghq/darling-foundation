import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

let main: RunLoop = RunLoop.main
expect(main === RunLoop.current, "RunLoop.main is the main thread's RunLoop.current")
expect(NotificationCenter.default === NotificationCenter.default, "NotificationCenter.default is a singleton")

// Generic over the date parameter so the test holds whether NSDate bridges to Date or not.
func runMain<D>(_ run: (RunLoop.Mode, D) -> Bool, seconds: Double) -> Bool {
    return run(.default, Date(timeIntervalSinceNow: seconds) as NSDate as! D)
}

// A block queued from another thread must wake the sleeping main run loop.
var ranInCommonModes = false
var ranAt = 0.0
let start = CFAbsoluteTimeGetCurrent()
DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
    main.perform(inModes: [.common]) {
        ranInCommonModes = true
        ranAt = CFAbsoluteTimeGetCurrent()
    }
}
while !ranInCommonModes && CFAbsoluteTimeGetCurrent() < start + 10 {
    _ = runMain(main.run(mode:before:), seconds: 10)
}
let waited = ranAt - start
expect(ranInCommonModes, "perform(inModes:block:) from another thread ran on the main run loop")
expect(waited < 5, "perform(inModes:block:) woke the sleeping run loop (waited \(waited)s)")

var ranInDefaultMode = false
main.perform { ranInDefaultMode = true }
_ = runMain(main.run(mode:before:), seconds: 1)
expect(ranInDefaultMode, "perform(_:) runs in the default mode")
expect(main.currentMode == nil, "currentMode is nil outside a run")
print("PASS: RunLoop.main/current, perform(inModes:block:), run(mode:before:), NotificationCenter.default")
