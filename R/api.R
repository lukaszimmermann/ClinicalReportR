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
                       scriptPath = "/usr/bin/vep.pl")
  param
}

# Annotates a vcf file with ensembleVEP and returns all annotations in a data frame.
#' @export
annotate <- function(input_file, output_file) {
  param <- .defaultConfig()
  ensemblVEP::input(param)$output_file=output_file
  ann <- ensemblVEP::ensemblVEP(input_file, param)
}

# Annotates a vcf file with ensembleVEP and returns all annotations in a data frame.
#' @export
annotate <- function(input_file) {
  param <- .defaultConfig()
  ann <- ensemblVEP::ensemblVEP(input_file, param)
  mcols(ann)
}
