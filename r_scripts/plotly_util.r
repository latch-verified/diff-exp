library(purrr)

library(htmlwidgets)

cdn_base_url <- "https://latch-public.s3.us-west-2.amazonaws.com/R_cdn/"
cdn_packages <- list(
  typedarray = "typedarray-0.1/",
  jquery = "jquery-3.5.1/",
  crosstalk = "crosstalk-1.2.0/",
  "plotly-htmlwidgets-css" = "plotly-htmlwidgets-css-2.5.1/",
  "plotly-binding" = "plotly-binding-4.10.0/",
  htmlwidgets = "htmlwidgets-1.5.4/"
) %>% map(~ paste0(cdn_base_url, .x))

# >>> Monkey-patch htmlwidgets
htmlwidgets <- getNamespace("htmlwidgets")
old_html_widgets_getDependency <- htmlwidgets::getDependency

unlockBinding("getDependency", htmlwidgets)
htmlwidgets$getDependency <- function(name, package = name) {
  map(old_html_widgets_getDependency(name, package), function(x) {
    h <- cdn_packages[[x$name]]
    if (is.null(h)) {
      return(x)
    }

    x$src$href <- h
    x$src$file <- NULL

    x
  })
}
lockBinding("getDependency", htmlwidgets)
# >>>

saveWidgetCDN <- function(plot, file) {
  plot$dependencies <- map(plot$dependencies, function(x) {
    if (is.null(x$src$file)) {
      return(x)
    }

    h <- cdn_packages[[x$name]]
    if (is.null(h)) {
      return(x)
    }

    x$src$href <- h
    x$src$file <- NULL

    x
  })

  saveWidget(plot, file, selfcontained = FALSE)
}

plotly_style <- function(p) {
  style(p, hoverlabel = list(
    bgcolor = "#FAFBFC",
    bordercolor = "#F0F1F2",
    font = list(
      # family = "Inter", # todo(maximsmol)
      size = 15,
      color = "#474b52"
    )
  ))
}
