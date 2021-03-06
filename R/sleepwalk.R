`%||%` <- function(x, y) {
  if(is.null(x)) {
    y
  } else {
    x
  }
}

#' Interactively explore one or several 2D embeddings
#' 
#' A function to interactively explore a 2D embedding of some higher-dimensional
#' point cloud, as produced by a dimension reduction method such as MDS, t-SNE, or the like.
#'
#' The function opens a browser window and displays the embeddings as point clouds. When the user
#' moves the mouse over a point, the point gets selected and all data points change colour such
#' that their colour indicates
#' the feature-space distance to the point under the mouse cursor. This allows to quickly and
#' intuitively check how tight clusters are, how faithful the embedding is, and how similar
#' the clusters are to each other.
#' 
#' 
#' @param embeddings either an \eqn{n x 2} embedding matrix (where \eqn{n} is a number of points) or
#' a list of \eqn{n_i x 2} matices - one for each embedding. If \code{same = "objects"} all embedding
#' matrices must have the same number of rows.
#' @param featureMatrices either an \eqn{n x m} matrix of point coordinates in the feature-dimension
#' space or a list of such matrices - one for each embedding. The displayed distances will be calculated 
#' as Euclidean distances of the rows of these matrices. Alternatively, if \code{same = "objects"}
#' it is possible to provide the distances directly via the \code{distances} argument. 
#' If \code{same = "features"} then all the points must be from the same feature space and therefore
#' have the same number of columns. It is possible to use one feature matrix for all the embeddings.
#' @param maxdists a vector of the maximum distances (in feature space) for each provided feature or
#' distance matrix that should still be covered by the colour 
#' scale; higher distances are shown in light gray. This values can be changed later interactively.
#' If not provided, maximum distances will be estimated automatically as median value of the 
#' distances.
#' @param pointSize size of the points on the plots.
#' @param distances distances (in feature space) between points that should be displayed as colours.
#' This is an alternative to \code{featureMatrices} if \code{same = "objects"}.
#' @param same defines what kind of distances to show; must be either \code{"objects"} or \code{"features"}.
#' Use \code{same = "objects"} when all the embeddings show the same set of points. In this case,
#' each embedding is colored to show the distance of the selected point to all other points.
#' The same or different features can be supplied as \code{featureMatrices}, to use the same or different distances
#' in the different embeddings.
#' \code{same = "features"}
#' is used to compare different sets of points (e.g. samples from different patients, or different batches) 
#' in the same feature space. In this case the distance is calculated from the selected point to all other 
#' points (including those in other embeddings).
#' @param saveToFile path to the .html file where to save the plots. The resulting page will be fully interactive
#' and contain all the data. If this is \code{NULL}, than the plots will be shown as the web page in your 
#' default browser. Note, that if you try to save that page, using your browser's functionality,
#' it'll become static.
#' 
#' 
#' @return None.
#' 
#' @author Simon Anders, Svetlana Ovchinnikova
#' 
#' @importFrom jsonlite toJSON
#' @export
sleepwalk <- function( embeddings, featureMatrices = NULL, maxdists = NULL, pointSize = 1.5, titles = NULL,
                       distances = NULL, same = c( "objects", "features" ), compare = c("embeddings", "distances"),
                       saveToFile = NULL, ncol = NULL, nrow = NULL) {
  same = match.arg( same )
  compare = match.arg( compare )
  
  if(is.null(featureMatrices)) {
    if(same == "features")
      stop("In the `same features` mode feature matrices must be defined")
    if(is.null(distances))
      stop("One of the two arguments must be defined: 'featureMatrices', 'distances'")
    stopifnot(nrow(distances) == ncol(distances))
  }
  
  stopifnot( is.numeric(pointSize) && length(pointSize) == 1 )
  
  #if there is only one embedding
  if(!is.null(dim(embeddings))) 
    embeddings <- list(embeddings)
  stopifnot( is.list(embeddings) )
  
  if(length(embeddings) == 1 && same == "features")
    same = "objects"
  
  if(!is.null(dim(featureMatrices)))
    featureMatrices <- list(featureMatrices)
  if(!is.null(dim(distances)))
    distances <- list(distances)
  
  stopifnot( is.list(featureMatrices %||% distances) )

  if( same == "objects" ) {
    stopifnot( length(embeddings) == length(featureMatrices %||% distances) | 
                 length(featureMatrices %||% distances) == 1 )
  }
  else {
    stopifnot( length(embeddings) == length(featureMatrices) )
  }  
  
  oneFM <- NULL
  if(length(embeddings) != length(featureMatrices %||% distances))
    oneFM <- 1
  
  for( i in 1:length(embeddings) ) {
    stopifnot( length( dim( embeddings[[i]] ) ) == 2 )
    stopifnot( length( dim( (featureMatrices %||% distances)[[oneFM %||% i]] ) ) == 2 )
    stopifnot( ncol( embeddings[[i]] ) %in% c(2, 3) )
    stopifnot( nrow( embeddings[[i]] ) == nrow( (featureMatrices %||% distances)[[oneFM %||% i]] ) )
    embeddings[[i]] <- as.matrix(embeddings[[i]])
    if(!is.null(featureMatrices)) {
      featureMatrices[[oneFM %||% i]] <- as.matrix(featureMatrices[[oneFM %||% i]])
    } else {
      distances[[oneFM %||% i]] <- as.matrix(distances[[oneFM %||% i]])
    }
    if( same == "objects" ) 
      stopifnot( nrow( embeddings[[i]] ) == nrow( embeddings[[1]] ) )
    else
      stopifnot( ncol( featureMatrices[[i]] ) == ncol( featureMatrices[[1]] ) )
  }
  
  if(!is.null(titles)) {
    stopifnot(length(titles) == length(embeddings))  
  } else {
    if(!is.null(names(embeddings))) {
      titles <- names(embeddings)
    } else {
      titles <- rep("", length(embeddings))
    }
  }
  
  if(!is.null(names(embeddings)))
    embeddings <- unname(embeddings)
      
  #estimate maxdists from the data
  if(is.null(maxdists)) {
    if(!is.null(featureMatrices)) {
      maxdists <- sapply(1:length(featureMatrices), function(i) {
        message(paste0("Estimating 'maxdist' for feature matrix "), i)
        pairs <- cbind(sample(nrow(featureMatrices[[i]]), 1500, TRUE), 
                       sample(nrow(featureMatrices[[i]]), 1500, TRUE))
        median(sqrt(rowSums((featureMatrices[[i]][pairs[, 1], ] - featureMatrices[[i]][pairs[, 2], ])^2))) 
      })
    } else {
      maxdists <- sapply(distances, median)
    }
  }
  stopifnot( is.numeric(maxdists) )
    
  if( same == "objects" ) {
    stopifnot( length(maxdists) == length(featureMatrices %||% distances) )
  }
  else {
    stopifnot( length(maxdists) == length(featureMatrices) | length(maxdists) == 1 )
  }
  
  if(is.null(saveToFile)) {
    JsRCom::openPage( FALSE, system.file( package="sleepwalk" ), "sleepwalk.html" )
    
    if( same == "objects" ) 
      JsRCom::sendData( "mode", "A" )
    else
      JsRCom::sendData( "mode", "B" )
    
    JsRCom::sendData( "n_charts", length(embeddings) )
    JsRCom::sendData( "titles", titles, TRUE )
    JsRCom::sendData( "maxdist", maxdists, TRUE )
    JsRCom::sendData( "embedding", embeddings, TRUE )
    if(!is.null(featureMatrices)) {
      JsRCom::sendData( "featureMatrix", featureMatrices, TRUE )
    } else {
      JsRCom::sendData( "distance", distances, TRUE )
    }
    JsRCom::sendData( "pointSize", pointSize )
    if(!is.null(ncol))
      JsRCom::sendData( "ncol", ncol )
    if(!is.null(nrow))
      JsRCom::sendData( "nrow", nrow )
    JsRCom::sendData( "compare", compare )
    JsRCom::sendCommand( "set_up_chart()" )
  } else {
    content <- readLines(paste0(system.file( package="sleepwalk" ), "/", "sleepwalk.html"), warn = F)
    
    while(sum(grepl("script src", content)) != 0) {
      i <- which(grepl("script src", content))[1]
      fName <- gsub("<script src=\"(.*?)\"></script>", "\\1", content[i])
      script <- readLines(paste0(system.file( package="sleepwalk" ), "/", fName), warn = F)
      content <- c(content[1:(i - 1)], "<script>", script, "</script>", content[(i + 1):length(content)])
    }
    
    newLines <- c(
      paste0("mode = ", ifelse(same == "objects", "'A'", "'B'"), ";"),
      paste0("n_charts = ", length(embeddings), ";"),
      paste0("maxdist = ", toJSON(maxdists), ";"),
      paste0("embedding = ", toJSON(embeddings), ";"),
      ifelse(!is.null(featureMatrices), 
        paste0("featureMatrix = ", toJSON(featureMatrices), ";"),
        paste0("distance = ", toJSON(distances), ";")),
      paste0("pointSize = ", pointSize, ";"),
      paste0("titles = ", toJSON(titles), ";"),
      ifelse(!is.null(nrow), 
        paste0("nrow = ", nrow, ";"), ""),
      ifelse(!is.null(ncol),
        paste0("ncol = ", ncol, ";"), ""),
      paste0("compare = '", compare, "';"),
      "set_up_chart();"
    )
    
    content <- c(content[1:(length(content) - 3)], newLines, "</script>", "</body>", "</html>")
    
    writeLines(content, saveToFile)
  }
}

#' On selection
#' 
#' This function is called each time any points are selected or deselected.
#' You can customise it by redefining.
#' 
#' @param points a vector of indices of the selected points.
#' @param emb an index of the embedding, where the points have been selected.
#' 
#' @export
slw_on_selection <- function(points, emb) {
  message(paste0("You've selected ", length(points), " points from the embedding ", emb, "."))
  message(paste0("The indices of the selected points are now stored in the variable 'selPoints'."))
  message(paste0("You can also redefine this function 'slw_on_selection' that is called each time any points are selected."))
  message(paste0("It's first argument is a vector of indices of all the selected points, and the second one is the index of ",
                 "the embedding, where they were selected."))
}

#' @importFrom httpuv service
#' @import ggplot2
#' @importFrom scales squish
#' @importFrom cowplot plot_grid
#' @export
slw_snapshot <- function(point, emb = 1, returnList = FALSE) {
  stopifnot(is.numeric(point))
  stopifnot(is.numeric(emb))
  
  if(length(point) > 1) {
    warning("More than one focuse point is provided, only the first one will be used.")
    point <- point[1]
  }
  if(length(emb) > 1) {
    warning("More than one focuse embedding is provided, only the first one will be used.")
    emb <- emb[1]
  }
  
  en <- new.env()
  JsRCom::setEnvironment(en)
  en$finished <- 0
  JsRCom::sendCommand(paste0("getSnapshotData(", point - 1, ", ", emb - 1, ");"))

  for( i in 1:(10/0.05) ) {
    service(100)
    if( en$finished > 0 ) 
      break
    
    Sys.sleep( .05 )
  }
  
  JsRCom::setEnvironment(globalenv())
  
  if( en$finished == 0 )
    stop( "Failed to get embedding data from the server" )

  maxdists <- en$maxdists
  colours <- c("#000000", "#1A1935", "#15474E", "#2B6F39", "#767B33", "#C17A6F", "#D490C6", "#C3C0F2")
  if(is.list(en$embs)) {
    n_charts <- length(en$embs)    
  } else {
    n_charts <- dim(en$embs)[1]
  }
  
  if(n_charts == 1) {
    data <- as.data.frame(cbind(en$embs[1, , ], en$dists[1, ]))
    colnames(data) <- c("x1", "x2", "dists")
    ggplot(data) + geom_point(aes(x = x1, y = x2, colour = dists), size = en$pointSize/2) +
      scale_color_gradientn(colours = colours, limits = c(0, maxdists), oob = squish) +
      ggtitle(en$titles) +
      theme(axis.title = element_blank(), axis.line = element_blank(), panel.grid.major = element_blank(),
            axis.text = element_blank(), axis.ticks = element_blank(), panel.grid.minor = element_blank(),
            legend.position = "bottom", legend.title = element_blank()) + guides(colour = guide_colourbar(barwidth = 15, barheight = 0.5))
  } else {
    plots <- list()
    for(i in 1:n_charts) {
      if(is.list(en$embs)) {
        data <- as.data.frame(en$embs[[i]])
      } else {
        data <- as.data.frame(en$embs[i, , ])
      }
      colnames(data) <- c("x1", "x2")
      if(is.list(en$dists)) {
        data$dists <- en$dists[[i]]
        md <- maxdists[i]
      } else {
        if(dim(en$dists)[1] == 1) {
          data$dists <- en$dists[1, ]
          md <- maxdists
        } else {
          data$dists <- en$dists[i, ]
          md <- maxdists[i]
        }
      }
      plots[[i]] <-     ggplot(data) + geom_point(aes(x = x1, y = x2, colour = dists), size = en$pointSize/2) +
        scale_color_gradientn(colours = colours, limits = c(0, md), oob = squish) +
        ggtitle(en$titles[i]) +
        theme(axis.title = element_blank(), axis.line = element_blank(), panel.grid.major = element_blank(),
              axis.text = element_blank(), axis.ticks = element_blank(), panel.grid.minor = element_blank(),
              legend.position = "bottom", legend.title = element_blank()) + guides(colour = guide_colourbar(barwidth = 15, barheight = 0.5))
    }
    if(returnList) {
      plots
    } else {
      plot_grid(plotlist = plots)
    }
  }
}

