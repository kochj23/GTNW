//
//  TheLivingRoom.swift
//  GTNW
//
//  THE LEGENDARY FEATURE: Real-Time Voice Conversations with World Leaders
//  Combines voice cloning, LLM dialogue, and sentiment analysis
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
class TheLivingRoom: ObservableObject {
    static let shared = TheLivingRoom()

    @Published var activeConversation: Conversation?
    @Published var conversationHistory: [ConversationExchange] = []
    @Published var isProcessing = false
    @Published var isPlayingAudio = false

    private let voices = WorldLeaderVoices.shared
    private let llm = AIBackendManager.shared
    private let sentiment = AnalysisUnified.shared
    private var audioPlayer: AVAudioPlayer?

    private init() {}

    // MARK: - Start Conversation

    func initiateConversation(
        with country: Country,
        context: ConversationContext
    ) async throws -> Conversation {
        isProcessing = true
        defer { isProcessing = false }

        let leaderName = voices.getLeaderName(for: country)

        // Generate opening statement from leader
        let opening = try await generateLeaderResponse(
            country: country,
            playerMessage: nil,
            context: context
        )

        let conversation = Conversation(
            id: UUID(),
            withCountry: country,
            leaderName: leaderName,
            startedAt: Date(),
            context: context,
            exchanges: [opening],
            isActive: true
        )

        activeConversation = conversation
        conversationHistory.append(opening)

        // Play opening audio
        await playAudio(opening.audioURL)

        return conversation
    }

    // MARK: - Player Responds

    func playerResponds(
        message: String,
        tone: ConversationTone
    ) async throws {
        guard let conversation = activeConversation else { return }

        isProcessing = true
        defer { isProcessing = false }

        // Record player's exchange
        let playerExchange = ConversationExchange(
            speaker: .player,
            leaderName: "US President",
            message: message,
            tone: tone,
            audioURL: nil,
            sentiment: nil,
            timestamp: Date()
        )

        conversationHistory.append(playerExchange)

        // Generate leader's response
        let leaderResponse = try await generateLeaderResponse(
            country: conversation.withCountry,
            playerMessage: message,
            context: conversation.context,
            playerTone: tone
        )

        conversationHistory.append(leaderResponse)

        // Update conversation
        activeConversation?.exchanges.append(contentsOf: [playerExchange, leaderResponse])

        // Play leader's audio response
        if let audioURL = leaderResponse.audioURL {
            await playAudio(audioURL)
        }

        // Update relations based on conversation
        updateRelationsFromConversation(
            country: conversation.withCountry,
            playerTone: tone,
            leaderSentiment: leaderResponse.sentiment
        )
    }

    // MARK: - Generate Leader Response

    private func generateLeaderResponse(
        country: Country,
        playerMessage: String?,
        context: ConversationContext,
        playerTone: ConversationTone? = nil
    ) async throws -> ConversationExchange {
        let leaderName = voices.getLeaderName(for: country)

        // Build prompt for LLM
        let prompt = buildConversationPrompt(
            country: country,
            leaderName: leaderName,
            playerMessage: playerMessage,
            playerTone: playerTone,
            context: context
        )

        // Generate AI response
        let aiResponse = try await llm.generate(prompt: prompt)

        // Clone leader's voice for response
        let audioURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("living_room_\(UUID().uuidString).wav")

        try await voices.voiceCloner.cloneVoice(
            referenceAudio: voices.voiceLibrary[leaderName]?.referenceAudioURL ?? URL(fileURLWithPath: "/"),
            targetText: aiResponse,
            outputURL: audioURL
        )

        // Analyze sentiment
        let sentimentResult = try await sentiment.analyzeSentiment(aiResponse)

        return ConversationExchange(
            speaker: .leader,
            leaderName: leaderName,
            message: aiResponse,
            tone: interpretTone(from: sentimentResult),
            audioURL: audioURL,
            sentiment: sentimentResult,
            timestamp: Date()
        )
    }

    private func buildConversationPrompt(
        country: Country,
        leaderName: String,
        playerMessage: String?,
        playerTone: ConversationTone?,
        context: ConversationContext
    ) -> String {
        var prompt = """
        You are \(leaderName), leader of \(country.name).

        CONTEXT:
        - US President just: \(context.triggeringAction)
        - Your country's relations with US: \(context.currentRelations)
        - Your personality: \(country.personality?.personalityType.rawValue ?? "Calculating")
        - Recent grievances: \(country.memory.grievances.map { $0.cause }.joined(separator: "; "))
        - Your nuclear status: \(country.hasNuclearWeapons ? "Nuclear-armed" : "Unarmed")
        - Turn: \(context.turn)
        - DEFCON: \(context.defconLevel)

        CONVERSATION HISTORY:
        \(conversationHistory.map { "[\($0.speaker)]: \($0.message)" }.joined(separator: "\n"))
        """

        if let playerMsg = playerMessage, let tone = playerTone {
            prompt += """

            \nUS PRESIDENT JUST SAID (tone: \(tone.rawValue)):
            "\(playerMsg)"

            RESPOND:
            - Stay in character as \(leaderName)
            - React to their tone (if defiant, respond accordingly)
            - Reference your previous statements
            - Make threats if appropriate to your personality
            - Be dramatic but realistic
            - 3-4 sentences maximum
            - NO asterisks or actions, just spoken dialogue
            """
        } else {
            prompt += """

            \nGive your OPENING STATEMENT about US actions.
            - Express \(country.name)'s perspective
            - Make your position clear
            - Threaten, negotiate, or demand as appropriate
            - 3-4 sentences
            - Speak as \(leaderName) would actually speak
            """
        }

        return prompt
    }

    private func interpretTone(from sentiment: SentimentResult) -> ConversationTone {
        switch sentiment.overallSentiment {
        case .positive: return .diplomatic
        case .negative: return .threatening
        case .neutral: return .neutral
        case .mixed: return .cautious
        }
    }

    // MARK: - Relations Impact

    private func updateRelationsFromConversation(
        country: Country,
        playerTone: ConversationTone,
        leaderSentiment: SentimentResult?
    ) {
        var relationsDelta = 0

        // Player's tone affects relations
        switch playerTone {
        case .diplomatic:
            relationsDelta += 5
        case .defiant:
            relationsDelta -= 10
        case .threatening:
            relationsDelta -= 15
        case .conciliatory:
            relationsDelta += 10
        case .neutral:
            relationsDelta += 0
        case .cautious:
            relationsDelta += 2
        }

        // Apply to country relations
        // country.relations[player] += relationsDelta
        print("Relations change: \(relationsDelta) based on conversation tone")
    }

    // MARK: - Audio Playback

    private func playAudio(_ url: URL) async {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        isPlayingAudio = true

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            // Wait for audio to finish
            let duration = audioPlayer?.duration ?? 0
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        } catch {
            print("Audio playback error: \(error)")
        }

        isPlayingAudio = false
    }

    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlayingAudio = false
    }

    // MARK: - End Conversation

    func endConversation() {
        activeConversation = nil
        stopAudio()
    }
}

// MARK: - Models

struct Conversation: Identifiable {
    let id: UUID
    let withCountry: Country
    let leaderName: String
    let startedAt: Date
    let context: ConversationContext
    var exchanges: [ConversationExchange]
    var isActive: Bool
}

struct ConversationContext {
    let triggeringAction: String
    let currentRelations: Int
    let turn: Int
    let defconLevel: Int
    let recentEvents: [String]
}

struct ConversationExchange: Identifiable {
    let id = UUID()
    let speaker: Speaker
    let leaderName: String
    let message: String
    let tone: ConversationTone
    let audioURL: URL?
    let sentiment: SentimentResult?
    let timestamp: Date
}

enum Speaker {
    case player
    case leader
}

enum ConversationTone: String, CaseIterable {
    case diplomatic = "Diplomatic"
    case defiant = "Defiant"
    case threatening = "Threatening"
    case conciliatory = "Conciliatory"
    case neutral = "Neutral"
    case cautious = "Cautious"
}

// MARK: - The Living Room View

struct TheLivingRoomView: View {
    @StateObject private var livingRoom = TheLivingRoom.shared
    @State private var playerMessage = ""
    @State private var selectedTone: ConversationTone = .diplomatic

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Leader video feed (portrait)
            leaderPortrait
                .frame(height: 300)

            Divider()

            // Conversation transcript
            transcript
                .frame(height: 250)

            Divider()

            // Player response controls
            responseControls
                .frame(height: 150)
        }
        .background(Color.black)
    }

    private var header: some View {
        HStack {
            if let conversation = livingRoom.activeConversation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📞 In Conversation")
                        .font(.caption)
                        .foregroundColor(.green)

                    Text(conversation.leaderName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(conversation.withCountry.name)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                if livingRoom.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }

                if livingRoom.isPlayingAudio {
                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.green)
                        Text("Speaking...")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Button("End Call") {
                    livingRoom.endConversation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }

    private var leaderPortrait: some View {
        ZStack {
            Color.black.opacity(0.9)

            if let conversation = livingRoom.activeConversation {
                VStack {
                    // Leader portrait (would be AI-generated in production)
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.blue)

                    Text(conversation.leaderName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(conversation.withCountry.name)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))

                    // Sentiment indicator
                    if let lastExchange = conversation.exchanges.last(where: { $0.speaker == .leader }),
                       let sentiment = lastExchange.sentiment {
                        Text(sentiment.overallSentiment.description.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(sentimentColor(sentiment))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(sentimentColor(sentiment).opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var transcript: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(livingRoom.conversationHistory.suffix(10)) { exchange in
                    ConversationBubble(exchange: exchange)
                }
            }
            .padding()
        }
        .background(Color.gray.opacity(0.1))
    }

    private var responseControls: some View {
        VStack(spacing: 12) {
            // Tone selector
            HStack {
                Text("Your Tone:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Picker("Tone", selection: $selectedTone) {
                    ForEach(ConversationTone.allCases, id: \.self) { tone in
                        Text(tone.rawValue).tag(tone)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Quick responses
            HStack(spacing: 8) {
                QuickResponseButton("Comply", tone: .conciliatory) {
                    playerMessage = "We will comply with your request."
                    sendMessage()
                }

                QuickResponseButton("Refuse", tone: .defiant) {
                    playerMessage = "We will not be intimidated."
                    sendMessage()
                }

                QuickResponseButton("Threaten", tone: .threatening) {
                    playerMessage = "You will face severe consequences."
                    sendMessage()
                }

                QuickResponseButton("Negotiate", tone: .diplomatic) {
                    playerMessage = "Perhaps we can find a diplomatic solution."
                    sendMessage()
                }
            }

            // Custom response
            HStack {
                TextField("Type your response...", text: $playerMessage)
                    .textFieldStyle(.roundedBorder)

                Button("Send") {
                    sendMessage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(playerMessage.isEmpty || livingRoom.isProcessing)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }

    private func sendMessage() {
        guard !playerMessage.isEmpty else { return }

        Task {
            try await livingRoom.playerResponds(
                message: playerMessage,
                tone: selectedTone
            )
            playerMessage = ""
        }
    }

    private func sentimentColor(_ sentiment: SentimentResult) -> Color {
        switch sentiment.overallSentiment {
        case .positive: return .green
        case .negative: return .red
        case .neutral: return .gray
        case .mixed: return .orange
        }
    }
}

struct QuickResponseButton: View {
    let label: String
    let tone: ConversationTone
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(toneColor.opacity(0.3))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var toneColor: Color {
        switch tone {
        case .diplomatic: return .blue
        case .defiant: return .red
        case .threatening: return .red
        case .conciliatory: return .green
        case .neutral: return .gray
        case .cautious: return .yellow
        }
    }
}

struct ConversationBubble: View {
    let exchange: ConversationExchange

    var body: some View {
        HStack {
            if exchange.speaker == .player {
                Spacer()
            }

            VStack(alignment: exchange.speaker == .player ? .trailing : .leading, spacing: 4) {
                Text(exchange.leaderName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.7))

                Text(exchange.message)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(bubbleColor)
                    .cornerRadius(12)

                if let sentiment = exchange.sentiment {
                    Text(sentiment.overallSentiment.description)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: 400)

            if exchange.speaker == .leader {
                Spacer()
            }
        }
    }

    private var bubbleColor: Color {
        exchange.speaker == .player
            ? Color.blue.opacity(0.3)
            : Color.gray.opacity(0.3)
    }
}

// MARK: - Access Extensions

extension WorldLeaderVoices {
    func getLeaderName(for country: Country) -> String {
        switch country.id {
        case "Russia": return "Vladimir Putin"
        case "China": return "Xi Jinping"
        case "North Korea": return "Kim Jong-un"
        case "France": return "Emmanuel Macron"
        case "India": return "Narendra Modi"
        case "Israel": return "Benjamin Netanyahu"
        case "Turkey": return "Recep Erdogan"
        case "Saudi Arabia": return "Mohammad bin Salman"
        case "Iran": return "Ayatollah Khamenei"
        case "UK": return "Prime Minister"
        default: return "\(country.name) Leader"
        }
    }
}
