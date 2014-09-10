#' Search for matches to sequences against the BOLD COI database.
#'
#' @export
#' @references \url{http://www.boldsystems.org/index.php/resources/api?type=idengine}
#'
#' @param sequences (character) Returns all records containing matching marker codes.
#' @param db (character) The database to match against, one of COX1, COX1_SPECIES, 
#' COX1_SPECIES_PUBLIC, OR COX1_L604bp. See Details for more information.
#' @param response (logical) Note that response is the object that returns from the Curl call,
#' useful for debugging, and getting detailed info on the API call.
#' @param ... Further args passed on to httr::GET, main purpose being curl debugging
#' 
#' @details Detailed desdription of options for the db parmeter:
#' 
#' \itemize{
#'  \item COX1 Every COI barcode record with a species level identification and a minimum sequence 
#'  length of 500bp. This includes many species represented by only one or two specimens as well as 
#'  all species with interim taxonomy.
#'  \item COX1_SPECIES Every COI barcode record on BOLD with a minimum sequence length of 500bp 
#'  (warning: unvalidated library and includes records without species level identification). This 
#'  includes many species represented by only one or two specimens as well as all species with 
#'  interim taxonomy. This search only returns a list of the nearest matches and does not provide 
#'  a probability of placement to a taxon.
#'  \item COX1_SPECIES_PUBLIC All published COI records from BOLD and GenBank with a minimum 
#'  sequence length of 500bp. This library is a collection of records from the published projects 
#'  section of BOLD.
#'  \item OR COX1_L604bp Subset of the Species library with a minimum sequence length of 640bp and 
#'  containing both public and private records. This library is intended for short sequence 
#'  identification as it provides maximum overlap with short reads from the barcode region of COI.
#' }
#' @return A data.frame with details for each specimen matched.
#' @examples \dontrun{
#' seq <- sequences$seq1
#' head(bold_identify(sequences=seq)[[1]])
#' head(bold_identify(sequences=seq, db='COX1_SPECIES')[[1]])
#' bold_identify(sequences=seq, response=TRUE)
#' 
#' # Multiple sequences
#' out <- bold_identify(sequences=c(sequences$seq2, sequences$seq3), db='COX1')
#' lapply(out, head)
#' 
#' # curl debugging
#' library('httr')
#' bold_identify(sequences=seq, response=TRUE, config=verbose())[[1]]
#' }

bold_identify <- function(sequences = NULL, db = 'COX1', response=FALSE, ...)
{
  url <- 'http://boldsystems.org/index.php/Ids_xml'

  foo <- function(a, b){
    args <- bold_compact(list(sequence=a, db=b))
    out <- GET(url, query=args, ...)
    stop_for_status(out)
    assert_that(out$headers$`content-type`=='text/xml')
    if(response){ out } else {
      tt <- content(out, as = "text")
      xml <- xmlParse(tt)
      nodes <- getNodeSet(xml, "//match")
      toget <- c("ID","sequencedescription","database","citation","taxonomicidentification","similarity")
      outlist <- lapply(nodes, function(x){
        tmp2 <- sapply(toget, function(y) xpathSApply(x, y, xml_value_name), USE.NAMES = FALSE)
        spectmp <- xpathSApply(x, "specimen", xmlToList, addAttributes = TRUE, simplify = FALSE)[[1]]
        spectmp <- unnest(spectmp)
        names(spectmp) <- c('specimen_url','specimen_country','specimen_lat','specimen_lon')
        spectmp[sapply(spectmp, is.null)] <- NA
        data.frame(c(tmp2, spectmp), stringsAsFactors = FALSE)
      })
      do.call(rbind.fill, outlist)
    }
  }
  lapply(sequences, foo, b=db)
}

xml_value_name <- function(x){
  tmp <- xmlValue(x)
  names(tmp) <- xmlName(x)
  tmp
}

unnest <- function(x){
  if (is.null(names(x))) {
    list(unname(unlist(x)))
  } else {
    do.call(c, lapply(x, unnest))
  }
}