General GPU allocation:
salloc --account=PAS2699 --partition=gpu --gpus=1 --mem=64G --time=2:00:00

RUNNING VLLM and TESTS:
salloc --account=PAS2699 --partition=gpu --nodes=1 --gpus=2 --mem=128G --time=4:00:00



module load miniconda3/24.1.2-py310

conda env list

conda activate deepresearch




COMMAND TO RUN QUEST-35B-RL

cd inference

MODEL_PATH=osunlp/QUEST-35B-RL \
MEMORY_THRESHOLD=8000 \
VISIT_LOCAL_PROMPT_ENABLED=true \
MEMORY_LOCAL_PROMPT_ENABLED=true \
MAX_WORKERS=2 \
DATASET=mini.jsonl \
OUTPUT_PATH=./outputs/test/results \
TASK_LOG_DIR=./outputs/test/logs \
bash scripts/run_react_infer_gaia.sh



COMMAND TO START THE VLM:
export LD_PRELOAD="$CONDA_PREFIX/lib/python3.10/site-packages/nvidia/nccl/lib/libnccl.so.2"


vllm serve osunlp/QUEST-35B-RL \
    --host 0.0.0.0 --port 6000 \
    --served-model-name deepresearch \
    --tensor-parallel-size 2 \
    --gpu-memory-utilization 0.90



ADD this to .venv
module load miniconda3/24.1.2-py310                                                    # 1. put conda on PATH
conda activate deepresearch                                                            # 2. activate env
export LD_PRELOAD="$CONDA_PREFIX/lib/python3.10/site-packages/nvidia/nccl/lib/libnccl.so.2"  # 3. fix NCCL
export HF_HOME=/fs/scratch/PAS2699/naveenkamath/hf_cache                               # 4. downloads off home quota


starting the VLLM with 2 gpu on 1 node:
module load miniconda3/24.1.2-py310
conda activate deepresearch
export LD_PRELOAD="$CONDA_PREFIX/lib/python3.10/site-packages/nvidia/nccl/lib/libnccl.so.2"
export HF_HOME=/fs/scratch/PAS2699/naveenkamath/hf_cache
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export VLLM_USE_FLASHINFER_SAMPLER=0

vllm serve osunlp/QUEST-35B-RL \
    --host 0.0.0.0 --port 6000 \
    --served-model-name deepresearch \
    --tensor-parallel-size 2 \
    --gpu-memory-utilization 0.90 \
    --gdn-prefill-backend triton




How to run Qwen vllm:
# env block (same as before)
export LD_PRELOAD="$CONDA_PREFIX/lib/python3.10/site-packages/nvidia/nccl/lib/libnccl.so.2"
export HF_HOME=/fs/scratch/PAS2699/naveenkamath/hf_cache
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export VLLM_USE_FLASHINFER_SAMPLER=0

vllm serve Qwen/Qwen2.5-32B-Instruct \
    --host 0.0.0.0 --port 6000 \
    --served-model-name qwen32b \
    --tensor-parallel-size 1 \
    --gpu-memory-utilization 0.90
