# Copyright (C) 2014  Music Technology Group - Universitat Pompeu Fabra
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses/.

# CHECK ARGUMENTS (taken from main script) #########################################################

path.indicators <- file.path(path.base, "results", tool.name, track.length, srate, descriptor.name,
                             "indicators.txt")
if(!file.exists(path.indicators)){
  cat(sep="", "Error: indicators file '", path.indicators, "' does not exist.\n")
  q(status=1)
}

# RUN ##############################################################################################

library(doBy)

# Prepare destination file =========================================================================

# For efficiency, we simply write tab-separated raw data instead of creating temporary data.frames
# and then writing them to the file.
path.distribution <- file.path(path.base, "results", tool.name, track.length, srate, descriptor.name,
                            "distributions.txt")
dir.create(dirname(path.distribution), recursive=T, showWarnings=F)
# Delete previous data, if any
unlink(path.distribution, force=T)
# Initialize file
conn <- file(path.distribution, open="w")

# Read indicators data and describe distributions ==================================================

ind <- read.table(path.indicators, head=T, sep="\t", quote="\"", stringsAsFactors=F)
track.index <- which(names(ind) == "track") # to quickly index factor names and indicators

# Function and names of the summaries
summary.fun <- function(x){ c(length(x),
                              mean(x), median(x),
                              min(x), max(x),
                              quantile(x, .025), quantile(x, .975),
                              var(x), sd(x)) }
summary.names <- paste0("desc.", c("n",
                                   "mean","median",
                                   "min", "max",
                                   "p2.5","p97.5",
                                   "var","sd"))

# Compile list of effects to summarize by ----------------------------------------------------------

factors <- c("genre", "track", "codec", "codec:brate")
# If we have custom params, parse and add to list of factors
if(track.index != 4){
  params <- names(ind)[3:(track.index-2)]
  
  # Include params main effects
  factors <- append(factors, params)
  # their interaction with the codec effect
  factors <- append(factors, paste("codec", params, sep=":"))
  # and their interaction with the codec:brate effect
  factors <- append(factors, paste("codec:brate", params, sep=":"))
}

# Traverse indicators
for(i in (track.index+1):length(ind)){
  ind.name <- names(ind)[i]
  ind.cleanname <- gsub("ind.", "", ind.name, fixed=T)
  
  # Overall distribution ---------------------------------------------------------------------------
  
  form <- as.formula(paste0(ind.name, " ~ 1"))
  a <- summaryBy(form, data=ind, FUN=summary.fun)
  names(a)[seq(to=length(a), length.out=length(summary.names))] <- summary.names
  
  writeLines(c(paste("**", ind.cleanname),
               paste(names(a), collapse="\t"),
               apply(a, 1, function(x){ paste(x, collapse="\t") }),
               ""),
             con=conn)
  
  # Distributions by factors -----------------------------------------------------------------------
  
  for(f in factors[order.factors(factors)]){
    form <- as.formula(paste0(ind.name, " ~ ", f))
    a <- summaryBy(form, data=ind, FUN=summary.fun)
    names(a)[seq(to=length(a), length.out=length(summary.names))] <- summary.names
    
    writeLines(c(paste("**", ind.cleanname, "by", f),
                 paste(names(a), collapse="\t"),
                 apply(a, 1, function(x){ paste(x, collapse="\t") }),
                 ""),
               con=conn)
  }
}

# Close destination file
close(conn)
