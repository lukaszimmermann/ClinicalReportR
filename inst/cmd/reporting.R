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
# update CiVIC data
###################

civic_evidence <- read.table('https://civic.genome.wustl.edu/downloads/nightly/nightly-ClinicalEvidenceSummaries.tsv', sep="\t", header=T, fill = T, quote = "\"", comment.char = "%") %>%
  dplyr::rename(chr=chromosome, alt=variant_bases, ref=reference_bases) %>%
  filter(evidence_status == "accepted")

civic_genes <- civic_evidence %>%
  dplyr::filter(drugs != "") %>%
  dplyr::group_by(gene) %>%
  # TODO: check if existing concatenations of drugs are due to combination therapy (here we throw them all together)
  dplyr::summarise(drugs = paste(unique(stringr::str_trim(unlist(stringr::str_split(drugs, ",")))),collapse=" | "),
                   clinical_significance = paste(unique(clinical_significance),collapse=" | "),
                   pubmed_ids = paste(unique(pubmed_id),collapse=" | "))

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
  mutate(chr = stringr::str_extract(chr, "[0-9,X,Y]+")) %>%
  # select only fixed VCF columns plus VEP annotations!
  dplyr::select(chr, start, end, width, location, ref = REF, alt = ALT, qual = QUAL, filter = FILTER, CSQ) %>%
  tidyr::unnest(CSQ) %>%
  tidyr::separate("CSQ", fields, sep = "\\|") %>%
#  left_join(civic_evidence, by = c("chr", "start", "ref", "alt")) %>%
#  dplyr::rename(civic_drugs = drugs) %>%
  filter(filter == "PASS") %>% # filter quality
  filter(PICK == 1) %>% # filter only transcripts that VEP picked
  filter(BIOTYPE == "protein_coding" & Consequence != "synonymous_variant" & Consequence != "intron_variant") %>%
  mutate(Consequence = stringr::str_replace_all(stringr::str_extract(Consequence, "^(?:(?!_variant)\\w)*"), "_", " "),
         reference_build = "GRCh37",
         HGNC_ID = as.integer(HGNC_ID),
         dbSNP = as.character(stringr::str_extract_all(Existing_variation, "rs\\w+")),
         COSMIC = as.character(stringr::str_extract_all(Existing_variation, "COSM\\w+")),
         DNA = stringr::str_extract(HGVSc, "(?<=:).*"),
         Protein = stringr::str_extract(HGVSp, "(?<=:).*")) %>% # positive lookbehind
  dplyr::select(-Gene) %>%       # drop Ensembl Gene ID as we're using HUGO from here on
  dplyr::rename(Gene = SYMBOL, Type = VARIANT_CLASS, Mutation = Protein) %>%
  filter(LoF != "" | startsWith(SIFT, "deleterious") | endsWith(PolyPhen, "damaging"))
  #tidyr::unite_("Mutation", c("Type", "DNA", "Protein", "Consequence"), sep="\n")

db_baseurl = 'http://localhost:5000/biograph_genes?where={"meta_information.hgnc_id":{"$in":['
querystring = URLencode(paste(db_baseurl, paste(mvld$HGNC_ID, collapse = ","), ']}}', sep=""))

db_query <- fromJSON(querystring, flatten = T)
oncogenes <- tbl_df(db_query$`_items`)
mvld <- mvld %>%
  left_join(oncogenes, by=c("HGNC_ID" = "meta_information.hgnc_id"))

# helper function extracting only cancer-relevant drugs
extract_cancer_drugs <- function(x) {
  if (is.null(x)) {
    return("")
  }
  y <- tbl_df(x) %>%
    dplyr::filter(base::grepl("^L.*", ATC_code)) %>%
    dplyr::filter(!is.na(drug_name)) %>%
    dplyr::mutate(drug_name = tolower(drug_name))
  paste(unique(y$drug_name), collapse = ",")
}

# driver genes with mutation
lof_driver <- mvld %>%
  dplyr::filter(nodes.is_driver) %>%
  mutate(Driver = lapply(meta_information.driver_information, function(x) {  paste(unique(x$driver_type), sep = "\n", collapse = "\n") }),
         Pathway = lapply(meta_information.driver_information, function(x) {  ifelse(is.null(x$core_pathway), "", x$core_pathway) }),
         Process = lapply(meta_information.driver_information, function(x) {  ifelse(is.null(x$Process), "", x$Process) }),
         Therapy = lapply(meta_information.drugs, extract_cancer_drugs)
         ) %>%
  dplyr::select(Gene, Mutation, Driver, Pathway, Process, Therapy)

# drug targets with mutation
lof_variant_dt_table <- mvld %>%
  dplyr::filter(!nodes.is_driver) %>%
  #dplyr::filter(!unlist(lapply(meta_information.drugs, is.null))) %>%
  mutate(Pathway = lapply(meta_information.driver_information, function(x) {  ifelse(is.null(x$core_pathway), "", x$core_pathway) }),
         Process = lapply(meta_information.driver_information, function(x) {  ifelse(is.null(x$Process), "", x$Process) }),
         Therapy = lapply(meta_information.drugs, extract_cancer_drugs)
  ) %>%
  dplyr::filter(Therapy != "") %>%
  dplyr::select(Gene, Mutation, Pathway, Process, Therapy)

# civic targets with mutation
lof_civic_dt_table <- mvld %>%
  left_join(civic_genes, by=c("Gene" = "gene")) %>%
  filter(!is.na(drugs)) %>%
  dplyr::select(Gene, Mutation, Drugs = drugs, Pubmed = pubmed_ids)

# mutation-specific annotations (from civic)
drug_variants <- mvld %>%
  inner_join(civic_evidence, by = c("chr", "start", "ref", "alt")) %>%
  mutate(drugs = as.character(drugs)) %>%
  filter(stringr::str_length(stringr::str_trim((drugs))) > 0) %>%
  filter(variant_origin == "Somatic Mutation") %>%
  #group_by(variant_id) %>%
  #summarise()
  #dplyr::select(Gene, Mutation, Drugs = drugs, Disease = disease, Biomarker = evidence_type, Effect = clinical_significance, Evidence = evidence_level, Pubmed = pubmed_id) %>%
  dplyr::select(Gene, Mutation, Drugs = drugs, Disease = disease, Evidence = evidence_level, Pubmed = pubmed_id) %>%
  arrange(Evidence)

###################
#
# write report
#
###################

# write to docx (report)
template_file <- system.file('extdata','template_report_en.docx',package = 'ClinicalReportR')
mydoc <- ReporteRs::docx(template = template_file)


# Some default props
body.par.props = parProperties(text.align = "center",
                               border.bottom = borderNone(),
                               border.left = borderNone())
body.cell.props = cellProperties(padding = 3)
header.par.props = parProperties(text.align = "center")

options('ReporteRs-default-font' = "Verdana")

# DRIVER
if (nrow(lof_driver) > 0) {
  my_driver_FTable = ReporteRs::FlexTable(data = as.data.frame(lof_driver), add.rownames = FALSE,
                                          body.par.props = body.par.props,
                                          body.cell.props = body.cell.props,
                                          header.par.props = header.par.props) %>%
    setFlexTableWidths(widths = c(.8, 1.2, 1, 1, 1, 2)) %>%
    setFlexTableBorders(inner.vertical = borderProperties(width = 0),
                        inner.horizontal = borderProperties(width = 0), outer.vertical = borderProperties(width = 0),
                        outer.horizontal = borderProperties(width = 2)) %>%
    addHeaderRow(value = c('Somatic Mutations in Driver Genes'), colspan = c(ncol(lof_driver)),
                 text.properties = textProperties(color = "white", font.size = 16),
                 cell.properties = cellProperties(background.color = "#14731C"),
                 first = TRUE)

  mydoc <- ReporteRs::addFlexTable(mydoc, my_driver_FTable, bookmark = "lof_driver")
}

# LOF (direct)
if (nrow(lof_variant_dt_table) > 0) {
  my_driver_FTable = ReporteRs::FlexTable(data = as.data.frame(lof_variant_dt_table), add.rownames = FALSE,
                                          body.par.props = body.par.props,
                                          body.cell.props = body.cell.props,
                                          header.par.props = header.par.props) %>%
    setFlexTableWidths(widths = c(.8, 1.2, 1, 1, 3)) %>%
    setFlexTableBorders(inner.vertical = borderProperties(width = 0),
                        inner.horizontal = borderProperties(width = 0), outer.vertical = borderProperties(width = 0),
                        outer.horizontal = borderProperties(width = 2)) %>%
    addHeaderRow(value = c('Direct Association (Mutation in drug target)'), colspan = c(ncol(lof_variant_dt_table)), first = TRUE) %>%
    addHeaderRow(value = c('Somatic Mutations in Pharmaceutical Target Proteins'), colspan = c(ncol(lof_variant_dt_table)),
                 text.properties = textProperties(color = "white", font.size = 16),
                 cell.properties = cellProperties(background.color = "#14731C"),
                 first = TRUE)

  mydoc <- ReporteRs::addFlexTable(mydoc, my_driver_FTable, bookmark = "lof_variant_dt_table")
}

# LOF CiVIC (indirect)
if (nrow(lof_civic_dt_table) > 0) {
  my_driver_FTable = ReporteRs::FlexTable(data = as.data.frame(lof_civic_dt_table), add.rownames = FALSE,
                                          body.par.props = body.par.props,
                                          body.cell.props = body.cell.props,
                                          header.par.props = header.par.props) %>%
    setFlexTableWidths(widths = c(.8, 1.2, 2.5, 2.5)) %>%
    setFlexTableBorders(inner.vertical = borderProperties(width = 0),
                        inner.horizontal = borderProperties(width = 0), outer.vertical = borderProperties(width = 0),
                        outer.horizontal = borderProperties(width = 2)) %>%
    addHeaderRow(value = c('Indirect Association (other Mutations with known effect on drug)'), colspan = c(ncol(lof_civic_dt_table)), first = TRUE) %>%
    addHeaderRow(value = c('Somatic Mutations in Pharmaceutical Target Proteins'), colspan = c(ncol(lof_civic_dt_table)),
                 text.properties = textProperties(color = "white", font.size = 16),
                 cell.properties = cellProperties(background.color = "#14731C"),
                 first = TRUE)

  mydoc <- ReporteRs::addFlexTable(mydoc, my_driver_FTable, bookmark = "lof_civic_dt_table")
}

# CiVIC
if (nrow(drug_variants) > 0) {
  my_driver_FTable = ReporteRs::FlexTable(data = as.data.frame(drug_variants), add.rownames = FALSE,
                                          body.par.props = body.par.props,
                                          body.cell.props = body.cell.props,
                                          header.par.props = header.par.props) %>%
    setFlexTableWidths(widths = c(.8, 1.2, 2, 1, 1, 1)) %>%
    setFlexTableBorders(inner.vertical = borderProperties(width = 0),
                        inner.horizontal = borderProperties(width = 0), outer.vertical = borderProperties(width = 0),
                        outer.horizontal = borderProperties(width = 2)) %>%
    addHeaderRow(value = c('Somatic Mutations with known pharmacogenetic effect'), colspan = c(ncol(drug_variants)),
                 text.properties = textProperties(color = "white", font.size = 16),
                 cell.properties = cellProperties(background.color = "#14731C"),
                 first = TRUE)

  mydoc <- ReporteRs::addFlexTable(mydoc, my_driver_FTable, bookmark = "drug_variants")
}

ReporteRs::writeDoc(mydoc, file = reportFile)
