//
//  JobPump.swift
//  GTNWCore
//
//  Runs the engine's Swift tasks without a run loop. `endTurn` resolves the computer's moves in a main-actor Task;
//  the app lets the main run loop pick it up. WebAssembly has no run loop and a bridge call must return a finished
//  turn, so the bridge takes the jobs over (the runtime's enqueue hooks, CGTNWExecutor.h) and `pump()` runs them,
//  oldest first, on the calling thread. Sleeping jobs and `GameScheduler` work run in virtual time, earliest first,
//  so a turn takes no wall-clock time and plays the same way every run.
//

#if GTNW_CORE
import CGTNWExecutor
import Foundation
#if os(WASI)
// ponytail: MainActor.executor / RunLoopExecutor are SPI in Swift 6.4 (custom executors, SE pending); the one way to
// drain WASI's cooperative main executor from a reactor. Replace with the public API once it lands.
@_spi(ExperimentalCustomExecutors) import _Concurrency
#endif

enum JobPump {
    /// Jobs in arrival order, and whether each belongs on the main actor.
    private nonisolated(unsafe) static var ready: [(job: UnownedJob, main: Bool)] = []
    private nonisolated(unsafe) static var installed = false

    /// Take over the runtime's job queues (once per process).
    static func install() {
        guard !installed else { return }
        installed = true
        typealias Enqueue = @convention(thin) (UnownedJob, gtnw_enqueue_original) -> Void
        typealias EnqueueDelay = @convention(thin) (UInt64, UnownedJob, gtnw_enqueue_delay_original) -> Void
        typealias EnqueueDeadline = @convention(thin) (Int64, Int64, Int64, Int64, Int32, UnownedJob,
                                                       gtnw_enqueue_deadline_original) -> Void
        let enqueue: Enqueue = { job, _ in JobPump.ready.append((job, false)) }
        let enqueueMain: Enqueue = { job, _ in JobPump.ready.append((job, true)) }
        let delayed: EnqueueDelay = { nanoseconds, job, _ in
            CoreRunLoop.schedule(after: Double(nanoseconds) / 1e9) { JobPump.ready.append((job, false)) }
        }
        let deadline: EnqueueDeadline = { sec, nsec, _, _, _, job, _ in
            // Deadlines are relative to the runtime's clock, which the pump does not follow: run it after `sec`.
            CoreRunLoop.schedule(after: Double(sec) + Double(nsec) / 1e9) { JobPump.ready.append((job, false)) }
        }
        swift_task_enqueueGlobal_hook = unsafeBitCast(enqueue, to: UnsafeMutableRawPointer?.self)
        swift_task_enqueueMainExecutor_hook = unsafeBitCast(enqueueMain, to: UnsafeMutableRawPointer?.self)
        swift_task_enqueueGlobalWithDelay_hook = unsafeBitCast(delayed, to: UnsafeMutableRawPointer?.self)
        swift_task_enqueueGlobalWithDeadline_hook = unsafeBitCast(deadline, to: UnsafeMutableRawPointer?.self)
    }

    /// Run every ready job, then deferred work in time order, until nothing is left and `busy` is false.
    /// Returns the jobs and deferred items run.
    @discardableResult
    static func pump(while busy: () -> Bool = { false }, limit: Int = 1_000_000) -> Int {
        var count = 0, spins = 0
        while count < limit {
            if !ready.isEmpty {
                let next = ready.removeFirst()
                if next.main {
                    next.job.runSynchronously(on: MainActor.sharedUnownedExecutor)
                } else {
                    next.job.runSynchronously(on: globalConcurrentExecutor.asUnownedTaskExecutor())
                }
            } else if CoreRunLoop.runNext() {
                // ran one deferred item
            } else if busy() {
                // Main-actor jobs skip the enqueue hook on both runtimes and wait in the platform's main executor.
                guard spins < 1_000 else { break }
                spins += 1
                #if os(WASI)
                // The cooperative main executor: run its jobs until it has none (it never waits: no timers queued).
                try? MainActor.executor.runUntil { false }
                #else
                // ponytail: Darwin's main queue; run it as the app's tests do while they wait for the computer's
                // moves (wall-clock bound: 2 s).
                RunLoop.main.run(until: Date().addingTimeInterval(0.002))
                #endif
            } else {
                break
            }
            count += 1
        }
        return count
    }

    static var isIdle: Bool { ready.isEmpty && CoreRunLoop.isEmpty }
}
#endif
