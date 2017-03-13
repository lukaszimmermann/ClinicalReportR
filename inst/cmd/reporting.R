#!/usr/bin/env Rscript --no-save --no-restore --no-init-file --no-site-file

# reporting.R
# Julian Heinrich (julian.heinrich@uni-tuebingen.de)
#
# This script parses a vcf file and generates two output files:
# a xml and a docx file, each containing information about the most
# relevant mutations found in the input vcf that can be used for
# clinical reporting.

options(warn=-1)

# make sure that all required packages are available
# this tries to install missing packages that are missing
list.of.packages.cran <- c("dplyr", "dtplyr", "tidyr", "stringr", "splitstackshape", "RMySQL", "ReporteRs", "optparse", "readr")
new.packages <- list.of.packages.cran[!(list.of.packages.cran %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos = "http://cran.rstudio.com/")

list.of.packages.bioconductor <- c("VariantAnnotation")
new.packages <- list.of.packages.bioconductor[!(list.of.packages.bioconductor %in% installed.packages()[,"Package"])]
if(length(new.packages)) {
  source("https://bioconductor.org/biocLite.R")
  biocLite(new.packages)
}

#lapply(c(list.of.packages.cran, list.of.packages.bioconductor), library, character.only=T)
library(dplyr)


# steps to make the ReporteRs library load:
# 1. sudo R CMD javareconf
# 2. sudo ln -f -s $(/usr/libexec/java_home)/jre/lib/server/libjvm.dylib /usr/local/lib
# 3. install.packages("rJava", type = "source")

# parse command-line parameters
option_list = list(
  optparse::make_option(c("-f", "--file"), type = "character", help = "the input file in vcf format", default = NULL),
  optparse::make_option(c("-r", "--report"), type = "character", help = "the file name for the detailed output report", default = NULL),
  optparse::make_option(c("-H", "--host"), type = "character", help = "the hostname of the mydrug database", default = NULL),
  optparse::make_option(c("-d", "--database"), type = "character", help = "the database of the mydrug database", default = NULL),
  optparse::make_option(c("-u", "--username"), type = "character", help = "the username of the mydrug database", default = NULL),
  optparse::make_option(c("-p", "--password"), type = "character", help = "the password of the mydrug database", default = NULL),
  optparse::make_option(c("-P", "--port"), type = "character", help = "the port of the mydrug database", default = 3306),
  optparse::make_option(c("-c", "--vepconfig"), type = "character", help = "ensembl-vep configuration file", default = NULL)
)

opt_parser <- optparse::OptionParser(option_list = option_list)
opt <- optparse::parse_args(opt_parser)

if (is.null(opt$file) || !file.exists(opt$file)) {
  optparse::print_help(opt_parser)
  stop("Please supply an existing input file via -f")
}

vcfFile <- opt$file
reportFile <- opt$report

if (is.null(reportFile)) {
  reportFile <- paste(tools::file_path_sans_ext(vcfFile), "docx", sep=".")
}

###################
#
# create database objects
#
###################

# create civic variant database from nightly updates
civic_variants <- read.table('https://civic.genome.wustl.edu/downloads/nightly/nightly-ClinicalEvidenceSummaries.tsv', sep="\t", header=T, fill = T, quote = "\"", comment.char = "%") %>%
  dplyr::rename(chr=chromosome, alt=variant_bases, ref=reference_bases) %>%
  filter(evidence_status == "accepted")

civic_genes <- civic_variants %>%
  dplyr::filter(drugs != "") %>%
  dplyr::group_by(gene) %>%
  # TODO: check if existing concatenations of drugs are due to combination therapy (here we throw them all together)
  dplyr::summarise(drugs = paste(unique(stringr::str_trim(unlist(stringr::str_split(drugs, ",")))),collapse=" | "),
                   clinical_significance = paste(unique(clinical_significance),collapse=" | "),
                   pubmed_ids = paste(unique(pubmed_id),collapse=" | "))

# Drug targets
my_drug_con <- dplyr::src_mysql(opt$database, opt$host, as.integer(opt$port), opt$user, opt$password)

compounds <- dplyr::tbl(my_drug_con, "compound") %>%
  dplyr::collect()
compound2gene <- dplyr::tbl(my_drug_con, "compound2gene") %>%
  dplyr::collect()
variant2compound <- dplyr::tbl(my_drug_con, "variant2compound") %>%
  dplyr::collect()

targets <- compounds %>%
  dplyr::left_join(compound2gene) %>%
  dplyr::filter(interaction_type == "target") %>%
  splitstackshape::cSplit("ATC", sep = "|", direction = "long") %>%
  dplyr::filter_(quote(base::grepl("^L.*", ATC))) %>%
  dplyr::select(interaction_type = target_action, name, gene = gene_symbol, isFdaApproved, drugbank_pubmed_id, iuphar_pubmed_id) %>%
  dplyr::group_by(gene) %>%
  dplyr::summarise_(
    drugs = quote(paste(unique(stringr::str_trim(unlist(stringr::str_split(name, "\\|")))),collapse=" | ")),
    interaction_type = quote(paste(unique(stringr::str_trim(unlist(stringr::str_split(interaction_type, "\\|")))),collapse=" | ")),
    pubmed_ids = quote(paste(unique(stringr::str_trim(unlist(c(stringr::str_split(drugbank_pubmed_id, "\\|"), stringr::str_split(iuphar_pubmed_id, "\\|"))))), collapse=" | "))
  )

driver_genes <- dplyr::tbl_df(read.table(system.file('extdata','Drivers_type_role.tsv', package = 'ClinicalReportR'), sep="\t", header=T)) %>%
  dplyr::rename(Gene = geneHGNCsymbol) %>%
  dplyr::mutate(Gene = as.character(Gene)) %>%
  dplyr::group_by(Gene) %>%
  dplyr::summarise(Roles = paste(unique(Role), collapse=", "),
            Driver_types = paste(unique(Driver_type), collapse=", "))

###################
#
# read VCF file
#
###################

# for testing
#vcf <- VariantAnnotation::readVcf("inst/extdata/strelka.passed.missense.somatic.snvs-1_annotated.vcf")
vcf <- VariantAnnotation::readVcf(vcfFile)
info <- rownames(VariantAnnotation::info(VariantAnnotation::header(vcf)))
if (!("CSQ" %in% info)) {
  cmd <- "vep.pl"
  if (opt$vepconfig) {
    cmd <- paste("vep.pl --config", opt$vepconfig)
  }
  system(cmd)
}

header <- stringr::str_sub(VariantAnnotation::info(VariantAnnotation::header(vcf))["CSQ",3], 51)
fields <- stringr::str_split(header, "\\|")[[1]]

ann <- dplyr::tbl_df(VariantAnnotation::info(vcf)) %>%
  dplyr::select(CSQ)
fixed <- VariantAnnotation::fixed(vcf)
ranges <- SummarizedExperiment::rowRanges(vcf)
location <- tbl_df(data.frame(chr = SummarizedExperiment::seqnames(ranges), SummarizedExperiment::ranges(ranges))) %>%
  dplyr::rename(location = names)
fixed$ALT <- unlist(lapply(fixed$ALT, toString))

# minium variant level data (MLVD) according to
# Ritter et al. (https://genomemedicine.biomedcentral.com/articles/10.1186/s13073-016-0367-z)
mvld <- location %>%
  bind_cols(tbl_df(fixed)) %>%
  bind_cols(ann) %>%
  filter(FILTER == "PASS") %>% # filter quality
  mutate(chr = stringr::str_extract(chr, "[0-9,X,Y]+")) %>%
  # select only fixed VCF columns plus VEP annotations!
  dplyr::select(chr, start, end, width, location, ref = REF, alt = ALT, qual = QUAL, filter = FILTER, CSQ) %>%
  tidyr::unnest(CSQ) %>%
  tidyr::separate("CSQ", fields, sep = "\\|") %>%
  filter(PICK == 1) %>% # filter only transcripts that VEP picked
  filter(BIOTYPE == "protein_coding" & Consequence != "synonymous_variant" | Consequence != "intron_variant") %>%
  mutate(Consequence = stringr::str_replace_all(stringr::str_extract(Consequence, "^(?:(?!_variant)\\w)*"), "_", " "),
         reference_build = "GRCh37",
         dbSNP = as.character(stringr::str_extract_all(Existing_variation, "rs\\w+")),
         COSMIC = as.character(stringr::str_extract_all(Existing_variation, "COSM\\w+")),
         DNA = stringr::str_extract(HGVSc, "(?<=:).*"),
         Protein = stringr::str_extract(HGVSp, "(?<=:).*")) %>% # positive lookbehind
  dplyr::select(-Gene) %>%       # drop Ensembl Gene ID as we're using HUGO from here on
  dplyr::rename(Gene = SYMBOL, Type = VARIANT_CLASS) %>%
  filter(LoF != "" | startsWith(SIFT, "deleterious") | endsWith(PolyPhen, "damaging")) %>%
  tidyr::unite_("Mutation", c("Type", "DNA", "Protein", "Consequence"), sep="\n")

lof_driver <- mvld %>%
  left_join(driver_genes) %>%
  filter(!is.na(Roles)) %>%
  dplyr::select(Gene, Mutation, Roles)

lof_variant_dt_table <- mvld %>%
  left_join(targets, by=c("Gene" = "gene")) %>%
  filter(!is.na(drugs)) %>%
  dplyr::select(Gene, Mutation, Drugs = drugs, Pubmed = pubmed_ids)

lof_civic_dt_table <- mvld %>%
  left_join(civic_genes, by=c("Gene" = "gene")) %>%
  filter(!is.na(drugs)) %>%
  dplyr::select(Gene, Mutation, Drugs = drugs, Pubmed = pubmed_ids)

drug_variants <- mvld %>%
  inner_join(civic_variants, by = c("chr", "start", "ref", "alt")) %>%
  mutate(drugs = as.character(drugs)) %>%
  filter(stringr::str_length(stringr::str_trim((drugs))) > 0) %>%
  filter(variant_origin == "Somatic Mutation") %>%
  #group_by(variant_id) %>%
  #summarise()
  dplyr::select(Gene, Mutation, Drugs = drugs, Disease = disease, Biomarker = evidence_type, Effect = clinical_significance, Evidence = evidence_level, Pubmed = pubmed_id) %>%
  arrange(Evidence)

###################
#
# write report
#
###################

# write to docx (report)
template_file <- system.file('extdata','template_report_en.docx',package = 'ClinicalReportR')
mydoc <- ReporteRs::docx(template = template_file)

# DRIVER
if (nrow(lof_driver) > 0) {
  my_driver_FTable = ReporteRs::light.table(data = as.data.frame(lof_driver), add.rownames = FALSE)
  mydoc <- ReporteRs::addFlexTable(mydoc, my_driver_FTable, bookmark = "lof_driver")
}

# LOF (direct)
if (nrow(lof_variant_dt_table) > 0) {
  my_driver_FTable = ReporteRs::light.table(data = as.data.frame(lof_variant_dt_table), add.rownames = FALSE)
  mydoc <- ReporteRs::addFlexTable(mydoc, my_driver_FTable, bookmark = "lof_variant_dt_table")
}

# LOF CiVIC (indirect)
if (nrow(lof_civic_dt_table) > 0) {
  my_driver_FTable = ReporteRs::light.table(data = as.data.frame(lof_civic_dt_table), add.rownames = FALSE)
  mydoc <- ReporteRs::addFlexTable(mydoc, my_driver_FTable, bookmark = "lof_civic_dt_table")
}

# CiVIC
if (nrow(drug_variants) > 0) {
  my_driver_FTable = ReporteRs::light.table(data = as.data.frame(drug_variants), add.rownames = FALSE)
  mydoc <- ReporteRs::addFlexTable(mydoc, my_driver_FTable, bookmark = "drug_variants")
}

ReporteRs::writeDoc(mydoc, file = reportFile)
