import Foundation

var failures = 0
func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        failures += 1
    }
}

func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

// Leaf progress: unit counts, fraction, finished, indeterminate.
let leaf = Progress(totalUnitCount: 10)
expect(leaf.fractionCompleted == 0 && !leaf.isFinished && !leaf.isIndeterminate, "fresh leaf")
leaf.completedUnitCount = 4
expect(close(leaf.fractionCompleted, 0.4), "4 of 10 is 0.4, got \(leaf.fractionCompleted)")
leaf.completedUnitCount = 10
expect(leaf.isFinished && close(leaf.fractionCompleted, 1), "10 of 10 is finished")
expect(Progress(totalUnitCount: 0).isIndeterminate, "total 0 with nothing completed is indeterminate")
expect(Progress(totalUnitCount: -1).isIndeterminate, "negative total is indeterminate")
expect(Progress.current() == nil, "no current progress by default")

// Explicit children with pending unit counts.
let parent = Progress.discreteProgress(totalUnitCount: 10)
let childA = Progress(totalUnitCount: 4, parent: parent, pendingUnitCount: 6)
let childB = Progress.discreteProgress(totalUnitCount: 2)
parent.addChild(childB, withPendingUnitCount: 4)
childA.completedUnitCount = 2
expect(close(parent.fractionCompleted, 0.3), "half of a 6/10 child is 0.3, got \(parent.fractionCompleted)")
expect(parent.completedUnitCount == 0, "unfinished children do not add completed units")
childA.completedUnitCount = 4
expect(parent.completedUnitCount == 6, "finished child adds its pending units, got \(parent.completedUnitCount)")
expect(close(parent.fractionCompleted, 0.6), "parent at 0.6, got \(parent.fractionCompleted)")
childB.completedUnitCount = 1
expect(close(parent.fractionCompleted, 0.8), "parent at 0.8, got \(parent.fractionCompleted)")
childB.completedUnitCount = 2
expect(parent.isFinished && close(parent.fractionCompleted, 1), "parent finished with its children")

// Implicit child through becomeCurrent; resignCurrent without a child completes the pending units.
let outer = Progress.discreteProgress(totalUnitCount: 4)
outer.becomeCurrent(withPendingUnitCount: 2)
expect(Progress.current() === outer, "becomeCurrent makes the progress current")
let implicitChild = Progress(totalUnitCount: 5)
let notAttached = Progress(totalUnitCount: 5)
outer.resignCurrent()
expect(Progress.current() == nil, "resignCurrent restores the previous current progress")
implicitChild.completedUnitCount = 5
expect(outer.completedUnitCount == 2, "implicit child finished adds 2, got \(outer.completedUnitCount)")
notAttached.completedUnitCount = 5
expect(outer.completedUnitCount == 2, "only the first progress created while current is attached")
outer.becomeCurrent(withPendingUnitCount: 2)
outer.resignCurrent()
expect(outer.isFinished, "resignCurrent with no child counts the pending units as done")

// Localized descriptions.
let described = Progress(totalUnitCount: 8)
described.completedUnitCount = 2
expect(described.localizedDescription == "25% completed", "description: \(described.localizedDescription ?? "nil")")
expect(described.localizedAdditionalDescription == "2 of 8", "additional: \(described.localizedAdditionalDescription ?? "nil")")
described.completedUnitCount = 4
expect(described.localizedDescription == "50% completed", "description updates: \(described.localizedDescription ?? "nil")")
described.localizedDescription = "Copying"
expect(described.localizedDescription == "Copying", "explicit description is kept")
described.localizedDescription = nil
expect(described.localizedDescription == "50% completed", "nil resets to the default description")

// userInfo, kind and the typed keys.
described.setUserInfoObject(3, forKey: .fileTotalCountKey)
expect(described.userInfo[.fileTotalCountKey] as? Int == 3, "userInfo stores values")
described.kind = .file
expect(described.kind == .file, "kind round-trips")
described.estimatedTimeRemaining = 12
expect(described.userInfo[.estimatedTimeRemainingKey] as? Int == 12, "estimatedTimeRemaining lives in userInfo")
expect(Progress.FileOperationKind.copying.rawValue == "NSProgressFileOperationKindCopying", "file operation kinds")

// KVO for completedUnitCount, fractionCompleted (through a child) and localizedDescription.
let observed = Progress.discreteProgress(totalUnitCount: 2)
let observedChild = Progress(totalUnitCount: 10, parent: observed, pendingUnitCount: 1)
var completedChanges: [Int64] = []
var fractions: [Double] = []
var descriptions: [String] = []
let o1 = observed.observe(\.completedUnitCount, options: [.new]) { _, change in completedChanges.append(change.newValue!) }
let o2 = observed.observe(\.fractionCompleted, options: [.new]) { _, change in fractions.append(change.newValue!) }
let o3 = observed.observe(\.localizedDescription, options: [.new]) { p, _ in descriptions.append(p.localizedDescription) }
observedChild.completedUnitCount = 5
observedChild.completedUnitCount = 10
observed.completedUnitCount = 2
expect(fractions.count >= 3 && close(fractions[0], 0.25) && close(fractions.last!, 1), "fractionCompleted KVO: \(fractions)")
expect(completedChanges == [1, 2], "completedUnitCount KVO: \(completedChanges)")
expect(descriptions.first == "25% completed" && descriptions.last == "100% completed", "localizedDescription KVO: \(descriptions)")
o1.invalidate(); o2.invalidate(); o3.invalidate()

// Cancellation and pausing propagate to children and run handlers.
let root = Progress.discreteProgress(totalUnitCount: 2)
root.isCancellable = true
root.isPausable = true
let leafChild = Progress(totalUnitCount: 1, parent: root, pendingUnitCount: 1)
let handled = DispatchSemaphore(value: 0)
leafChild.cancellationHandler = { handled.signal() }
leafChild.pausingHandler = { handled.signal() }
leafChild.resumingHandler = { handled.signal() }
root.pause()
expect(leafChild.isPaused, "pause propagates")
expect(handled.wait(timeout: .now() + 5) == .success, "pausing handler ran")
root.resume()
expect(!leafChild.isPaused, "resume propagates")
expect(handled.wait(timeout: .now() + 5) == .success, "resuming handler ran")
root.cancel()
expect(root.isCancelled && leafChild.isCancelled, "cancel propagates")
expect(handled.wait(timeout: .now() + 5) == .success, "cancellation handler ran")
let late = Progress.discreteProgress(totalUnitCount: 1)
root.addChild(late, withPendingUnitCount: 1)
expect(late.isCancelled, "a child added to a cancelled parent is cancelled")

// A child that outlives its parent keeps working.
var orphan: Progress!
autoreleasepool {
    let shortLived = Progress.discreteProgress(totalUnitCount: 1)
    orphan = Progress(totalUnitCount: 2, parent: shortLived, pendingUnitCount: 1)
}
orphan.completedUnitCount = 2
expect(orphan.isFinished, "child of a deallocated parent")

if failures == 0 {
    print("PASS: progress-swift")
    exit(0)
}
exit(1)
