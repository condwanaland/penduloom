test_that("server flushes configuration inside a reactive context", {
  shiny::testServer(penduloom:::penduloom_server, {
    session$setInputs(joint_count = 3, trace_enabled = TRUE, preset = "custom")

    expect_no_error(session$flushReact())

    session$setInputs(joint_count = 5)
    expect_no_error(session$flushReact())

    session$setInputs(preset = "deltoid")
    expect_no_error(session$flushReact())

    session$setInputs(show_pendulum = FALSE, step_frame = 1, export_image = 1)
    expect_no_error(session$flushReact())

    session$setInputs(
      penduloom_length_edit = list(
        index = 1, value = 205, playhead = 0.5, nonce = 1
      )
    )
    expect_no_error(session$flushReact())
  })
})

test_that("drawing presets contain valid configurations", {
  expect_length(penduloom:::penduloom_presets, 7)

  for (preset in penduloom:::penduloom_presets) {
    expect_equal(length(preset$lengths), length(preset$speeds))
    expect_true(length(preset$lengths) %in% 1:8)
    expect_true(all(preset$lengths >= 35 & preset$lengths <= 220))
    expect_true(all(preset$speeds >= -1080 & preset$speeds <= 1080))
  }
})

test_that("trajectory messages contain R-generated frame batches", {
  config <- list(
    lengths = c(100, 80),
    speeds = c(120, -45),
    colors = c("#aaa", "#bbb"),
    trace = TRUE,
    showPendulum = TRUE
  )
  message <- penduloom:::trajectory_message(config, 120, revision = 4)

  expect_equal(message$startFrame, 120)
  expect_equal(message$fps, 60)
  expect_equal(dim(message$x), c(601, 3))
  expect_equal(dim(message$y), c(601, 3))
  expect_equal(message$x[1, ], pendulum_trajectory(2, c(100, 80), c(120, -45))$x[1, ])
})

