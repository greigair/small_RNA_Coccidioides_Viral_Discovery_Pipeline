# ---------------------------------------------------------
# Coccidioides small RNA-seq Figure Making
# Generates step-wise data yield charts
# ---------------------------------------------------------

# Load required libraries
library(tidyverse)
library(ggplot2)
library(scales)

# ==============================================================================
# --- USER CONFIGURATION ---
# ==============================================================================
INPUT_CSV <- "data/read_counts.csv"        # Path to your read_counts.csv
OUTPUT_DIR <- "outputs/figures/"           # Directory to save generated plots
# ==============================================================================

# Create output directory if it doesn't exist
if(!dir.exists(OUTPUT_DIR)) {dir.create(OUTPUT_DIR, recursive = TRUE)}

# 1. Read and Summarise Data
read_counts <- read.csv(INPUT_CSV)

summary_read_counts <- read_counts %>%
  group_by(life_stage) %>%
  summarise(
    total_raw = sum(raw_reads, na.rm = TRUE),
    total_unaligned = sum(X1_unaligned_reads, na.rm = TRUE),
    total_contigs = sum(X1_unaligned_seq_contigs, na.rm = TRUE),
    total_viral = sum(X1_viral_unaligned_seq_contigs, na.rm = TRUE)
  ) %>%
  # Force the order of the x-axis so 'Control' is always neatly at the end
  mutate(life_stage = factor(life_stage, levels = c("Arthroconidia", "Arthrocelia", "Mycelia", "Spherule", "Control")))

# Export summary table
write.csv(summary_read_counts, file.path(OUTPUT_DIR, "life_stage_summary_read_counts.csv"), row.names = FALSE)

# 2. Define Plotting Function
plot_attrition <- function(df, y_column, y_label, plot_title, fill_color) {
  ggplot(df, aes(x = life_stage, y = !!sym(y_column))) +
    geom_bar(stat = "identity", fill = fill_color, color = "black", linewidth = 0.3, width = 0.5) +
    geom_text(aes(label = scales::comma(!!sym(y_column))), vjust = -0.5, size = 4) +
    scale_y_continuous(labels = scales::comma) + 
    labs(
      title = plot_title,
      x = NULL, 
      y = y_label
    ) +
    theme_bw() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 11, face = "bold"),
      axis.title.y = element_text(size = 12, face = "bold"),
      axis.text.y = element_text(size = 11),
      plot.title = element_text(hjust = 0.5, face = "bold", size = 14)
    )
}

# 3. Generate Plots
plot_raw <- plot_attrition(summary_read_counts, "total_raw", "Total Reads", "Raw Small RNA-seq Reads", "#4E79A7")
plot_unaligned <- plot_attrition(summary_read_counts, "total_unaligned", "Total Reads", "Unaligned Small RNA-seq Reads", "#F28E2B")
plot_contigs <- plot_attrition(summary_read_counts, "total_contigs", "Total Contigs", "Assembled Contigs", "#E15759")
plot_viral <- plot_attrition(summary_read_counts, "total_viral", "Total Contigs", "Viral Contig Hits", "#76B7B2")

# 4. Define Save Function and Export
save_png <- function(plot_object, file_name) {
  ggsave(
    filename = file.path(OUTPUT_DIR, paste0(file_name, ".png")), 
    plot = plot_object, 
    width = 8,       
    height = 6,      
    dpi = 300,       
    bg = "white"     
  )
}

save_png(plot_raw, "Raw_Small_RNA-seq_Reads")
save_png(plot_unaligned, "Unaligned_Small_RNA-seq_Reads")
save_png(plot_contigs, "Assembled_Contigs")
save_png(plot_viral, "Viral_Contig_Hits")

print("Figure generation complete.")
