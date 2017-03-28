#' @export
annotate <- function(vcfFile) {
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

  ensemblVEP::ensemblVEP(vcfFile, param)
}
