#!/bin/bash --login
#SBATCH -J sra_download
#SBATCH -o logs/sra_download_%A_%a.out
#SBATCH -e logs/sra_download_%A_%a.err
#SBATCH -p serial
#SBATCH -t 1-0
#SBATCH -a 1
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your@email.ac.uk

# Clean environment
module purge

# Load required modules
module load apps/bioinf
module load apps/binapps/sra/3.0.0
module load tools/gcc/pigz/2.5

# check if tools loaded correctly
if ! command -v prefetch &> /dev/null; then
    echo "ERROR: prefetch not found. Check module name with: module search sra"
    exit 1
fi
echo "SRA tools loaded successfully: $(prefetch --version)"

if ! command -v pigz &> /dev/null; then
    echo "ERROR: pigz not found. Check module name with: module search pigz"
    exit 1
fi

echo "pigz loaded successfully: $(pigz --version)"

# --- JOB ARRAY ---
# Read sample name from list.txt and strip hidden carriage returns
SAMPLE=$(awk "NR==$SLURM_ARRAY_TASK_ID" Your_list.txt | tr -d '\r')
SRA=$(awk "NR==$SLURM_ARRAY_TASK_ID" Your_data.txt | tr -d '\r')
# -----------------

# check if sample name is read
if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: Sample name not found for SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID. Check Your_list.txt"
    exit 1
fi

# --- USER INPUT ---
OUTDIR="1229574_SRA_data"         # Output directory
# ------------------

# check if output directory exists, if not create it
if [[ ! -d "$OUTDIR" ]]; then
    mkdir -p "$OUTDIR"
fi

echo "Downloading $SRA and naming it $SAMPLE..."

# 1. Create a private temporary directory just for this specific job clone
TEMP_DIR="${OUTDIR}/temp_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$TEMP_DIR"

# 2. Download into the private temp directory
prefetch "$SRA" -O "$TEMP_DIR"

# 3. Convert to FASTQ
fasterq-dump "${TEMP_DIR}/${SRA}" \
    --outdir "$TEMP_DIR" \
    --progress

# 4. Find whatever FASTQ file was generated and rename/move it safely
mv "$TEMP_DIR"/*.fastq "${OUTDIR}/${SAMPLE}.fastq"

# 5. Clean up the empty temp directory
rm -rf "$TEMP_DIR"

# 6. Compress the perfectly named file
pigz "${OUTDIR}/${SAMPLE}.fastq"

echo "Finished processing $SAMPLE"
