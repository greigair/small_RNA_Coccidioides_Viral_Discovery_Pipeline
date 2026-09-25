# small_RNA_Coccidioides_Viral_Discovery_Pipeline

**An In Silico Search for Mycoviruses in Coccidioides posadasii Small RNA Transcriptomes.**

Coccidioides is a dimorphic fungal genus comprising two species C. posadasii and C. immitis. Both species are causative agents of coccidioidomycosis (Valley Fever) a non-contagious pulmonary infection endemic to arid regions of the western hemisphere with the largest area of prevalence being the United States. To date no mycoviruses have been characterised in Coccidioides species. Mycoviruses are well understood to induce changes in host fungal physiology, including hypovirulence. Therefore, possible mycoviral discoveries could lay the groundwork for developing targeted virotherapies. 

Fungal hosts may defend against mycoviral infection through the RNA interference pathway, using viral guide RNAs to guide an RNA-induced silencing complex into digesting and excreting viral transcriptomic material. The aim of this study was to thus investigate the presence of mycoviruses in C. posadasii by analysing public small RNA sequencing depositories.

This process included sRNA host genome alignment, contiguous sequence assembly, and manual filtering. Taxonomic and genomic analyses were conducted to characterise and confirm the origin of suspected viral contigs within currently known viral taxonomies. The pipeline itself included multiple scripts on the Bash terminal, all analysis was completed using the SLURM workload manager on the University of Manchester's Computational Shared Facility (CSF). 


## Pipeline overview
 
Scripts are numbered in the order they are run. Each Bash script is written as a SLURM job array (one array task per sample), and each R script consumes the aggregated outputs of the Bash steps.
 
| Step | Script | Purpose |
|---|---|---|
| 1 | `1_downloading_sra.sh` | Downloads raw sRNA-seq FASTQ files from NCBI SRA (`prefetch` + `fasterq-dump`), renames per sample, compresses with `pigz`. |
| 2 | `2_bowtie1_full_sample_alignment.sh` | Aligns each sample against a reference genome (In this project's case *C. posadasii* Silveira) with Bowtie1 and exports unaligned (candidate non-host) reads via `--un`. |
| 3 | `3_velvet.sh` | De novo assembles the unaligned reads into contigs using Velvet (`velveth`/`velvetg`). |
| 4 | `4_blastx.sh` | BLASTX search of assembled contigs against a local custom viral RefSeq/nr (viral taxid 10239) or any other database of choice to identify candidate viral protein hits. |
| 5 | `5_bowtie1_contigs_alignment.sh` | This script was used to re-align raw sRNA reads from confirmed viral-hit samples against a composite *Akanthomyces* spp. Chrysovirus 1 reference genome, then converted/sorted/indexed to BAM for downstream coverage analysis and IGV visualisation. This may be used similarly for another virus/organism |
| 6 | `6_blastx_taxonomic_analysis.R` | Aggregates all per-sample BLASTX TSV outputs, queries NCBI (via `rentrez`/`taxize`) to resolve taxonomic order for each hit, and filters to mycovirus-associated orders to produce the high-priority contig shortlist. |
| 7 | `7_sequence_count_figure_making.R` | Generates the stepwise data-yield figures (raw reads → unaligned reads → assembled contigs → viral contig hits) for each step major of the pipeline. This was used to summarise  for us by *Coccidioides* life stage. |
 
---
 
## Requirements
 
**Bash / HPC:**
- SLURM workload manager (scripts are written as `--array` jobs)
- SRA Toolkit ≥ 3.0.0 (`prefetch`, `fasterq-dump`)
- pigz
- Bowtie1 (v1.3.1)
- Velvet (`velveth`, `velvetg`)
- BLAST+ (v2.17.0)
- samtools (v1.21)
**R (v4.5.1):**
- tidyverse
- taxize
- rentrez
- pbapply
- ggplot2
- scales
An NCBI Entrez API key is recommended to avoid rate limiting when running `FullViralDB_Cocci_Blastx_Analysis.R`.

## Usage notes
 
- All scripts are templates: paths, index/database locations, sample list filenames, and SLURM directives (partition, memory, walltime, email) are placeholders and need to be edited for your own environment before running.
- Scripts expect a plain-text sample list (one sample name per line) and use `$SLURM_ARRAY_TASK_ID` to select the corresponding sample for each array task. (I.e., you could download 80 samples of small RNA-seq, and each of those 80 would require a line in the your_list.txt file with their identification so that they may be sampled accordingly from the corresponding your_data file.
- The two R scripts expect the Bash outputs (BLASTX TSVs, and a `read_counts.csv` summarising per-sample read/contig counts) to be organised under a `data/` directory — see the `TSV_DIR`/`INPUT_CSV` variables at the top of each script.
---

## Acknowledgements

This work is based off of a previous pipeline constructed by Stefano Declan Togatorop, a postgraduate student who worked on this project previously, who analysed general mRNA-seq Coccidioides data. His github is found here:  https://github.com/stogaclan
