# Human Oral Pangenomes
This file describes the necessary steps to make species-level pangenomes from the Human Oral Microbiome Database.<br><br>
Created  by Julian Torres-Morales ® <br>
Date: May 9, 2025

## What's the motivation?
"This" can be broken down into three reasons:
* To make accessible to the oral microbiology research community, and beyond, with systematically constructed pangenomes that can be inspected, downloaded, and modify by the users.
* Having open-source code ensures our pipelines and workflow are reproducible and subject to the strictest review - you, the users.
By making both the pangenomes and code available, we ensure our pipelines and workflow are reproducible and subject to the strictest review - you, the users.

## Pangenome definition and context
A **pangenome** is the **"complete"** collection of **genes** from members of a closley related taxonomic group - typically a **species**.
It encompases shared (**core**), and unique (**accessory**) genetic material that captures the genetic diversity. It can help us to understand evolution, adaptation, and functional potential of these groups.

## Data
To construct a pangenome we need genomes.
HOMD is an information-rich and multi-omic curated database for oral and aerodigestive tract microbes from humans. This database steps aside from the rest by objectively assigning sequences (genomes and ribosomal genes) to taxonomic groups, refered to as Human Microbiome Taxa (HMT), rather than creating new species names. **In this study, we defined HMT as equivalents to species.** 

## What's the motivation?
"This" can be broken down into three reasons:
* To make accessible to the oral microbiology research community, and beyond, with systematically constructed pangenomes that can be inspected, downloaded, and modify by the users.
* Having open-source code ensures our pipelines and workflow are reproducible and subject to the strictest review - you, the users.
By making both the pangenomes and code available, we ensure our pipelines and workflow are reproducible and subject to the strictest review - you, the users.

Genomes info is available from: https://www.homd.org/genome/genome_table.

# Genome preparation
1. Genomes were downloaded from NCBI on April 8, 2025 using the assembly ID with the program _datasets_. And are availabble from "../20250408_S_HOMDv4_HMP1993/03_genomes/"
```bash
mkdir -p 01_download_genomes 02_contigs_db/{01_raw_assemblies,02_edited_assemblies,03_contigs_db}

# Copy raw fasta
for file in ../20250408_S_HOMDv4_HMP1993/02_assemblies/*.fa
do
cp $file 02_contigs_db/01_raw_assemblies
done

# Copy reformated fasta
for g_id in $(cat genome_id-8487.txt)
do
cp ../20250408_S_HOMDv4_HMP1993/03_genomes/$g_id/$g_id-contigs-prefix-formatted-only.fa 02_contigs_db/02_edited_assemblies/$g_id.fa
done

```
'''
2. We used a snakemake workflow (from anvi'o) to:
    * Reformat the FASTA files: all contigs were kept regardless their size, deflines were renamed to meet anvi'o requirements, and nucleotides with non-canoncical bases were replaced by the letter 'N'.
    * Generated a contigs DB for every genome: open reading frames were predicted, and contigs were soft-split at 20,000 nucleotides.
    * Contigs DBs were annotated:
    * Bacteria 71 set (r214)
    * Ribosomal rRNA genes
    * Transfer rRNA genes
    * CAZymes (v13)
    * NCBI COGs (COG20)
    * KEGG Modules and Orthologs (v2023-09-22; snapshot)
    * Pfam (v37.2)
```bash
conda activate anvio-8

# Prepare test files for Snakemake (n=2 and n=10)
head -n 2 genome_id-8487.txt > genome_id-8487-test.txt
head -n 10 genome_id-8487.txt > genome_id-8487-test.txt


cd 02_contigs_db

# Test Snakefile until it works
# Create the snakemake DAGs with 2 genomes first, then with 10
snakemake --rulegraph | dot -Tpdf > workflow-test.pdf
snakemake --dag | dot -Tpdf > workflow_dag-test.pdf

# Run Snakefile test 
snakemake --jobs 50 --cores 100

# DO NOT RUN this command once the workflow is functional
# Clean output (contigs DBs will be removed permanently)
#snakemake clean -j 1

# To run snakemake on all genomes (n=8487) use the bash exe 
# Run Snakemake through bash and detached
mkdir 99_nohup
nohup ./s-01_run_snakemake_for_contigs_db.sh >> 99_nohup/nohup-01_run_snakemake_for_contigs_db.out 2>&1 &
```
