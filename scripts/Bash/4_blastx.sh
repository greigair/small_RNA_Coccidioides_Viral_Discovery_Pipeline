#!/bin/bash --login
#SBATCH -J blastx
#SBATCH -o logs/cocci_blastx_%A_%a.out
#SBATCH -e logs/cocci_blastx_%A_%a.err
#SBATCH -p multicore
#SBATCH -n 8
#SBATCH --mem=32G
#SBATCH -t 1-0
#SBATCH -a 1
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your@email.ac.uk

# Clean environment
module purge

# Load BLAST module (Adjust or remove depending on environment)
module load apps/binapps/blast@2.17.0


# ==============================================================================
# --- USER CONFIGURATION ---
# Adjust the following paths and variables to match your local environment
# ==============================================================================

BLASTX_BIN="blastx"                              # Or provide absolute path to blastx
BLASTDB="/database"            			 # Path to the BLAST database index prefix
SAMPLE_LIST="Your_list.txt"                      # Text file containing one sample name per line

# Input directories
# Note: This points to the Velvet assembly output from step 3 of pipeline.
INPUT_BASE_DIR="velvet_out" 
QUERY_FILENAME="contigs.fa"                      # The name of the assembled FASTA file

# Output directory
OUT_BASE_DIR="blastx_out"       		 # Base directory for BLAST outputs

# BLAST Parameters
EVALUE="1e-10"
MAX_HITS="5"
OUT_FMT="6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle"

# ==============================================================================


# Read sample name and strip hidden carriage returns
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" "$SAMPLE_LIST" | tr -d '\r')

echo "Running local BLASTx for Cocci sample: $SAMPLE"

# Define dynamic paths for this specific sample
QUERY="${INPUT_BASE_DIR}/${SAMPLE}/${QUERY_FILENAME}"
SAMPLE_OUTDIR="${OUT_BASE_DIR}/${SAMPLE}"

# check if query exists
if [[ ! -f "$QUERY" ]]; then
    echo "ERROR: contigs file not found at $QUERY"
    exit 1
fi

# check if outdir exists, if not create it
if [[ ! -d "$SAMPLE_OUTDIR" ]]; then
    mkdir -p "$SAMPLE_OUTDIR"
fi

# Count how many contigs were built
QUERY_COUNT=$(grep -c ">" "$QUERY")

echo "Starting local BLASTx against NCBI viral database..."
echo "Start time: $(date)"

# The BLAST Command (Using TSV format for quick Excel/R viewing)
"$BLASTX_BIN" \
    -query "$QUERY" \
    -db "$BLASTDB" \
    -evalue "$EVALUE" \
    -num_threads "$SLURM_NTASKS" \
    -max_target_seqs "$MAX_HITS" \
    -outfmt "$OUT_FMT" \
    -out "${SAMPLE_OUTDIR}/${SAMPLE}.blastx.local.tsv"

EXIT_CODE=$?

# Check if search succeeded
if [[ $EXIT_CODE -ne 0 ]]; then
    echo "ERROR: Local BLASTx failed!"
    exit 1
fi

# Check output was created and isn't empty
if [[ ! -s "${SAMPLE_OUTDIR}/${SAMPLE}.blastx.local.tsv" ]]; then
    echo "WARNING: BLASTx output is empty - no viral hits found in $SAMPLE!"
    exit 0
fi



# --- SUMMARY STATISTICS ---
HITS=$(wc -l < "${SAMPLE_OUTDIR}/${SAMPLE}.blastx.local.tsv")
CONTIGS_WITH_HITS=$(cut -f1 "${SAMPLE_OUTDIR}/${SAMPLE}.blastx.local.tsv" | sort -u | wc -l)
SUMMARY_FILE="${SAMPLE_OUTDIR}/${SAMPLE}_summary.txt"

{
    echo "Local BLASTx Summary for $SAMPLE"
    echo "Total number of unmapped contigs: $QUERY_COUNT"
    echo "Contigs with sequence hits: $CONTIGS_WITH_HITS"
    echo "Total hits: $HITS"
    echo "Finished at: $(date)"
} > "$SUMMARY_FILE"

echo "SUCCESS: BLASTx complete! Summary saved to $SUMMARY_FILE"