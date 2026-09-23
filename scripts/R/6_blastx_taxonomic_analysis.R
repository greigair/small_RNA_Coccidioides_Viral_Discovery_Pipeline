# ---------------------------------------------------------
# Cocci BLASTx Result Taxonomic Parsing & Plotting
# Aggregates TSV outputs, fetches NCBI taxonomy, and filters viral hits
# ---------------------------------------------------------

library(tidyverse)
library(taxize)
library(rentrez)
library(pbapply)


# ==============================================================================
# --- USER CONFIGURATION ---
# ==============================================================================
# Set your NCBI API key to avoid rate limiting
Sys.setenv(ENTREZ_KEY = "YOUR_API_KEY_HERE")

TSV_DIR <- "data/blastx_outputs/"          # Directory containing pipeline blastx output TSV files
OUTPUT_DIR <- "outputs/taxonomy/"          # Directory for generated CSVs and plots
# ==============================================================================


if(!dir.exists(OUTPUT_DIR)) {dir.create(OUTPUT_DIR, recursive = TRUE)}


# ---------------------------------------------------------
# 1. Compile BLASTx TSV Data
# ---------------------------------------------------------
blast_cols <- c("qseqid", "sseqid", "pident", "length", "mismatch", "gapopen", 
                "qstart", "qend", "sstart", "send", "evalue", "bitscore", "stitle")

tsv_files <- list.files(path = TSV_DIR, pattern = "\\.tsv$", recursive = TRUE, full.names = TRUE)
tsv_files <- tsv_files[which(file.size(tsv_files) > 0)]

all_blast_data <- tsv_files %>%
  set_names() %>%
  map_dfr(
    ~ read_tsv(
      .x, 
      col_names = blast_cols, 
      col_types = cols(
        pident   = col_double(), length   = col_double(), mismatch = col_double(),     
        gapopen  = col_double(), evalue   = col_double(), bitscore = col_double(),
        .default = col_guess()       
      ), 
      show_col_types = FALSE
    ), 
    .id = "source_file"
  )

all_blast_viral_db_data <- all_blast_data %>%
  mutate(
    Sample = basename(dirname(source_file)),
    Pipeline = basename(dirname(dirname(source_file)))
  ) %>%
  select(Pipeline, Sample, everything(), -source_file)

# Separate Pipelines
unalignedseq_contigs_df <- all_blast_viral_db_data %>% filter(Pipeline == "4_fullvirusDB_unalignedseq_contigs_blastx_out_full_bioproj_contig")
rawseq_contigs_unaligned_df <- all_blast_viral_db_data %>% filter(Pipeline == "4_fullvirusDB_rawseq_contigs_unaligned_blastx_out_full_bioproj_contig")

rm(all_blast_data) # Free memory


# ---------------------------------------------------------
# 2. Extract and Plot Initial Genus Distributions
# ---------------------------------------------------------
plot_data <- all_blast_viral_db_data %>%
  mutate(
    life_stage = str_extract(Sample, "^[^_]+"),
    organism = str_extract(stitle, "(?<=\\[).*?(?=\\])"),
    genus = word(organism, 1)
  ) %>%
  filter(!is.na(genus))

summary_counts <- plot_data %>%
  group_by(life_stage, genus) %>%
  summarise(hit_count = n(), .groups = "drop") %>%
  group_by(life_stage) %>%
  slice_max(order_by = hit_count, n = 5)

p_genus <- ggplot(summary_counts, aes(x = life_stage, y = hit_count, fill = genus)) +
  geom_bar(stat = "identity", position = "stack", color = "black", linewidth = 0.2) +
  theme_bw() +
  labs(
    title = "Top small-RNA Contig Blastx Hits by Coccidioides Life Stage",
    x = "Life Stage", y = "Number of Contig Hits", fill = "Viral Taxon (1st Word)"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 12, face = "bold"),
        legend.position = "right", plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave(file.path(OUTPUT_DIR, "Top_Contig_Hits_By_Stage.png"), plot = p_genus, width = 8, height = 6)


# ---------------------------------------------------------
# 3. Define NCBI Query Functions
# ---------------------------------------------------------
get_protein_uid <- function(acc) {
  tryCatch({
    res <- entrez_search(db = "protein", term = paste0(acc, "[ACCN]"))
    if (length(res$ids) == 0) return(NA_character_)
    summ <- entrez_summary(db = "protein", id = res$ids[1])
    return(as.character(summ$taxid))
  }, error = function(e) return(NA_character_))
}

get_order <- function(tax_df) {
  if (is.null(tax_df) || (length(tax_df) == 1 && is.na(tax_df))) return(NA_character_) 
  order_row <- tax_df[tax_df$rank == "order", ]
  if (nrow(order_row) > 0) return(order_row$name[1]) else return("Unclassified Order")
}

annotate_blast_taxonomy <- function(blast_df, pipeline_name) {
  print(paste("Processing taxonomy for:", pipeline_name))
  clean_data <- blast_df %>%
    mutate(life_stage = str_extract(Sample, "^[^_]+"), accession = str_remove_all(sseqid, "^[a-z]+\\||\\|$"))
  
  unique_accessions <- unique(clean_data$accession)
  uids <- pbsapply(unique_accessions, get_protein_uid)
  
  tax_mapping <- data.frame(accession = unique_accessions, uid = uids, stringsAsFactors = FALSE)
  valid_tax_mapping <- tax_mapping[!is.na(tax_mapping$uid), ]
  
  classifications <- classification(valid_tax_mapping$uid, db = 'ncbi')
  valid_tax_mapping$tax_order <- sapply(classifications, get_order)
  
  annotated_data <- clean_data %>%
    left_join(valid_tax_mapping[, c("accession", "tax_order")], by = "accession") %>%
    filter(!is.na(tax_order))
  
  return(annotated_data)
}


# ---------------------------------------------------------
# 4. Execute Taxonomy Fetching
# ---------------------------------------------------------
NCBI_annotated_unaligned <- annotate_blast_taxonomy(unalignedseq_contigs_df, "Pipeline_1")
NCBI_annotated_rawseq <- annotate_blast_taxonomy(rawseq_contigs_unaligned_df, "Pipeline_2")

# Save backups
write_csv(NCBI_annotated_unaligned, file.path(OUTPUT_DIR, "Pipeline1_annotated_unaligned_backup.csv"))
write_csv(NCBI_annotated_rawseq, file.path(OUTPUT_DIR, "Pipeline2_annotated_rawseqcontigs_backup.csv"))


# ---------------------------------------------------------
# 5. Extract High-Priority Target Contigs
# ---------------------------------------------------------
mycovirus_orders <- c("Ghabrivirales", "Imitervirales", "Wolframvirales", "Ortervirales")

filter_mycoviruses <- function(annotated_df) {
  annotated_df %>%
    filter(tax_order %in% mycovirus_orders) %>%
    select(Life_Stage = life_stage, Sample_Name = Sample, Contig_ID = qseqid,
           NCBI_Accession = accession, Taxonomic_Order = tax_order, E_value = evalue,
           Identity_Percent = pident, Hit_Description = stitle) %>%
    arrange(Life_Stage, Taxonomic_Order, E_value)
}

Pipeline1_mycovirus_contigs <- filter_mycoviruses(NCBI_annotated_unaligned)
Pipeline2_mycovirus_contigs <- filter_mycoviruses(NCBI_annotated_rawseq)

write_csv(Pipeline1_mycovirus_contigs, file.path(OUTPUT_DIR, "Pipeline1_High_Priority_Mycovirus_Contigs.csv"))
write_csv(Pipeline2_mycovirus_contigs, file.path(OUTPUT_DIR, "Pipeline2_High_Priority_Mycovirus_Contigs.csv"))

print("Taxonomic parsing and filtering complete.")