###################
#
# create database objects
#
###################

# Updates database objects.
updateDatabases <- function(database, host, port, user, password) {

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
  my_drug_con <- dplyr::src_mysql(database, host, as.integer(port), user, password)

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

  dbs <- list(civic_genes=civic_genes, civic_variants=civic_variants, targets=targets, driver_genes=driver_genes)
  devtools::use_data(dbs)
}
