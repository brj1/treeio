##' read nhx tree file
##'
##'
##' @title read.nhx
##' @param file nhx file
##' @return nhx object
##' @importFrom tibble as_tibble
##' @export
##' @examples
##' nhxfile <- system.file("extdata/NHX", "ADH.nhx", package="treeio")
##' read.nhx(nhxfile)
##' @author Guangchuang Yu \url{https://guangchuangyu.github.io}
read.nhx <- function(file) {
    treetext <- readLines(file, warn=FALSE)
    treetext <- treetext[treetext != ""]
    treetext <- treetext[treetext != " "]

    if (length(treetext) > 1) {
        treetext <- paste0(treetext, collapse = '')
    }
    treetext <- gsub(" ", "", treetext)

    phylo <- read.tree(text=treetext)
    nnode <- Nnode(phylo, internal.only=FALSE)
    nlab <- paste("X", 1:nnode, sep="")
    tree2 <- treetext

    pattern <- "(\\w+)?(:?\\d*\\.?\\d*[Ee]?[\\+\\-]?\\d*)?\\[&&NHX.*?\\]"
    for (i in 1:nnode) {
        tree2 <- sub(pattern, paste0("\\", nlab[i], "\\2"), tree2)
    }

    phylo2 <- read.tree(text = tree2)
    node <- match(nlab, sub(".+(X\\d+)$","\\1",
                            c(phylo2$tip.label, phylo2$node.label)))

    ## https://github.com/YuLab-SMU/treeio/pull/40
    node <- node[!is.na(node)]

    nhx.matches <- gregexpr(pattern, treetext)

    matches <- nhx.matches[[1]]
    match.pos <- as.numeric(matches)
    if (length(match.pos) == 1 && (match.pos == -1)) {
        nhx_tags <- data.frame(node = 1:nnode)
    } else {
        match.len <- attr(matches, 'match.length')

        nhx_str <- substring(treetext, match.pos, match.pos+match.len-1)

        nhx_features <- gsub("^[^\\[]*", "", nhx_str) %>%
            gsub("\\[&&NHX:", "", .) %>%
            gsub("\\]", "", .)

        nhx_tags <- get_nhx_feature(nhx_features)
        fields <- names(nhx_tags)
        for (i in ncol(nhx_tags)) {
            if(any(grepl("\\D+", nhx_tags[,i])) == FALSE) {
                ## should be numerical varialbe
                nhx_tags[,i] <- as.numeric(nhx_tags[,i])
            }
        }
        nhx_tags$node <- as.integer(node)
    }

    # Order rows by row number to facilitate downstream manipulations
    nhx_tags <- nhx_tags[order(nhx_tags$node),]

    new("treedata",
        file = filename(file),
        phylo = phylo,
        data = as_tibble(nhx_tags)
        )
}


get_nhx_feature <- function(nhx_features) {
    nameSET <- strsplit(nhx_features, split=":") %>% unlist %>%
        gsub("=.*", "", .) %>% unique
    lapply(nhx_features, get_nhx_feature_internal, nameSET=nameSET) %>%
        do.call(rbind, .) %>% as.data.frame(., stringsAsFactors = FALSE)
}

get_nhx_feature_internal <- function(feature, nameSET) {
    x <- strsplit(feature, ":") %>% unlist
    name <- gsub("=.*", "", x)
    val <- gsub(".*=", "", x)

    names(val) <- name
    y <- character(length(nameSET))
    for (i in seq_along(nameSET)) {
        if (nameSET[i] %in% name) {
            y[i] <- val[nameSET[i]]
        } else {
            y[i] <- NA
        }
    }
    names(y) <- nameSET
    return(y)
}

