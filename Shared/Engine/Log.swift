//
//  Log.swift
//  Global Thermal Nuclear War
//
//  3.33.0: unified logging. One `os.Logger` per subsystem area instead of `print`, so messages carry a level and a
//  category and can be filtered in Console (subsystem = the bundle id, e.g. `log stream --predicate
//  'subsystem == "com.wopr.gtnw.macos" AND category == "engine"'`). Only real command-line output
//  (`--migrate-store`, `--launch-smoke`) still prints.
//

import Foundation
import os

enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.wopr.gtnw"

    /// The turn loop, the computer's moves, saving.
    static let engine = Logger(subsystem: subsystem, category: "engine")
    /// Model-backed features (adaptive opponent, war room, narrative, what-if).
    static let ai = Logger(subsystem: subsystem, category: "ai")
    /// The Games DB and local saves.
    static let store = Logger(subsystem: subsystem, category: "store")
    /// The loopback Nova API server.
    static let api = Logger(subsystem: subsystem, category: "api")
    /// Typed and natural-language commands.
    static let commands = Logger(subsystem: subsystem, category: "commands")
    /// Diplomacy and the Living Room.
    static let diplomacy = Logger(subsystem: subsystem, category: "diplomacy")
    /// Intelligence queries.
    static let intel = Logger(subsystem: subsystem, category: "intel")
    /// Voices and sound.
    static let audio = Logger(subsystem: subsystem, category: "audio")
    /// The home-screen widget's shared data.
    static let widget = Logger(subsystem: subsystem, category: "widget")
    /// `Retry.run` attempts.
    static let retry = Logger(subsystem: subsystem, category: "retry")

    static let categories = ["engine", "ai", "store", "api", "commands", "diplomacy", "intel", "audio", "widget", "retry"]
}

extension Logger {
    /// Verbose tracing (debug level: kept in memory, not persisted unless asked for).
    func trace(_ message: String) { debug("\(message, privacy: .public)") }
    /// Something worth keeping (info level). Game messages carry no secrets.
    func note(_ message: String) { info("\(message, privacy: .public)") }
    /// A failure (error level). Its text may name a host or a path, so it is private outside a debugger.
    func failure(_ message: String) { error("\(message, privacy: .private)") }
}
