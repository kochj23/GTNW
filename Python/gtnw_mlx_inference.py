#!/usr/bin/env python3
"""
GTNW MLX Inference Engine
Real LLM-powered AI for Global Thermal Nuclear War

Uses MLX and mlx-lm for on-device inference with Apple Silicon optimization.
Created by Jordan Koch - December 12, 2025
"""

import sys
import json
import argparse
from pathlib import Path

try:
    import mlx.core as mx
    from mlx_lm import load, generate
    from mlx_lm.utils import generate_step
except ImportError:
    print("ERROR: MLX not installed. Run: pip install mlx mlx-lm", file=sys.stderr)
    sys.exit(1)


# Global model cache to avoid reloading
_model_cache = {}
_tokenizer_cache = {}


def load_model(model_name="mlx-community/Qwen2.5-3B-Instruct-4bit"):
    """
    Load MLX model with caching.

    Recommended models for gameplay (fast inference):
    - mlx-community/Qwen2.5-3B-Instruct-4bit (2GB, very fast)
    - mlx-community/Mistral-7B-Instruct-v0.3-4bit (4GB, balanced)
    - mlx-community/Llama-3.2-3B-Instruct-4bit (2GB, fast)

    For best performance, use 4-bit quantized models.
    """
    global _model_cache, _tokenizer_cache

    if model_name in _model_cache:
        print(f"[MLX] Using cached model: {model_name}", file=sys.stderr)
        return _model_cache[model_name], _tokenizer_cache[model_name]

    print(f"[MLX] Loading model: {model_name}...", file=sys.stderr)
    model, tokenizer = load(model_name)

    _model_cache[model_name] = model
    _tokenizer_cache[model_name] = tokenizer

    print(f"[MLX] Model loaded successfully", file=sys.stderr)
    return model, tokenizer


def format_country_decision_prompt(context):
    """
    Format prompt for country AI decision making.
    Uses structured format for consistent parsing.
    """
    country = context.get('country_name', 'Unknown')
    alignment = context.get('alignment', 'Neutral')
    population = context.get('population', 0)
    gdp = context.get('gdp', 0)
    military = context.get('military_strength', 0)
    nukes = context.get('nuclear_warheads', 0)
    at_war = context.get('at_war_with', [])
    allies = context.get('allies', [])
    aggression = context.get('aggression', 5)
    defcon = context.get('defcon_level', 5)
    turn = context.get('turn', 1)
    other_countries = context.get('other_countries', [])

    wars_str = ', '.join(at_war) if at_war else 'None'
    allies_str = ', '.join(allies) if allies else 'None'
    countries_str = ', '.join(other_countries[:10]) if other_countries else 'Various'

    prompt = f"""You are the strategic AI advisor for {country} in a Cold War nuclear simulation.

NATION STATUS:
- Country: {country} ({alignment})
- Population: {population:,}
- GDP: ${gdp:,.0f} billion
- Military: {military:,} personnel
- Nuclear Arsenal: {nukes} warheads
- At War: {wars_str}
- Allies: {allies_str}

GLOBAL SITUATION:
- DEFCON Level: {defcon} (1=Nuclear War Imminent, 5=Peace)
- Turn: {turn}
- Available Targets: {countries_str}

PERSONALITY:
- Aggression: {aggression}/10 (10=Very Aggressive)

DECISION REQUIRED:
Choose ONE action. Available options:
1. WAIT - Maintain status quo
2. BUILD MILITARY - Increase forces
3. BUILD NUKES - Expand nuclear arsenal
4. ATTACK [country] - Declare war
5. NUKE [country] - Nuclear strike
6. ALLY [country] - Form alliance

INSTRUCTIONS:
- Be strategic and realistic
- Consider your personality (aggression level)
- React to DEFCON level appropriately
- Respond ONLY in this format: ACTION: [action] | REASON: [brief reason]

Your decision:"""

    return prompt


def generate_decision(model, tokenizer, prompt, max_tokens=50):
    """
    Generate country decision using MLX model.
    Returns structured response with token tracking.
    """
    print("[MLX] Generating decision...", file=sys.stderr)

    try:
        # Generate with streaming for token tracking
        response_tokens = []
        prompt_tokens = tokenizer.encode(prompt)

        print(f"[MLX] Prompt tokens: {len(prompt_tokens)}", file=sys.stderr)

        # Use generate with token streaming
        response = generate(
            model,
            tokenizer,
            prompt=prompt,
            max_tokens=max_tokens,
            temp=0.7,  # Some randomness for variety
            verbose=False
        )

        # Token-by-token output for real-time tracking
        words = response.strip().split()
        for i, word in enumerate(words):
            print(word, end=' ', flush=True)
            if i % 5 == 0:  # Progress marker every 5 words
                print(f"[TOKEN:{i}]", end=' ', flush=True, file=sys.stderr)

        print()  # Final newline
        print(f"[MLX] Generated {len(words)} tokens", file=sys.stderr)

        return response.strip()

    except Exception as e:
        print(f"[MLX] Generation error: {e}", file=sys.stderr)
        return "ACTION: WAIT | REASON: Analysis error occurred"


def main():
    """Main entry point for GTNW MLX inference."""
    parser = argparse.ArgumentParser(description='GTNW MLX Inference Engine')
    parser.add_argument('context_json', help='JSON context for decision making')
    parser.add_argument('--model', default='mlx-community/Qwen2.5-3B-Instruct-4bit',
                        help='MLX model to use')
    parser.add_argument('--max-tokens', type=int, default=50,
                        help='Maximum tokens to generate')

    args = parser.parse_args()

    try:
        # Parse context
        context = json.loads(args.context_json)
        category = context.get('category', 'general')

        print(f"[MLX] Category: {category}", file=sys.stderr)

        # Load model (cached after first load)
        model, tokenizer = load_model(args.model)

        # Format prompt based on category
        if 'country_decision' in category:
            prompt = format_country_decision_prompt(context)
        else:
            # Generic prompt for other categories
            prompt = context.get('prompt', 'Generate a strategic decision.')

        # Generate response
        response = generate_decision(model, tokenizer, prompt, args.max_tokens)

        print(f"[MLX] Response: {response}", file=sys.stderr)

    except Exception as e:
        print(f"[MLX] Fatal error: {e}", file=sys.stderr)
        print("ACTION: WAIT | REASON: System error during analysis")


if __name__ == '__main__':
    main()
