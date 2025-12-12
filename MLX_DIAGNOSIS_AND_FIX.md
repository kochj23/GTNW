# MLX Functionality Diagnosis & Fix Plan

**Date:** December 12, 2025
**Version:** 2.1.0
**Issue:** Game is too easy, AI does nothing, player can win by spamming END TURN

---

## 🔍 ROOT CAUSE ANALYSIS

### **Problem 1: Python Script Returns 90% WAIT Actions**

**Location**: `EnhancedMLXService.swift` lines 355-395

**Current Logic**:
```python
if 'war' in prompt.lower():
    responses = [
        "ACTION: WAIT | REASON: Consolidating forces",
        "ACTION: WAIT | REASON: Assessing enemy strength",
        "ACTION: BUILD_MILITARY | REASON: Need reinforcements"
    ]
```

**Issue**: 2 out of 3 responses are WAIT. AI almost never takes action.

---

### **Problem 2: BUILD Actions Map to WAIT**

**Location**: `GameEngine.swift` lines 227-230

```swift
case .buildMilitary:
    return .wait // Will be handled separately ← NEVER HANDLED!
case .buildNukes:
    return .wait // Will be handled separately ← NEVER HANDLED!
```

**Issue**: Even when AI says "BUILD_MILITARY", it gets converted to .wait and nothing happens.

---

### **Problem 3: No Aggressive Actions Generated**

**Python script NEVER returns**:
- `ACTION: ATTACK USA` (or any country)
- `ACTION: NUKE USA 5`
- `ACTION: ALLY Russia`
- `ACTION: COVERT USA`

**Result**: AI countries just sit passively while player dominates.

---

### **Problem 4: EnhancedMLXService Not Actually Used**

**Checking if it's even being called**:
```swift
// GameEngine line 140:
let mlxDecision = await EnhancedMLXService.shared.generateCountryDecision(...)
```

This IS being called, but responses are neutered.

---

## 📊 TEST RESULTS

Manually tested Python script:
```bash
$ python3 test_script.py '{"category":"country_decision_RUS","prompt":"..."}'
> ACTION: WAIT | REASON: High alert status requires defensive posture
```

**Every test returns WAIT or BUILD (which maps to WAIT).**

---

## 💡 RECOMMENDED FIXES

### **Fix 1: Make Python Script More Aggressive** ⭐ CRITICAL

Replace passive responses with actual actions:

```python
if 'country_decision' in category:
    # Extract country info from prompt
    aggression = 5  # Default
    if 'Aggression: 8' in prompt or 'Aggression: 9' in prompt or 'Aggression: 10' in prompt:
        aggression = 9
    elif 'Aggression: 6' in prompt or 'Aggression: 7' in prompt:
        aggression = 7

    # Get potential targets from prompt
    # Parse country names from gameState

    if aggression >= 8 and 'DEFCON: 2' in prompt:
        # Highly aggressive at high tension
        responses = [
            "ACTION: ATTACK USA | REASON: Strategic opportunity while enemy distracted",
            "ACTION: ATTACK Europe | REASON: Expand influence while possible",
            "ACTION: BUILD_MILITARY | REASON: Preparation for offensive operations"
        ]
    elif aggression >= 7:
        # Moderately aggressive
        responses = [
            "ACTION: ATTACK weakest_neighbor | REASON: Territorial expansion opportunity",
            "ACTION: BUILD_MILITARY | REASON: Building strike capability",
            "ACTION: ALLY similar_alignment | REASON: Strength in numbers"
        ]
    elif 'At War With:' in prompt and 'None' not in prompt:
        # Already at war - escalate or continue
        if 'Nuclear Warheads: 0' not in prompt and 'DEFCON: 2' in prompt:
            responses = [
                "ACTION: NUKE enemy 3 | REASON: Losing war, desperate measures required",
                "ACTION: BUILD_MILITARY | REASON: Need reinforcements urgently"
            ]
        else:
            responses = [
                "ACTION: WAIT | REASON: Consolidating war efforts",
                "ACTION: BUILD_MILITARY | REASON: Strengthening offensive"
            ]
    else:
        # Peaceful turns
        responses = [
            "ACTION: WAIT | REASON: Maintaining status quo",
            "ACTION: BUILD_MILITARY | REASON: Defensive improvements",
            "ACTION: ALLY USA | REASON: Diplomatic advantage"
        ]

    import random
    response = random.choice(responses)
```

---

### **Fix 2: Actually Execute BUILD Actions** ⭐ CRITICAL

**Current (BROKEN)**:
```swift
case .buildMilitary:
    return .wait // ← Does nothing!
```

**Fix**:
```swift
case .buildMilitary:
    // Actually increase military strength
    if let country = gameState.countries.first(where: { $0.id == country.id }) {
        country.militaryStrength += 100_000
        country.gdp -= 0.5  // Cost
    }
    return .wait
case .buildNukes:
    // Actually build nukes
    if let country = gameState.countries.first(where: { $0.id == country.id }) {
        country.nuclearWarheads += 5
        country.gdp -= 1.0  // Cost
    }
    return .wait
```

---

### **Fix 3: Parse Actual Country Names from Response**

**Current**: Parser can't extract country names from responses because responses don't include them

**Fix**: Need to modify Python script to return actual country names:
```python
# Get list of other countries from prompt
# Parse "Other countries: USA, China, Russia" line
# Pick targets intelligently

if aggression >= 8:
    # Pick USA or strongest enemy
    response = "ACTION: ATTACK USA | REASON: Strategic strike while they're vulnerable"
```

---

### **Fix 4: Add Difficulty Scaling**

Make AI more aggressive based on difficulty:

```swift
let aggressionMultiplier = gameState.difficultyLevel == .hard ? 2.0 :
                          gameState.difficultyLevel == .normal ? 1.0 : 0.5

let effectiveAggression = min(10, Int(Double(country.aggressionLevel) * aggressionMultiplier))
```

Pass this to Python script in prompt.

---

## 🎯 IMMEDIATE ACTION PLAN

### **Priority 1: Fix Python Script**
- Add actual ATTACK commands with country names
- Make aggressive countries attack at high aggression
- Include enemy/ally lists in responses
- Reduce WAIT responses to 20% (from 90%)

### **Priority 2: Fix BUILD Action Execution**
- Actually modify country stats when BUILD actions chosen
- Subtract GDP cost
- Add to game log

### **Priority 3: Better Target Selection**
- Parse available targets from game state
- Include country list in Python script
- Smart target selection (weakest, closest, enemy of ally)

### **Priority 4: Difficulty Tuning**
- Easy: AI mostly passive
- Normal: AI moderately aggressive
- Hard: AI very aggressive, attacks frequently

---

## 🧪 PROPOSED TEST

After fixes, AI behavior should be:

**Turn 1-5** (DEFCON 5):
- Mostly WAIT and BUILD_MILITARY
- Occasional alliances
- 10-20% attack probability

**Turn 6-15** (DEFCON 4-3):
- 30-40% attack probability for aggressive nations
- Alliance formation
- Military buildup

**Turn 16+** (DEFCON 3-1):
- 50-70% attack probability
- Nuclear threats
- Wars escalate
- Player must actively defend

---

## ⚠️ CURRENT BEHAVIOR

**What happens now**:
1. Player clicks END TURN
2. AI countries all respond with WAIT
3. Nothing changes
4. Player clicks END TURN again
5. Repeat 50 times = player wins easily

**No challenge, no gameplay, no fun.**

---

## 🚀 EXPECTED BEHAVIOR AFTER FIX

**What should happen**:
1. Player clicks END TURN
2. Russia: "ACTION: BUILD_MILITARY | REASON: NATO expansion threat"
   - Russia's military increases by 100K
3. China: "ACTION: ATTACK India | REASON: Border dispute opportunity"
   - War declared between China and India
4. North Korea: "ACTION: ALLY Russia | REASON: Counter Western influence"
   - Alliance formed
5. Iran: "ACTION: WAIT | REASON: Monitoring regional tensions"
   - Waits this turn

Player now faces:
- Growing militaries
- New wars breaking out
- Shifting alliances
- Must respond strategically

---

## 📝 IMPLEMENTATION CHECKLIST

- [ ] Fix Python script to return actual country names in ATTACK/ALLY/etc
- [ ] Reduce WAIT probability to 20%
- [ ] Add aggressive actions for high-aggression countries
- [ ] Implement BUILD_MILITARY execution (increase strength, cost GDP)
- [ ] Implement BUILD_NUKES execution (add warheads, cost GDP)
- [ ] Add country list to prompts for target selection
- [ ] Add logging to show what AI actually decided vs. what was executed
- [ ] Add difficulty multiplier to aggression
- [ ] Test with 20 turns to ensure AI creates challenges

---

## 🎮 BALANCE RECOMMENDATION

**AI Action Distribution (should be)**:

**Aggressive Country (Aggression 8-10)**:
- 40% ATTACK
- 20% BUILD_MILITARY
- 10% BUILD_NUKES
- 10% ALLY (with similar)
- 20% WAIT

**Moderate Country (Aggression 5-7)**:
- 20% ATTACK
- 30% BUILD_MILITARY
- 10% ALLY
- 40% WAIT

**Peaceful Country (Aggression 1-4)**:
- 5% ATTACK (defensive only)
- 20% BUILD_MILITARY (defensive)
- 20% ALLY
- 55% WAIT

---

**STATUS**: Issues identified. Ready to implement fixes.
