library(readr)
library(readxl)

p <- function(msg, ...) {
  cat(sprintf(as.character(msg), ...), sep = "\n")
}

read_tabular <- function(path) {
  tryCatch(
    {
      read_excel(path)
    },
    error = function(cond) {
      read_delim(path, trim_ws = TRUE)
    }
  )
}
