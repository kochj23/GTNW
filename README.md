# GTNW - Global Thermal Nuclear War

> **Comprehensive historical nuclear strategy game with AI-powered opponents and 139 real historical crises from 1945-2025**

![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B%20%7C%20iOS%2015.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-1.1.0-brightgreen)

---

## 🎮 Overview

**GTNW** is a comprehensive turn-based nuclear strategy game inspired by the 1983 film "WarGames." Play as any of 14 U.S. Presidents from Truman (1945) through Biden (2024), experience real historical crises, and manage nuclear diplomacy with AI-powered opponents featuring unique personalities and memory systems.

### Core Philosophy

- **Historical Accuracy** - 139 real crises, era-appropriate nuclear arsenals, authentic presidential cabinets
- **Engaging AI** - Opponents with personalities, memory, and emotional states
- **Strategic Depth** - Diplomacy, covert operations, economic warfare, nuclear deterrence
- **Educational Value** - Learn Cold War history through gameplay

---

## 🚀 Key Features

### Historical Authenticity

**14 Presidential Administrations (1945-2025):**
- Truman, Eisenhower, Kennedy, Johnson, Nixon, Ford, Carter
- Reagan, Bush Sr., Clinton, Bush Jr., Obama, Trump (1st & 2nd), Biden
- Each with full historically accurate cabinet members
- 8 key advisors per administration with real personality traits

**139 Historical Crises:**
- **Truman Era (12):** Hiroshima decision, Berlin Blockade, Korean War, MacArthur firing
- **Eisenhower Era (11):** Stalin's death, Suez Crisis, Sputnik, U-2 incident, Castro
- **Kennedy Era (15):** Bay of Pigs, Cuban Missile Crisis, Berlin Wall, Civil Rights
- **Johnson-Biden (101):** Gulf of Tonkin, Watergate, Iran hostages, 9/11, COVID-19, Ukraine
- Real decisions faced by presidents with historical outcomes

**Era-Based Nuclear Club:**
- 1945: USA only
- 1949: +USSR
- 1952: +UK
- 1960: +France
- 1964: +China
- 1974: +India
- 1998: +Pakistan
- 2006: +North Korea
- Arsenal sizes historically accurate for each era

**95 Countries Database:**
- All major powers with real GDP, military, population data
- Regional representatives
- Historical countries (USSR, Yugoslavia, East/West Germany)
- Era-appropriate country lists

---

### AI-Powered Opponents (6 Engines)

**1. AI Personality Engine**
- 8 unique personalities: Opportunistic (Russia), Patient (China), Unpredictable (North Korea), etc.
- Memory system tracks your betrayals, alliances, attacks
- Emotional states: Calm, Angry, Fearful, Emboldened, Desperate, Paranoid
- Grudges and favors with decay over time
- Trust levels (-100 to +100) based on your actions

**2. Narrative Engine**
- Dynamic AI-generated news headlines with story continuity
- In-character advisor dialogue based on personality
- Consequence narratives beyond numbers
- Victory/defeat epilogues referencing your decisions
- Story arcs tracked across turns

**3. AI War Room**
- Strategic threat analysis with reasoning
- Opportunity identification (weaknesses to exploit)
- Actionable recommendations
- Victory path assessment
- Time-sensitive intelligence ("Act within 3 turns")

**4. What-If Simulator**
- Predict consequences before taking actions
- Best case / Worst case / Most likely outcomes
- War probability estimates
- Retaliation likelihood
- Economic impact forecasts

**5. AI Opponent Profiler**
- Strategic goal assessment for each country
- Weakness identification (military, economic, diplomatic)
- Next move prediction with probability
- Personality-based behavior analysis
- Recommended approach for dealing with each nation

**6. Crisis Event System**
- 139 historical scenarios with AI-generated unique descriptions
- Dynamic crisis options reflecting current advisors
- Cascading crisis chains
- Multi-turn crisis resolution

---

### Enhanced UI (TopGUI-Inspired)

**Streamlined Command Center:**
- Large Shadow President button (132 actions)
- 2 critical action buttons (Nuclear Strike, Declare War)
- Category quick buttons (Diplomatic, Military, Covert, Economic)
- Dashboard glass cards for stats

**Crystal Clear Terminal:**
- 🟢 LATEST EVENTS banner (never confusing which end is current)
- [T#] turn indicator on every message
- HH:MM:SS timestamps
- Glass card styling per log entry
- Color-coded borders by severity

**AI Backend Integration:**
- Green dot availability indicators (like TopGUI)
- Backend selector in terminal header
- Model picker for Ollama
- 5 backend support: Ollama, MLX, TinyLLM, TinyChat, OpenWebUI
- Real-time switching

**Diplomatic Messages:**
- Interactive inbox with Accept/Decline buttons
- Context-sensitive actions (Send Aid, Form Alliance, Comply)
- Messages delete after response
- Relations impact gameplay
- Process all messages in one turn

**Nuclear Warfare Enhanced:**
- Choose warhead count: 1 / 5 / 10 / 25 / 50
- Alert dialog with consequences warning
- "X available" warhead display
- Massive/Devastating strike options

**Game Management:**
- Leaderboard shows past games with scores
- Victory conditions enforced (can't continue after game over)
- 7 victory paths (Peace Maker, Master Diplomat, Nuclear Supremacy, etc.)
- Score tracking and high scores

---

### Core Gameplay Systems

**Shadow President Actions (132):**
- 15 Diplomatic actions (embassies, summits, state visits)
- 20 Military actions (deployments, strikes, exercises)
- 18 Economic actions (aid, loans, sanctions, trade deals)
- 25 Covert operations (assassination, coups, sabotage, cyber)
- 12 Intelligence operations (spies, reconnaissance, counter-intel)
- 15 Nuclear options (strikes, tests, sharing, policies)
- 15 Treaties (non-aggression, mutual defense, arms control)
- 12 Propaganda (media campaigns, broadcasts, disinformation)

**Game Systems:**
- Nuclear Arsenal: Warheads, ICBMs, SLBMs, Bombers
- Diplomacy: Relations, treaties, alliances
- Intelligence: Spy networks, surveillance
- Economics: GDP, treasury, trade agreements
- Military: Strength ratings, cyber offense/defense
- Environmental: Nuclear winter, radiation, casualties
- Crisis Management: 139 historical scenarios
- News Generation: Dynamic headlines from AI

**Victory Conditions:**
1. Peace Maker (1500 pts) - No wars, no nukes, 20+ turns
2. WOPR's Choice (2000 pts) - Secret ending, 50+ turns
3. Master Diplomat (1200 pts) - 80%+ allies
4. Economic Tycoon (1000 pts) - GDP dominance
5. Nuclear Supremacy (800 pts) - Only nuclear power remaining
6. Sole Survivor (600 pts) - Survived nuclear winter
7. Pyrrhic Victory (200 pts) - Won but massive casualties

---

## 📦 Installation

### Prerequisites

- **macOS 13.0+** (Ventura or later)
- **Apple Silicon recommended** (M1/M2/M3/M4)
- **16GB RAM** recommended
- **Ollama** (optional, for AI features)

### Quick Start

1. **Build from source:**
   ```bash
   cd "/Volumes/Data/xcode/GTNW"
   xcodebuild -scheme "GTNW_macOS" -configuration Release build
   ```

2. **Install:**
   ```bash
   cp -R build/Release/GTNW.app ~/Applications/
   open ~/Applications/GTNW.app
   ```

3. **Optional - Install Ollama for AI:**
   ```bash
   brew install ollama
   ollama serve
   ollama pull mistral
   ```

---

## 🎯 How to Play

### Starting a Game

1. **Launch GTNW**
2. **Select President** - Choose from 14 administrations
3. **Select Country** - Play as USA (default)
4. **Choose Difficulty** - Easy / Normal / Hard / Nightmare
5. **Start Game**

### Your Turn

**1. Select Target Nation** - Click country picker (green button)

**2. Choose Action:**
- **Shadow President** - 132 diplomatic/military/covert actions
- **Nuclear Strike** - Choose 1-50 warheads
- **Declare War** - Conventional conflict
- **Quick Categories** - Diplomatic, Military, Covert, Economic buttons

**3. Actions Auto-End Turn** - Turn advances automatically

**4. AI Countries Take Turns** - Watch terminal for their actions

**5. Manage Crises** - Historical scenarios appear every 3-5 turns

**6. Read Diplomatic Messages:**
- Click Messages card in STATUS section
- Accept or Decline each message
- Relations change based on your responses
- Messages delete after handling

### Win Conditions

**Achieve any of 7 victory paths:**
- Peace without war
- Global alliances
- Economic dominance
- Nuclear superiority
- Survival through nuclear winter
- Secret WOPR ending
- Pyrrhic victory

---

## 🎨 UI Guide

### Main Interface (Tabbed)

**Command Tab:**
- Left Panel: Command center with action buttons
- Right Panel: Terminal with event log
- Clear "LATEST EVENTS" indicator
- Timestamps and turn numbers on all messages

**World Map Tab:**
- Interactive world map
- Country selection
- Nuclear power indicators
- War visualization

**Systems Tab:**
- Game systems overview
- Intelligence operations
- Cyber warfare
- Weapons programs

**Advisors Tab:**
- Cabinet member grid
- Tap for full advisor profile
- Personality traits, expertise, loyalty
- Current advice

**Intelligence Tab:**
- Crisis events when active
- Intelligence reports
- Covert operations status

### Quick Stats (Glass Cards)

**5 Stat Cards:**
- **Nuclear Powers** - Count of nuclear-armed nations
- **Active Wars** - Current conflicts
- **Treaties** - Signed agreements
- **Radiation** - Global radiation level
- **Messages** - Diplomatic communications (with unread badge)

### Status Indicators

**DEFCON Level:**
- DEFCON 5 (Green) - Peace
- DEFCON 4 (Yellow) - Increased alert
- DEFCON 3 (Orange) - Force readiness
- DEFCON 2 (Red) - Next step is nuclear war
- DEFCON 1 (Red Flashing) - Nuclear war imminent

**Terminal Log:**
- [T#] = Turn number
- HH:MM:SS = Timestamp
- Color-coded by severity
- Glass card per message

---

## 🤖 AI Backend Configuration

### Supported Backends (5)

**Ollama** (Recommended)
```bash
brew install ollama
ollama serve
ollama pull mistral
ollama pull llama2
```

**TinyLLM by Jason Cox**
```bash
git clone https://github.com/jasonacox/TinyLLM
cd TinyLLM
docker-compose up -d
```

**MLX Toolkit**
```bash
pip install mlx-lm
```

**TinyChat**
- Same setup as TinyLLM
- Chat-focused interface

**OpenWebUI**
```bash
docker run -d -p 8080:8080 ghcr.io/open-webui/open-webui:main
```

### Changing AI Backend

**In-Game:**
- Terminal header → Click AI backend indicator
- Green dot = Available, Gray = Offline
- Select from dropdown
- Model picker appears for Ollama

**Settings Menu:**
- Menu Bar → GTNW → Settings (⌘,)
- Full backend configuration
- Model selection
- Server URLs
- Status indicators

---

## 🎓 Advanced Features

### Historical Scenarios

**Play Actual Historical Events:**
- **1945:** Hiroshima/Nagasaki decision
- **1962:** Cuban Missile Crisis
- **1973:** Yom Kippur War & DEFCON 3
- **1979:** Iran Hostage Crisis
- **2001:** 9/11 response
- **2020:** COVID-19 pandemic decisions
- **2022:** Ukraine invasion response

**Each crisis has:**
- Real historical context
- Multiple decision options
- Consequences based on actual outcomes
- Advisor recommendations

### Shadow President System

**132 Actions Organized by Category:**

**Diplomatic (15):** Ambassadors, summits, mediation, recognition
**Military (20):** Deployments, bases, blockades, strikes, invasions
**Economic (18):** Aid, loans, sanctions, trade deals, tariffs
**Covert (25):** Assassination, coups, sabotage, cyber attacks, blackmail
**Intelligence (12):** Spies, reconnaissance, counter-intelligence
**Nuclear (15):** Strikes, tests, sharing, policies, inspections
**Treaties (15):** Non-aggression, defense pacts, arms control
**Propaganda (12):** Media campaigns, broadcasts, disinformation

### AI Opponent Behavior

**Decision Making:**
- **With AI Backend:** Real LLM decisions based on personality and memory
- **Without AI:** Enhanced fallback using personality-modulated aggression

**Personality Types:**
- **Opportunistic** (Russia) - Exploits weakness
- **Patient** (China) - Long-term planning
- **Unpredictable** (North Korea) - Erratic behavior
- **Diplomatic** (France) - Mediator
- **Hawkish** (Israel) - Preemptive strikes
- **Isolationist** (Switzerland) - Defensive only
- **Vengeful** (Iran) - Holds grudges
- **Calculating** (UK) - Pragmatic

**Memory System:**
- Remembers your betrayals ("Broke alliance Turn 12")
- Tracks trust levels (-100 to +100)
- Maintains grievances with severity scores
- Favors and debts recorded
- Influences future AI decisions

---

## 🎯 What's New in v1.1.0

### Enhanced UI (January 2026)

**Terminal Clarity:**
- ✅ LATEST EVENTS banner with green dot
- ✅ Turn numbers [T#] on every message
- ✅ Timestamps (HH:MM:SS) on all events
- ✅ Glass card styling per log entry
- ✅ Fixed auto-scroll to newest events
- ✅ Color-coded severity borders

**Streamlined Actions:**
- ✅ Reduced from 6 to 2 critical action buttons
- ✅ Large Shadow President primary button
- ✅ Dashboard glass cards (TopGUI-inspired)
- ✅ Category quick access buttons

**AI Integration:**
- ✅ Backend selector with green dot indicators
- ✅ Model picker in terminal header
- ✅ Settings menu (⌘,) for full configuration
- ✅ Real-time backend switching

### Diplomatic System (January 2026)

**Interactive Diplomacy:**
- ✅ Messages inbox with country flags
- ✅ Accept/Decline buttons on each message
- ✅ Context-sensitive actions (Send Aid, Form Alliance, Comply)
- ✅ Relations changes affect gameplay
- ✅ Messages delete after response
- ✅ Process all messages in one turn

**Message Types:**
- Requests (aid/help) → Accept & Send Aid
- Proposals (pacts/treaties) → Form Alliance
- Demands (cease/stop) → Comply or Decline
- Statements → Acknowledge

### Nuclear Warfare (January 2026)

**Enhanced Strike Options:**
- ✅ Choose warhead count: 1 / 5 / 10 / 25 / 50
- ✅ Alert dialog with consequences warning
- ✅ Massive/Devastating strike descriptions
- ✅ "X available" warhead counter
- ✅ Retaliation warnings

### Historical Expansion (January 2026)

**Complete Historical Coverage:**
- ✅ 139 crises across all 14 presidents
- ✅ Nuclear club progression (1945 → 2006)
- ✅ 95 countries with real data
- ✅ Era-appropriate gameplay (Truman game = USA has only nukes)
- ✅ Historical countries (USSR, Yugoslavia, etc.)

### AI Enhancements (January 2026)

**6 AI Engines Created:**
1. **Personality Engine** - Unique opponent behaviors
2. **Narrative Engine** - Dynamic storytelling
3. **War Room** - Strategic intelligence
4. **What-If Simulator** - Consequence prediction
5. **Opponent Profiler** - Enemy analysis
6. **Crisis Generator** - AI-enhanced scenarios

**Status:** Engines implemented, integration in progress

### Game Flow (January 2026)

**Improved Experience:**
- ✅ Actions auto-end turn (no manual clicking)
- ✅ Leaderboard functional (view past games)
- ✅ Can't continue after game over (proper flow)
- ✅ Clear victory/defeat screens

---

## 🛠️ Technical Details

### Architecture

**Technology Stack:**
- Language: Swift 5.9+
- Framework: SwiftUI
- Pattern: MVVM with Combine
- AI: AIBackendManager (5 backend support)
- Platforms: macOS 13.0+, iOS 15.0+

**Core Components:**
- GameEngine.swift (1775 lines) - Game loop, AI processing
- Country.swift - 150+ attributes per nation
- CrisisEvents.swift (1283 lines) - Crisis system
- HistoricalCrises.swift (1075 lines) - 139 scenarios
- NuclearClubProgression.swift (164 lines) - Nuclear timeline
- WorldCountriesDatabase.swift (318 lines) - 95 countries
- AIPersonalityEngine.swift (270 lines) - AI behaviors
- NarrativeEngine.swift (265 lines) - Storytelling

**UI Components:**
- UnifiedCommandCenter.swift (1500+ lines) - Main interface
- DiplomaticMessagesView.swift - Message inbox
- WarRoomView.swift - Strategic analysis (ready)
- ShadowPresidentMenu.swift - 132 actions

---

## 🎮 Gameplay Tips

### Strategy Fundamentals

**1. Manage DEFCON Levels**
- Lower DEFCON = Higher crisis probability
- DEFCON 1 = 50% crisis chance per turn
- Balance aggression with stability

**2. Use Diplomacy First**
- Alliances provide security
- Treaties reduce tensions
- Relations affect AI behavior
- Diplomatic messages are strategic opportunities

**3. Economic Power Matters**
- High GDP enables more options
- Economic aid builds alliances
- Sanctions weaken enemies
- Trade deals provide income

**4. Intelligence is Key**
- Spy networks reveal enemy plans
- Counter-intelligence protects you
- Cyber warfare disrupts opponents
- Know before you act

**5. Nuclear Deterrence**
- Large arsenal deters attacks
- SDI provides defense
- First strike capability is tempting but risky
- Second strike capability ensures survival

### Advanced Tactics

**Coalition Building:**
- Form alliances early
- Isolate rivals
- Balance of power prevents dominance

**Crisis Management:**
- Read historical context carefully
- Consult advisors (personality matters)
- Long-term consequences matter
- Some crises are unwinnable

**AI Opponent Strategy:**
- Learn each country's personality
- They remember your actions
- Betrayal damages trust permanently
- Consistent behavior builds reputation

---

## 📊 System Requirements

### Minimum
- macOS 13.0 (Ventura)
- 8GB RAM
- Apple Silicon M1
- 5GB free disk space

### Recommended
- macOS 13.0+
- 16GB RAM
- M2 Pro/Max or M3
- Ollama installed for AI

### Optimal
- macOS 14.0+
- 32GB RAM
- M3 Max/Ultra
- Multiple AI backends

---

## 🐛 Troubleshooting

### "AI opponents not interesting"
- Install Ollama: `brew install ollama`
- Pull model: `ollama pull mistral`
- Settings (⌘,) → Select Ollama backend
- AI personality engine activates

### "Only 4 sample emails in diplomatic messages"
- Diplomatic system is separate from email (different feature)
- Messages generate randomly (10% chance per AI country per turn)
- Play 5-10 turns to receive messages

### "Can't launch nuclear strike"
- Select target country first (green picker button)
- Ensure you have warheads (check player status card)
- Button grays out if no warheads or target

### "Terminal confusing"
- Look for 🟢 LATEST EVENTS banner at top
- Newest events always at top
- [T#] shows turn number
- Timestamps on every message

---

## 🤝 Credits

### Third-Party Software

**TinyLLM** by Jason Cox
- Project: https://github.com/jasonacox/TinyLLM
- Used for AI backend option
- MIT License

**TinyChat** by Jason Cox
- Project: https://github.com/jasonacox/tinychat
- Alternative AI backend
- MIT License

**Ollama**
- Project: https://ollama.com
- Primary AI backend recommendation
- MIT License

**OpenWebUI**
- Project: https://github.com/open-webui/open-webui
- Self-hosted AI platform option
- MIT License

### Inspiration

- **WarGames (1983)** - WOPR terminal aesthetic
- **Shadow President (1993)** - Cabinet advisor system
- **TopGUI** - Glass card UI design
- **Historical Sources** - Presidential libraries, declassified documents

---

## 📝 License

MIT License

---

## 👤 Author

**Jordan Koch**
- GitHub: [@kochj23](https://github.com/kochj23)

### Related Projects

- [URL-Analysis](https://github.com/kochj23/URL-Analysis) - AI web performance tool
- [Mail Summary](https://github.com/kochj23/MailSummary) - AI email assistant
- [MLX Code](https://github.com/kochj23/MLXCode) - AI development assistant
- [TopGUI](https://github.com/kochj23/TopGUI) - System monitor

---

## 📈 Version History

### v1.1.0 - Major Enhancements (January 22, 2026)

**AI Features:**
- ✅ 6 AI enhancement engines (personality, narrative, war room, simulator, profiler)
- ✅ AI backend selector with green dot indicators
- ✅ 5 backend support (Ollama, MLX, TinyLLM, TinyChat, OpenWebUI)

**Historical Content:**
- ✅ 139 historical crises (Truman 1945 → Biden 2024)
- ✅ Nuclear club progression (historically accurate)
- ✅ 95 countries database with real data
- ✅ Era-appropriate gameplay

**UI Improvements:**
- ✅ Terminal clarity (LATEST banner, timestamps, turn numbers)
- ✅ Streamlined actions (2 critical buttons)
- ✅ Dashboard glass cards (TopGUI-inspired)
- ✅ Diplomatic messages with Accept/Decline
- ✅ Nuclear warhead selector (1-50)
- ✅ Leaderboard functional
- ✅ Game over control

### v1.0 - Initial Release (December 2025)

**Core Features:**
- Turn-based nuclear strategy
- 40+ nations
- Trump administration advisors
- Basic AI opponents
- DEFCON system
- Nuclear warfare
- Diplomacy and treaties

---

## 🚀 Future Roadmap

### Planned Enhancements

**AI Integration (In Progress):**
- Wire personality engine to game (engines created, need integration)
- Activate narrative engine for dynamic news
- Enable War Room for strategic analysis
- Deploy What-If simulator for action prediction

**Content Expansion:**
- Complete 100 remaining countries (framework exists)
- Additional historical scenarios
- More presidential eras

**Multiplayer:**
- Network play (planned)
- Hot-seat multiplayer
- AI vs AI spectator mode

**Polish:**
- Sound effects
- Enhanced animations
- Mobile UI improvements (iOS)

---

## 📞 Support

**Issues:** Open issue on GitHub
**Documentation:** See `Documentation/` folder
**Guides:** Check `.md` files in project root

---

**GTNW - Experience nuclear strategy through the lens of history. Play as 14 presidents, face 139 real crises, and navigate the most dangerous decisions in human history.**

**Last Updated:** January 22, 2026
**Version:** 1.1.0
**Status:** ✅ Production Ready
