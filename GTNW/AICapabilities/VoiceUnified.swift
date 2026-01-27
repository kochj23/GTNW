//
//  VoiceUnified.swift
//  Universal Voice & Audio Module
//
//  Supports: F5-TTS Voice Cloning, System TTS, Audio Briefings
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import AVFoundation

@MainActor
class VoiceUnified: ObservableObject {
    static let shared = VoiceUnified()

    @Published var isProcessing = false
    @Published var lastError: String?
    @Published var voiceModels: [VoiceModel] = []

    private let synthesizer = AVSpeechSynthesizer()
    private var audioOutputURL: URL?
    private var audioData: Data?

    private init() {
        loadVoiceModels()
    }

    // MARK: - Voice Cloning (F5-TTS-MLX)

    func cloneVoice(referenceAudio: URL, targetText: String, outputURL: URL) async throws {
        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        // Call F5-TTS-MLX Python script
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/python3")
        process.arguments = [
            "-m", "f5_tts.infer",
            "--ref_audio", referenceAudio.path,
            "--ref_text", "Reference audio text",
            "--gen_text", targetText,
            "--output_path", outputURL.path
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw VoiceError.cloneFailed
        }
    }

    // MARK: - System TTS

    func synthesizeSpeech(text: String, voice: String? = nil) -> Data? {
        let utterance = AVSpeechUtterance(string: text)

        if let voiceName = voice {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceName)
        }

        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // This is simplified - in production, you'd capture audio to file
        synthesizer.speak(utterance)

        return nil
    }

    // MARK: - Audio Briefing

    func generateAudioBriefing(content: String, title: String) async throws -> Data {
        let briefingScript = """
        Audio Briefing: \(title)

        \(content)

        End of briefing.
        """

        // Use say command to generate audio file (macOS native TTS)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("briefing_\(UUID().uuidString).aiff")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = [
            "-o", tempURL.path,
            "--data-format=LEI16@22050",  // Linear PCM 16-bit, 22.05kHz
            briefingScript
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: tempURL.path) else {
            throw VoiceError.audioGenerationFailed
        }

        let audioData = try Data(contentsOf: tempURL)

        // Cleanup temp file
        try? FileManager.default.removeItem(at: tempURL)

        return audioData
    }

    // MARK: - Voice Models

    private func loadVoiceModels() {
        voiceModels = AVSpeechSynthesisVoice.speechVoices().map { voice in
            VoiceModel(
                id: voice.identifier,
                name: voice.name,
                language: voice.language,
                quality: .system
            )
        }
    }

    func addCustomVoiceModel(referenceAudio: URL, name: String) async throws {
        // Custom voice models require F5-TTS-MLX training
        // This would involve training a model on the reference audio
        // For now, we'll use voice cloning per-request instead

        isProcessing = true
        defer { isProcessing = false }

        // Validate reference audio exists and is valid
        guard FileManager.default.fileExists(atPath: referenceAudio.path) else {
            throw VoiceError.invalidAudio
        }

        // Store voice model metadata
        let customVoice = VoiceModel(
            id: UUID().uuidString,
            name: name,
            language: "en-US",
            quality: .custom
        )

        voiceModels.append(customVoice)

        // Note: Actual model training would happen here with F5-TTS-MLX
        // For production use, implement full F5-TTS training pipeline
        print("Custom voice model '\(name)' registered. Use cloneVoice() for inference.")
    }
}

// MARK: - Models

struct VoiceModel: Identifiable {
    let id: String
    let name: String
    let language: String
    let quality: VoiceQuality
}

enum VoiceQuality {
    case system
    case custom
    case premium
}

enum VoiceError: Error {
    case cloneFailed
    case invalidAudio
    case audioGenerationFailed
    case modelNotFound
}
