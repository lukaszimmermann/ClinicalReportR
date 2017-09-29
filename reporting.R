#!/usr/bin/env Rscript --no-save --no-restore --no-init-file --no-site-file

# reporting.R
# Julian Heinrich (julian.heinrich@uni-tuebingen.de)
#
# This script parses a vcf file and generates two output files:
# a xml and a docx file, each containing information about the most
# relevant mutations found in the input vcf that can be used for
# clinical reporting.

options(warn=1)

# parse command-line parameters
option_list = list(
  optparse::make_option(c("-f", "--file"), type = "character", help = "the input file in vcf format", default = NULL),
  optparse::make_option(c("-r", "--report"), type = "character", help = "the file name for the detailed output report", default = NULL)
  #optparse::make_option(c("-t", "--template"), type = "character", help = "the file name of the report template", default = NULL),
  #optparse::make_option(c("-c", "--vepconfig"), type = "character", help = "ensembl-vep configuration file", default = NULL),
  #optparse::make_option(c("-x", "--test"), type = "logical", help = "generate test report", default = FALSE)
)

opt_parser <- optparse::OptionParser(option_list = option_list)
opt <- optparse::parse_args(opt_parser)

# set this manually to run code interactively
#debug <- opt$test
#debug <- TRUE
debug <- FALSE

if (!debug && (is.null(opt$file) || !file.exists(opt$file))) {
  optparse::print_help(opt_parser)
  stop("Please supply a valid input file")
}

# if (!debug && (is.null(opt$template) || !file.exists(opt$template))) {
#   optparse::print_help(opt_parser)
#   stop("Please supply a valid template file")
# }

# make sure that all required packages are available
# this tries to install missing packages that are missing
list.of.packages.cran <- c("dplyr", "dtplyr", "tidyr", "stringr", "splitstackshape", "flextable", "optparse", "readr", "tidyjson", "RCurl")
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

vcfFile <- opt$file
reportFile <- opt$report

if (debug) {
  # for testing
  #vcfFile <- "inst/extdata/strelka.passed.missense.somatic.snvs_annotated.vcf"
  #vcfFile <- "inst/extdata/strelka.passed.nonsense.somatic.snvs.vcf.out.vcf"
  vcfFile <- "inst/extdata/test.vcf"

  # test without annotation
  #vcfFile <- "inst/extdata/strelka.passed.missense.somatic.snvs.vcf"
}

if (is.null(reportFile)) {
  reportFile <- paste(tools::file_path_sans_ext(vcfFile), "docx", sep=".")
  msg <- paste("Invalid output file or option not given. Using", reportFile)
  print(msg)
}


###################
# update CiVIC data
###################

# Collects the most recent data from CiVIC and returns a list with two data frames for genes and evidence.
civic_source = "https://civic.genome.wustl.edu/downloads/nightly/nightly-ClinicalEvidenceSummaries.tsv"
if (debug) {
  civic_source = "inst/extdata/nightly-ClinicalEvidenceSummaries.tsv"
}

civic_evidence <- read.table(civic_source, sep="\t", header=T, fill = T, quote = "\"", comment.char = "%") %>%
  dplyr::rename(chr=chromosome, alt=variant_bases, ref=reference_bases) %>%
  filter(evidence_status == "accepted") %>%
  filter(variant_origin == "Somatic Mutation") %>%
  filter(evidence_type == "Predictive" & evidence_direction == "Supports")

###################
#
# annotate VCF file
#
###################

vcf <- VariantAnnotation::readVcf(vcfFile)
info <- rownames(VariantAnnotation::info(VariantAnnotation::header(vcf)))
if (!("CSQ" %in% info)) {
  stop("Please run VEP on this VCF before generating a report.")
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

# minium variant level data (MVLD) according to
# Ritter et al. (https://genomemedicine.biomedcentral.com/articles/10.1186/s13073-016-0367-z)
mvld <- location %>%
  bind_cols(tbl_df(fixed)) %>%
  bind_cols(ann) %>%
  mutate(chr = stringr::str_extract(chr, "[0-9,X,Y]+")) %>%
  # select only fixed VCF columns plus VEP annotations!
  dplyr::select(chr, start, stop = end, width, location, ref = REF, alt = ALT, qual = QUAL, filter = FILTER, CSQ) %>%
  tidyr::unnest(CSQ) %>%
  tidyr::separate("CSQ", fields, sep = "\\|") %>%
  mutate(Consequence = stringr::str_replace_all(stringr::str_extract(Consequence, "^(?:(?!_variant)\\w)*"), "_", " "),
  #       reference_build = "GRCh37",
         hgnc_id = as.integer(HGNC_ID),
         dbSNP = as.character(stringr::str_extract_all(Existing_variation, "rs\\w+")),
         COSMIC = as.character(stringr::str_extract_all(Existing_variation, "COSM\\w+")),
         DNA = stringr::str_extract(HGVSc, "(?<=:).*"),
         Protein = stringr::str_extract(HGVSp, "(?<=:).*")) %>% # positive lookbehind
  dplyr::select(-Gene, -HGNC_ID) %>%       # drop Ensembl Gene ID as we're using HUGO from here on
  dplyr::rename(gene_symbol = SYMBOL, Type = VARIANT_CLASS) %>%
  dplyr::mutate(Mutation = ifelse(Consequence == "stop gained", Consequence, Protein)) %>%
  filter(filter == "PASS" | filter == ".") %>% # filter quality
  filter(PICK == 1) %>% # filter only transcripts that VEP picked
  filter(BIOTYPE == "protein_coding" & Consequence != "synonymous" & Consequence != "intron")
  #filter(LoF != "" | startsWith(SIFT, "deleterious") | endsWith(PolyPhen, "damaging"))

if (nrow(mvld) == 0) {
  stop("No variants found that passed the QC tests.")
}

# now query our noSQL database for information on drugs and driver status for all genes occuring in the
# mvld. Then create a relational schema for each with hgnc_id as our 'key', resulting in 3 tables, one each for genes, drivers, and drugs.

db_baseurl = 'http://localhost:5000/biograph_genes?where={"hgnc_id":{"$in":["'
querystring = URLencode(paste(db_baseurl, paste(unique(mvld$hgnc_id), collapse = '","'), '"]}}', sep=''))

biograph_json <- as.tbl_json(getURL(querystring))

# get information on genes by hgnc_id
biograph_genes <- biograph_json %>%
  tidyjson::enter_object("_items") %>% gather_array() %>%
  spread_values(
    gene_symbol = jstring("gene_symbol"),
    status = jstring("status"),
    hgnc_id = jstring("hgnc_id"),
    driver_score = jnumber("driver_score")
  ) %>%
  mutate(hgnc_id = as.integer(hgnc_id)) %>%
  mutate(driver_score = ifelse(is.na(driver_score), 0, driver_score)) %>%
  dplyr::select(gene_symbol, hgnc_id, status, driver_score)

biograph_drugs <- biograph_json %>%
  enter_object("_items") %>% gather_array() %>%
  spread_values(
    gene_symbol = jstring("gene_symbol"),
    hgnc_id = jstring("hgnc_id")
    ) %>%
  enter_object("drugs") %>% gather_array() %>%
  spread_values(
    ATC_code = jstring("ATC_code"),
    drug_name = jstring("drug_name"),
    drug_source_name = jstring("source_name"),
    drugbank_id = jstring("drugbank_id"),
    target_action = jstring("target_action"),
    drug_pmid = jstring("pmid"),
    interaction_type = jstring("interaction_type"),
    is_cancer_drug = jlogical("is_cancer_drug")
  ) %>%
  mutate(hgnc_id = as.integer(hgnc_id)) %>%
  mutate(drug_pmid = ifelse(drug_pmid == "null", NA, drug_pmid)) %>%
  # make a row for every pubmed id
  mutate(drug_pmid = str_split(drug_pmid, "\\|")) %>%
  unnest(drug_pmid) %>%
  dplyr::select(-document.id, -array.index)

biograph_driver <- biograph_json %>%
  enter_object("_items") %>% gather_array() %>%
  spread_values(
    gene_symbol = jstring("gene_symbol"),
    hgnc_id = jstring("hgnc_id")
  ) %>%
  enter_object("cancer") %>% gather_array() %>%
  spread_values(
    driver_type = jstring("driver_type"),
    driver_source_name = jstring("source_name"),
    driver_pmid = jstring("pmid")
  ) %>%
  mutate(hgnc_id = as.integer(hgnc_id)) %>%
  left_join(mvld) %>%
  dplyr::select(gene_symbol, Mutation, driver_pmid)

# prepare a tidy dataset, where all information on drugs and drivers is available for all mutations, i.e.
# every row is a unique combination of mutation, transcript, gene, driver status, and drug interactions.
# In addition, we apply some standard filters to pick only high quality and LoF mutations and do some renaming.
# mvld_tidy <- mvld %>%
#   left_join(biograph_genes) %>%
#   left_join(biograph_driver) %>%
#   left_join(biograph_drugs)

# driver genes with mutation (irrespective of being a drug target or not)
lof_driver <- biograph_driver %>%
  dplyr::group_by(gene_symbol) %>%
  dplyr::summarize(Mutation = unique(Mutation), Confidence = n(), References = paste(driver_pmid, collapse = "|")) %>%
  dplyr::arrange(desc(Confidence)) %>%
  dplyr::rename(Gene = gene_symbol)

# cancer drug targets with mutation

# direct association:
# cancer drug targets with mutation
lof_variant_dt_table <- biograph_drugs %>%
  # only cancer drug targets
  filter(is_cancer_drug & interaction_type == "target") %>%
  dplyr::left_join(mvld) %>%
  group_by(gene_symbol, Mutation, drug_name) %>%
  summarise(Confidence = n(), References = paste(unique(na.omit(drug_pmid)), collapse = "|")) %>%
  dplyr::select(Gene = gene_symbol, Mutation, Therapy = drug_name, Confidence, References) %>%
  dplyr::arrange(desc(Confidence))

# indirect associations:
# other mutations in *any* gene (not necessarily drug target) with known effect on drug.
# Here we list all genes with any LoF mutation (not necessarily the same mutation that occured in the sample) with evidence
# that the affected patient could show a resistance to a drug. Note that lof_civic_dt_table is a superset
# of drug_variants below.
lof_civic_dt_table <- mvld %>%
  inner_join(civic_evidence, by = c("gene_symbol" = "gene")) %>%
  dplyr::select(Gene = gene_symbol, Mutation = variant, Therapy = drugs, Disease = disease, Effect = clinical_significance, Evidence = evidence_level, References = pubmed_id)

# mutation-specific annotations (from civic)
# These are mutations reported by CiVIC with a known pharmacogenetic effect, clinical significance, and evidence level.
# Note that these variants have to match with the sample variants in their exact position on the genome.
drug_variants <- mvld %>%
  inner_join(civic_evidence, by = c("gene_symbol" = "gene", "chr", "start", "stop", "ref", "alt")) %>%
  dplyr::select(Gene = gene_symbol, Mutation = variant, Therapy = drugs, Disease = disease, Effect = clinical_significance, Evidence = evidence_level, References = pubmed_id) %>%
  arrange(Evidence)

# Now remove drug_variants that are also contained in lof_civic_dt_table
lof_civic_dt_table <- setdiff(lof_civic_dt_table, drug_variants) %>%
  arrange(Evidence)

# build a reference index to the bibliography
reference_map <- tibble(References = c(lof_driver$References, lof_variant_dt_table$References, lof_civic_dt_table$References, drug_variants$References)) %>%
  mutate(References = str_split(References, "\\|")) %>%
  unnest(References) %>%
  mutate(References = str_trim(References)) %>%
  distinct() %>%
  tibble::rowid_to_column()

base_url <- "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?retmode=json;db=pubmed;id="
querystring <- URLencode(paste(base_url, paste(
  (reference_map$References), collapse = ",", sep = ""), sep = ""))

references_json <- as.tbl_json(getURL(querystring))

references <- references_json  %>%
  enter_object("result") %>%
  gather_object() %>%
  spread_values(
    first = jstring("sortfirstauthor"),
    title = jstring("title"),
    journal = jstring("fulljournalname"),
    volume = jstring("volume"),
    issue = jstring("issue"),
    pages = jstring("pages"),
    date = jstring("pubdate")
  ) %>%
  filter(row_number() != 1) %>%
  mutate(
    year = str_extract(date, "\\d*"),
    authors = paste(stringr::str_extract(first, "\\w*"), "et al."),
    citation = paste(authors, title, journal, volume, issue, year, sep = ", ")
  ) %>%
  left_join(reference_map, by = c("name" = "References")) %>%
  dplyr::select(rowid, citation)

# now replace pubmed ids with indexes for all the previous tables

if (nrow(lof_driver)) {
  lof_driver <- lof_driver %>%
    mutate(References = str_split(References, "\\|")) %>%
    unnest(References) %>%
    mutate(References = str_trim(References)) %>%
    left_join(reference_map) %>%
    group_by(Gene, Mutation, Confidence) %>%
    arrange(rowid, .by_group = T) %>%
    summarise(References = paste(rowid, collapse = ",")) %>%
    dplyr::arrange(desc(Confidence))
}

if (nrow(lof_variant_dt_table)) {
  lof_variant_dt_table <- lof_variant_dt_table %>%
    mutate(References = str_split(References, "\\|")) %>%
    unnest(References) %>%
    mutate(References = str_trim(References)) %>%
    left_join(reference_map) %>%
    group_by(Gene, Mutation, Therapy, Confidence) %>%
    arrange(rowid, .by_group = T) %>%
    summarise(References = paste(rowid, collapse = ",")) %>%
    dplyr::arrange(desc(Confidence))
}

if (nrow(lof_civic_dt_table)) {
  lof_civic_dt_table <- lof_civic_dt_table %>%
    mutate(References = str_split(References, "\\|")) %>%
    unnest(References) %>%
    mutate(References = str_trim(References)) %>%
    left_join(reference_map) %>%
    group_by(Gene, Mutation, Therapy, Disease, Evidence) %>%
    summarise(References = paste(rowid, collapse = ","))
}

if (nrow(drug_variants)) {
  drug_variants <- drug_variants %>%
    mutate(References = str_split(References, "\\|")) %>%
    unnest(References) %>%
    mutate(References = str_trim(References)) %>%
    left_join(reference_map) %>%
    group_by(Gene, Mutation, Therapy, Disease, Evidence) %>%
    summarise(References = paste(rowid, collapse = ",")) %>%
    arrange(Evidence)
}

###################
#
# write report
#
###################

# write to docx (report)
# template_file <- ifelse(debug, system.file('extdata','template_report_en.docx',package = 'ClinicalReportR'), opt$template)
mydoc <- officer::read_docx()

# Default properties
# header_props <- fp_text(font.size = 20, bold = T, color = 'white', shading.color = "orange", font.family = "Verdana")
# header_par_props <- fp_par(text.align = "center")

# DRIVER
if (nrow(lof_driver) > 0) {

  my_driver_FTable = flextable::flextable(data = as.data.frame(lof_driver)) %>%
    theme_vanilla() %>%
    align(align = "center", part = "all") %>%
    autofit()

  mydoc <- mydoc %>%
    body_add_par('Somatic Mutations in Known Driver Genes', style = 'heading 1') %>%
    # body_add_fpar(fpar(ftext("Somatic Mutations in Known Driver Genes"), style = "heading 1")) %>%
    body_add_flextable(value = my_driver_FTable)
}

# LOF (direct)
if (nrow(lof_variant_dt_table) > 0) {
  my_variant_dt_FTable <- flextable::flextable(data = as.data.frame(lof_variant_dt_table)) %>%
    theme_vanilla() %>%
    align(align = "center", part = "all") %>%
    autofit()

  mydoc <- mydoc %>%
    body_add_par('Somatic Mutations in Pharmaceutical Target Proteins', style = 'heading 1') %>%
    body_add_par('Direct Association (Mutation in drug target)', style = 'heading 2') %>%
    # body_add_fpar(fpar(ftext("Somatic Mutations in Pharmaceutical Target Proteins", prop = header_props))) %>%
    # body_add_fpar(fpar(ftext("Direct Association (Mutation in drug target)", prop = header_props))) %>%
    body_add_flextable(value = my_variant_dt_FTable)
}

# LOF CiVIC (indirect)
if (nrow(lof_civic_dt_table) > 0) {
  my_civic_dt_FTable = flextable::flextable(data = as.data.frame(lof_civic_dt_table)) %>%
    theme_vanilla() %>%
    align(align = "center", part = "all") %>%
    autofit()

  mydoc <- mydoc %>%
    body_add_par('Indirect Association (other Mutations with known effect on drug)', style = 'heading 2') %>%
    # body_add_fpar(fpar(ftext("Indirect Association (other Mutations with known effect on drug)", prop = header_props))) %>%
    body_add_flextable(value = my_civic_dt_FTable)
}

# CiVIC
if (nrow(drug_variants) > 0) {
  my_drug_variants_FTable = flextable::flextable(data = as.data.frame(drug_variants)) %>%
    theme_vanilla() %>%
    align(align = "center", part = "all")

  mydoc <- mydoc %>%
    body_add_par('Somatic Mutations with known pharmacogenetic effect', style = 'heading 1') %>%
    # body_add_fpar(fpar(ftext('Somatic Mutations with known pharmacogenetic effect', prop = header_props)), style="centered") %>%
    body_add_flextable(my_drug_variants_FTable)
}

# References
if (nrow(references) > 0) {
  #mydoc <- ReporteRs::addPageBreak(mydoc)

  my_references_FTable <- flextable::flextable(data = as.data.frame(references)) %>%
    theme_vanilla() %>%
#    fontsize(9) %>%
    # border() %>%
    align(align = "left", part = "all") %>%
    width("rowid", 0.5) %>%
    width("citation", 6)

  mydoc <- mydoc %>%
    body_add_par('References', style = 'heading 1') %>%
    # body_add_fpar(fpar(ftext('References', prop = header_props)), style = "centered") %>%
    body_add_flextable(my_references_FTable)
}

if (nrow(mvld) > 0) {
  appendix <- mvld %>%
    dplyr::select(Gene = gene_symbol, Mutation, dbSNP, COSMIC)

  my_appendix_FTable = flextable::flextable(data = as.data.frame(appendix)) %>%
    theme_vanilla() %>%
    align(align = "center", part = "all") %>%
    autofit()

  mydoc <- mydoc %>%
    body_add_par('Appendix', style = 'heading 1') %>%
    # body_add_fpar(fpar(ftext("Appendix", prop = header_props))) %>%
    body_add_flextable(value = my_appendix_FTable)
}

print(mydoc, target = reportFile)
# ReporteRs::writeDoc(mydoc, file = reportFile)
