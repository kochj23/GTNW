# How to Use Diplomatic Messages in GTNW

## Step-by-Step Guide

### 1. How to Access Diplomatic Messages

**Location:** Left panel → STATUS section → **Messages card**

```
📊 STATUS
┌──────────┬──────────┐
│ Nuclear  │  Wars    │
│    20    │    2     │
├──────────┼──────────┤
│ Treaties │ Messages │  ← CLICK HERE!
│    5     │    3●    │  ← Red dot = unread messages
└──────────┴──────────┘
```

**When to look:**
- Red dot appears when you have unread messages
- Terminal log shows: "📨 New Diplomatic Messages: 3"
- Number on card = total messages
- Red dot = new/unread count

---

### 2. Reading Messages

**When you click Messages card, you'll see:**

```
┌─────────────────────────────────────────────┐
│ 📧 DIPLOMATIC MESSAGES        (3 unread)   │
│                                       [X]    │
├─────────────────────────────────────────────┤
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 🇷🇺  From: Russia          Relations: -20│ │
│ │      Turn 5                              │ │
│ │                                          │ │
│ │ "We demand you cease military buildup   │ │
│ │  immediately."                           │ │
│ │                                          │ │
│ │ [✓ Comply with Demand] [✗ Decline]      │ │  ← ACTION BUTTONS HERE!
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 🇨🇳  From: China           Relations: 30 │ │
│ │      Turn 4                              │ │
│ │                                          │ │
│ │ "We request $5B economic aid to         │ │
│ │  stabilize our economy."                 │ │
│ │                                          │ │
│ │ [✓ Accept & Send Aid] [✗ Decline]       │ │  ← DIFFERENT TEXT!
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

### 3. Action Buttons Explained

**Each message has 2 buttons at the bottom:**

#### Green Accept Button (Context-Sensitive):
The button text changes based on message content:

| Message Type | Button Text | What Happens |
|-------------|-------------|--------------|
| Request for aid | "Accept & Send Aid ($5B)" | Sends $5B, +30 relations |
| Proposal (pact/treaty) | "Accept Proposal" | Forms alliance |
| Demand (cease/stop) | "Comply with Demand" | +20 relations (shows compliance) |
| Statement (general) | "Acknowledge" | +10 relations |

#### Red Decline Button:
- Text: "Decline"
- Effect: Worsens relations (-20 for demands, -10 for others)
- Result: Message dismissed, no other action

---

### 4. What Happens After You Click

**Immediately:**
1. Action executes (relations change, alliance formed, etc.)
2. Terminal log shows result:
   - "✓ Sent $5B aid to China. Relations improved (+30)."
   - "✗ Declined message from Russia. Relations -20."
3. Message inbox closes
4. Turn auto-advances (0.5 second delay)
5. AI countries take their turns
6. You see results in next turn

---

### 5. Example Scenario

**Message from China:**
> "We request $5B economic aid to stabilize our economy."

**Your Options:**

**Option 1: Accept**
- Click: `[✓ Accept & Send Aid ($5B)]`
- Result:
  - China relations: +30
  - Your relations with China: +30
  - Potential future ally
  - Terminal: "✓ Sent $5B aid to China. Relations improved (+30)."
  - Turn auto-advances

**Option 2: Decline**
- Click: `[✗ Decline]`
- Result:
  - China relations: -10
  - China may become hostile
  - Terminal: "✗ Declined message from China. Relations -10."
  - Turn auto-advances

---

### 6. Strategic Considerations

**When to Accept:**
- Building alliances
- Need regional support
- Country has resources you want
- Prevent them joining enemy coalitions

**When to Decline:**
- Can't afford economic cost
- Country is enemy or hostile
- Playing isolationist strategy
- Want to provoke conflict

---

### 7. Troubleshooting

**"I don't see any messages"**
- AI countries send messages randomly (10% chance per turn)
- Play 5-10 turns to receive messages
- Check terminal for: "📨 New Diplomatic Messages: #"

**"Messages card shows 0"**
- No messages received yet
- Keep playing, they'll come
- More messages at higher DEFCON levels

**"I clicked Messages but nothing opened"**
- Make sure you're clicking the Messages **stat card** (not a button)
- It's in the STATUS section with envelope icon
- Should open a modal window

**"Actions buttons not showing"**
- You may be running old build
- Quit GTNW completely (Cmd+Q)
- Reopen - fresh build should load
- Action buttons appear at BOTTOM of each message card

---

### Current Build Info

**Version:** Latest (just deployed)
**Build Time:** Just now (completely clean rebuild)
**Location:** ~/Applications/GTNW.app

**What's New:**
- Streamlined UI (2 critical actions only)
- Dashboard glass cards
- Green dot LLM indicators
- Functional Accept/Decline on messages

---

**To test diplomatic messages RIGHT NOW:**
1. Start/continue a game
2. Play 5-10 turns (messages will arrive)
3. Terminal shows: "📨 New Diplomatic Messages: 1"
4. Click **Messages** card (envelope icon, bottom-left of STATUS section)
5. Inbox opens showing messages
6. Scroll to see **Accept/Decline buttons** at bottom of each message
7. Click your choice
8. See result in terminal, turn auto-advances

---

The action buttons ARE there - they're at the bottom of each message card. Make sure you're running the fresh build I just deployed!
