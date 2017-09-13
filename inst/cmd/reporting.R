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
  optparse::make_option(c("-r", "--report"), type = "character", help = "the file name for the detailed output report", default = NULL),
  #optparse::make_option(c("-c", "--vepconfig"), type = "character", help = "ensembl-vep configuration file", default = NULL),
  optparse::make_option(c("-t", "--test"), type = "logical", help = "generate test report", default = FALSE)
)

opt_parser <- optparse::OptionParser(option_list = option_list)
opt <- optparse::parse_args(opt_parser)

# set this manually to run code interactively
debug <- opt$test
debug <- TRUE

if (!opt$test && (is.null(opt$file) || !file.exists(opt$file)) && !debug) {
  optparse::print_help(opt_parser)
  stop("Please supply an existing input file via -f")
}

# make sure that all required packages are available
# this tries to install missing packages that are missing
list.of.packages.cran <- c("dplyr", "dtplyr", "tidyr", "stringr", "splitstackshape", "RMySQL", "ReporteRs", "optparse", "readr", "tidyjson", "RCurl")
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
  vcfFile <- "inst/extdata/strelka.passed.missense.somatic.snvs_annotated.vcf"
  #vcfFile <- "inst/extdata/strelka.passed.missense.somatic.snvs_short.vcf"

  # test without annotation
  #vcfFile <- "inst/extdata/strelka.passed.missense.somatic.snvs.vcf"
}

if (is.null(reportFile)) {
  reportFile <- paste(tools::file_path_sans_ext(vcfFile), "docx", sep=".")
}


###################
# update CiVIC data
###################

civic <- ClinicalReportR::get_civic()

###################
#
# annotate VCF file
#
###################

vcf <- ClinicalReportR::check_annotation(vcfFile)

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
  #dplyr::left_join(civic$evidence) %>%
  mutate(Consequence = stringr::str_replace_all(stringr::str_extract(Consequence, "^(?:(?!_variant)\\w)*"), "_", " "),
         reference_build = "GRCh37",
         hgnc_id = as.integer(HGNC_ID),
         dbSNP = as.character(stringr::str_extract_all(Existing_variation, "rs\\w+")),
         COSMIC = as.character(stringr::str_extract_all(Existing_variation, "COSM\\w+")),
         DNA = stringr::str_extract(HGVSc, "(?<=:).*"),
         Protein = stringr::str_extract(HGVSp, "(?<=:).*")) %>% # positive lookbehind
  dplyr::select(-Gene, -HGNC_ID) %>%       # drop Ensembl Gene ID as we're using HUGO from here on
  dplyr::rename(gene_symbol = SYMBOL, Type = VARIANT_CLASS, Mutation = Protein) %>%
  filter(filter == "PASS") %>% # filter quality
  filter(PICK == 1) %>% # filter only transcripts that VEP picked
  filter(BIOTYPE == "protein_coding" & Consequence != "synonymous_variant" & Consequence != "intron_variant") %>%
  filter(LoF != "" | startsWith(SIFT, "deleterious") | endsWith(PolyPhen, "damaging"))

  #tidyr::unite_("Mutation", c("Type", "DNA", "Protein", "Consequence"), sep="\n")


# now query our noSQL database for information on drugs and driver status for all genes occuring in the
# mvld. Then create a relational schema for each with hgnc_id as our 'key', resulting in 3 tables, one each for genes, drivers, and drugs.

db_baseurl = 'http://localhost:5000/biograph_genes?where={"hgnc_id":{"$in":["'
querystring = URLencode(paste(db_baseurl, paste(unique(mvld$hgnc_id), collapse = '","'), '"]}}', sep=''))

biograph_json <- as.tbl_json(getURL(querystring))

# get information on genes by hgnc_id
biograph_genes <- biograph_json %>%
  enter_object("_items") %>% gather_array() %>%
  spread_values(
    gene_symbol = jstring("gene_symbol"),
    status = jstring("status"),
    hgnc_id = jstring("hgnc_id"),
    driver_score = jnumber("driver_score")
  ) %>%
  mutate(hgnc_id = as.numeric(hgnc_id)) %>%
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
  mutate(hgnc_id = as.numeric(hgnc_id)) %>%
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
  mutate(hgnc_id = as.numeric(hgnc_id)) %>%

  dplyr::select(-document.id, -array.index)

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

# helper function to filter for drug targets.
#' @return TRUE if a gene x is of interaction_type 'target' for at least one cancer drug
is_cancer_drug_target <- function(x) {
  if (is.null(x)) {
    return(FALSE)
  }

  return(any(x$interaction_type == "target"))

}

# prepare a tidy dataset, where all information on drugs and drivers is available for all mutations, i.e.
# every row is a unique combination of mutation, transcript, gene, driver status, and drug interactions.
# In addition, we apply some standard filters to pick only high quality and LoF mutations and do some renaming.
mvld_tidy <- mvld %>%
  left_join(biograph_genes) %>%
  left_join(biograph_driver) %>%
  left_join(biograph_drugs)


## OBSOLETE?
# can this be done with 'replace'?
#mvld$meta_information.drugs <- lapply(mvld$meta_information.drugs, function(x) { if(is.null(x)) return(data.frame()) else return(x) })
#mvld$meta_information.driver_information <- lapply(mvld$meta_information.driver_information, function(x) { if(is.null(x)) return(data.frame()) else return(x) })

#mvld <- mvld %>%
  # extract and aggregate some information
#  mutate(Driver = lapply(meta_information.driver_information, function(x) {  paste(unique(x$driver_type), sep = "\n", collapse = "\n") }),
#         Pathway = lapply(meta_information.driver_information, function(x) {  ifelse(is.null(x$core_pathway), "", x$core_pathway) }),
#         Process = lapply(meta_information.driver_information, function(x) {  ifelse(is.null(x$Process), "", x$Process) }),
#         is_cancer_drug_target = unlist(lapply(meta_information.drugs, is_cancer_drug_target)),
#         Therapy = lapply(meta_information.drugs, extract_cancer_drugs)
#  ) %>%
#  dplyr::select(Gene, Mutation, Driver, Pathway, Process, Therapy, is_cancer_drug_target, Swissprot = SWISSPROT, meta_information.drugs)
#### END OBSOLETE

# driver genes with mutation (irrespective of being a drug target or not)
lof_driver <- biograph_driver %>%
  dplyr::group_by(gene_symbol) %>%
  dplyr::summarize(Confidence = n(), References = paste(driver_pmid, collapse = "|")) %>%
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
# mutation in *any* gene (not necessarily drug target) with known effect on drug.
# Here we list all genes with a LoF mutation associated with enzymes, transporters, or carriers as defined by DrugBank and
# those with known pharmacogenetic effect from CiVIC on the gene level. As a result, we would list mutations in Genes with a known
# effect due to *another* mutation (in CiVIC).
lof_civic_dt_table <- mvld %>%
  left_join(civic$genes, by = c("gene_symbol" = "gene")) %>%
  filter(!is.na(drugs)) %>%
  dplyr::select(Gene = gene_symbol, Therapy = drugs, References = pubmed_ids)

# mutation-specific annotations (from civic)
# These are mutations reported by CiVIC with a known pharmacogenetic effect, clinical significance, and evidence level.
drug_variants <- mvld %>%
  inner_join(civic$evidence) %>%
  mutate(drugs = as.character(drugs)) %>%
  filter(stringr::str_length(stringr::str_trim((drugs))) > 0) %>%
  filter(variant_origin == "Somatic Mutation") %>%
  #group_by(pubmed_id) %>%
  #summarise()
  #dplyr::select(Gene, Mutation, Drugs = drugs, Disease = disease, Biomarker = evidence_type, Effect = clinical_significance, Evidence = evidence_level, Pubmed = pubmed_id) %>%
  dplyr::select(Gene = gene_symbol, Mutation, Therapy = drugs, Disease = disease, Evidence = evidence_level, References = pubmed_id) %>%
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
  gather_keys() %>%
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
  left_join(reference_map, by = c("key" = "References")) %>%
  dplyr::select(rowid, citation)

# now replace pubmed ids with indexes for all the previous tables

lof_driver <- lof_driver %>%
  mutate(References = str_split(References, "\\|")) %>%
  unnest(References) %>%
  mutate(References = str_trim(References)) %>%
  left_join(reference_map) %>%
  group_by(Gene, Confidence) %>%
  arrange(rowid, .by_group = T) %>%
  summarise(References = paste(rowid, collapse = ",")) %>%
  dplyr::arrange(desc(Confidence))

lof_variant_dt_table <- lof_variant_dt_table %>%
  mutate(References = str_split(References, "\\|")) %>%
  unnest(References) %>%
  mutate(References = str_trim(References)) %>%
  left_join(reference_map) %>%
  group_by(Gene, Mutation, Therapy, Confidence) %>%
  arrange(rowid, .by_group = T) %>%
  summarise(References = paste(rowid, collapse = ",")) %>%
  dplyr::arrange(desc(Confidence))

lof_civic_dt_table <- lof_civic_dt_table %>%
  mutate(References = str_split(References, "\\|")) %>%
  unnest(References) %>%
  mutate(References = str_trim(References)) %>%
  left_join(reference_map) %>%
  group_by(Gene, Therapy) %>%
  summarise(References = paste(rowid, collapse = ","))

drug_variants <- drug_variants %>%
  mutate(References = str_split(References, "\\|")) %>%
  unnest(References) %>%
  mutate(References = str_trim(References)) %>%
  left_join(reference_map) %>%
  group_by(Gene, Mutation, Therapy, Disease, Evidence) %>%
  summarise(References = paste(rowid, collapse = ",")) %>%
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
    addHeaderRow(value = c('Somatic Mutations in Known Driver Genes'), colspan = c(ncol(lof_driver)),
                 text.properties = textProperties(color = "white", font.size = 16),
                 cell.properties = cellProperties(background.color = "#F79646"),
                 first = TRUE) %>%
    setFlexTableWidths(widths = c(.8, 1.2, 5)) %>%
    setFlexTableBorders(inner.vertical = borderProperties(width = 0),
                        inner.horizontal = borderProperties(width = 0), outer.vertical = borderProperties(width = 0),
                        outer.horizontal = borderProperties(width = 0))


  mydoc <- ReporteRs::addFlexTable(mydoc, my_driver_FTable, bookmark = "lof_driver")
}

# LOF (direct)
if (nrow(lof_variant_dt_table) > 0) {
  my_variant_dt_FTable = ReporteRs::FlexTable(data = as.data.frame(lof_variant_dt_table), add.rownames = FALSE,
                                          body.par.props = body.par.props,
                                          body.cell.props = body.cell.props,
                                          header.par.props = header.par.props) %>%
    addHeaderRow(value = c('Direct Association (Mutation in drug target)'), colspan = c(ncol(lof_variant_dt_table)), first = TRUE) %>%
    addHeaderRow(value = c('Somatic Mutations in Pharmaceutical Target Proteins'), colspan = c(ncol(lof_variant_dt_table)),
                 text.properties = textProperties(color = "white", font.size = 16),
                 cell.properties = cellProperties(background.color = "#14731C"),
                 first = TRUE) %>%
    setFlexTableWidths(widths = c(.8, 1.1, 1.1, 1, 3)) %>%
    setFlexTableBorders(inner.vertical = borderProperties(width = 0),
                        inner.horizontal = borderProperties(width = 0), outer.vertical = borderProperties(width = 0),
                        outer.horizontal = borderProperties(width = 0)) %>%
    spanFlexTableRows(j = c("Gene", "Mutation"), runs = lof_variant_dt_table$Gene)


  mydoc <- ReporteRs::addFlexTable(mydoc, my_variant_dt_FTable, bookmark = "lof_variant_dt_table")
}

# LOF CiVIC (indirect)
if (nrow(lof_civic_dt_table) > 0) {
  my_civic_dt_FTable = ReporteRs::FlexTable(data = as.data.frame(lof_civic_dt_table), add.rownames = FALSE,
                                          body.par.props = body.par.props,
                                          body.cell.props = body.cell.props,
                                          header.par.props = header.par.props) %>%
    addHeaderRow(value = c('Indirect Association (other Mutations with known effect on drug)'), colspan = c(ncol(lof_civic_dt_table)), first = TRUE) %>%
    setFlexTableWidths(widths = c(.8, 1.5, 3.7)) %>%
    setFlexTableBorders(inner.vertical = borderProperties(width = 0),
                        inner.horizontal = borderProperties(width = 0), outer.vertical = borderProperties(width = 0),
                        outer.horizontal = borderProperties(width = 0))
    #addHeaderRow(value = c('Somatic Mutations in Pharmaceutical Target Proteins'), colspan = c(ncol(lof_civic_dt_table)),
    #             text.properties = textProperties(color = "white", font.size = 16),
    #             cell.properties = cellProperties(background.color = "#14731C"),
    #             first = TRUE)

  mydoc <- ReporteRs::addFlexTable(mydoc, my_civic_dt_FTable, bookmark = "lof_civic_dt_table")
}

# CiVIC
if (nrow(drug_variants) > 0) {
  my_drug_variants_FTable = ReporteRs::FlexTable(data = as.data.frame(drug_variants), add.rownames = FALSE,
                                          body.par.props = body.par.props,
                                          body.cell.props = body.cell.props,
                                          header.par.props = header.par.props) %>%
    addHeaderRow(value = c('Somatic Mutations with known pharmacogenetic effect'), colspan = c(ncol(drug_variants)),
                 text.properties = textProperties(color = "white", font.size = 16),
                 cell.properties = cellProperties(background.color = "#C0504D"),
                 first = TRUE) %>%
    setFlexTableWidths(widths = c(.8, 1.2, 2, 1, 1, 1)) %>%
    setFlexTableBorders(inner.vertical = borderProperties(width = 0),
                        inner.horizontal = borderProperties(width = 0), outer.vertical = borderProperties(width = 0),
                        outer.horizontal = borderProperties(width = 0)) %>%
    spanFlexTableRows(j = "Gene", runs = drug_variants$Gene)

  mydoc <- ReporteRs::addFlexTable(mydoc, my_drug_variants_FTable, bookmark = "drug_variants")
}

# References
if (nrow(references) > 0) {
  #mydoc <- ReporteRs::addPageBreak(mydoc)

  my_references_FTable = ReporteRs::FlexTable(data = as.data.frame(references), add.rownames = FALSE,
                                              body.par.props = parProperties(text.align = "left",
                                                                             border.bottom = borderNone(),
                                                                             border.left = borderNone()),
                                          body.cell.props = body.cell.props,
                                          header.par.props = header.par.props,
                                          header.columns = F) %>%
    addHeaderRow(value = c('References'), colspan = c(ncol(references)),
                 text.properties = textProperties(color = "white", font.size = 16),
                 cell.properties = cellProperties(background.color = "#3275b2"),
                 first = TRUE) %>%
    #setFlexTableWidths(widths = c(.8, 1.2, 2, 1, 1, 1)) %>%
    setFlexTableBorders(inner.vertical = borderProperties(width = 0),
                        inner.horizontal = borderProperties(width = 0), outer.vertical = borderProperties(width = 0),
                        outer.horizontal = borderProperties(width = 0))

  mydoc <- ReporteRs::addFlexTable(mydoc, my_references_FTable, bookmark = "references")
}

ReporteRs::writeDoc(mydoc, file = reportFile)
