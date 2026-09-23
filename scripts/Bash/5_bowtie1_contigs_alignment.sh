#!/bin/bash --login
#SBATCH -J bt1_sRNA_alignment
#SBATCH -o logs/bt1_sRNA_%A_%a.out
#SBATCH -e logs/bt1_sRNA_%A_%a.err
#SBATCH -p multicore
#SBATCH -n 8
#SBATCH --mem=16G
#SBATCH -t 0-4
#SBATCH -a 1
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your@email.ac.uk

# Clean environment
module purge

# Load required modules (Adjust or remove depending on environment)
module load apps/gcc/samtools/1.21


# ==============================================================================
# --- USER CONFIGURATION ---
# Adjust the following paths and variables to match your local environment
# ==============================================================================

BOWTIE_BIN="bowtie"                              # Or absolute path: ~/software/bowtie/bowtie-1.3.1-linux-x86_64/bowtie
SAMTOOLS_BIN="samtools"                          # Or absolute path to samtools
INDEX_PREFIX="index/reference_index" 		 # Path to viral reference index prefix
SAMPLE_LIST="Alignment_list.txt"                 # Text file containing one sample name per line

# Input and Output Directories
INPUT_DIR="Raw_RNA-seq_Alignment"                # Directory containing raw FASTQ files
INPUT_EXT=".fastq"                               # Adjust to .fastq.gz if files are compressed
OUT_DIR="Raw_read_alignments"     		 # Output directory for alignments

# ==============================================================================


# Read the sample name from your list based on the SLURM array ID and strip hidden carriage returns
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" "$SAMPLE_LIST" | tr -d '\r')

echo "Starting array task $SLURM_ARRAY_TASK_ID for sample: $SAMPLE"

INPUT_FASTQ="${INPUT_DIR}/${SAMPLE}${INPUT_EXT}"

# Create output directory if it doesn't exist
if [[ ! -d "$OUT_DIR" ]]; then
    mkdir -p "$OUT_DIR"
fi

echo "Aligning raw small RNA reads to Akanthomyces multi-segment genome with Bowtie 1..."

# Run Bowtie 1
# -q : Input is FASTQ (default, but good to be explicit)
# -v 3 : Allows up to 3 mismatches
# -a --best --strata : Reports the best alignments
"$BOWTIE_BIN" \
    -q \
    --threads "$SLURM_NTASKS" \
    -v 3 \
    -a --best --strata \
    --sam \
    -x "$INDEX_PREFIX" \
    "$INPUT_FASTQ" \
    > "${OUT_DIR}/${SAMPLE}.sam"

echo "Alignment complete. Converting SAM to sorted BAM for IGV visualization..."

# Convert SAM to BAM
"$SAMTOOLS_BIN" view -bS "${OUT_DIR}/${SAMPLE}.sam" > "${OUT_DIR}/${SAMPLE}.bam"

# Sort the BAM file
"$SAMTOOLS_BIN" sort "${OUT_DIR}/${SAMPLE}.bam" -o "${OUT_DIR}/${SAMPLE}.sorted.bam"

# Index the sorted BAM file (creates the .bai file IGV needs)
"$SAMTOOLS_BIN" index "${OUT_DIR}/${SAMPLE}.sorted.bam"

# Clean up the intermediate unsorted files to save space
rm "${OUT_DIR}/${SAMPLE}.sam"
rm "${OUT_DIR}/${SAMPLE}.bam"

echo "Finished processing $SAMPLE! The .sorted.bam file is ready for IGV."