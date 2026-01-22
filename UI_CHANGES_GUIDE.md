# GTNW UI Changes Guide

**Date:** January 22, 2026
**Build:** Latest (just deployed)

---

## What Was Changed

### ✅ REMOVED: AI Performance Card with tokens/sec
- **What:** The "📊 AI PERFORMANCE" card showing tok/sec stats
- **Status:** Completely removed (not commented out)
- **Why:** Was non-functional and taking up space

### ✅ ADDED: AI Backend & Model Selector
- **What:** Inline selectors for AI backend and model (like MLX Code)
- **Location:** Terminal header (top right of terminal panel)
- **Status:** Fully functional

---

## Where to Find the AI Selector

### Location on Screen:

```
┌─────────────────────────────────────────────────────┐
│  💻 TERMINAL & EVENT LOG    [🧠 Ollama ✓] [💻 mistral:latest]  │ ← HERE!
│                                    ↑            ↑                │
│                              Backend Picker  Model Picker       │
├─────────────────────────────────────────────────────────────────┤
│  🟢 LATEST EVENTS (Turn 5)                                     │
│  [T5] 13:45:23 Russia attacks...                              │
└─────────────────────────────────────────────────────────────────┘
```

### How to Use:

**Change AI Backend:**
1. Look at the terminal panel header (says "💻 TERMINAL & EVENT LOG")
2. On the right side, you'll see `[🧠 Ollama ✓]` or `[🧠 MLX]` etc.
3. Click on it
4. Menu opens with: Ollama, MLX, TinyLLM, TinyChat, OpenWebUI, Auto
5. Select your preferred backend
6. Checkmark shows current selection

**Change Ollama Model** (when Ollama selected):
1. Next to the backend selector, you'll see `[💻 mistral:latest]` or your current model
2. Click on it
3. Menu opens with all available Ollama models
4. Select model (llama2, mistral, codellama, etc.)
5. Checkmark shows current model

**Visual Indicators:**
- **Green** = AI backend is online and working
- **Red** = No AI backend available
- Backend name shows in selector
- Model name shows (Ollama only)

---

## ✅ ADDED: Auto-End Turn After Actions

**What Changed:**
- Shadow President actions now automatically end your turn
- 0.5 second delay to show action result
- Then immediately processes AI turns

**Before:**
1. Choose action
2. See result
3. Click "End Turn" button ← Extra step!
4. AI turns process

**After:**
1. Choose action
2. See result
3. Turn auto-advances (no button needed!)
4. AI turns process

---

## ✅ ENHANCED: Terminal/Event Log

**Major Clarity Improvements:**
- **🟢 LATEST EVENTS** banner at top (no more confusion!)
- **[T#]** turn number on every message
- **HH:MM:SS** timestamp on every message
- **Glass cards** around each log entry
- **Color-coded borders** by severity
- **Fixed auto-scroll** to newest events

---

## ✅ ADDED: Diplomatic Messages Inbox

**New Feature:**
- **Location:** Quick Stats grid (left panel)
- **Card:** "Messages" with envelope icon
- **Shows:** Total messages and "(X New)" when unread
- **Click:** Opens full inbox with all diplomatic communications
- **Auto-mark:** Messages marked read when viewed

---

## Troubleshooting

### "I don't see the AI selector"
- Make sure you're looking at the **terminal panel** (not the left command panel)
- It's in the **header area** at the very top of the terminal
- Look for small buttons with brain icon on the RIGHT side of "TERMINAL & EVENT LOG"

### "I still see tokens/sec"
- You may be looking at an old cached window
- **Solution:** Quit GTNW completely (Cmd+Q) and reopen
- The latest build has this removed

### "Auto-end turn isn't working"
- Verify you used a **Shadow President action** (not nuclear strike or declare war quick buttons)
- Those quick buttons still require manual "End Turn"
- Shadow President menu actions auto-advance

---

## Current Build Info

**Version:** v1.1.0 (in progress)
**Build Date:** January 22, 2026
**Location:** `~/Applications/GTNW.app`
**Git Commits:** 7ca8358, 2a0563a, 5c59ae4 (all pushed)

**Confirmed Features:**
✅ AI Performance t/s stats removed
✅ AI Backend selector added to terminal header
✅ Ollama model selector added (when Ollama selected)
✅ Auto-end turn after Shadow President actions
✅ Clear terminal with LATEST indicator
✅ Diplomatic Messages inbox

---

If you're still not seeing these features after quitting and reopening GTNW, let me know and I'll investigate further!
