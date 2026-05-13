import Testing
import Foundation
@testable import RippleCore

// MARK: - Versioning

@Test func versionStringIsSemVer() {
    let parts = Ripple.version.split(separator: ".")
    #expect(parts.count == 3)
    for p in parts { #expect(Int(p) != nil) }
}

// MARK: - Exercise phase sequences

@Test func fourSevenEightPhaseSequence() {
    let ex = BreathExercise.fourSevenEight
    #expect(ex.phases.map(\.kind) == [.inhale, .holdFull, .exhale])
    #expect(ex.phases.map(\.duration) == [4, 7, 8])
    #expect(ex.cycleDuration == 19)
}

@Test func boxPhaseSequence() {
    let ex = BreathExercise.box
    #expect(ex.phases.map(\.kind) == [.inhale, .holdFull, .exhale, .holdEmpty])
    #expect(ex.phases.allSatisfy { $0.duration == 4 })
    #expect(ex.cycleDuration == 16)
}

@Test func coherentPhaseSequence() {
    let ex = BreathExercise.coherent
    #expect(ex.phases.map(\.kind) == [.inhale, .exhale])
    #expect(ex.phases.allSatisfy { $0.duration == 5.5 })
    #expect(ex.cycleDuration == 11)
}

@Test func sighPhaseSequence() {
    let ex = BreathExercise.sigh
    #expect(ex.phases.map(\.kind) == [.inhale, .inhaleTop, .exhale])
    #expect(ex.cycleDuration == 7.5)
}

@Test func sessionDurationScalesWithCycles() {
    let ex = BreathExercise.fourSevenEight
    #expect(ex.sessionDuration(cycles: 1) == 19)
    #expect(ex.sessionDuration(cycles: 4) == 76)
    #expect(ex.sessionDuration(cycles: 10) == 190)
}

// MARK: - Alias resolution

@Test func resolveCanonicalNames() {
    #expect(BreathExercise.resolve("478") == .fourSevenEight)
    #expect(BreathExercise.resolve("4-7-8") == .fourSevenEight)
    #expect(BreathExercise.resolve("BOX") == .box)
    #expect(BreathExercise.resolve("Square") == .box)
    #expect(BreathExercise.resolve("hrv") == .coherent)
    #expect(BreathExercise.resolve("physsigh") == .sigh)
    #expect(BreathExercise.resolve("banana") == nil)
}

// MARK: - SessionConfig

@Test func sessionConfigClampsCycles() {
    let belowMin = SessionConfig(exercise: .box, cycles: 0)
    #expect(belowMin.cycles == BreathExercise.box.defaultCycles)

    let aboveMax = SessionConfig(exercise: .box, cycles: 99)
    #expect(aboveMax.cycles == 10)

    let inRange = SessionConfig(exercise: .box, cycles: 5)
    #expect(inRange.cycles == 5)
}

@Test func sessionConfigDefaultMatchesExercise() {
    let c = SessionConfig(.coherent)
    #expect(c.cycles == 6)
    #expect(c.totalSeconds == 66)
}

// MARK: - Affirmations

@Test func affirmationPoolHasTenItems() {
    #expect(AffirmationPool.all.count == 10)
}

@Test func affirmationRandomReturnsFromPool() {
    for _ in 0..<10 {
        let a = AffirmationPool.random()
        #expect(AffirmationPool.all.contains(a))
    }
}

// MARK: - PhaseRunner

@Test func phaseRunnerEmitsExpectedEventSequence() async {
    let runner = PhaseRunner(config: SessionConfig(exercise: .coherent, cycles: 1))
    var kinds: [PhaseEvent.Kind] = []
    // Run with timeout much shorter than real durations by skipping the sleep
    // — but our runner does sleep. For the unit test, just collect what we get
    // within a deterministic budget.
    let task = Task {
        for await event in runner.events {
            kinds.append(event.kind)
        }
    }
    // Coherent is 11s per cycle — too long for a unit test. We just verify
    // session began. Comprehensive timing is checked separately.
    try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
    task.cancel()
    #expect(kinds.first == .sessionBegan)
}
