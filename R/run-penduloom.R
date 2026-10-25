#' Create or run the penduloom Shiny application
#'
#' `penduloom_app()` creates the application object without starting a server.
#' `run_penduloom()` launches that object with [shiny::runApp()].
#'
#' @return `penduloom_app()` returns a `shiny.appobj`. `run_penduloom()`
#'   invisibly returns the value from [shiny::runApp()].
#' @export
#'
#' @examples
#' app <- penduloom_app()
penduloom_app <- function() {
  shiny::shinyApp(ui = penduloom_ui(), server = penduloom_server)
}

#' @rdname penduloom_app
#' @param ... Arguments passed to [shiny::runApp()], such as `port` or
#'   `launch.browser`.
#' @export
#'
#' @examples
#' \dontrun{
#' run_penduloom()
#' }
run_penduloom <- function(...) {
  shiny::runApp(penduloom_app(), ...)
}

