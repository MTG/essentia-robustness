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

# options(echo=T)

DEFAULT_PATH_BASE <- file.path("..", "data")

# PARSE COMMAND LINE ARGUMENTS #####################################################################

args <- commandArgs(trailingOnly=T)
tool.name <- args[1]
track.length <- args[2]
srate <- args[3]
descriptor.name <- args[4]
path.base <- args[5]
path.base <- ifelse(is.na(path.base), DEFAULT_PATH_BASE, path.base)

# Check arguments
if(is.na(tool.name) | is.na(track.length) | is.na(srate) | is.na(descriptor.name) | is.na(path.base)){
  cat(sep="",
      "usage: Rscript distributions.R <tool> <track-length> <srate> <descriptor> [<path>]\n",
      "\n",
      "tool          name of the tool used to compute descriptors, eg. 'essentia'.\n",
      "track-length  length of the track used to compute descriptors, eg '30-60'.\n",
      "srate         sampling rate of the track used to compute descriptors, eg. '44100'.\n",
      "descriptor    name of the descriptor to describe distributions with, eg. 'lowlevel.mfcc.mean'.\n",
      "path          optional path to all data, defaults to '", DEFAULT_PATH_BASE, "'.\n",
      "\n",
      "Expected file structure:\n",
      "  path/indicators/<tool>/<track-length>/<srate>/<descriptor>.txt\n")
  q(status=1)
}
path.indicators <- file.path(path.base, "indicators", tool.name, track.length, srate,
                             paste0(descriptor.name, ".txt"))
if(!file.exists(path.indicators)){
  cat(sep="", "Error: indicators file '", path.indicators, "' does not exist.\n")
  q(status=1)
}

# RUN ##############################################################################################

library(doBy)

# Prepare destination file =========================================================================

# For efficiency, we simply write tab-separated raw data instead of creating temporary data.frames
# and then writing them to the file.
path.distribution <- file.path(path.base, "distributions", tool.name, track.length, srate,
                               paste0(descriptor.name, ".txt"))
dir.create(dirname(path.distribution), recursive=T, showWarnings=F)
# Delete previous data, if any
unlink(path.distribution, force=T)
# Initialize file
conn <- file(path.distribution, open="w")

# Read indicators data and describe distributions ==================================================

ind <- read.table(path.indicators, head=T, sep="\t", quote="\"", stringsAsFactors=F)
track.index <- which(names(ind) == "track") # to quickly index factor names and indicators

# Traverse indicators
for(i in (track.index+1):length(ind)){
  ind.name <- names(ind)[i]
  ind.cleanname <- gsub("ind.", "", ind.name, fixed=T)
  
  # Overall distribution ---------------------------------------------------------------------------
  
  form <- as.formula(paste0(ind.name, " ~ 1"))
  a <- summaryBy(form, data=ind, FUN=function(x){ list(mean(x), median(x), var(x), sd(x)) })
  names(a)[seq(to=length(a), length.out=4)] <- c("mean","median","var","sd")
  
  writeLines(c(paste("**", ind.cleanname),
               paste(names(a), collapse="\t"),
               apply(a, 1, function(x){ paste(x, collapse="\t") }),
               ""),
             con=conn)
  
  # Distributions by factors -----------------------------------------------------------------------
  
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
  
  for(f in factors){
    form <- as.formula(paste0(ind.name, " ~ ", f))
    a <- summaryBy(form, data=ind, FUN=function(x){ list(mean(x), median(x), var(x), sd(x)) })
    names(a)[seq(to=length(a), length.out=4)] <- c("mean","median","var","sd")
    
    writeLines(c(paste("**", ind.cleanname, "by", f),
                 paste(names(a), collapse="\t"),
                 apply(a, 1, function(x){ paste(x, collapse="\t") }),
                 ""),
               con=conn)
  }
}

# Close destination file
close(conn)