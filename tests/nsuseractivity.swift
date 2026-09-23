import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

func spinMainRunLoop() {
    _ = CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.2, false)
}

final class SaveCounter: NSObject, NSUserActivityDelegate {
    var saves = 0
    var needsSaveDuringSave: Bool?

    func userActivityWillSave(_ userActivity: NSUserActivity) {
        saves += 1
        needsSaveDuringSave = userActivity.needsSave
        userActivity.addUserInfoEntries(from: ["saved": saves])
    }
}

let activity = NSUserActivity(activityType: "org.darlinghq.test.browsing")
expect(activity.activityType == "org.darlinghq.test.browsing", "activityType round-trips")
expect(activity.title == nil && activity.userInfo == nil, "title and userInfo start nil")
expect(activity.keywords.isEmpty, "keywords start empty")
expect(activity.isEligibleForHandoff, "eligible for Handoff by default")
expect(!activity.isEligibleForSearch && !activity.isEligibleForPublicIndexing, "not indexed by default")
expect(!activity.needsSave, "needsSave starts false")

activity.title = "Page"
activity.userInfo = ["a": 1]
activity.addUserInfoEntries(from: ["b": "two"])
expect(activity.title == "Page", "title round-trips")
expect(activity.userInfo?["a"] as? Int == 1 && activity.userInfo?["b"] as? String == "two", "userInfo merge keeps both entries")

var counter: SaveCounter? = SaveCounter()
activity.delegate = counter

activity.needsSave = true
spinMainRunLoop()
expect(counter!.saves == 0, "no save while the activity is not current")

activity.becomeCurrent()
spinMainRunLoop()
expect(counter!.saves == 1, "becomeCurrent with needsSave triggers userActivityWillSave (saves=\(counter!.saves))")
expect(counter!.needsSaveDuringSave == true, "needsSave is still set inside userActivityWillSave")
expect(!activity.needsSave, "needsSave is cleared after the save")
expect(activity.userInfo?["saved"] as? Int == 1, "delegate updates made during the save are kept")

activity.needsSave = true
activity.needsSave = true
spinMainRunLoop()
expect(counter!.saves == 2, "repeated needsSave coalesces into one save (saves=\(counter!.saves))")

let other = NSUserActivity(activityType: "org.darlinghq.test.other")
other.becomeCurrent()
activity.needsSave = true
spinMainRunLoop()
expect(counter!.saves == 2, "no save once another activity became current")

activity.becomeCurrent()
spinMainRunLoop()
expect(counter!.saves == 3, "becoming current again saves the pending state")

activity.resignCurrent()
activity.needsSave = true
spinMainRunLoop()
expect(counter!.saves == 3, "no save after resignCurrent")
expect(activity.needsSave, "needsSave stays set while not current")

activity.invalidate()
activity.becomeCurrent()
spinMainRunLoop()
expect(counter!.saves == 3, "becomeCurrent after invalidate is a no-op")

weak var weakCounter = counter
counter = nil
expect(weakCounter == nil, "the activity does not retain its delegate")
expect(activity.delegate == nil, "delegate reads nil after it is deallocated")

var streamError: NSError?
var handlerCalled = false
other.getContinuationStreams { input, output, error in
    handlerCalled = true
    expect(input == nil && output == nil, "no continuation streams without Handoff")
    streamError = error as NSError?
}
expect(handlerCalled, "continuation handler is called")
expect(streamError?.value(forKey: "domain") as? String == NSCocoaErrorDomain
       && streamError?.value(forKey: "code") as? Int == NSFeatureUnsupportedError,
       "continuation reports NSFeatureUnsupportedError (\(String(describing: streamError)))")
other.resignCurrent()

print("PASS: NSUserActivity")
