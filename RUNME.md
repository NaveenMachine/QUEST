salloc --account=PAS2699 --partition=gpu --gpus=1 --mem=64G --time=2:00:00

module load miniconda3/24.1.2-py310

conda env list

conda activate deepresearch