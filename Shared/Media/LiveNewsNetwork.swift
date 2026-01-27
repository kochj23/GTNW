//
//  LiveNewsNetwork.swift
//  GTNW
//
//  Living World News Network with Multiple Outlets
//  AI-generated photos, voice anchors, bias detection
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class LiveNewsNetwork: ObservableObject {
    static let shared = LiveNewsNetwork()

    @Published var newsArticles: [NewsArticle] = []
    @Published var isGenerating = false
    @Published var selectedOutlet: NewsOutlet = .cnn

    private let imageGen = ImageGenerationUnified.shared
    private let voice = VoiceUnified.shared
    private let analysis = AnalysisUnified.shared
    private let llm = AIBackendManager.shared

    private init() {}

    // MARK: - Generate News Article

    func generateNewsArticle(
        event: GameEvent,
        outlets: [NewsOutlet] = NewsOutlet.allCases
    ) async throws -> [NewsArticle] {
        isGenerating = true
        defer { isGenerating = false }

        var articles: [NewsArticle] = []

        for outlet in outlets {
            // Generate outlet-specific coverage
            let article = try await generateOutletCoverage(event: event, outlet: outlet)
            articles.append(article)
        }

        newsArticles.append(contentsOf: articles)
        return articles
    }

    private func generateOutletCoverage(
        event: GameEvent,
        outlet: NewsOutlet
    ) async throws -> NewsArticle {
        // 1. Generate headline with outlet bias
        let headlinePrompt = """
        You are a \(outlet.rawValue) news writer.

        Event: \(event.description)

        Write a headline with \(outlet.bias) bias.
        - \(outlet.style)
        - 10-15 words maximum
        - Reflect \(outlet.rawValue) editorial stance

        Return only the headline.
        """

        let headline = try await llm.generate(prompt: headlinePrompt)

        // 2. Generate article body
        let bodyPrompt = """
        Write \(outlet.rawValue) news article about: \(event.description)

        Style: \(outlet.style)
        Bias: \(outlet.bias)
        Length: 150 words

        Capture \(outlet.rawValue)'s typical coverage approach.
        """

        let body = try await llm.generate(prompt: bodyPrompt)

        // 3. Generate accompanying image
        let imagePrompt = """
        News photo for "\(headline)",
        journalistic photography, \(event.imagePrompt),
        professional news photography, photorealistic
        """

        let imageData = try await imageGen.generateImage(
            prompt: imagePrompt,
            backend: .swarmui,
            size: .landscape768x512,
            style: .realistic
        )

        // 4. Generate anchor narration
        let narrationText = "\(outlet.rawValue) Breaking News. \(headline)."
        // Voice synthesis would happen here

        // 5. Detect bias
        let biasAnalysis = try await analysis.detectBias(body)

        return NewsArticle(
            id: UUID(),
            outlet: outlet,
            headline: headline,
            body: body,
            imageData: imageData,
            narrationURL: nil, // Would contain audio
            biasScore: biasAnalysis.politicalLean,
            sentiment: biasAnalysis.emotionalTone,
            event: event,
            timestamp: Date()
        )
    }

    // MARK: - Compare Coverage

    func compareCoverage(articles: [NewsArticle]) -> CoverageComparison {
        let headlines = articles.map { $0.headline }
        let biases = articles.map { "\($0.outlet.rawValue): \($0.biasScore)" }

        return CoverageComparison(
            topic: articles.first?.event.title ?? "",
            sources: articles.map { $0.outlet.rawValue },
            uniqueAngles: headlines,
            consensus: identifyConsensus(articles),
            disagreements: identifyDisagreements(articles)
        )
    }

    private func identifyConsensus(_ articles: [NewsArticle]) -> [String] {
        // Find common themes across outlets
        return ["Basic facts agreed upon by all outlets"]
    }

    private func identifyDisagreements(_ articles: [NewsArticle]) -> [String] {
        // Find divergent coverage
        return ["Editorial interpretations differ significantly"]
    }
}

// MARK: - Models

struct NewsArticle: Identifiable {
    let id: UUID
    let outlet: NewsOutlet
    let headline: String
    let body: String
    let imageData: Data
    let narrationURL: URL?
    let biasScore: Double // -1 (left) to 1 (right)
    let sentiment: Double // -1 (negative) to 1 (positive)
    let event: GameEvent
    let timestamp: Date
}

enum NewsOutlet: String, CaseIterable {
    case cnn = "CNN"
    case fox = "FOX News"
    case bbc = "BBC"
    case rt = "RT (Russia Today)"
    case aljazeera = "Al Jazeera"
    case reuters = "Reuters"
    case ap = "Associated Press"

    var bias: String {
        switch self {
        case .cnn: return "center-left"
        case .fox: return "right-leaning"
        case .bbc: return "balanced"
        case .rt: return "pro-Russian"
        case .aljazeera: return "Middle Eastern perspective"
        case .reuters: return "neutral"
        case .ap: return "fact-focused"
        }
    }

    var style: String {
        switch self {
        case .cnn: return "dramatic breaking news style"
        case .fox: return "opinion-driven, conservative angle"
        case .bbc: return "understated British journalism"
        case .rt: return "pro-Kremlin perspective"
        case .aljazeera: return "global south perspective"
        case .reuters: return "just the facts"
        case .ap: return "wire service brevity"
        }
    }

    var color: Color {
        switch self {
        case .cnn: return .red
        case .fox: return .blue
        case .bbc: return Color(red: 0.7, green: 0.1, blue: 0.1)
        case .rt: return .green
        case .aljazeera: return Color(red: 0.9, green: 0.6, blue: 0.0)
        case .reuters: return .orange
        case .ap: return .gray
        }
    }
}

struct GameEvent {
    let title: String
    let description: String
    let imagePrompt: String
    let severity: EventSeverity
}

enum EventSeverity {
    case routine
    case developing
    case breaking
    case critical
}

// MARK: - News Network View

struct NewsNetworkView: View {
    @StateObject private var newsNetwork = LiveNewsNetwork.shared
    @State private var selectedOutlet: NewsOutlet = .cnn

    var body: some View {
        VStack(spacing: 0) {
            // Outlet selector
            outletSelector

            Divider()

            // News feed
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredArticles) { article in
                        NewsArticleCard(article: article)
                    }
                }
                .padding()
            }
        }
        .background(Color.black.opacity(0.9))
    }

    private var outletSelector: some View {
        HStack {
            ForEach(NewsOutlet.allCases, id: \.self) { outlet in
                Button(action: {
                    selectedOutlet = outlet
                }) {
                    VStack(spacing: 4) {
                        Text(outlet.rawValue)
                            .font(.caption)
                            .fontWeight(selectedOutlet == outlet ? .bold : .regular)

                        if selectedOutlet == outlet {
                            Rectangle()
                                .fill(outlet.color)
                                .frame(height: 2)
                        }
                    }
                    .foregroundColor(selectedOutlet == outlet ? .white : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }

    private var filteredArticles: [NewsArticle] {
        newsNetwork.newsArticles.filter { $0.outlet == selectedOutlet }
    }
}

struct NewsArticleCard: View {
    let article: NewsArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Outlet badge
            HStack {
                Text(article.outlet.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(article.outlet.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(article.outlet.color.opacity(0.2))
                    .cornerRadius(6)

                Spacer()

                Text(formatTime(article.timestamp))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }

            // Headline
            Text(article.headline)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Image
            if let nsImage = NSImage(data: article.imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(8)
            }

            // Body
            Text(article.body)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(5)

            // Bias indicator
            HStack {
                Text("Bias:")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))

                BiasIndicator(score: article.biasScore)

                Spacer()

                Text("Sentiment:")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))

                SentimentIndicator(score: article.sentiment)
            }
        }
        .padding()
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(article.outlet.color.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct BiasIndicator: View {
    let score: Double // -1 to 1

    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 30, height: 8)
                .opacity(score < -0.3 ? 1.0 : 0.3)

            Rectangle()
                .fill(Color.gray)
                .frame(width: 30, height: 8)
                .opacity(abs(score) < 0.3 ? 1.0 : 0.3)

            Rectangle()
                .fill(Color.red)
                .frame(width: 30, height: 8)
                .opacity(score > 0.3 ? 1.0 : 0.3)
        }
    }
}

struct SentimentIndicator: View {
    let score: Double // -1 to 1

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Image(systemName: sentimentIcon(index))
                    .font(.caption2)
                    .foregroundColor(sentimentColor)
            }
        }
    }

    private func sentimentIcon(_ index: Int) -> String {
        let filledCount = Int((score + 1.0) / 2.0 * 5)
        return index < filledCount ? "star.fill" : "star"
    }

    private var sentimentColor: Color {
        if score > 0.3 { return .green }
        if score < -0.3 { return .red }
        return .yellow
    }
}
