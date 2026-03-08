import Testing
@testable import Hodie

struct FocusTimerEngineTests {
    @Test func countdownCompletes() async throws {
        let engine = FocusTimerEngine()
        engine.start(durationMinutes: 1)
        #expect(engine.state == .running)
        engine.advance(by: 30)
        #expect(engine.remaining <= engine.duration)
        engine.advance(by: 40)
        #expect(engine.state == .completed)
        #expect(engine.remaining == 0)
    }

    @Test func pauseAndResume() async throws {
        let engine = FocusTimerEngine()
        engine.start(durationMinutes: 1)
        engine.pause()
        #expect(engine.state == .paused)
        engine.resume()
        #expect(engine.state == .running)
        engine.stop()
        #expect(engine.state == .idle)
    }
}
