#!/usr/bin/env Rscript

if (!require("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install(version = "3.15")

source("/usr/local/lib/R/etc/RProfile.site")
install.packages("/root/lasso2", repos = NULL, type = "source")

BiocManager::install(c(
    "DESeq2",
    "DEGreport",
    "ashr",

    "rjson",

    "purrr",
    "vctrs",
    "dplyr",
    "tibble",
    "readr",
    "readxl",

    "ggplot2",
    "ggrepel",
    "EnhancedVolcano",
    "heatmaply",
    "RColorBrewer",
    "plotly",
    "stringr",
    "data.table"
  ), update=FALSE)
