
# ============================================
# 🐍 Snakefile for Pangenomic Analysis Pipeline
# ============================================
# 📅 Date: 2025-05-19
# 👤 Creator: Julian [📝 Registered User]
# 📁 Project: HOMDv4 Anvi'o 8 Pangenomes
# 🧪 Description:
#     This Snakefile defines the workflow for generating contigs databases,
#     running CAZyme, HMM annotations, and tracking completion status.
#
# 🛠️ Requirements:
#     - Conda
#     - Anvi'o v8 environment
#     - Python 3.10.15
#     - Anvi'o software:
#       * tRNAscan-SE (v2.0.12)
#       * DIAMOND (v2.1.11)
#       * HMMER (v3.4)
#     - Databases:
#       * CAZymes (v13)
#       * HMMS (r214.1)
#           * Ribosomal rRNA genes
#           * Transfer rRNA genes
#           * Bacteria (Bacteria 71), Archaea (76), and Eukaryotes (Protista 83) single-copy genes
#       * KEGG Modules and Orthologs (v2023-09-22; snapshot)
#       * NCBI COGs (COG20)
#       * Pfam (v37.2)
#       * GTDB (v214; SCG taxonomy)
#       * GTDB (v214; tRNA taxonomy)
#     - Required Snakemake software:
#     - Graphviz (for rulegraph)
#
# 📌 Notes:
#     - 'contigs.db' is passed as a parameter, not checked as input
#     - Elapsed time is logged in dd:hh:mm:ss format
#     - Output logs and done flags are stored in structured directories
#
# ============================================

# ========== CONFIGURATION ==========
import os

# Use the current working directory as the base
CURRENT_DIR = os.getcwd()

# Input files
GENOMES_LIST = os.path.join(CURRENT_DIR, "../genome_id-8487.txt")

# Output directory for species-specific pangenomes
DONE_DIR = os.path.join(CURRENT_DIR, "99_done")
EDITED_ASSEMBLY_DIR = os.path.join(CURRENT_DIR, "02_edited_assemblies")
CONTIGS_DB_DIR = os.path.join(CURRENT_DIR, "03_contigs_db")

# Read genome ID list
with open(GENOMES_LIST) as f:
    genomes_list = [line.strip() for line in f if line.strip()]

# ========== RULES ==========

rule all:
    input:
        expand(os.path.join(DONE_DIR, "{genome}-contigs_db.done"), genome=genomes_list),
        expand(os.path.join(DONE_DIR, "{genome}-cazymes.done"), genome=genomes_list),
        expand(os.path.join(DONE_DIR, "{genome}-hmms.done"), genome=genomes_list),
        expand(os.path.join(DONE_DIR, "{genome}-trnas.done"), genome=genomes_list),
        expand(os.path.join(DONE_DIR, "{genome}-pfams.done"), genome=genomes_list),
        expand(os.path.join(DONE_DIR, "{genome}-ncbi_cogs.done"), genome=genomes_list),
        expand(os.path.join(DONE_DIR, "{genome}-kegg_kofams.done"), genome=genomes_list),
        expand(os.path.join(DONE_DIR, "{genome}-scg_taxonomy.done"), genome=genomes_list),
        expand(os.path.join(DONE_DIR, "{genome}-trna_taxonomy.done"), genome=genomes_list)

# Create contigs database from edited assemblies
# IMPORTANT: creating a DONE file is essential to avoid snakemake crashing after each annotation step since the contigs.db is modified after each annotation
rule create_contigs_db:
    input:
        edited_fasta=os.path.join(EDITED_ASSEMBLY_DIR, "{genome}.fa")
    output:
        contigs_db=os.path.join(CONTIGS_DB_DIR, "{genome}-contigs.db"),
        done_contigs_db=os.path.join(DONE_DIR, "{genome}-contigs_db.done")
    log:
        "00_log/contigs_db/{genome}-contigs.db.log"
    threads: lambda wildcards, input: max(1, min(2, os.cpu_count()))
    shell:
        '''
        mkdir -p 00_log/contigs_db
        anvi-gen-contigs-database -f {input.edited_fasta} \
                                -o {output.contigs_db} \
                                --project-name {wildcards.genome} \
                                --num-threads {threads} \
                                &> {log}
        touch {output.done_contigs_db}
        '''

# Rule to annotate with CAZymes (v13) with HMMER (hmmsearch)
rule run_cazymes:
    input:
        done_contigs_db=os.path.join(DONE_DIR, "{genome}-contigs_db.done")
    params:
        contigs_db=lambda wildcards: os.path.join(CONTIGS_DB_DIR, f"{wildcards.genome}-contigs.db")
    output:
        done_cazymes=os.path.join(DONE_DIR, "{genome}-cazymes.done")
    log: 
        "00_log/cazymes/{genome}-cazymes.log"
    threads: lambda wildcards, input: max(6, min(8, os.cpu_count()))
    shell:
        '''
        mkdir -p 00_log/cazymes
        anvi-run-cazymes -c {params.contigs_db} \
                         --num-threads {threads} \
                         --hmmer-program "hmmsearch" \
                         &> {log}
        touch {output.done_cazymes}
        '''

# Rule to annotate with HMMs with HMMER (hmmscan) for ribosomal RNA genes and single-copy genes of Archeaea, Bacteria, and Protista DBs 
rule run_hmms:
    input:
        done_contigs_db=os.path.join(DONE_DIR, "{genome}-contigs_db.done")
    params:
        contigs_db=lambda wildcards: os.path.join(CONTIGS_DB_DIR, f"{wildcards.genome}-contigs.db")
    output:
        done_hmms=os.path.join(DONE_DIR, "{genome}-hmms.done")
    log: 
        "00_log/hmms/{genome}-hmms.log"
    threads: lambda wildcards, input: max(6, min(8, os.cpu_count()))
    shell:
        '''
        mkdir -p 00_log/hmms
        anvi-run-hmms -c {params.contigs_db} \
                      --num-threads {threads} \
                      --hmmer-program "hmmscan" \
                      &> {log}
        touch {output.done_hmms}
        '''

# Rule to scan tRNAs (tRNAscan-SE; v2.0.12)
rule scan_trnas:
    input:
        done_contigs_db=os.path.join(DONE_DIR, "{genome}-contigs_db.done")
    params:
        contigs_db=lambda wildcards: os.path.join(CONTIGS_DB_DIR, f"{wildcards.genome}-contigs.db")
    output:
        done_trnas=os.path.join(DONE_DIR, "{genome}-trnas.done")
    log: 
        "00_log/trnas/{genome}-trnas.log"
    threads: lambda wildcards, input: max(6, min(8, os.cpu_count()))
    shell:
        '''
        mkdir -p 00_log/trnas
        anvi-scan-trnas -c {params.contigs_db} \
                        --num-threads {threads} \
                        &> {log}
        touch {output.done_trnas}
        '''

# Rule run Pfams (v37.2) with HMMER (hmmsearch)
rule run_pfams:
    input:
        done_contigs_db=os.path.join(DONE_DIR, "{genome}-contigs_db.done")
    params:
        contigs_db=lambda wildcards: os.path.join(CONTIGS_DB_DIR, f"{wildcards.genome}-contigs.db")
    output:
        done_pfams=os.path.join(DONE_DIR, "{genome}-pfams.done")
    log: 
        "00_log/pfams/{genome}-pfams.log"
    threads: lambda wildcards, input: max(6, min(10, os.cpu_count()))
    shell:
        '''
        mkdir -p 00_log/pfams
        anvi-run-pfams -c {params.contigs_db} \
                        --num-threads {threads} \
                        --hmmer-program "hmmsearch" \
                        &> {log}
        touch {output.done_pfams}
        '''

# Rule run NCBI COGs (COG20) with DIAMOND (v2.1.11)
rule run_ncbi_cogs:
    input:
        done_contigs_db=os.path.join(DONE_DIR, "{genome}-contigs_db.done")
    params:
        contigs_db=lambda wildcards: os.path.join(CONTIGS_DB_DIR, f"{wildcards.genome}-contigs.db")
    output:
        done_ncbi_cogs=os.path.join(DONE_DIR, "{genome}-ncbi_cogs.done")
    log: 
        "00_log/ncbi_cogs/{genome}-ncbi_cogs.log"
    threads: lambda wildcards, input: max(4, min(8, os.cpu_count()))
    shell:
        '''
        mkdir -p 00_log/ncbi_cogs
        anvi-run-ncbi-cogs -c {params.contigs_db} \
                            --num-threads {threads} \
                            --search-with "diamond" \
                            &> {log}
        touch {output.done_ncbi_cogs}
        '''

# Rule run KEGG Modules / KOfam (v2023-09-22) with HMMER (hmmsearch)
rule run_kegg_kofams:
    input:
        done_contigs_db=os.path.join(DONE_DIR, "{genome}-contigs_db.done")
    params:
        contigs_db=lambda wildcards: os.path.join(CONTIGS_DB_DIR, f"{wildcards.genome}-contigs.db")
    output:
        done_kegg_kofams=os.path.join(DONE_DIR, "{genome}-kegg_kofams.done")
    log: 
        "00_log/kegg_kofams/{genome}-kegg_kofams.log"
    threads: lambda wildcards, input: max(8, min(12, os.cpu_count()))
    shell:
        '''
        mkdir -p 00_log/kegg_kofams
        anvi-run-kegg-kofams -c {params.contigs_db} \
                      --num-threads {threads} \
                      --hmmer-program "hmmsearch" \
                      &> {log}
        touch {output.done_kegg_kofams}
        '''

# Rule run SCG taxonomy (GTDB v214)
rule run_scg_taxonomy:
    input:
        done_contigs_db=os.path.join(DONE_DIR, "{genome}-contigs_db.done"),
        done_hmms=os.path.join(DONE_DIR, "{genome}-hmms.done")
    params:
        contigs_db=lambda wildcards: os.path.join(CONTIGS_DB_DIR, f"{wildcards.genome}-contigs.db")
    output:
        done_scg_taxonomy=os.path.join(DONE_DIR, "{genome}-scg_taxonomy.done")
    log: 
        "00_log/scg_taxonomy/{genome}-scg_taxonomy.log"
    threads: lambda wildcards, input: max(4, min(8, os.cpu_count()))
    shell:
        '''
        mkdir -p 00_log/scg_taxonomy
        anvi-run-scg-taxonomy -c {params.contigs_db} \
                      --num-parallel-processes 1 \
                      --num-threads {threads} \
                      &> {log}
        touch {output.done_scg_taxonomy}
        '''

# Rule run tRNA taxonomy (GTDB v214)
rule run_trna_taxonomy:
    input:
        done_contigs_db=os.path.join(DONE_DIR, "{genome}-contigs_db.done"),
        done_trnas=os.path.join(DONE_DIR, "{genome}-trnas.done")
    params:
        contigs_db=lambda wildcards: os.path.join(CONTIGS_DB_DIR, f"{wildcards.genome}-contigs.db")
    output:
        done_trna_taxonomy=os.path.join(DONE_DIR, "{genome}-trna_taxonomy.done")
    log: 
        "00_log/trna_taxonomy/{genome}-trna_taxonomy.log"
    threads: lambda wildcards, input: max(6, min(12, os.cpu_count()))
    shell:
        '''
        mkdir -p 00_log/trna_taxonomy
        anvi-run-trna-taxonomy -c {params.contigs_db} \
                      --num-parallel-processes 1 \
                      --num-threads {threads} \
                      &> {log}
        touch {output.done_trna_taxonomy}
        '''

# Rule to remove all output files
rule clean:
    message:
        "Removing all output files..."
    shell:
        """
        rm -rf 00_log/
        rm -rf {CONTIGS_DB_DIR}
        rm -rf {DONE_DIR}
        """
