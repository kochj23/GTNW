# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Performance improvements
- Additional features based on community feedback

## [1.3.1] - 2026-03-05

### Fixed
- Resolved 331 compile errors caused by an incomplete data model refactor
- Fixed all `Country` property references: `relations` → `diplomaticRelations`, `isPlayer` → `isPlayerControlled`, `hasNuclearWeapons` → `nuclearWarheads > 0`; removed stale `personality` and `memory` references
- Fixed `GameState` missing stats properties: added `warsStarted`, `nukesLaunched`, `presidentsPlayed`, `crisisesCompleted`, `totalWarheadsLaunched`, `victoryType`, and 14 others needed by `AchievementEngine`
- Added `GameState` convenience computed properties: `gameEnded`, `turnNumber`, `recentEvents`, `currentYear`
- Resolved 5 duplicate type definitions causing ambiguous-type errors: `CrisisSeverity` → `DynamicSeverity`, `DynamicCrisis`, `GameEvent` → `LiveNewsEvent`, `NewsEvent` → `LiveNewsEvent`, `ActionCategory` → `AIActionCategory`
- Fixed Xcode compilation batch isolation: removed `ImageGenerationUnified`, `VoiceUnified`, `AnalysisUnified`, `SecurityUnified` dependencies from all `Shared/` files (these compile in a separate batch from app-level files)
- Moved `SentimentResult` and `Sentiment` types to `AppSettings.swift` (Shared layer) so they are available to both compilation batches
- Fixed `DefconLevel` enum vs `Int` comparison errors (added `.rawValue` where needed)
- Fixed `War` struct usage: `War.involves()` → inline expressions, `War.description` → inline string
- Fixed `CyberAttackType` case names and `CyberOperation` API mismatches
- Fixed `CrisisOption` initializer signature (`title:outcome:` → `title:description:consequences:`)
- Fixed type-checker timeout in `DynamicCrisisView` by extracting sub-views

### Security
- No security-sensitive changes in this release

*Released by Jordan Koch*

## [1.0.0] - 2025-01-01

### Added
- Initial release
- Core functionality
- macOS native interface
- MIT License

---

*For detailed release notes, see [GitHub Releases](https://github.com/kochj23/GTNW/releases).*
