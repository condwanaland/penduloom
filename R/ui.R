penduloom_dependency <- function() {
  asset_path <- system.file("app/www", package = "penduloom")
  if (!nzchar(asset_path)) {
    stop("Could not locate penduloom's browser assets. Reinstall the package.",
         call. = FALSE)
  }

  htmltools::htmlDependency(
    name = "penduloom-assets",
    version = as.character(utils::packageVersion("penduloom")),
    src = c(file = asset_path),
    script = "app.js",
    stylesheet = "styles.css",
    all_files = FALSE
  )
}

penduloom_ui <- function() {
  tags <- htmltools::tags

  bslib::page_fillable(
    title = "Penduloom",
    theme = bslib::bs_theme(
      version = 5,
      bg = "#f5f6f7",
      fg = "#1f2933",
      primary = "#b45309",
      secondary = "#66717d",
      base_font = bslib::font_collection(
        "Avenir Next", "Segoe UI", "Helvetica Neue", "sans-serif"
      ),
      heading_font = bslib::font_collection(
        "Avenir Next", "Segoe UI", "Helvetica Neue", "sans-serif"
      )
    ),
    penduloom_dependency(),
    tags$head(
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")
    ),
    tags$div(
      class = "app-shell",
      tags$div(
        class = "topbar",
        tags$div(
          class = "brand-lockup",
          tags$div(
            tags$div(class = "brand-name", "penduloom"),
            tags$div(class = "brand-subtitle", "Pendulum simulator")
          )
        )
      ),
      bslib::layout_sidebar(
        class = "studio-layout",
        sidebar = bslib::sidebar(
          width = 350,
          open = "always",
          tags$div(
            class = "control-section preset-section",
            shiny::selectInput(
              "preset", "Preset",
              choices = preset_choices(), selected = "custom"
            )
          ),
          tags$div(
            class = "control-section",
            tags$div(class = "section-label", "Structure"),
            shiny::sliderInput(
              "joint_count", "Number of joints",
              min = 1, max = 8, value = 3, step = 1
            )
          ),
          tags$div(
            class = "control-section joint-section",
            tags$div(class = "section-label", "Joint settings"),
            shiny::uiOutput("joint_controls")
          ),
          tags$div(
            class = "trace-row",
            tags$strong("Path tracing"),
            bslib::input_switch("trace_enabled", NULL, value = TRUE)
          ),
          tags$div(
            class = "trace-row",
            tags$strong("Show pendulum"),
            bslib::input_switch("show_pendulum", NULL, value = TRUE)
          ),
          tags$div(
            class = "control-actions",
            shiny::actionButton(
              "run_toggle", tags$span(shiny::icon("play"), tags$span("Run")),
              class = "btn-run"
            ),
            shiny::actionButton(
              "step_frame", tags$span(shiny::icon("forward-step"), tags$span("Step")),
              class = "btn-step", title = "Advance by one 60 FPS frame",
              `aria-label` = "Advance by one frame"
            ),
            shiny::actionButton(
              "reset", tags$span(shiny::icon("rotate-left"), tags$span("Reset")),
              class = "btn-reset", title = "Reset simulation",
              `aria-label` = "Reset simulation"
            ),
            shiny::actionButton(
              "export_image", tags$span(shiny::icon("download"), tags$span("Export PNG")),
              class = "btn-export"
            )
          )
        ),
        tags$div(
          class = "stage-wrap",
          tags$canvas(
            id = "pendulum-canvas",
            `aria-label` = "Animated chained pendulum simulation",
            role = "img"
          ),
          tags$div(
            class = "stage-overlay readout-panel",
            tags$div(
              tags$span(class = "readout-label", "Elapsed"),
              tags$span(id = "elapsed-readout", class = "readout-value", "00:00.00")
            ),
            tags$div(
              tags$span(class = "readout-label", "Tip speed"),
              tags$span(id = "velocity-readout", class = "readout-value", "0.00")
            )
          )
        )
      )
    )
  )
}

