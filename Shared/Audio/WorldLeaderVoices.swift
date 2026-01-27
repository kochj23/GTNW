//
//  WorldLeaderVoices.swift
//  GTNW
//
//  Voice-Acted World Leaders System
//  F5-TTS Voice Cloning Integration
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
class WorldLeaderVoices: ObservableObject {
    static let shared = WorldLeaderVoices()

    @Published var isProcessing = false
    @Published var lastError: String?
    @Published var voiceLibrary: [String: VoiceModel] = [:]
    @Published var generatedAudio: [GeneratedAudio] = []

    private let voiceCloner = VoiceUnified.shared
    private let llm = AIBackendManager.shared
    private var audioPlayer: AVAudioPlayer?

    // Voice library directory
    private let voiceLibraryPath = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0].appendingPathComponent("GTNW/VoiceLibrary")

    private init() {
        createVoiceLibraryDirectory()
        loadVoiceLibrary()
    }

    // MARK: - Voice Library Setup

    private func createVoiceLibraryDirectory() {
        try? FileManager.default.createDirectory(
            at: voiceLibraryPath,
            withIntermediateDirectories: true
        )
    }

    private func loadVoiceLibrary() {
        // Pre-configured world leader voices
        // In production, these would reference actual audio samples
        voiceLibrary = [
            "Vladimir Putin": VoiceModel(
                id: "putin",
                name: "Vladimir Putin",
                country: "Russia",
                language: "en-RU",
                referenceAudioURL: voiceLibraryPath.appendingPathComponent("putin_reference.wav"),
                voiceModelURL: voiceLibraryPath.appendingPathComponent("putin_model.pth")
            ),
            "Xi Jinping": VoiceModel(
                id: "xi",
                name: "Xi Jinping",
                country: "China",
                language: "en-CN",
                referenceAudioURL: voiceLibraryPath.appendingPathComponent("xi_reference.wav"),
                voiceModelURL: voiceLibraryPath.appendingPathComponent("xi_model.pth")
            ),
            "Kim Jong-un": VoiceModel(
                id: "kim",
                name: "Kim Jong-un",
                country: "North Korea",
                language: "en-KR",
                referenceAudioURL: voiceLibraryPath.appendingPathComponent("kim_reference.wav"),
                voiceModelURL: voiceLibraryPath.appendingPathComponent("kim_model.pth")
            ),
            "Emmanuel Macron": VoiceModel(
                id: "macron",
                name: "Emmanuel Macron",
                country: "France",
                language: "en-FR",
                referenceAudioURL: voiceLibraryPath.appendingPathComponent("macron_reference.wav"),
                voiceModelURL: voiceLibraryPath.appendingPathComponent("macron_model.pth")
            ),
            "Narendra Modi": VoiceModel(
                id: "modi",
                name: "Narendra Modi",
                country: "India",
                language: "en-IN",
                referenceAudioURL: voiceLibraryPath.appendingPathComponent("modi_reference.wav"),
                voiceModelURL: voiceLibraryPath.appendingPathComponent("modi_model.pth")
            ),
            "Benjamin Netanyahu": VoiceModel(
                id: "netanyahu",
                name: "Benjamin Netanyahu",
                country: "Israel",
                language: "en-IL",
                referenceAudioURL: voiceLibraryPath.appendingPathComponent("netanyahu_reference.wav"),
                voiceModelURL: voiceLibraryPath.appendingPathComponent("netanyahu_model.pth")
            ),
            "Recep Erdogan": VoiceModel(
                id: "erdogan",
                name: "Recep Erdogan",
                country: "Turkey",
                language: "en-TR",
                referenceAudioURL: voiceLibraryPath.appendingPathComponent("erdogan_reference.wav"),
                voiceModelURL: voiceLibraryPath.appendingPathComponent("erdogan_model.pth")
            ),
            "Mohammad bin Salman": VoiceModel(
                id: "mbs",
                name: "Mohammad bin Salman",
                country: "Saudi Arabia",
                language: "en-SA",
                referenceAudioURL: voiceLibraryPath.appendingPathComponent("mbs_reference.wav"),
                voiceModelURL: voiceLibraryPath.appendingPathComponent("mbs_model.pth")
            )
        ]
    }

    // MARK: - Generate Voiced Diplomatic Message

    func generateVoicedMessage(
        from country: Country,
        message: String,
        context: GameContext
    ) async throws -> VoicedDiplomaticMessage {
        isProcessing = true
        defer { isProcessing = false }

        // 1. Generate AI response using LLM
        let leaderName = getLeaderName(for: country)
        let voiceModel = voiceLibrary[leaderName]

        let prompt = """
        You are \(leaderName), leader of \(country.name).

        Context:
        - US just: \(context.lastAction)
        - Your relations with US: \(country.relations[country.id] ?? 0)
        - Your personality: \(country.personality?.rawValue ?? "Calculating")
        - Recent grievances: \(country.memory.grievances.map { $0.cause }.joined(separator: ", "))
        - Your nuclear status: \(country.hasNuclearWeapons ? "Armed" : "Unarmed")

        Respond as \(leaderName) would. Be in character.
        Express your perspective on US actions.
        Make threats if appropriate to your personality.
        Keep to 3-4 sentences. Be dramatic but realistic.
        """

        let aiResponse = try await llm.generate(prompt: prompt)

        // 2. Generate voice audio using cloned voice
        let audioURL = voiceLibraryPath.appendingPathComponent("generated_\(UUID().uuidString).wav")

        if let voiceModel = voiceModel,
           FileManager.default.fileExists(atPath: voiceModel.referenceAudioURL.path) {
            // Use F5-TTS voice cloning
            try await voiceCloner.cloneVoice(
                referenceAudio: voiceModel.referenceAudioURL,
                targetText: aiResponse,
                outputURL: audioURL
            )
        } else {
            // Fallback to system TTS
            _ = voiceCloner.synthesizeSpeech(text: aiResponse, voice: nil)
            // Save to audioURL (simplified for now)
        }

        // 3. Analyze sentiment of response
        let sentiment = try await AnalysisUnified.shared.analyzeSentiment(aiResponse)

        let voicedMessage = VoicedDiplomaticMessage(
            id: UUID(),
            from: country,
            leaderName: leaderName,
            text: aiResponse,
            audioURL: audioURL,
            sentiment: sentiment,
            timestamp: Date()
        )

        generatedAudio.append(GeneratedAudio(
            id: UUID(),
            leader: leaderName,
            text: aiResponse,
            audioURL: audioURL,
            timestamp: Date()
        ))

        return voicedMessage
    }

    // MARK: - Play Audio

    func playVoicedMessage(_ message: VoicedDiplomaticMessage) {
        guard FileManager.default.fileExists(atPath: message.audioURL.path) else {
            print("Audio file not found: \(message.audioURL.path)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: message.audioURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            lastError = "Failed to play audio: \(error.localizedDescription)"
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Helpers

    private func getLeaderName(for country: Country) -> String {
        // Map countries to their current leaders
        switch country.id {
        case "Russia": return "Vladimir Putin"
        case "China": return "Xi Jinping"
        case "North Korea": return "Kim Jong-un"
        case "France": return "Emmanuel Macron"
        case "India": return "Narendra Modi"
        case "Israel": return "Benjamin Netanyahu"
        case "Turkey": return "Recep Erdogan"
        case "Saudi Arabia": return "Mohammad bin Salman"
        default: return "\(country.name) Leader"
        }
    }

    // MARK: - Voice Model Training

    func trainVoiceModel(
        leaderName: String,
        referenceAudio: URL
    ) async throws {
        // Train F5-TTS model from reference audio
        let modelURL = voiceLibraryPath.appendingPathComponent("\(leaderName.lowercased())_model.pth")

        // F5-TTS training process
        // In production, this would call actual F5-TTS training pipeline
        print("Training voice model for \(leaderName)...")

        voiceLibrary[leaderName] = VoiceModel(
            id: leaderName.lowercased().replacingOccurrences(of: " ", with: "_"),
            name: leaderName,
            country: "",
            language: "en",
            referenceAudioURL: referenceAudio,
            voiceModelURL: modelURL
        )
    }
}

// MARK: - Models

struct VoiceModel: Codable {
    let id: String
    let name: String
    let country: String
    let language: String
    let referenceAudioURL: URL
    let voiceModelURL: URL
}

struct VoicedDiplomaticMessage: Identifiable {
    let id: UUID
    let from: Country
    let leaderName: String
    let text: String
    let audioURL: URL
    let sentiment: SentimentResult
    let timestamp: Date
}

struct GeneratedAudio: Identifiable {
    let id: UUID
    let leader: String
    let text: String
    let audioURL: URL
    let timestamp: Date
}

struct GameContext {
    let lastAction: String
    let turnNumber: Int
    let defconLevel: Int
    let recentEvents: [String]
}

// MARK: - Voice Player View

struct VoiceMessagePlayerView: View {
    let message: VoicedDiplomaticMessage
    @StateObject private var voices = WorldLeaderVoices.shared
    @State private var isPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Leader header
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(sentimentColor)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(message.leaderName)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(message.from.name)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Sentiment indicator
                Text(message.sentiment.overallSentiment.description.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(sentimentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sentimentColor.opacity(0.2))
                    .cornerRadius(4)
            }

            // Message text
            Text(message.text)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .padding(.vertical, 8)

            // Audio controls
            HStack {
                Button(action: {
                    if isPlaying {
                        voices.stopPlayback()
                        isPlaying = false
                    } else {
                        voices.playVoicedMessage(message)
                        isPlaying = true
                    }
                }) {
                    HStack {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        Text(isPlaying ? "Stop" : "Play Voice")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(sentimentColor.opacity(0.5), lineWidth: 2)
                )
        )
    }

    private var sentimentColor: Color {
        switch message.sentiment.overallSentiment {
        case .positive: return .green
        case .negative: return .red
        case .neutral: return .gray
        case .mixed: return .orange
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

extension Sentiment {
    var description: String {
        switch self {
        case .positive: return "Friendly"
        case .negative: return "Hostile"
        case .neutral: return "Neutral"
        case .mixed: return "Mixed"
        }
    }
}
