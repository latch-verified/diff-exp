plotVolcanoPlotly <- function(lfc, title) {
  maxl2fc <- max(lfc$log2FoldChange)
  minl2fc <- min(lfc$log2FoldChange)

  col_tres_low <- (-2 - minl2fc) / (maxl2fc - minl2fc)
  col_tres_high <- (2 - minl2fc) / (maxl2fc - minl2fc)

  vol <- ggplot(
    data = as.data.frame(lfc),
    aes(
      x = log2FoldChange,
      y = -log10(padj),
      col = log2FoldChange,
      text = paste0(
        rownames(lfc),
        "<br>",
        "-log<sub>10</sub>(<i>P</i>): ", sprintf("%.4f", -log10(padj)),
        "<br>",
        "log<sub>2</sub> fold change: ", sprintf("%.4f", log2FoldChange)
      )
    )
  ) +
    scale_colour_gradientn(
      colors = c("#20B0E8", "#1E87B0", "#253858", "#253858", "#B0391E", "#E84520"),
      values = c(0, col_tres_low, col_tres_low + 0.0001, col_tres_high, col_tres_high + 0.0001, 1)
    ) +
    scale_x_continuous() +
    geom_vline(xintercept = c(-2, 2), linetype = 2, size = 0.1) +
    geom_hline(yintercept = -log10(0.01), linetype = 2, size = 0.1) +
    geom_point(size = 0.5) +
    labs(
      x = "log<sub>2</sub> fold change",
      y = "-log<sub>10</sub>(<i>P</i>)",
      col = "log<sub>2</sub> fold change",
      title = title
    ) +
    theme_minimal()

  ggplotly(vol, tooltip = c("text")) %>%
    plotly_style() %>%
    layout(
      xaxis = list(
        dtick = 5,
        tick0 = 0,
        tickmode = "linear"
      ),
      yaxis = list(
        dtick = 5,
        tick0 = 0,
        tickmode = "linear"
      )
    ) %>%
    toWebGL()
}
