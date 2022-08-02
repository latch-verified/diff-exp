#!/usr/bin/env Rscript

source("util.r")

p("Loading Libraries")
tryCatch(
  {
    suppressMessages(suppressWarnings(library(vctrs)))
    suppressMessages(suppressWarnings(library(dplyr)))
    suppressMessages(suppressWarnings(library(tibble)))
    suppressMessages(suppressWarnings(library(stringr)))

    suppressMessages(suppressWarnings(library(DEGreport)))
    suppressMessages(suppressWarnings(library(DESeq2)))

    suppressMessages(suppressWarnings(library(ggplot2)))
    suppressMessages(suppressWarnings(library(EnhancedVolcano)))
    suppressMessages(suppressWarnings(library(heatmaply)))
    suppressMessages(suppressWarnings(library(plotly)))

    suppressMessages(suppressWarnings(library(purrr)))
  },
  error = function(err) {
    p("  Failed")
    p(err)
    latch_error(list(source = "imports", error = as.character(err)))
    stop()
  }
)

source("latch.r")
source("plotly_util.r")

source("maplot.r")
source("volcanoplot.r")

get_plot_dims <- function(heat_map) {
  plot_height <- sum(sapply(heat_map$gtable$heights, grid::convertHeight, "in"))
  plot_width <- sum(sapply(heat_map$gtable$widths, grid::convertWidth, "in"))
  return(list(height = plot_height, width = plot_width))
}

heatmap_colorscheme_around0 <- scale_fill_gradient2(
  low = "#20B0E8",
  mid = "#FAFBFC",
  high = "#E84520",
  midpoint = 0
)

args <- commandArgs(trailingOnly = TRUE)
arg_design_matrix <- args[1]
arg_sample_id_column <- args[2]
arg_explanatory_columns <- args[3]
arg_confounding_columns <- args[4]
arg_cluster_columns <- args[5]
arg_counts_table <- args[6]
arg_gene_id_column <- args[7]
arg_goi <- args[8] # todo(maximsmol): make frontend-only
arg_num_sig_genes <- args[9]
arg_out_path <- args[10]

op <- function(x) {
  file.path(arg_out_path, x)
}

p("Arguments:")
p("  Design matrix: %s", arg_design_matrix)
p("  Design matrix sample ID column: '%s'", arg_sample_id_column)
p("  Design matrix explanatory columns: '%s'", arg_explanatory_columns)
p("  Design matrix comparison cluster columns: '%s'", arg_cluster_columns)
p("  Design matrix confounding columns: '%s'", arg_confounding_columns)
p("  Counts table: %s", arg_counts_table)
p("  Counts table gene ID column: '%s'", arg_gene_id_column)
p("  Genes of interest: %s", arg_goi)
p("  Number of significant genes: %s", arg_num_sig_genes)
p("")

sample_id_column <- vec_as_names(arg_sample_id_column, repair = "unique")
gene_id_column <- vec_as_names(arg_gene_id_column, repair = "unique")

p("Reading the design matrix")
tryCatch(
  {
    coldata <- read_tabular(arg_design_matrix) %>%
      mutate(across(!all_of(sample_id_column), as.factor))
    samples <- coldata[[sample_id_column]]

    # todo(maximsmol): allow releveling when/if we add support matters
    # mutate(condition = relevel(condition, "WT")) %>%
    # mutate(stage = relevel(stage, "iPSC"))
  },
  error = function(err) {
    p("  Failed")
    p(err)
    latch_error(list(source = "coldata read", error = as.character(err)))
    stop()
  }
)

dims <- dim(coldata)
p(sprintf("Design Matrix %s x %s: [head]", dims[1], dims[2]))
head(coldata)
p("")

tryCatch(
  {
    cts <- read_tabular(arg_counts_table) %>%
      select(all_of(gene_id_column) | all_of(samples)) %>%
      mutate(
        across(
          !all_of(gene_id_column),
          floor
        )
      )
  },
  error = function(err) {
    p("  Failed")
    p(err)
    latch_error(list(source = "cts read", error = as.character(err)))
    stop()
  }
)

p("Reading the counts table")
dims <- dim(cts)
p(sprintf("Counts Table %s x %s: [head]", dims[1], dims[2]))
head(cts)
p("")

genesOfInterest <- c()
tryCatch(
  {
    p("Reading genes of interest")
    genesSplit <- strsplit(arg_goi, ",")
    genesOfInterest <- genesSplit[[1]]
  },
  error = function(err) {
    p("  Failed")
    p(err)
    latch_error(list(source = "genesOfInterest", error = as.character(err)))
    stop()
  }
)

sigGenesNum <- 30
tryCatch(
  {
    p("Reading number of significant genes")
    sigGenesNum <- as.integer(arg_num_sig_genes)
  },
  error = function(err) {
    p("  Failed")
    p(err)
    latch_error(list(source = "sigGenesNum", error = as.character(err)))
    stop()
  }
)

tryCatch(
  {
    p("Plotting size factor QC")
    plot <- degCheckFactors(cts %>% select(!all_of(gene_id_column))) +
      labs(x = "Density", y = "Size Factor") +
      ggtitle("Gene Size Factor Distribution") +
      theme_minimal()

    png(file = op("Plots/QC/Size Factor QC.png"), width = 960, height = 540)
    print(plot)
    dev.off()

    plot$mapping$text <- plot$data$sample
    plot$layers[[1]]$aes_params$size <- 0.1
    plot %>%
      ggplotly(tooltip = c("text")) %>%
      partial_bundle(local = F) %>%
      saveWidgetCDN(op("Plots/QC/Size Factor QC.html"))
    p("")
    p("")
  },
  error = function(err) {
    p("  Failed")
    p(err)
    p("")
    p("")
    latch_warning(list(source = "size factor qc", error = as.character(err)))
  }
)

explanatory_columns <- str_split(arg_explanatory_columns, ",")[[1]] %>% str_trim()
confounding_columns <- str_split(arg_confounding_columns, ",")[[1]] %>% str_trim()
cluster_columns <- str_split(arg_cluster_columns, ",")[[1]] %>% str_trim()

if (explanatory_columns[[1]] == "") {
  explanatory_columns <- list()
}
if (confounding_columns[[1]] == "") {
  confounding_columns <- list()
}
if (cluster_columns[[1]] == "") {
  cluster_columns <- list()
}

if (length(explanatory_columns) == 1 && length(cluster_columns) == 0) {
  design_column <- colnames(coldata) %>%
    detect(~ tolower(.x) == tolower(explanatory_columns[1]))

  if (is.null(design_column)) {
    latch_warning(list(source = "design_column", message = "Specified design column not found"))
    design_column <- colnames(coldata) %>% detect(~ str_trim(tolower(.x)) == "group")
  }

  if (is.null(design_column)) {
    design_column <- colnames(coldata) %>% detect(~ .x != sample_id_column)
  }
} else if (length(cluster_columns) == 0) {
  coldata <- coldata %>%
    mutate(
      autogen_group =
        explanatory_columns %>%
          map(~ coldata[[.x]]) %>%
          reduce(paste, sep = ".") %>%
          as.factor()
    )

  design_column <- "autogen_group"
} else {
  coldata <- coldata %>%
    mutate(
      autogen_group =
        cluster_columns %>%
          map(~ coldata[[.x]]) %>%
          reduce(paste, sep = ".") %>%
          paste(
            explanatory_columns %>%
              map(~ coldata[[.x]]) %>%
              reduce(paste, sep = "."),
            sep = "__"
          ) %>%
          as.factor()
    )

  design_column <- "autogen_group"
}

p("Creating the DESeq2 dataset")
tryCatch(
  {
    if (length(confounding_columns) > 0) {
      design_formula <- sprintf(
        "~ %s + %s",
        design_column,
        paste(confounding_columns, collapse = " + ")
      )
    } else {
      design_formula <- sprintf(
        "~ %s",
        design_column
      )
    }
    p(sprintf("  Design formula: %s", design_formula))
    p(sprintf("  Condition column: %s", design_column))
    print(coldata[[design_column]])
    p("")

    ddsMat <- DESeqDataSetFromMatrix(
      cts %>%
        select(all_of(gene_id_column) | all_of(coldata[[sample_id_column]])) %>%
        column_to_rownames(gene_id_column),
      coldata %>%
        column_to_rownames(sample_id_column),
      as.formula(design_formula)
    )
    p("")
    p("")
  },
  error = function(err) {
    p("  Failed")
    p(err)
    latch_error(list(source = "ddsMat", error = as.character(err)))
    stop()
  }
)

p(">>><<<")
p("Running DESeq2")
tryCatch(
  {
    dds <- DESeq(ddsMat)
    # load("/Users/maximsmol/projects/latchbio/wf-core-deseq2/katja_dds.RData")
    p("")
    p("")

    print("DDS")
    print(dds)
    p("")
    p("")
    p("Writing DDS")
    saveRDS(dds, file = op("Data/dds.rds"))
    p("")

    p("Variance Stabilization Transform DDS")
    vsd <- vst(dds)
    vsd_assay <- assay(vsd)
    print(vsd)
    p("")
    p("")
    p("Writing vsd")
    saveRDS(vsd, file = op("Data/vsd.rds"))
    p("")
  },
  error = function(err) {
    p("  Failed")
    p(err)
    latch_error(list(source = "dds", error = as.character(err)))
    stop()
  }
)

tryCatch(
  {
    p("Plotting Sample Level PCA")

    names <- c(
      explanatory_columns,
      cluster_columns,
      confounding_columns,
      design_column
    )
    for (name in names) {
      tryCatch(
        {
          pca_plot <- plotPCA(vsd, intgroup = name) +
            theme_minimal() +
            ggtitle(sprintf("PCA grouped by %s", name))

          pca_plot$mapping$text <- rownames(pca_plot$data)
          pca_plot$layers[[1]]$aes_params$size <- 1.5
          pca_plot$labels$colour <- name

          png(
            file = op(sprintf("Plots/QC/PCA/%s.png", name)),
            width = 960,
            height = 540
          )
          print(pca_plot)
          dev.off()

          pca_plot %>%
            ggplotly(tooltip = c("text")) %>%
            plotly_style() %>%
            partial_bundle(local = F) %>%
            saveWidgetCDN(op(sprintf("Plots/QC/PCA/%s.html", name)))
        },
        error = function(err) {
          p(sprintf("  %s: failed", name))
          p(err)
          p("")
          p("")
          latch_warning(list(source = "pca plot", error = as.character(err)))
        }
      )
    }
  },
  error = function(err) {
    p("  Failed")
    p(err)
    p("")
    p("")
    latch_warning(list(source = "pca plot outer loop", error = as.character(err)))
  }
)


tryCatch(
  {
    p("Plotting sample correlation QC")

    vsd_cor <- cor(vsd_assay)
    write.csv(vsd_cor, file = op("Data/Sample Correlation.csv"))

    min_cor <- min(vsd_cor)
    max_cor <- max(vsd_cor)

    heatmaply(
      vsd_cor,
      fontsize_row = 7,
      fontsize_col = 7,
      column_text_angle = 60,
      scale_fill_gradient_fun = scale_fill_gradient2(
        low = "#20B0E8",
        mid = "#FAFBFC",
        high = "#E84520",
        midpoint = min_cor + (max_cor - min_cor) / 2
      ),
      label_names = c("Sample", "Gene", "Correlation"),
      # dendrogram = "none", # todo(maximsmol): allow switching this
    ) %>%
      plotly_style() %>%
      partial_bundle(local = F) %>%
      saveWidgetCDN(op("Plots/Sample Correlation.html"))
  },
  error = function(err) {
    p("  Failed")
    p(err)
    p("")
    p("")
    latch_warning(list(source = "sample correlation qc", error = as.character(err)))
  }
)

tryCatch(
  {
    p("Plotting heat map of the count matrix")

    p("  Finding the top 100 most expressed genes")
    sorted_vsd_assay <- vsd_assay %>%
      as_tibble(rownames = "gene_id") %>%
      rowwise() %>%
      mutate(
        max = max(across(!all_of("gene_id")))
      ) %>%
      ungroup() %>%
      slice_max(max, n = 100, with_ties = FALSE)

    p("  Computing Z scores")
    sorted_vsd_assay <- sorted_vsd_assay %>%
      select(!max) %>%
      rowwise() %>%
      mutate(
        mean = rowMeans(across(!all_of("gene_id"))),
        sd = sd(across(!all_of("gene_id")))
      ) %>%
      mutate(
        across(!all_of(c("gene_id", "mean", "sd")), ~ (.x - mean) / sd)
      ) %>%
      ungroup() %>%
      select(!all_of(c("mean", "sd"))) %>%
      na.omit() %>%
      column_to_rownames("gene_id")

    p("  Saving results")
    write.csv(sorted_vsd_assay, file = op("Data/Counts Heatmap.csv"))

    p("  Saving plot")
    plot <- heatmaply(
      sorted_vsd_assay,
      fontsize_row = 7,
      fontsize_col = 7,
      column_text_angle = 60,
      scale_fill_gradient_fun = heatmap_colorscheme_around0,
      label_names = c("Sample", "Gene", "Count Z-Score"),
      # dendrogram = "none", # todo(maximsmol): allow switching this
    ) %>%
      plotly_style() %>%
      partial_bundle(local = F) %>%
      saveWidgetCDN(op("Plots/QC/Counts Heatmap.html"))

    p("  Repeating for genes of interest")
    if (length(genesOfInterest) > 0) {
      sorted_vsd_assay <- vsd_assay[rownames(vsd_assay) %in% genesOfInterest] %>%
        as_tibble(rownames = "gene_id")

      sorted_vsd_assay <- sorted_vsd_assay %>%
        slice(1:100) %>%
        rowwise() %>%
        mutate(
          mean = rowMeans(across(!all_of("gene_id"))),
          sd = sd(across(!all_of("gene_id")))
        ) %>%
        mutate(
          across(!all_of(c("gene_id", "mean", "sd")), ~ (.x - mean) / sd)
        ) %>%
        ungroup() %>%
        select(!all_of(c("mean", "sd"))) %>%
        na.omit() %>%
        column_to_rownames("gene_id")

      plot <- heatmaply(
        sorted_vsd_assay,
        fontsize_row = 7,
        fontsize_col = 7,
        column_text_angle = 60,
        scale_fill_gradient_fun = heatmap_colorscheme_around0,
        label_names = c("Sample", "Gene", "Count Z-Score"),
        # todo(maximsmol): style these, and change colors
        # dendrogram = "none", # todo(maximsmol): allow switching this
      ) %>%
        plotly_style() %>%
        partial_bundle(local = F) %>%
        saveWidgetCDN(op("Plots/Counts Heatmap (Genes of Interest).html"))

      write.csv(sorted_vsd_assay, file = op("Data/Counts Heatmap (Genes of Interest).csv"))
    }
  },
  error = function(err) {
    p("  Failed")
    p(err)
    p("")
    p("")
    latch_warning(list(source = "count matrix heatmap", error = as.character(err)))
  }
)

plotVolcano <- function(column_name) {
  tryCatch(
    {
      ls <- levels(coldata[[column_name]])

      for (i in 1:length(ls)) {
        l1 <- ls[[i]]
        for (j in 1:length(ls)) {
          l2 <- ls[[j]]
          if (l1 == l2) {
            next
          }

          cluster1 <- str_split(l1, "__")[[1]]
          cluster2 <- str_split(l2, "__")[[1]]
          if (
            length(cluster1) > 1 && length(cluster2) > 1 &&
              cluster1[[1]] != cluster2[[1]]
          ) {
            next
          }

          g1 <- str_replace_all(l1, "/", "_")
          g2 <- str_replace_all(l2, "/", "_")
          if (g1 == g2) {
            next
          }

          tryCatch(
            {
              full <- sprintf("%s vs %s (%s)", g1, g2, column_name)
              p(sprintf("Generating QC, MA, and Volcano Plot for %s vs %s", g1, g2))

              res <- results(dds, contrast = c(column_name, l1, l2))

              write.csv(as.data.frame(res), file = op(sprintf("Data/Contrast/%s.csv", full)))

              dir.create(op(sprintf("Plots/Contrast/%s/", full)))

              lfc <- lfcShrink(dds, res = res, type = "ashr")

              tryCatch(
                {
                  p("Plotting Sample Variance and P Value Distribution")
                  res_df <- as.data.frame(res)
                  pvalue <- res_df[["pvalue"]]
                  png(file = op(sprintf("Plots/QC/Variance P-Value/%s.png", full)), width = 960, height = 540)
                  print(degQC(counts(dds, normalized = TRUE), names(colData(dds)), pvalue = pvalue))
                  dev.off()
                  p("")
                  p("")
                },
                error = function(err) {
                  p("  Failed")
                  p(err)
                  p("")
                  p("")
                  latch_warning(list(source = "variance pvalue qc", error = as.character(err)))
                }
              )

              png(file = op(sprintf("Plots/Contrast/%s/MA.png", full)), width = 960, height = 540)
              ma_plot <- plotMA(lfc, ylim = c(-2, 2), main = paste(g1, g2, sep = " vs "))
              print(ma_plot)
              dev.off()

              plotMAPlotly(lfc, full) %>%
                partial_bundle(local = F) %>%
                saveWidgetCDN(op(sprintf("Plots/Contrast/%s/MA.html", full)))

              if (length(genesOfInterest) > 0) {
                whichLabels <- genesOfInterest
                voc1 <- EnhancedVolcano(
                  lfc,
                  lab = rownames(lfc),
                  selectLab = whichLabels,
                  drawConnectors = TRUE,
                  x = "log2FoldChange",
                  y = "padj",
                  title = sprintf("%s Target Genes", full),
                  subtitle = "",
                  legendPosition = "none",
                  widthConnectors = 0.5,
                )
                png(file = op(sprintf("Plots/Contrast/%s/Volcano (Genes of Interest).png", full)), width = 960, height = 540)
                print(voc1)
                dev.off()
              }

              voc2 <- EnhancedVolcano(
                lfc,
                lab = rownames(lfc),
                drawConnectors = TRUE,
                x = "log2FoldChange",
                y = "padj",
                title = sprintf("%s vs %s", g1, g2),
                subtitle = "",
                legendPosition = "none",
                widthConnectors = 0.5,
              )
              png(file = op(sprintf("Plots/Contrast/%s/Volcano.png", full)), width = 960, height = 540)
              print(voc2)
              dev.off()

              plotVolcanoPlotly(lfc, sprintf("%s vs %s", g1, g2)) %>%
                partial_bundle(local = F) %>%
                saveWidgetCDN(op(sprintf("Plots/Contrast/%s/Volcano.html", full)))
            },
            error = function(err) {
              p(paste("", full, "Failed", sep = " "))
              p(err)
              p("")
              p("")
              latch_warning(list(source = "volcano plot", error = as.character(err)))
            }
          )
        }
      }
    },
    error = function(err) {
      p("  Failed")
      p(err)
      p("")
      p("")
      latch_warning(list(source = "volcano and ma plot generation", error = as.character(err)))
    }
  )
}

plotVolcano(design_column)

for (x in confounding_columns) {
  plotVolcano(x)
}

quit(status = 0)
