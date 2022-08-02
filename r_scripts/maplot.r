plotMAPlotly <- function(lfc, title) {
  no_na <- na.omit(lfc$padj)
  maxpadj <- max(-log10(no_na))
  minpadj <- min(-log10(no_na))

  col_tres <- (-log10(0.1) - minpadj) / (maxpadj - minpadj)

  p <- ggplot(as.data.frame(lfc), aes(
    x = log10(baseMean),
    y = log2FoldChange,
    col = ifelse(
      is.na(padj) | padj > 0.1,
      0,
      -log10(padj)
    ),
    text = paste0(
      rownames(lfc),
      "<br>",
      "log<sub>10</sub> average counts: ", sprintf("%.2f", log10(baseMean)),
      "<br>",
      "log<sub>2</sub> fold change: ", sprintf("%.2f", log2FoldChange),
      "<br>",
      "-log<sub>10</sub>(<i>P</i>): ", sprintf("%.4f", -log10(padj))
    )
  )) +
    labs(
      x = "log<sub>10</sub> base mean",
      y = "log<sub>2</sub> fold change",
      col = "-log<sub>10</sub>(<i>P</i>)",
      title = sprintf("%s MA Plot", title)
    ) +
    scale_colour_gradientn(
      colors = c("#253858", "#253858", "#1E87B0", "#20B0E8"),
      values = c(0, col_tres, col_tres + 0.0001, 1)
    ) +
    geom_point(size = 0.1) +
    theme_minimal()

  p %>%
    ggplotly(tooltip = c("text")) %>%
    plotly_style() %>%
    layout(
      xaxis = list(
        dtick = 1,
        tick0 = 0,
        tickmode = "linear",
        range = c(-1, 5)
      ),
      yaxis = list(
        dtick = 1,
        tick0 = 0,
        tickmode = "linear",
        range = c(-2, 2)
      )
    ) %>%
    toWebGL()
}
