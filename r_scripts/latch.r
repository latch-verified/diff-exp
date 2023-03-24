library(rjson)

latch_message <- function(type, data) {
  p("__LATCH_MESSAGE_DATA %s %s", type, toJSON(data))
}

latch_warning <- function(data) {
  p("__LATCH_MESSAGE_DATA error %s", toJSON(data))
}

latch_error <- function(data) {
  p("__LATCH_MESSAGE_DATA error %s", toJSON(data))
}
