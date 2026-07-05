# Running QUEST on OSC Cardinal

Practical runbook for running QUEST inference on the OSC **Cardinal** cluster.
Everything below was verified on Cardinal (RHEL9, Python 3.10, CUDA 13, torch
2.11, vLLM 0.24) in the `deepresearch` conda env.

> **Golden rules**
> 1. **Never build or run on a login node** (`cardinal-login01`). No GPU, shared,
>    against policy. Always grab a compute node first (`salloc`).
> 2. **Always `export LD_PRELOAD=<bundled libnccl.so.2>`** before anything that
>    imports torch (the vLLM server *and* the QUEST harness). Without it torch
>    dies with `undefined symbol: ncclDevCommDestroy`.

---

## 0. The experiment matrix

8 runs = 4 checkpoints × 2 harnesses (QUEST baseline vs. RLM with no context
condenser). Same weights are served either way; only the harness differs.

| # | Config | Harness | MODEL_PATH |
| --- | --- | --- | --- |
| 1 | Tongyi-30B (baseline) | QUEST | `Alibaba-NLP/Tongyi-DeepResearch-30B-A3B` |
| 2 | Tongyi-30B + RLM (no condenser) | **RLM** | `Alibaba-NLP/Tongyi-DeepResearch-30B-A3B` |
| 3 | QUEST-35B-SFT (baseline) | QUEST | `osunlp/QUEST-35B-SFT` |
| 4 | QUEST-35B-SFT + RLM (no condenser) | **RLM** | `osunlp/QUEST-35B-SFT` |
| 5 | QUEST-35B-MT-Plus-SFT (baseline) | QUEST | `osunlp/QUEST-35B-MT-Plus-SFT` |
| 6 | QUEST-35B-MT-Plus-SFT + RLM (no condenser) | **RLM** | `osunlp/QUEST-35B-MT-Plus-SFT` |
| 7 | QUEST-35B-RL (baseline) | QUEST | `osunlp/QUEST-35B-RL` |
| 8 | QUEST-35B-RL + RLM (no condenser) | **RLM** | `osunlp/QUEST-35B-RL` |

- **Odd rows (1, 3, 5, 7)** — QUEST baselines, run from **this** repo (env
  `deepresearch`, Python 3.10). Sections 3–5 below.
- **Even rows (2, 4, 6, 8)** — same checkpoint driven by the `rlm/` package
  with the context condenser off (different env — Python ≥3.11). See the RLM
  appendix at the bottom.

---

## 1. One-time setup (already done — for reproducibility)

Run these once, **on a compute node**, to (re)build the env from scratch.

```bash
# get a GPU node first (see section 2)
module load miniconda3/24.1.2-py310
conda create -n deepresearch python=3.10 -y
conda activate deepresearch

# vLLM FIRST — it pulls a compatible torch automatically.
# Do NOT use requirements.txt as-is: it pins torch==2.10.0 / vllm==0.19.0,
# which do not exist on the Cardinal package index.
pip install vllm

# remaining QUEST deps (transformers/openai/tiktoken/numpy already came with vllm)
pip install litellm json5 qwen-agent sandbox_fusion pandas
pip install soundfile librosa      # transitive deps of qwen-agent (audio libs)
```

Notes:
- **Ignore the `transformers<5.0` pin.** vLLM installs transformers 5.x and QUEST
  imports fine on it — do not downgrade or you break vLLM.
- All QUEST modules import cleanly under this env
  (`prompt, tool_search, tool_visit, tool_memory, tool_scholar, tool_python,
  react_agent`).

---

## 2. Per-session startup ("start the venv") — do this EVERY time

### Step A — get a GPU compute node

```bash
salloc --account=PAS2699 --partition=gpu --gpus=1 --mem=64G --time=2:00:00
# wait for: "Nodes cXXXX are ready for job"; you are now ON the compute node
```

> A 30B/35B model in fp16 is ~60–70 GB. If it does not fit on one GPU, request
> two (`--gpus=2`) and serve with `--tensor-parallel-size 2`. Confirm your GPU
> with `nvidia-smi --query-gpu=name,memory.total --format=csv`.

### Step B — activate the env (paste this block, or `source ~/quest_env.sh`)

```bash
module load miniconda3/24.1.2-py310
conda activate deepresearch

# REQUIRED: fix torch's NCCL symbol load order
export LD_PRELOAD="$CONDA_PREFIX/lib/python3.10/site-packages/nvidia/nccl/lib/libnccl.so.2"

# keep large model downloads off the 500 GB home quota
export HF_HOME=/fs/scratch/PAS2699/naveenkamath/hf_cache
```

**Tip:** save those lines as `~/quest_env.sh` and just `source ~/quest_env.sh`.

### Step C — sanity check

```bash
python -c "import torch; print('CUDA:', torch.cuda.is_available(), '| GPUs:', torch.cuda.device_count())"
# expect: CUDA: True | GPUs: 1  (or 2)
```

---

## 3. Configure QUEST (in `inference/`)

### `inference/api_config.yaml`
- `SERPER_KEY_ID` — Serper web-search key (free tier fine for testing)
- `JINA_API_KEYS` — Jina page-reader key (free tier fine for testing)
- Leave the `API_KEY` / `AZURE_*` fields as placeholders — **not used** in local mode.

> **Do not commit real keys.** Add `inference/api_config.yaml` to `.gitignore`.
> Forks are public; leaked keys get scraped and abused within minutes.

### Route the summary + memory LLMs to your local vLLM (free, no Azure)
The visit tool summarizes **every page** with the summary model, so this is
**not optional**. Set before launching (or add to `~/quest_env.sh`):

```bash
export VISIT_LOCAL_PROMPT_ENABLED=true    # page summarizer -> local vLLM
export MEMORY_LOCAL_PROMPT_ENABLED=true   # memory/context condenser -> local vLLM
export MEMORY_THRESHOLD=8000              # low, so the condenser actually fires in a short test
```

### `inference/server_endpoints.conf`
Points the agent at your model server. For a single local server:

```text
HOSTNAME_LIST=localhost
PORTS=6000
```

---

## 4. Serve the model (compute node, env active)

Pick the checkpoint for the config you are testing. Example — config #1 (Tongyi-30B):

```bash
vllm serve Alibaba-NLP/Tongyi-DeepResearch-30B-A3B \
    --host 0.0.0.0 --port 6000 \
    --served-model-name deepresearch \
    --gpu-memory-utilization 0.90
# add: --tensor-parallel-size 2   (if using 2 GPUs)
```

Leave it running (or `&` it / use a second terminal / tmux). It is ready when
`curl -s http://localhost:6000/v1/models` returns JSON.

> The QUEST launch scripts **do not start the server** — they check for it and
> `exit 1` if it is missing. Serve first, then run.

---

## 5. Run a test case

From `inference/`, with the env active and server up:

```bash
cd inference

# smaller/faster benchmark for a smoke test; override MODEL_PATH per config
MODEL_PATH=Alibaba-NLP/Tongyi-DeepResearch-30B-A3B \
MAX_WORKERS=2 \
DATASET=../evaluation/gaia/gaia-text-only-103.jsonl \
OUTPUT_PATH=./outputs/test/results \
TASK_LOG_DIR=./outputs/test/logs \
bash scripts/run_react_infer_gaia.sh
```

For the other configs, change `MODEL_PATH` (and re-serve that checkpoint):
`osunlp/QUEST-35B-SFT`, `osunlp/QUEST-35B-MT-Plus-SFT`, `osunlp/QUEST-35B-RL`.

To only run a couple of examples, point `DATASET` at a trimmed `.jsonl`
(e.g. `head -3 file.jsonl > mini.jsonl`). Runs are resumable — rerun the same
command with the same `OUTPUT_PATH`/`TASK_LOG_DIR`.

Available benchmark launchers live in `inference/scripts/run_react_infer_*.sh`
(bc, bcp, gaia, hle, drb, lrb, m2w2, ws).

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `undefined symbol: ncclDevCommDestroy` on `import torch` | torch can't resolve bundled NCCL early | `export LD_PRELOAD=$CONDA_PREFIX/lib/python3.10/site-packages/nvidia/nccl/lib/libnccl.so.2` (LD_LIBRARY_PATH is **not** enough) |
| `Missing VLLM servers, stop now.` → `exit 1` | model server not running | start `vllm serve` on the port in `server_endpoints.conf` first |
| `No module named 'soundfile'` | qwen-agent audio dep | `pip install soundfile librosa` |
| `Could not find a version ... torch==2.10.0` | impossible pin / wrong Python | use a **3.10 conda env** and `pip install vllm` (don't pin torch) |
| Visit tool crashes on Azure creds | summary model pointed at placeholder Azure | set `VISIT_LOCAL_PROMPT_ENABLED=true` + `MEMORY_LOCAL_PROMPT_ENABLED=true` |
| Memory/condenser never triggers | threshold too high for a short run | lower `MEMORY_THRESHOLD` (e.g. 8000) |
| `nvidia-smi` fails / `CUDA: False` | you're on a login node | you must be on the `salloc` compute node |
| HF `401` / gated repo | checkpoint gated | `huggingface-cli login` (set `HF_TOKEN`) |
| CUDA OOM on load | model bigger than one GPU | request 2 GPUs, add `--tensor-parallel-size 2`; lower `--max-model-len` |

---

## Appendix — RLM runs (configs #2, #4, #6, #8) — separate env

The four "+ RLM (no context condenser)" runs all use the RLM package
(`../rlm/`, imported as `rlms`), which needs **Python ≥3.11**, so it cannot share
the QUEST env. Same four checkpoints as the baselines — only the harness changes.

```bash
# separate env (build once)
conda create -n rlm python=3.11 -y
conda activate rlm
cd ../rlm && pip install -e .
```

For each RLM config: serve the checkpoint with vLLM, then drive it from RLM with
the condenser off. Example shows Tongyi-30B (config #2); swap the model for #4/#6/#8.

```bash
# same LD_PRELOAD rule applies in this env
export LD_PRELOAD="$CONDA_PREFIX/lib/python3.11/site-packages/nvidia/nccl/lib/libnccl.so.2"

# serve the checkpoint for the config you're testing:
#   #2 Alibaba-NLP/Tongyi-DeepResearch-30B-A3B
#   #4 osunlp/QUEST-35B-SFT
#   #6 osunlp/QUEST-35B-MT-Plus-SFT
#   #8 osunlp/QUEST-35B-RL
vllm serve <MODEL_PATH> --host 0.0.0.0 --port 8000 --served-model-name rlm-model
```

Then point RLM at the local server, with the context condenser **off** (this is
the default — `compaction=False`):

```python
from rlm import RLM
rlm = RLM(
    backend="vllm",
    backend_kwargs={"base_url": "http://localhost:8000/v1",
                    "model_name": "<MODEL_PATH>"},   # match --served-model-name / the served checkpoint
    environment="local",
    compaction=False,   # "No Context Condenser"
)
```

No API keys required for the local-vLLM + local-environment path. Run all four
RLM configs the same way, changing only the served checkpoint.
