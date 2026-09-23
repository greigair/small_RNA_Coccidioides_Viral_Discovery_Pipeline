#!/bin/bash --login
#SBATCH -J bt1_align
#SBATCH -o logs/bt1_%A_%a.out
#SBATCH -e logs/bt1_%A_%a.err
#SBATCH -p multicore
#SBATCH -n 8
#SBATCH --mem=32G
#SBATCH -t 0-4
#SBATCH -a 1
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your@email.ac.uk

module purge


# ==============================================================================
# --- USER CONFIGURATION ---
# Adjust the following paths and variables to match your local environment
# ==============================================================================

BOWTIE_BIN="bowtie"                              # Or provide absolute path: ~/software/bowtie/.../bowtie
INDEX_PREFIX="/index"   			 # Path to reference index prefix
SAMPLE_LIST="Your_list.txt"                   	 # Text file containing one sample name per line
INPUT_DIR="Your_data"                            # Directory containing input .fastq.gz files
OUT_BASE_DIR="bowtie1_full_bioproj_out"          # Base directory for outputs

# ==============================================================================


# Read the pooled sample names and strip the hidden carriage return
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" "$SAMPLE_LIST" | tr -d '\r')

# Set up directories for the RAW reads and the new output
INPUT_FASTQ="${INPUT_DIR}/${SAMPLE}.fastq.gz"
SAMPLE_OUTDIR="${OUT_BASE_DIR}/${SAMPLE}"

mkdir -p "$SAMPLE_OUTDIR"

echo "Aligning $SAMPLE with Bowtie 1..."

# The Bowtie 1 Command
"$BOWTIE_BIN" \
    --threads "$SLURM_NTASKS" \
    -v 2 \
    --sam \
    --un "${SAMPLE_OUTDIR}/${SAMPLE}.unmapped.fastq" \
    -x "$INDEX_PREFIX" \
    "$INPUT_FASTQ" \
    > "${SAMPLE_OUTDIR}/${SAMPLE}.sam"

echo "Finished aligning $SAMPLE!"
