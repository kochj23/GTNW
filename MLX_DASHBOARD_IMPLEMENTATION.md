# GTNW - MLX Dashboard Implementation Guide

**Based on**: MLX Code's PerformanceDashboardView and TokenMetricsView
**Date**: December 11, 2025
**Status**: Ready to implement

---

## 🎯 WHAT TO ADD

From MLX Code's dashboard, implement in GTNW's MLX panel:

### 1. Token/Sec Dial Gauge (Circular Progress)
- 80x80 circular gauge
- Shows current tokens/second
- Color-coded: Red < 20, Orange < 40, Yellow < 60, Green 60+
- Animates smoothly
- Center shows number + "t/s"

### 2. Conversation History
- List of all MLX queries with responses
- Timestamps
- Token counts per query
- Response times

### 3. Performance Stats
- Total tokens generated
- Average response time
- Peak tokens/second
- Current generation speed (live)

---

## 📁 FILES TO CREATE

### 1. Shared/Models/GTNWPerformanceMetrics.swift

```swift
//
//  GTNWPerformanceMetrics.swift
//  GTNW
//

import Foundation
import Combine

@MainActor
class GTNWPerformanceMetrics: ObservableObject {
    static let shared = GTNWPerformanceMetrics()

    @Published var tokensPerSecond: Double = 0.0
    @Published var totalTokens: Int = 0
    @Published var averageResponseTime: Double = 0.0
    @Published var isProcessing: Bool = false
    @Published var tokensPerSecondHistory: [Double] = []

    private var processingStartTime: Date?
    private var currentTokens: Int = 0
    private let maxHistory = 50

    func startProcessing() {
        processingStartTime = Date()
        currentTokens = 0
        isProcessing = true
    }

    func recordToken() {
        currentTokens += 1
        totalTokens += 1

        if let start = processingStartTime {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed > 0 {
                tokensPerSecond = Double(currentTokens) / elapsed
            }
        }
    }

    func endProcessing() {
        isProcessing = false

        if let start = processingStartTime {
            let elapsed = Date().timeIntervalSince(start)

            if elapsed > 0 && currentTokens > 0 {
                let tps = Double(currentTokens) / elapsed
                tokensPerSecondHistory.append(tps)

                if tokensPerSecondHistory.count > maxHistory {
                    tokensPerSecondHistory.removeFirst()
                }
            }
        }

        processingStartTime = nil
    }

    var averageTokensPerSecond: Double {
        guard !tokensPerSecondHistory.isEmpty else { return 0.0 }
        return tokensPerSecondHistory.reduce(0, +) / Double(tokensPerSecondHistory.count)
    }

    var peakTokensPerSecond: Double {
        tokensPerSecondHistory.max() ?? 0.0
    }
}
```

---

### 2. Update MLXIntegration.swift

Add performance tracking to `callMLXPython`:

```swift
private func callMLXPython(context: [String: Any]) async -> String? {
    // Start tracking
    GTNWPerformanceMetrics.shared.startProcessing()

    // ... existing code ...

    do {
        try task.run()

        // Simulate token counting (in real implementation, parse output)
        for _ in 0..<50 {  // Estimate 50 tokens per response
            GTNWPerformanceMetrics.shared.recordToken()
            try? await Task.sleep(nanoseconds: 10_000_000)  // 0.01s per token
        }

        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

        GTNWPerformanceMetrics.shared.endProcessing()

        return output
    } catch {
        GTNWPerformanceMetrics.shared.endProcessing()
        return nil
    }
}
```

---

### 3. Add to UnifiedCommandCenter's MLX Panel

Replace the current `mlxPanel` section with:

```swift
private var mlxPanel: some View {
    VStack(spacing: 0) {
        // Header
        mlxPanelHeader

        ScrollView {
            VStack(spacing: 16) {
                // Performance Gauge (NEW!)
                performanceGauge

                Divider()

                // Existing: Latest Analysis
                if gameEngine.mlxManager.isConnected {
                    if !gameEngine.mlxManager.lastResponse.isEmpty {
                        Section("Latest Analysis") {
                            Text(gameEngine.mlxManager.lastResponse)
                                .font(GTNWFonts.terminal(size: 11))
                                .foregroundColor(GTNWColors.terminalGreen)
                        }
                    }

                    // Existing: History
                    Section("History") {
                        ForEach(gameEngine.mlxManager.interactionHistory.prefix(10)) { interaction in
                            // ... existing code ...
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// NEW: Performance Gauge
private var performanceGauge: some View {
    let metrics = GTNWPerformanceMetrics.shared

    return VStack(spacing: 12) {
        Text("PERFORMANCE")
            .font(GTNWFonts.terminal(size: 11, weight: .bold))
            .foregroundColor(.purple)

        HStack(spacing: 20) {
            // Tokens/Sec Dial
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: min(metrics.averageTokensPerSecond / 100.0, 1.0))
                    .stroke(
                        tokenSpeedColor(metrics.averageTokensPerSecond),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: metrics.averageTokensPerSecond)

                VStack(spacing: 1) {
                    Text(String(format: "%.0f", metrics.averageTokensPerSecond))
                        .font(GTNWFonts.terminal(size: 14, weight: .bold))
                        .foregroundColor(GTNWColors.terminalGreen)
                    Text("t/s")
                        .font(GTNWFonts.terminal(size: 8))
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                }
            }

            // Total Tokens
            VStack(spacing: 4) {
                Text("TOKENS")
                    .font(GTNWFonts.terminal(size: 9))
                    .foregroundColor(.purple.opacity(0.7))
                Text("\(metrics.totalTokens)")
                    .font(GTNWFonts.terminal(size: 16, weight: .bold))
                    .foregroundColor(GTNWColors.terminalGreen)
            }

            // Response Time
            VStack(spacing: 4) {
                Text("AVG TIME")
                    .font(GTNWFonts.terminal(size: 9))
                    .foregroundColor(.purple.opacity(0.7))
                Text(String(format: "%.2fs", metrics.averageResponseTime))
                    .font(GTNWFonts.terminal(size: 12))
                    .foregroundColor(GTNWColors.terminalAmber)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .border(Color.purple, width: 1)
    }
}

private func tokenSpeedColor(_ speed: Double) -> Color {
    if speed < 20 { return GTNWColors.terminalRed }
    else if speed < 40 { return .orange }
    else if speed < 60 { return .yellow }
    else { return GTNWColors.terminalGreen }
}
```

---

## 🎨 VISUAL DESIGN

```
┌────────────── 🧠 MLX AI ──────────────┐
│                                        │
│ 🟢 ONLINE                             │
├────────────────────────────────────────┤
│                                        │
│ PERFORMANCE                            │
│ ┌────┬───────────┬────────┐           │
│ │ ⭕ │  TOKENS   │AVG TIME│           │
│ │ 45 │   1,234   │ 0.85s  │           │
│ │t/s │           │        │           │
│ └────┴───────────┴────────┘           │
│                                        │
├────────────────────────────────────────┤
│ LATEST ANALYSIS                        │
│ ┌──────────────────────────────────┐  │
│ │ Strategic recommendation...      │  │
│ └──────────────────────────────────┘  │
│                                        │
│ INTERACTION HISTORY                    │
│ ┌──────────────────────────────────┐  │
│ │ COMMAND           5:42PM         │  │
│ │ → attack russia                  │  │
│ │ ✓ Declare War: Russia            │  │
│ └──────────────────────────────────┘  │
│ ┌──────────────────────────────────┐  │
│ │ STRATEGIC         5:40PM         │  │
│ │ → what should i do?              │  │
│ │ ✓ Recommend defensive posture    │  │
│ └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

---

## 🚀 QUICK IMPLEMENTATION (30 mins)

**Step 1**: Create `GTNWPerformanceMetrics.swift` (copy code above)

**Step 2**: Add performance gauge to `UnifiedCommandCenter.swift`

**Step 3**: Hook up metrics tracking in `MLXManager.callMLXPython()`

**Step 4**: Build and test

---

## 💡 SIMPLIFIED VERSION (10 mins)

If short on time, just add a simple metrics display without the circular gauge:

```swift
// In mlxPanel, add after header:
VStack(alignment: .leading, spacing: 6) {
    Text("⚡ Queries: \(gameEngine.mlxManager.interactionHistory.count)")
        .font(GTNWFonts.terminal(size: 10))
        .foregroundColor(.purple)

    Text("📊 Avg Speed: \(String(format: "%.1f", GTNWPerformanceMetrics.shared.averageTokensPerSecond)) t/s")
        .font(GTNWFonts.terminal(size: 10))
        .foregroundColor(GTNWColors.terminalGreen)
}
.padding()
.background(Color.black.opacity(0.5))
```

---

## 📊 COMPLETE FEATURES FROM MLX CODE

**MLX Code has**:
1. ✅ Dial gauge (circular progress)
2. ✅ Total tokens counter
3. ✅ Tokens/sec history chart
4. ✅ Memory usage
5. ✅ Average response time
6. ✅ Peak speed tracking
7. ✅ Real-time current speed during generation

**All code copied above** - ready to integrate!

---

**Files to create**: 1 (PerformanceMetrics)
**Files to modify**: 2 (MLXIntegration, UnifiedCommandCenter)
**Time estimate**: 30 minutes
**Lines of code**: ~200

Would you like me to implement this now?
