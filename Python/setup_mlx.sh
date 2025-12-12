#!/bin/bash
#
# GTNW MLX Setup Script
# Downloads and configures MLX model for gameplay
# Created by Jordan Koch - December 12, 2025
#

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GTNW MLX AI Setup"
echo "  Real LLM-Powered Gameplay"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check Python version
echo "🔍 Checking Python..."
python3 --version || { echo "❌ Python 3 not found"; exit 1; }

# Check if MLX is installed
echo "🔍 Checking MLX installation..."
if python3 -c "import mlx.core; import mlx_lm" 2>/dev/null; then
    echo "✅ MLX already installed"
else
    echo "📦 Installing MLX..."
    pip3 install mlx mlx-lm
    echo "✅ MLX installed"
fi

# Download recommended model
echo ""
echo "📥 Downloading AI Model..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Recommended models:"
echo "  1. Qwen2.5-3B-Instruct-4bit (2GB, very fast) ← RECOMMENDED"
echo "  2. Mistral-7B-Instruct-v0.3-4bit (4GB, balanced)"
echo "  3. Llama-3.2-3B-Instruct-4bit (2GB, fast)"
echo ""
read -p "Choose model (1-3) [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        MODEL="mlx-community/Qwen2.5-3B-Instruct-4bit"
        ;;
    2)
        MODEL="mlx-community/Mistral-7B-Instruct-v0.3-4bit"
        ;;
    3)
        MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
        ;;
    *)
        echo "Invalid choice, using Qwen2.5-3B"
        MODEL="mlx-community/Qwen2.5-3B-Instruct-4bit"
        ;;
esac

echo ""
echo "📥 Downloading $MODEL..."
echo "This may take a few minutes..."
echo ""

# Test the model by loading it
python3 << EOF
from mlx_lm import load
import sys

try:
    print("Loading model: $MODEL")
    model, tokenizer = load("$MODEL")
    print("✅ Model loaded successfully!")
    print(f"   Model size: ~{sys.getsizeof(model) / (1024*1024):.1f}MB in memory")
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Model: $MODEL"
echo "Location: ~/.cache/huggingface/hub/"
echo ""
echo "🎮 You can now launch GTNW and enjoy AI-powered gameplay!"
echo ""
echo "The AI will use real language model reasoning for:"
echo "  • Strategic decisions"
echo "  • War declarations"
echo "  • Alliance formation"
echo "  • Nuclear deterrence"
echo ""
echo "Have fun! 🚀"
