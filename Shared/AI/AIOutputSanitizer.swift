//
//  AIOutputSanitizer.swift
//  Global Thermal Nuclear War
//
//  Every line a model returns passes through here before it reaches the game: reasoning blocks are stripped,
//  control characters removed, whitespace collapsed and the length clamped. Empty or junk output becomes nil so the
//  caller keeps its scripted line. Moves are validated separately (`MoveResponse.decode` + `applyMove`, which rejects
//  illegal actions and clamps warheads to the arsenal).
//
//  Created by Jordan Koch on 2026.
//

import Foundation

enum AIOutputSanitizer {
    /// Hard cap on any generated text (characters).
    static let maxCharacters = 4000

    /// PURE: clean model output. Returns nil when nothing usable is left.
    static func clean(_ raw: String, maxCharacters: Int = maxCharacters) -> String? {
        var s = raw
        // Reasoning models wrap their scratchpad in <think>…</think>; drop it (and an unterminated one).
        while let open = s.range(of: "<think>", options: .caseInsensitive) {
            if let close = s.range(of: "</think>", options: .caseInsensitive, range: open.upperBound..<s.endIndex) {
                s.removeSubrange(open.lowerBound..<close.upperBound)
            } else {
                s.removeSubrange(open.lowerBound..<s.endIndex)
            }
        }
        // Remove control characters other than newline/tab (no terminal escapes, no NULs).
        s = String(String.UnicodeScalarView(s.unicodeScalars.filter { scalar in
            scalar == "\n" || scalar == "\t" || !CharacterSet.controlCharacters.contains(scalar)
        }))
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.count > maxCharacters { s = String(s.prefix(maxCharacters)) }
        // A reply that is only punctuation/symbols is junk.
        guard s.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) else { return nil }
        return s
    }
}
