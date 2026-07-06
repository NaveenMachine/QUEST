#!/usr/bin/env bash
set -euo pipefail

# Configure judge environment here.
# --- Local vLLM judge (free; reuses the model already served on localhost:6000) ---
# litellm routes "openai/<name>" to an OpenAI-compatible server at OPENAI_API_BASE.
export JUDGE_MODEL_NAME="openai/deepresearch"
export OPENAI_API_BASE="http://localhost:6000/v1"
export OPENAI_API_KEY="EMPTY"
export JUDGE_OPENAI_API_KEY="EMPTY"
#
# Alternatives (uncomment and fill in to use an external judge instead):
# export JUDGE_MODEL_NAME="gpt-4o-mini"
# export JUDGE_OPENAI_API_KEY="..."
#
# export JUDGE_MODEL_NAME="bedrock/anthropic.claude-3-5-sonnet-20240620-v1:0"
# export JUDGE_AWS_ACCESS_KEY_ID="..."
# export JUDGE_AWS_SECRET_ACCESS_KEY="..."
# export JUDGE_AWS_REGION_NAME="..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_DIRS=(
  "${SCRIPT_DIR}/../../inference/outputs/test/results/deepresearch/mini"
)


export DATASET_PATH="${SCRIPT_DIR}/gaia-103-org.json" # unzipped from gaia-103-org.zip, password: 8sK9pR2xQ7bT5gA3
export WORKERS=4

for TARGET_DIR in "${TARGET_DIRS[@]}"; do
  echo "=========================================="
  echo "Processing: $TARGET_DIR"
  echo "=========================================="

  if [ ! -d "$TARGET_DIR" ]; then
    echo "Warning: Directory does not exist, skipping: $TARGET_DIR"
    continue
  fi

  python "$SCRIPT_DIR/judge.py" \
    --target-dir "$TARGET_DIR" \
    --dataset "$DATASET_PATH" \
    --workers "$WORKERS"

  echo ""
done

echo "All target directories processed!"
