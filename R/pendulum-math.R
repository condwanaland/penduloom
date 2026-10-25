#' Calculate chained pendulum positions
#'
#' Computes the Cartesian coordinates of every joint in a serial pendulum.
#' Angles are relative to vertical and cumulative, so each arm rotates from
#' the orientation of its parent.
#'
#' @param time A single time in seconds.
#' @param lengths Positive arm lengths.
#' @param speeds Angular velocities in degrees per second.
#' @param phases Initial angles in degrees. Defaults to zero for every joint.
#' @param origin The two-element starting coordinate.
#'
#' @return A matrix with one row for the origin plus one row per joint, and
#'   columns named `x` and `y`.
#' @export
#'
#' @examples
#' pendulum_positions(0.5, lengths = c(1, 1), speeds = c(90, -45))
pendulum_positions <- function(time, lengths, speeds, phases = NULL,
                               origin = c(0, 0)) {
  trajectory <- pendulum_trajectory(
    times = time,
    lengths = lengths,
    speeds = speeds,
    phases = phases,
    origin = origin
  )

  cbind(
    x = unname(trajectory$x[1, ]),
    y = unname(trajectory$y[1, ])
  )
}

#' Calculate a batch of chained pendulum frames
#'
#' Vectorized counterpart to [pendulum_positions()]. This is the authoritative
#' simulation function used by the Shiny app to prepare rolling animation
#' buffers for the browser.
#'
#' @param times Numeric vector of times in seconds.
#' @inheritParams pendulum_positions
#'
#' @return A list containing `time`, plus `x` and `y` matrices. Each matrix has
#'   one row per requested time and one column for the origin plus every joint.
#' @export
#'
#' @examples
#' pendulum_trajectory(seq(0, 1, length.out = 5), 1, 90)
pendulum_trajectory <- function(times, lengths, speeds, phases = NULL,
                                origin = c(0, 0)) {
  stopifnot(
    length(times) > 0L,
    all(is.finite(times)),
    length(lengths) > 0L,
    length(lengths) == length(speeds),
    all(is.finite(lengths)),
    all(lengths > 0),
    all(is.finite(speeds)),
    length(origin) == 2L,
    all(is.finite(origin))
  )

  if (is.null(phases)) {
    phases <- rep(0, length(lengths))
  }
  stopifnot(length(phases) == length(lengths), all(is.finite(phases)))

  relative_angles <- outer(times, speeds, `*`)
  relative_angles <- sweep(relative_angles, 2, phases, `+`) * pi / 180
  absolute_angles <- relative_angles

  if (length(lengths) > 1L) {
    for (joint in 2:length(lengths)) {
      absolute_angles[, joint] <- absolute_angles[, joint - 1L] +
        relative_angles[, joint]
    }
  }

  x_steps <- sweep(sin(absolute_angles), 2, lengths, `*`)
  y_steps <- sweep(cos(absolute_angles), 2, lengths, `*`)

  if (length(lengths) > 1L) {
    for (joint in 2:length(lengths)) {
      x_steps[, joint] <- x_steps[, joint - 1L] + x_steps[, joint]
      y_steps[, joint] <- y_steps[, joint - 1L] + y_steps[, joint]
    }
  }

  x <- cbind(origin[[1]], origin[[1]] + x_steps)
  y <- cbind(origin[[2]], origin[[2]] + y_steps)

  list(time = times, x = x, y = y)
}

