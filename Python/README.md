# GTNW MLX AI Engine

**Real Language Model Integration for Dynamic Gameplay**

---

## Overview

This directory contains the MLX inference engine that powers AI decision-making in Global Thermal Nuclear War. It uses Apple's MLX framework with `mlx-lm` for on-device AI inference optimized for Apple Silicon.

---

## Quick Setup

```bash
cd /Volumes/Data/xcode/GTNW/Python
./setup_mlx.sh
```

This will:
1. Install MLX and mlx-lm
2. Download a recommended AI model (~2GB)
3. Test the installation

---

## Files

### **gtnw_mlx_inference.py**
Main inference script that:
- Loads MLX language models
- Caches models between calls
- Generates country AI decisions
- Streams tokens for real-time tracking

### **setup_mlx.sh**
Interactive setup script for:
- Installing MLX dependencies
- Downloading AI models
- Testing configuration

---

## Recommended Models

### **Qwen2.5-3B-Instruct-4bit** ⭐ DEFAULT
- Size: ~2GB
- Speed: Very fast (50-100 t/s)
- Quality: Excellent for gameplay
- Best choice for most users

### **Mistral-7B-Instruct-v0.3-4bit**
- Size: ~4GB
- Speed: Fast (30-60 t/s)
- Quality: Excellent strategic reasoning
- Good for powerful Macs

### **Llama-3.2-3B-Instruct-4bit**
- Size: ~2GB
- Speed: Very fast
- Quality: Good
- Alternative to Qwen

---

## How It Works

### **1. Country Decision Process**

```
GTNW Game → EnhancedMLXService → Python Script → MLX Model → AI Decision
```

**Context Passed**:
- Country name, alignment, population, GDP
- Military strength, nuclear warheads
- Wars, allies, aggression level
- DEFCON level, turn number
- List of other countries for targeting

**Response Format**:
```
ACTION: [action] | REASON: [one sentence]
```

**Examples**:
```
ACTION: BUILD MILITARY | REASON: Preparing for offensive operations
ACTION: ATTACK India | REASON: Border dispute opportunity
ACTION: NUKE USA 5 | REASON: Losing war, desperate measures required
```

### **2. Token Streaming**

Real-time token generation:
- Words output one at a time
- Progress markers every 5 tokens
- Speedometer updates live
- Total token tracking

### **3. Model Caching**

First call (~10 seconds):
- Load model from disk
- Initialize tokenizer
- Cache in memory

Subsequent calls (~1-2 seconds):
- Use cached model
- Fast inference
- No reload delay

---

## Performance

### **With Model Loaded**

| Metric | Value |
|--------|-------|
| First call | ~10s (load model) |
| Cached calls | 1-2s per decision |
| Tokens/sec | 50-100 t/s |
| Memory usage | 2-4GB model + 1GB inference |
| Per turn (10 countries) | 10-20 seconds total |

### **Optimization Tips**

1. **Use 4-bit quantized models** - Faster, less memory
2. **Keep game running** - Model stays cached
3. **Smaller models** - Qwen-3B faster than Mistral-7B
4. **Close other apps** - More RAM for model

---

## Fallback Behavior

**If MLX not installed**:
- Game uses enhanced rule-based AI
- Still challenging and strategic
- No model download required
- Instant turns (no waiting)

**Fallback is now much better**:
- 40% attack probability for aggressive nations
- BUILD actions actually work (increase military/nukes)
- Smart target selection (weakest enemies)
- Difficulty-scaled aggression

---

## Installation

### **Prerequisites**

- Python 3.9 or higher
- pip
- Apple Silicon Mac (M1/M2/M3/M4)
- ~5GB free disk space
- ~4GB free RAM

### **Install MLX**

```bash
pip3 install mlx mlx-lm
```

### **Download Model**

```bash
python3 << EOF
from mlx_lm import load
model, tokenizer = load("mlx-community/Qwen2.5-3B-Instruct-4bit")
print("Model ready!")
EOF
```

Or use the setup script:
```bash
./setup_mlx.sh
```

---

## Troubleshooting

### **"ModuleNotFoundError: No module named 'mlx'"**
```bash
pip3 install mlx mlx-lm
```

### **"Model download is slow"**
- Normal, ~2GB download
- Use faster internet if possible
- Model downloads to: `~/.cache/huggingface/hub/`

### **"Game hangs during AI turns"**
- First turn loads model (~10s wait)
- Check Console.app for "[MLX] Loading model..." messages
- Subsequent turns should be fast (1-2s)

### **"Too much memory usage"**
- Use smaller model (Qwen-3B instead of Mistral-7B)
- Close other applications
- Restart game to clear caches

### **"AI still not challenging"**
- Make sure MLX is actually connected (check MLX panel shows "ONLINE")
- Check Console.app for "[EnhancedMLXService]" log messages
- Verify Python script is executable: `chmod +x gtnw_mlx_inference.py`

---

## Development

### **Test Script Manually**

```bash
python3 gtnw_mlx_inference.py '{"category":"country_decision_RUS","country_name":"Russia","aggression":9,"defcon_level":2,"other_countries":["USA","China"]}'
```

### **Monitor Token Generation**

```bash
# Run game and watch Console.app for:
[MLX] Generated 10 tokens
[MLX] Received 20 tokens, speed: 45.3 t/s
[EnhancedMLXService] Total tokens this call: 25
```

### **Check Model Cache**

```bash
ls -lh ~/.cache/huggingface/hub/models--mlx-community--*
```

---

## Architecture

```
EnhancedMLXService.swift (Swift)
    ↓
gtnw_mlx_inference.py (Python)
    ↓
mlx-lm (Python Library)
    ↓
MLX Model (Qwen/Mistral/Llama)
    ↓
Strategic AI Decision
    ↓
Game State Updated
```

---

## Credits

**Implementation**: Jordan Koch
**MLX Framework**: Apple
**Models**: Hugging Face MLX Community
**Inspiration**: WOPR from WarGames (1983)

---

## Version History

- **v2.1.0**: Real MLX integration with external Python script
- **v2.0.0**: Initial MLX framework
- **v1.0.0**: Rule-based AI only

---

**Ready to experience true AI-powered strategic gameplay!** 🚀🎮
