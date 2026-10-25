test_that("stationary pendulum hangs vertically", {
  result <- pendulum_positions(
    time = 10,
    lengths = c(2, 3),
    speeds = c(0, 0)
  )

  expect_equal(unname(result[, "x"]), c(0, 0, 0))
  expect_equal(unname(result[, "y"]), c(0, 2, 5))
})

test_that("relative angles accumulate along the chain", {
  result <- pendulum_positions(
    time = 1,
    lengths = c(1, 1),
    speeds = c(90, -90)
  )

  expect_equal(unname(result[2, ]), c(1, 0), tolerance = 1e-12)
  expect_equal(unname(result[3, ]), c(1, 1), tolerance = 1e-12)
})

test_that("invalid configurations are rejected", {
  expect_error(pendulum_positions(0, c(1, -1), c(10, 20)))
  expect_error(pendulum_positions(0, c(1, 1), 10))
  expect_error(pendulum_positions(0, 1, 10, phases = c(0, 2)))
})

test_that("trajectory batches agree with individual position calculations", {
  times <- seq(0, 2, by = 0.25)
  batch <- pendulum_trajectory(
    times,
    lengths = c(2, 1.5, 0.75),
    speeds = c(120, -45, 310)
  )

  expect_equal(dim(batch$x), c(length(times), 4))
  expect_equal(dim(batch$y), c(length(times), 4))

  expected <- pendulum_positions(
    times[[5]],
    lengths = c(2, 1.5, 0.75),
    speeds = c(120, -45, 310)
  )
  expect_equal(unname(batch$x[5, ]), unname(expected[, "x"]))
  expect_equal(unname(batch$y[5, ]), unname(expected[, "y"]))
})

