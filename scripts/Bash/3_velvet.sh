#!/bin/bash --login
#SBATCH -J velvet_assembly
#SBATCH -o logs/velvet_%A_%a.out
#SBATCH -e logs/velvet_%A_%a.err
#SBATCH -p multicore
#SBATCH -n 8
#SBATCH --mem=32G
#SBATCH -t 1-0
#SBATCH -a 1
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your@email.ac.uk

# Clean environment
module purge


# ==============================================================================
# --- USER CONFIGURATION ---
# Adjust the following paths and variables to match your local environment
# ==============================================================================

VELVETH_BIN="velveth"                            # Or absolute path: ~/velvet-master/velveth
VELVETG_BIN="velvetg"                            # Or absolute path: ~/velvet-master/velvetg
SAMPLE_LIST="Your_list.txt"                      # Text file containing one sample name per line
INPUT_DIR="Your_data"                            # Directory containing input FASTQ files
INPUT_EXT=".fastq"                               # Adjust to .fastq.gz if processing compressed reads
OUT_BASE_DIR="velvet_out"  			 # Base directory for Velvet outputs

# Velvet Assembly Parameters. Change as required.
KMER_SIZE=15
COV_CUTOFF=3
MIN_CONTIG_LGTH=60

# ==============================================================================


echo "======================================================"
echo "Starting Velvet Assembly Job (Task ID: $SLURM_ARRAY_TASK_ID)"
echo "======================================================"


# --- ERROR CHECK 1: Does the sample list exist? ---
if [[ ! -f "$SAMPLE_LIST" ]]; then
    echo "FATAL ERROR: $SAMPLE_LIST not found in the current directory."
    exit 1
fi

# Grab the specific sample and strip hidden carriage returns
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" "$SAMPLE_LIST" | tr -d '\r')
echo "Processing Sample: $SAMPLE"

# Define inputs
INPUT_FASTQ="${INPUT_DIR}/${SAMPLE}${INPUT_EXT}"
OUT_DIR="${OUT_BASE_DIR}/${SAMPLE}"

# --- ERROR CHECK 2: Input File Existence & Size ---
if [[ ! -f "$INPUT_FASTQ" ]]; then
    echo "FATAL ERROR: input file does not exist -> $INPUT_FASTQ"
    exit 1
fi

if [[ ! -s "$INPUT_FASTQ" ]]; then
    echo "FATAL ERROR: input file is completely empty (0 bytes) -> $INPUT_FASTQ"
    exit 1
fi

# --- ERROR CHECK 3: Tool Accessibility ---
if ! command -v "$VELVETH_BIN" &> /dev/null || ! command -v "$VELVETG_BIN" &> /dev/null; then
    echo "FATAL ERROR: Velvet tools are missing or not executable. Check your configured paths."
    exit 1
fi

# Check if outdir exists, if not create it
if [[ ! -d "$OUT_DIR" ]]; then
    mkdir -p "$OUT_DIR"
fi



echo "Read type: Short (21bp) | K-mer: $KMER_SIZE"
echo "Running velveth..."

# Step 1: velveth
"$VELVETH_BIN" "$OUT_DIR" "$KMER_SIZE" -fastq -short "$INPUT_FASTQ" || { echo "FATAL ERROR: velveth crashed!"; exit 1; }

echo "Running velvetg..."

# Step 2: velvetg
"$VELVETG_BIN" "$OUT_DIR" -cov_cutoff "$COV_CUTOFF" -min_contig_lgth "$MIN_CONTIG_LGTH" || { echo "FATAL ERROR: velvetg crashed!"; exit 1; }



# --- ERROR CHECK 4: Output Verification ---
FINAL_CONTIGS="$OUT_DIR/contigs.fa"

if [[ -s "$FINAL_CONTIGS" ]]; then
    # Count how many contigs Velvet actually built
    CONTIG_COUNT=$(grep -c ">" "$FINAL_CONTIGS")
    echo "SUCCESS! $SAMPLE finished processing."
    echo "Generated $CONTIG_COUNT contigs in -> $FINAL_CONTIGS"
else
    echo "WARNING: Velvet finished running, but contigs.fa is empty. No overlapping reads were found to build a contig."
fi

echo "======================================================"
