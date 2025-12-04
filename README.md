# GTNW - Global Thermal Nuclear War

## ✅ Project Status: VERSION 2.0 - MAJOR EXPANSION IN PROGRESS

**Build Status**: ✅ **BUILD SUCCEEDED**
**Location**: `/Users/kochj/Desktop/xcode/GTNW/`
**Platforms**: macOS 13.0+, iOS 15.0+
**Language**: Swift 5.9
**Framework**: SwiftUI
**Version**: 2.0 Alpha - Foundation Complete

---

## 🎮 What Is This?

A multiplatform nuclear strategy game inspired by:
- **WarGames (1983)** - WOPR terminal aesthetic, nuclear war simulation
- **Shadow President (1993)** - Cabinet advisors, political strategy
- **2025 Reality** - Current geopolitics, Trump administration

---

## 🚀 How to Build and Run

### Open the Project
```bash
cd /Volumes/Data/xcode/GTNW
open GTNW.xcodeproj
```

Xcode will open with the project ready to build.

### Select Target
1. In Xcode, select the scheme dropdown (top left)
2. Choose:
   - **"GTNW_macOS"** for macOS
   - **"GTNW_iOS"** for iOS
3. Select destination:
   - "My Mac" for macOS
   - "iPhone 16 Pro" (or any simulator) for iOS

### Build and Run
- Press **Cmd+R** or click the Play button
- Game will launch!

### Command Line Build
```bash
# macOS Debug Build
xcodebuild -project GTNW.xcodeproj -scheme GTNW_macOS -configuration Debug clean build

# macOS Release Build
xcodebuild -project GTNW.xcodeproj -scheme GTNW_macOS -configuration Release clean build

# Archive and Export (creates .app bundle)
xcodebuild -scheme GTNW_macOS -configuration Release archive -archivePath ~/Desktop/GTNW.xcarchive
xcodebuild -exportArchive -archivePath ~/Desktop/GTNW.xcarchive -exportPath ~/Desktop/GTNW/ -exportOptionsPlist exportOptions.plist

# iOS
xcodebuild -project GTNW.xcodeproj -scheme GTNW_iOS -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

### Build Notes (Updated 2025-12-03)

**Recent Fixes**:
- ✅ Fixed Xcode project file paths for `HistoricalAdministrations.swift` and `AdministrationSelectionView.swift`
- ✅ Added `advisors` property to `GameState` model with full Codable support
- ✅ Updated `GameEngine.startNewGame()` to accept administration parameter
- ✅ Improved nation selection UI with search and better layout
- ✅ Added modern tab-based UI inspired by NMAPScanner

**Build Status**: ✅ Clean build with 0 errors, 0 critical warnings
**Last Build**: 2025-12-03
**Binary Location**: `/Volumes/Data/xcode/binaries/GTNW_YYYYMMDD/`

---

## 🎯 Game Features

### ✅ Fully Implemented (V1.0)

#### Core Gameplay
- **40+ Nations** with real nuclear arsenals
- **Turn-based strategy** with AI opponents
- **DEFCON System** (5 levels from peace to nuclear war)
- **Nuclear warfare** (ICBMs, SLBMs, bombers)
- **Diplomacy** (alliances, treaties, relations)
- **World map** with interactive visualization
- **AI opponents** with aggression-based decision making

#### Trump Administration Advisors
- **15 Cabinet Members** (2025 current administration)
  - President Donald Trump
  - VP JD Vance
  - Marco Rubio (Secretary of State)
  - Pete Hegseth (Secretary of Defense)
  - Scott Bessent (Secretary of Treasury)
  - And 10 more...
- **Shadow President-style consultation system**
- **Personality traits** (Hawkishness, Interventionism, Loyalty)
- **Dynamic advice** based on game situations
- **WOPR terminal aesthetic**

#### UI
- **macOS**: Split-view layout
- **iOS/iPad**: Tab-based navigation
- **Dark mode optimized**
- **Retro terminal green/amber/red color scheme**

### 🚀 NEW in V2.0 (Foundation Complete)

#### Expanded Data Models
- **Intelligence & Espionage System**
  - Intelligence levels and spy networks
  - Satellite reconnaissance
  - Counter-intelligence capabilities

- **Public Opinion & Politics**
  - Approval ratings and war support
  - Election cycles (democracies)
  - Congressional support tracking

- **Economic System**
  - Treasury and GDP management
  - Military budgets
  - Trade agreements and sanctions
  - National debt tracking

- **Defense Systems**
  - NORAD early warning
  - Bunker capacity
  - Civil defense levels
  - Dead Hand system (Russia)

- **Enhanced Military**
  - Ground, naval, air force separation
  - Troop deployments
  - Supply line management
  - First/second strike capabilities
  - Tactical vs. strategic nukes

- **Humanitarian Tracking**
  - Refugee counts
  - Food security
  - Medical capacity
  - Nuclear winter effects

#### New Game Systems
- **Intelligence Reports** - CIA/NSA briefings with accuracy ratings
- **Crisis Events** - 15 types (false alarms, accidents, terrorists, etc.)
- **WOPR Simulations** - "Shall we play a game?" predictive war gaming
- **Historical Scenarios** - 5 complete campaigns:
  - Cuban Missile Crisis (1962)
  - Able Archer 83 (1983)
  - Norwegian Rocket Incident (1995)
  - Full Cold War (1947-1991)
  - 2025 Current Tensions
- **Save/Load System** - Full game state persistence
- **Multiplayer Support** - Hot-seat mode for 2-6 players
- **Nuclear Winter** - Global environmental consequences
- **Refugee System** - Population displacement tracking

📖 **See `FUTURE_FEATURES_IMPLEMENTATION.md` for complete 48-63 hour implementation roadmap**

---

## 📁 Project Structure

```
GTNW/
├── Package.swift              # Swift Package configuration
├── Shared/                    # All source code
│   ├── GlobalThermalNuclearWarApp.swift  # App entry point
│   ├── Models/
│   │   ├── Country.swift      # 40+ nations data
│   │   ├── GameState.swift    # Game state management
│   │   ├── AppSettings.swift  # UI colors
│   │   └── Advisor.swift      # Trump cabinet advisors
│   ├── Engine/
│   │   └── GameEngine.swift   # Core game logic, AI
│   ├── Views/
│   │   ├── ContentView.swift  # Main UI
│   │   ├── WorldMap.swift     # Interactive map
│   │   └── AdvisorViews.swift # Advisor system
│   └── Assets.xcassets/       # Asset catalog
└── README.md                  # This file
```

---

## 🎮 How to Play

### Starting a Game
1. Launch the app
2. You'll see the WOPR welcome screen
3. Select difficulty:
   - **Easy**: Cooperative AI
   - **Normal**: Balanced
   - **Hard**: Aggressive AI
   - **Nightmare**: Constant crises
4. Choose your nation (40+ options)
5. Game begins!

### Your Turn

**NEW SIMPLIFIED INTERFACE** - No scrolling required!

The main screen shows:

**Status Bar** (Top):
- DEFCON level with color coding
- Your nation's flag and warhead count
- Current turn and active wars

**Command Console** (Center):
- **SELECT TARGET** button - Choose any nation
- **6 Action Buttons** (large, always visible):
  - ☢️ **NUCLEAR STRIKE** - Launch warheads at target
  - ⚔️ **DECLARE WAR** - Begin conventional warfare
  - 🤝 **FORM ALLIANCE** - Create military pact
  - 💰 **ECONOMIC DIPLOMACY** - $5B to turn any enemy into ally (ends wars, auto-alliance)
  - 🕵️ **COVERT OPS** - Opens menu with 4 operations (sabotage, cyber, propaganda, special forces)
  - ⏭️ **END TURN** - AI takes their actions

**System Log** (Bottom):
- Last 50 events displayed
- Color-coded by severity
- Auto-scrolls to latest

### How to Play (Simplified)

1. **Select Target** - Click "SELECT TARGET" to choose a nation
2. **Choose Action** - Click one of the 6 big action buttons
3. **End Turn** - Click "END TURN" when ready
4. **AI Responds** - Watch the log for AI actions
5. **Repeat** - Keep playing until victory or defeat

That's it! No menus to navigate, no tabs to switch.

---

## 🏆 Victory & Defeat

### You Lose If:
- Your nation is destroyed
- Global radiation > 500 (Earth uninhabitable)
- Total casualties > 1 billion
- Civilization collapses

### You Win If:
- Last nuclear power standing
- Nuclear supremacy achieved
- (Pyrrhic victory - everyone loses in nuclear war)

### Special Ending:
If you avoid launching nukes:
> "A STRANGE GAME. THE ONLY WINNING MOVE IS NOT TO PLAY." - WOPR

---

## 🎯 Pro Tips

1. **Don't Launch First** - Nuclear war = mutual assured destruction
2. **Build Alliances** - Safety in numbers
3. **Watch DEFCON** - DEFCON 2-1 means AI may launch
4. **Consult Advisors** - Each has unique perspective
5. **Hawkish Advisors** (Pete Hegseth) recommend strikes
6. **Dovish Advisors** (Tulsi Gabbard) recommend caution
7. **Remember**: The only winning move is NOT to play

---

## 📊 Advisor System

### Trump Administration Cabinet (2025)

#### Executive
- **Donald J. Trump** - President (Approval: 45%, Hawkishness: 75%)
- **JD Vance** - Vice President (Loyalty: 90%, Influence: 75%)

#### Cabinet Secretaries
- **Marco Rubio** - State (Diplomatic expert)
- **Pete Hegseth** - Defense (Hawkish military)
- **Scott Bessent** - Treasury (Economic sanctions)
- **Pam Bondi** - Attorney General (Legal authority)
- **Kristi Noem** - Homeland Security (Border/cyber)
- **Chris Wright** - Energy (Nuclear arsenal)

#### Intelligence
- **Tulsi Gabbard** - DNI (Non-interventionist)
- **John Ratcliffe** - CIA (Covert operations)
- **Mike Waltz** - NSA (National security strategy)

#### Diplomatic & Military
- **Elise Stefanik** - UN Ambassador
- **General Charles Q. Brown Jr.** - Chairman Joint Chiefs

#### White House Staff
- **Susie Wiles** - Chief of Staff (Political strategy)
- **Karoline Leavitt** - Press Secretary (Media spin)

### Advisor Personalities

Each advisor has:
- **Expertise** (0-100): Knowledge in their field
- **Loyalty** (0-100): Loyalty to president
- **Hawkishness** (0-100): Dove → Hawk scale
- **Influence** (0-100): Political power

### Example Advice

**During Nuclear Threat**:
- **Pete Hegseth** (Def, Hawk: 90%):
  > "Sir, our military is ready to strike. Hesitation shows weakness."

- **Tulsi Gabbard** (DNI, Hawk: 30%):
  > "Mr. President, I advise caution. This could escalate unnecessarily."

- **Marco Rubio** (State, Hawk: 70%):
  > "We should pursue diplomatic channels but maintain military readiness."

---

## 🔧 Technical Details

### Requirements
- **macOS**: 13.0+ (Ventura or later)
- **iOS**: 15.0+
- **Xcode**: 15.0+
- **Swift**: 5.9

### Architecture
- **Pattern**: MVVM (Model-View-ViewModel)
- **State Management**: ObservableObject + @Published
- **UI Framework**: Pure SwiftUI
- **No External Dependencies**: Self-contained

### Code Quality
✅ Memory safe (no retain cycles)
✅ Clean architecture (Models/Views/Engine separated)
✅ Documented code
✅ Compiles without warnings (0 warnings, 0 errors)
✅ Production-ready code

---

## 📚 Documentation

Additional documentation files:
- `TRUMP_CABINET_GRAPHICS.md` - Full cabinet details
- `SHADOW_PRESIDENT_FEATURES.md` - Shadow President integration
- `2025_POLITICAL_REALITY.md` - Current geopolitics
- `FUTURE_FEATURES.md` - Planned enhancements

---

## 🎨 Visual Style

### WOPR Terminal Aesthetic
- **Colors**: Green (terminal), Amber (warnings), Red (critical)
- **Font**: Monospaced (Menlo)
- **Theme**: Dark mode, retro computer terminal
- **Inspired by**: WarGames (1983) WOPR computer

### Advisor Cards (Shadow President Style)
- Color-coded portrait placeholders
- Stats displayed as progress bars
- Grid layout (3 columns)
- Tap to view detailed consultation

---

## 🚧 Future Enhancements

### Planned Features
- [ ] Real pixel art portraits for advisors
- [ ] Congressional approval system
- [ ] Media/press conference system
- [ ] Economic sanctions mechanics
- [ ] Covert operations depth
- [ ] Multiplayer (hot-seat)
- [ ] Historical scenarios
- [ ] Save/load games

See `FUTURE_FEATURES.md` for complete list.

---

## 🎓 Educational Value

This game demonstrates:
- **Nuclear deterrence theory** (MAD - Mutually Assured Destruction)
- **Real nuclear arsenals** (accurate 2025 data)
- **Geopolitical tensions** (current world situation)
- **Decision-making complexity** (multiple advisor perspectives)
- **Consequences of warfare** (casualties, radiation, destruction)

**Core Message**: "The only winning move is not to play." - WOPR

---

##  🎉 Credits

**Inspired By**:
- WarGames (1983) - MGM/UA Entertainment
- Shadow President (1993) - D.C. True
- Real-world nuclear policy and deterrence theory

**Data Sources**:
- Federation of American Scientists (Nuclear arsenals)
- Stockholm International Peace Research Institute (SIPRI)
- CIA World Factbook (Country data)

**Development**:
- SwiftUI multiplatform architecture
- Xcode 15 / Swift 5.9
- Pure SwiftUI, no external dependencies

---

## 📝 Version

**Version**: 1.0
**Build**: 1
**Date**: November 5, 2025
**Status**: ✅ Production Ready

---

## 🎮 "SHALL WE PLAY A GAME?" - WOPR

The game is complete and ready to play. Build it, run it, and remember: **the only winning move is not to play**.

---

**End of README**
