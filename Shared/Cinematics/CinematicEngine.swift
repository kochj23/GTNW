//
//  CinematicEngine.swift
//  GTNW
//
//  Cinematic Event Sequences for Major Game Moments
//  Nuclear strikes, victories, major crises
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
class CinematicEngine: ObservableObject {
    static let shared = CinematicEngine()

    @Published var isPlayingCinematic = false
    @Published var currentSequence: CinematicSequence?

    private let imageGen = ImageGenerationUnified.shared
    private let voice = VoiceUnified.shared
    private var audioPlayer: AVAudioPlayer?

    private init() {}

    // MARK: - Nuclear Strike Cinematic

    func playNuclearStrikeCinematic(
        attacker: Country,
        target: Country,
        warheadCount: Int,
        estimatedCasualties: Int
    ) async throws {
        isPlayingCinematic = true
        defer { isPlayingCinematic = false }

        // Create cinematic sequence
        var sequence = CinematicSequence(
            id: UUID(),
            type: .nuclearStrike,
            title: "NUCLEAR STRIKE AUTHORIZED",
            scenes: []
        )

        // Scene 1: Launch Authorization
        let authScene = try await createScene(
            title: "Authorization",
            description: "Mr. President authorizes nuclear strike",
            imagePrompt: "Presidential seal, somber dark room, nuclear launch keys on table, dramatic lighting",
            voiceText: "Mr. President... may God forgive us for what we are about to do.",
            duration: 3.0
        )
        sequence.scenes.append(authScene)

        // Scene 2: Launch Sequence
        let launchScene = try await createScene(
            title: "Launch Sequence",
            description: "Missiles launching from silos",
            imagePrompt: "Nuclear missile launching from underground silo at night, fire and smoke, dramatic angle, photorealistic",
            voiceText: "Missiles away. Time to impact: \(warheadCount) warheads targeting \(target.name). Estimated casualties: \(estimatedCasualties).",
            duration: 5.0
        )
        sequence.scenes.append(launchScene)

        // Scene 3: Impact
        let impactScene = try await createScene(
            title: "Impact",
            description: "Nuclear detonation",
            imagePrompt: "Massive mushroom cloud over city, nuclear explosion, devastating, apocalyptic, photorealistic",
            voiceText: "Impact confirmed. \(target.name) has been struck by \(warheadCount) nuclear warheads.",
            duration: 4.0
        )
        sequence.scenes.append(impactScene)

        // Scene 4: Aftermath
        let aftermathScene = try await createScene(
            title: "Aftermath",
            description: "Consequences report",
            imagePrompt: "Devastated city ruins, nuclear aftermath, survivors in radiation suits, somber dark tones",
            voiceText: "Estimated casualties: \(estimatedCasualties). Radiation levels critical. Global fallout imminent.",
            duration: 3.0
        )
        sequence.scenes.append(aftermathScene)

        currentSequence = sequence

        // Play sequence (in production UI would handle this)
    }

    // MARK: - Victory Cinematic

    func playVictoryCinematic(
        victoryType: String,
        president: String,
        turnCount: Int,
        score: Int
    ) async throws {
        isPlayingCinematic = true
        defer { isPlayingCinematic = false }

        var sequence = CinematicSequence(
            id: UUID(),
            type: .victory,
            title: "\(victoryType) VICTORY",
            scenes: []
        )

        // Victory scene
        let victoryScene = try await createScene(
            title: "Victory",
            description: "Triumphant moment",
            imagePrompt: "American flag waving triumphantly, presidential seal, victory celebration, heroic lighting, dramatic",
            voiceText: "Congratulations, Mr. President. You have achieved \(victoryType). Your leadership over \(turnCount) turns has earned a score of \(score) points.",
            duration: 5.0
        )
        sequence.scenes.append(victoryScene)

        // Legacy scene
        let legacyScene = try await createScene(
            title: "Your Legacy",
            description: "Historical assessment",
            imagePrompt: "Presidential portrait in gold frame, White House, historical painting style",
            voiceText: "President \(president)'s legacy will be remembered for generations. Your decisions shaped the course of history.",
            duration: 4.0
        )
        sequence.scenes.append(legacyScene)

        currentSequence = sequence
    }

    // MARK: - Crisis Cinematic

    func playCrisisCinematic(crisis: String) async throws {
        isPlayingCinematic = true
        defer { isPlayingCinematic = false }

        let scene = try await createScene(
            title: "CRISIS ALERT",
            description: crisis,
            imagePrompt: "Situation room, urgent briefing, world leaders, tense atmosphere, photorealistic",
            voiceText: "Mr. President, we have a crisis situation. Your immediate decision is required.",
            duration: 3.0
        )

        let sequence = CinematicSequence(
            id: UUID(),
            type: .crisis,
            title: "BREAKING: \(crisis)",
            scenes: [scene]
        )

        currentSequence = sequence
    }

    // MARK: - Create Scene

    private func createScene(
        title: String,
        description: String,
        imagePrompt: String,
        voiceText: String,
        duration: Double
    ) async throws -> CinematicScene {
        // Generate image
        let imageData = try await imageGen.generateImage(
            prompt: imagePrompt,
            backend: .swarmui,
            size: .widescreen1024x576,
            style: .realistic
        )

        // Generate voice narration
        let audioURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cinematic_\(UUID().uuidString).wav")

        // Use system TTS for narration
        _ = voice.synthesizeSpeech(text: voiceText, voice: "deep dramatic narrator")

        return CinematicScene(
            id: UUID(),
            title: title,
            description: description,
            imageData: imageData,
            audioURL: audioURL,
            voiceText: voiceText,
            duration: duration
        )
    }
}

// MARK: - Models

struct CinematicSequence: Identifiable {
    let id: UUID
    let type: CinematicType
    let title: String
    var scenes: [CinematicScene]
}

struct CinematicScene: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let imageData: Data
    let audioURL: URL?
    let voiceText: String
    let duration: Double
}

enum CinematicType {
    case nuclearStrike
    case victory
    case defeat
    case crisis
    case majorEvent
}

// MARK: - Cinematic Player View

struct CinematicPlayerView: View {
    let sequence: CinematicSequence
    @State private var currentSceneIndex = 0
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if currentSceneIndex < sequence.scenes.count {
                let scene = sequence.scenes[currentSceneIndex]

                VStack(spacing: 0) {
                    // Scene image
                    if let nsImage = NSImage(data: scene.imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 800)
                    }

                    // Scene title and text
                    VStack(spacing: 12) {
                        Text(scene.title.uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(scene.voiceText)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding()
                }

                // Progress indicator
                HStack {
                    ForEach(0..<sequence.scenes.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentSceneIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding()

                // Skip button
                Button("Skip") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding()
                .frame(maxWidth: .infinity, alignment: .bottomTrailing)
            }
        }
        .onAppear {
            playSequence()
        }
    }

    private func playSequence() {
        guard currentSceneIndex < sequence.scenes.count else {
            dismiss()
            return
        }

        let scene = sequence.scenes[currentSceneIndex]

        // Play scene audio
        // playAudio(scene.audioURL)

        // Auto-advance after duration
        Task {
            try? await Task.sleep(nanoseconds: UInt64(scene.duration * 1_000_000_000))
            currentSceneIndex += 1

            if currentSceneIndex >= sequence.scenes.count {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                dismiss()
            } else {
                playSequence()
            }
        }
    }
}
