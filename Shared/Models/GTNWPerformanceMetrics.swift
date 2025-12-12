//
//  GTNWPerformanceMetrics.swift
//  GTNW
//
//  MLX performance tracking (based on MLX Code)
//  Created by Jordan Koch on 2025-12-11
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
    @Published var responseTimeHistory: [Double] = []

    private var processingStartTime: Date?
    private var currentTokens: Int = 0
    private var responseTimes: [Double] = []
    private let maxHistory = 50

    private init() {}

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

            responseTimes.append(elapsed)
            if responseTimes.count > maxHistory {
                responseTimes.removeFirst()
            }

            averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)

            if elapsed > 0 && currentTokens > 0 {
                let tps = Double(currentTokens) / elapsed
                tokensPerSecondHistory.append(tps)

                if tokensPerSecondHistory.count > maxHistory {
                    tokensPerSecondHistory.removeFirst()
                }
            }

            responseTimeHistory.append(elapsed)
            if responseTimeHistory.count > maxHistory {
                responseTimeHistory.removeFirst()
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

    func reset() {
        tokensPerSecond = 0.0
        totalTokens = 0
        averageResponseTime = 0.0
        currentTokens = 0
        responseTimes.removeAll()
        tokensPerSecondHistory.removeAll()
        responseTimeHistory.removeAll()
        isProcessing = false
    }
}
