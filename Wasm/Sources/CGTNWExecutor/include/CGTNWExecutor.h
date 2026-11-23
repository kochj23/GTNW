//
//  CGTNWExecutor.h
//  GTNWBridge
//
//  The Swift runtime's concurrency hooks (swift/include/swift/Runtime/ConcurrencyHooks.def), declared so the bridge
//  can run the engine's tasks itself: on one thread, in order, to completion, before a bridge call returns. Each hook
//  is a function pointer the runtime calls instead of its own executor when it is set. JavaScriptKit's event loop
//  uses the same hooks.
//

#ifndef CGTNWEXECUTOR_H
#define CGTNWEXECUTOR_H

#if __has_attribute(swiftcall)
#define GTNW_SWIFTCC __attribute__((swiftcall))
#else
#define GTNW_SWIFTCC
#endif

typedef struct GTNWJob GTNWJob;

/// The runtime's own enqueue, passed to every hook (unused: the bridge keeps every job).
typedef GTNW_SWIFTCC void (*gtnw_enqueue_original)(GTNWJob *_Nonnull job);
typedef GTNW_SWIFTCC void (*gtnw_enqueue_delay_original)(unsigned long long delay, GTNWJob *_Nonnull job);
typedef GTNW_SWIFTCC void (*gtnw_enqueue_deadline_original)(long long sec, long long nsec, long long tsec,
                                                           long long tnsec, int clock, GTNWJob *_Nonnull job);

extern void *_Nullable swift_task_enqueueGlobal_hook;
extern void *_Nullable swift_task_enqueueGlobalWithDelay_hook;
extern void *_Nullable swift_task_enqueueGlobalWithDeadline_hook;
extern void *_Nullable swift_task_enqueueMainExecutor_hook;

#endif
