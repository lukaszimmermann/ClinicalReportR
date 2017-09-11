.defaultConfig <- function() {
  param <- ensemblVEP::VEPParam(basic = list(config = "/vep/.vep/vep.ini"),
                       input=list(species=character(0)),
                       cache=list(dir = character(0), dir_cache=character(0), dir_plugins=character(0)),
                       output=list(terms = character(0)),
                       filterqc=list(),
                       database=list(host=character(0), database=FALSE),
                       advanced=list(buffer_size=5000),
                       identifier=list(),
                       colocatedVariants = list(),
                       dataformat = list(),
                       scriptPath = "/home/vep/src/ensembl-vep/vep")
  param
}

# Annotates the input_file in vcf format with ensembleVEP and stores the result in output_file.
#' @export
annotate <- function(input_file, output_file) {
  param <- .defaultConfig()
  ensemblVEP::input(param)$output_file=output_file
  ann <- ensemblVEP::ensemblVEP(input_file, param)
}

# Tests if the input file has already been annotated with VEP
#' @export
check_annotation <- function(input_file) {
  vcf <- VariantAnnotation::readVcf(input_file)
  info <- rownames(VariantAnnotation::info(VariantAnnotation::header(vcf)))
  if (!("CSQ" %in% info)) {
    stop("Please run VEP on this VCF before generating a report.")

    #dest <- file.path(tempfile())
    #ClinicalReportR::annotate(vcfFile, dest)
    #vcf <- VariantAnnotation::readVcf(dest)
  }

  vcf

}

# Annotates a vcf file with ensembleVEP and returns all annotations in a data frame.
#' @export
annotate <- function(input_file) {
  param <- .defaultConfig()
  ann <- ensemblVEP::ensemblVEP(input_file, param)
  mcols(ann)
}

# Collects the most recent data from CiVIC and returns a list with two data frames for genes and evidence.
#' @export
get_civic <- function() {
  evidence <- read.table('https://civic.genome.wustl.edu/downloads/nightly/nightly-ClinicalEvidenceSummaries.tsv', sep="\t", header=T, fill = T, quote = "\"", comment.char = "%") %>%
    dplyr::rename(chr=chromosome, alt=variant_bases, ref=reference_bases)

  genes <- evidence %>%
    dplyr::filter(drugs != "") %>%
    dplyr::group_by(gene) %>%
    # TODO: check if existing concatenations of drugs are due to combination therapy (here we throw them all together)
    dplyr::summarise(drugs = paste(unique(stringr::str_trim(unlist(stringr::str_split(drugs, ",")))),collapse=" | "),
                     clinical_significance = paste(unique(clinical_significance),collapse=" | "),
                     pubmed_ids = paste(unique(pubmed_id),collapse=" | "))

  list(evidence=evidence, genes=genes)
}
