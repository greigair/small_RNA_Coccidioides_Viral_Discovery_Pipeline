# small_RNA_Coccidioides_Viral_Discovery_Pipeline

**An In Silico Search for Mycoviruses in Coccidioides posadasii Small RNA Transcriptomes.**

Coccidioides is a dimorphic fungal genus comprising two species C. posadasii and C. immitis. Both species are causative agents of coccidioidomycosis (Valley Fever) a non-contagious pulmonary infection endemic to arid regions of the western hemisphere with the largest area of prevalence being the United States. To date no mycoviruses have been characterised in Coccidioides species. Mycoviruses are well understood to induce changes in host fungal physiology, including hypovirulence. Therefore, possible mycoviral discoveries could lay the groundwork for developing targeted virotherapies. 

Fungal hosts may defend against mycoviral infection through the RNA interference pathway, using viral guide RNAs to guide an RNA-induced silencing complex into digesting and excreting viral transcriptomic material. The aim of this study was to thus investigate the presence of mycoviruses in C. posadasii by analysing public small RNA sequencing depositories.

This process included sRNA host genome alignment, contiguous sequence assembly, and manual filtering. Taxonomic and genomic analyses were conducted to characterise and confirm the origin of suspected viral contigs within currently known viral taxonomies. The pipeline itself included multiple scripts on the Bash terminal, all analysis was completed using the SLURM workload manager on the University of Manchester's Computational Shared Facility (CSF). 
