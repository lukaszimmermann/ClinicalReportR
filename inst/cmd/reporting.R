#!/usr/bin/env Rscript --no-save --no-restore --no-init-file --no-site-file

# reporting.R
# Julian Heinrich (julian.heinrich@uni-tuebingen.de)
#
# This script parses a vcf file and generates two output files:
# a xml and a docx file, each containing information about the most
# relevant mutations found in the input vcf that can be used for
# clinical reporting.

options(warn=-1)

# parse command-line parameters
option_list = list(
  optparse::make_option(c("-f", "--file"), type = "character", help = "the input file in vcf format", default = NULL),
  optparse::make_option(c("-r", "--report"), type = "character", help = "the file name for the detailed output report", default = NULL),
  #optparse::make_option(c("-H", "--host"), type = "character", help = "the hostname of the mydrug database", default = NULL),
  #optparse::make_option(c("-d", "--database"), type = "character", help = "the database of the mydrug database", default = NULL),
  #optparse::make_option(c("-u", "--username"), type = "character", help = "the username of the mydrug database", default = NULL),
  #optparse::make_option(c("-p", "--password"), type = "character", help = "the password of the mydrug database", default = NULL),
  #optparse::make_option(c("-P", "--port"), type = "character", help = "the port of the mydrug database", default = 3306),
  #optparse::make_option(c("-c", "--vepconfig"), type = "character", help = "ensembl-vep configuration file", default = NULL),
  optparse::make_option(c("-t", "--test"), type = "logical", help = "generate test report", default = FALSE)
)

opt_parser <- optparse::OptionParser(option_list = option_list)
opt <- optparse::parse_args(opt_parser)

if (!opt$test && (is.null(opt$file) || !file.exists(opt$file))) {
  optparse::print_help(opt_parser)
  stop("Please supply an existing input file via -f")
}

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

lapply(c(list.of.packages.cran, list.of.packages.bioconductor), library, character.only=T)
#library(dplyr)


# steps to make the ReporteRs library load:
# 1. sudo R CMD javareconf
# 2. sudo ln -f -s $(/usr/libexec/java_home)/jre/lib/server/libjvm.dylib /usr/local/lib
# 3. install.packages("rJava", type = "source")



# set this manually to run code interactively
debug <- opt$test
#debug <- TRUE

vcfFile <- opt$file
reportFile <- opt$report

if (debug) {
  # for testing
  #vcfFile <- "inst/extdata/strelka.passed.missense.somatic.snvs-1_annotated.vcf"
  #vcfFile <- "inst/extdata/strelka.passed.missense.somatic.snvs_short.vcf"

  # test without annotation
  vcfFile <- "inst/extdata/strelka.passed.missense.somatic.snvs-1_annotated.vcf"
}

if (is.null(reportFile)) {
  reportFile <- paste(tools::file_path_sans_ext(vcfFile), "docx", sep=".")
}

###################
#
# annotate VCF file
#
###################

vcf <- VariantAnnotation::readVcf(vcfFile)
info <- rownames(VariantAnnotation::info(VariantAnnotation::header(vcf)))
if (!("CSQ" %in% info)) {
  dest <- file.path(tempfile())
  ClinicalReportR::annotate(vcfFile, dest)
  vcf <- VariantAnnotation::readVcf(dest)
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
  left_join(ClinicalReportR::dbs$driver_genes) %>%
  filter(!is.na(Roles)) %>%
  dplyr::select(Gene, Mutation, Roles)

lof_variant_dt_table <- mvld %>%
  left_join(ClinicalReportR::dbs$targets, by=c("Gene" = "gene")) %>%
  filter(!is.na(drugs)) %>%
  dplyr::select(Gene, Mutation, Drugs = drugs, Pubmed = pubmed_ids)

lof_civic_dt_table <- mvld %>%
  left_join(ClinicalReportR::dbs$civic_genes, by=c("Gene" = "gene")) %>%
  filter(!is.na(drugs)) %>%
  dplyr::select(Gene, Mutation, Drugs = drugs, Pubmed = pubmed_ids)

drug_variants <- mvld %>%
  inner_join(ClinicalReportR::dbs$civic_variants, by = c("chr", "start", "ref", "alt")) %>%
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
