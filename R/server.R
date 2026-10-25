joint_palette <- c("#b45309", "#c2410c", "#be123c", "#7c3aed",
                   "#2563eb", "#0891b2", "#059669", "#65a30d")
speed_limit <- 1080
arm_length_limits <- c(35, 220)
simulation_fps <- 60L
simulation_batch_seconds <- 10L

joint_defaults <- function(n) {
  speeds <- c(35, -58, 82, -47, 68, -91, 54, -72)
  lengths <- c(150, 120, 98, 82, 70, 62, 56, 50)
  list(speeds = speeds[seq_len(n)], lengths = lengths[seq_len(n)])
}

bounded_number <- function(value, fallback, lower, upper) {
  if (length(value) != 1L || !is.finite(value)) {
    return(fallback)
  }
  max(lower, min(upper, value))
}

trajectory_message <- function(config, start_frame, revision, replace = TRUE,
                               reset_time = FALSE) {
  start_frame <- max(0L, as.integer(start_frame))
  frame_count <- simulation_fps * simulation_batch_seconds + 1L
  frame_numbers <- seq.int(start_frame, length.out = frame_count)
  trajectory <- pendulum_trajectory(
    times = frame_numbers / simulation_fps,
    lengths = config$lengths,
    speeds = config$speeds
  )

  list(
    revision = revision,
    replace = replace,
    resetTime = reset_time,
    startFrame = start_frame,
    fps = simulation_fps,
    reach = sum(config$lengths),
    signature = paste(c(config$speeds, config$lengths), collapse = ":"),
    colors = config$colors,
    trace = config$trace,
    showPendulum = config$showPendulum,
    x = unname(trajectory$x),
    y = unname(trajectory$y)
  )
}

penduloom_server <- function(input, output, session) {
  tags <- htmltools::tags
  is_running <- shiny::reactiveVal(FALSE)
  revision_id <- 0L
  active_config <- NULL

  configuration_from_preset <- function(preset) {
    n <- length(preset$lengths)
    list(
      count = n,
      speeds = preset$speeds,
      lengths = preset$lengths,
      trace = isTRUE(input$trace_enabled %||% TRUE),
      showPendulum = isTRUE(input$show_pendulum %||% TRUE),
      colors = joint_palette[seq_len(n)]
    )
  }

  output$joint_controls <- shiny::renderUI({
    n <- input$joint_count %||% 3
    defaults <- joint_defaults(n)
    preset <- selected_preset(input$preset)

    shiny::tagList(lapply(seq_len(n), function(i) {
      if (!is.null(preset) && length(preset$lengths) == n) {
        speed_value <- preset$speeds[[i]]
        length_value <- preset$lengths[[i]]
      } else {
        speed_value <- shiny::isolate(input[[paste0("speed_", i)]]) %||%
          defaults$speeds[[i]]
        length_value <- shiny::isolate(input[[paste0("length_", i)]]) %||%
          defaults$lengths[[i]]
      }

      tags$div(
        class = "joint-card",
        tags$div(
          class = "joint-card-head",
          tags$span(class = "joint-identity",
               tags$span(class = "joint-swatch", style = paste0("--joint: ", joint_palette[[i]])),
               paste("Joint", i)),
          tags$span(class = "joint-direction", if (speed_value < 0) "CCW" else "CW")
        ),
        tags$div(
          class = "joint-input-grid",
          shiny::numericInput(
            paste0("speed_", i), "Angular speed",
            value = speed_value, min = -speed_limit, max = speed_limit, step = 1
          ),
          shiny::numericInput(
            paste0("length_", i), "Arm length",
            value = length_value, min = arm_length_limits[[1]],
            max = arm_length_limits[[2]], step = 1
          )
        )
      )
    }))
  })

  configuration <- function() {
    n <- input$joint_count %||% 3
    defaults <- joint_defaults(n)
    speeds <- vapply(seq_len(n), function(i) {
      bounded_number(
        input[[paste0("speed_", i)]], defaults$speeds[[i]],
        -speed_limit, speed_limit
      )
    }, numeric(1))
    lengths <- vapply(seq_len(n), function(i) {
      bounded_number(
        input[[paste0("length_", i)]], defaults$lengths[[i]],
        arm_length_limits[[1]], arm_length_limits[[2]]
      )
    }, numeric(1))

    list(
      count = n,
      speeds = speeds,
      lengths = lengths,
      trace = isTRUE(input$trace_enabled %||% TRUE),
      showPendulum = isTRUE(input$show_pendulum %||% TRUE),
      colors = joint_palette[seq_len(n)]
    )
  }

  playhead <- function(value = input$penduloom_playhead) {
    bounded_number(value, 0, 0, .Machine$double.xmax)
  }

  publish_configuration <- function(config, start_time = 0, reset_time = FALSE) {
    revision_id <<- revision_id + 1L
    active_config <<- config
    start_frame <- floor(playhead(start_time) * simulation_fps)
    session$sendCustomMessage(
      "penduloom:trajectory",
      trajectory_message(
        config, start_frame, revision_id,
        replace = TRUE, reset_time = reset_time
      )
    )
  }

  shiny::observeEvent(input$preset, {
    preset <- selected_preset(input$preset)
    if (is.null(preset)) {
      return()
    }

    is_running(FALSE)
    shiny::updateSliderInput(
      session, "joint_count", value = length(preset$lengths)
    )
    publish_configuration(
      configuration_from_preset(preset), 0, reset_time = TRUE
    )
    session$sendCustomMessage("penduloom:running", list(running = FALSE))
    session$sendCustomMessage("penduloom:reset", list())
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$run_toggle, {
    next_state <- !is_running()
    is_running(next_state)
    config <- configuration()
    preset <- selected_preset(input$preset)
    if (!is.null(preset) &&
        (!isTRUE(all.equal(config$speeds, preset$speeds)) ||
         !isTRUE(all.equal(config$lengths, preset$lengths)))) {
      shiny::updateSelectInput(session, "preset", selected = "custom")
    }
    publish_configuration(config, playhead())
    session$sendCustomMessage("penduloom:running", list(running = next_state))
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$reset, {
    is_running(FALSE)
    publish_configuration(configuration(), 0, reset_time = TRUE)
    session$sendCustomMessage("penduloom:reset", list())
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$step_frame, {
    is_running(FALSE)
    publish_configuration(configuration(), playhead())
    session$sendCustomMessage("penduloom:running", list(running = FALSE))
    session$sendCustomMessage("penduloom:step", list(seconds = 1 / simulation_fps))
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$export_image, {
    session$sendCustomMessage("penduloom:export", list())
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$trace_enabled, {
    session$sendCustomMessage(
      "penduloom:trace",
      list(enabled = isTRUE(input$trace_enabled))
    )
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$show_pendulum, {
    session$sendCustomMessage(
      "penduloom:pendulum",
      list(visible = isTRUE(input$show_pendulum))
    )
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$penduloom_length_edit, {
    edit <- input$penduloom_length_edit
    index <- as.integer(edit$index)
    config <- configuration()

    if (length(index) == 1L && is.finite(index) &&
        index >= 1L && index <= config$count) {
      config$lengths[[index]] <- bounded_number(
        edit$value, config$lengths[[index]],
        arm_length_limits[[1]], arm_length_limits[[2]]
      )
      shiny::updateSelectInput(session, "preset", selected = "custom")
      publish_configuration(config, playhead(edit$playhead))
    }
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$penduloom_batch_request, {
    request <- input$penduloom_batch_request
    request_revision <- as.integer(request$revision)
    start_frame <- as.integer(request$startFrame)

    if (!is.null(active_config) && length(request_revision) == 1L &&
        is.finite(request_revision) && request_revision == revision_id &&
        length(start_frame) == 1L && is.finite(start_frame)) {
      session$sendCustomMessage(
        "penduloom:trajectory",
        trajectory_message(
          active_config, start_frame, revision_id,
          replace = FALSE, reset_time = FALSE
        )
      )
    }
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$joint_count, {
    preset <- selected_preset(input$preset)
    if (!is.null(preset) && length(preset$lengths) != input$joint_count) {
      shiny::updateSelectInput(session, "preset", selected = "custom")
      preset <- NULL
    }
    is_running(FALSE)
    session$sendCustomMessage("penduloom:running", list(running = FALSE))
    session$onFlushed(function() {
      shiny::isolate({
        config <- if (is.null(preset)) {
          configuration()
        } else {
          configuration_from_preset(preset)
        }
        publish_configuration(config, 0, reset_time = TRUE)
      })
      session$sendCustomMessage("penduloom:reset", list())
    }, once = TRUE)
  }, ignoreInit = TRUE)

  session$onFlushed(function() {
    shiny::isolate(publish_configuration(configuration(), 0, reset_time = TRUE))
  }, once = TRUE)
}

