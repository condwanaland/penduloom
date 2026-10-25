penduloom_presets <- list(
  deltoid = list(
    label = "Deltoid",
    lengths = c(160, 80),
    speeds = c(45, -135)
  ),
  cardioid = list(
    label = "Cardioid-like",
    lengths = c(160, 80),
    speeds = c(45, 45)
  ),
  three_frequency_flower = list(
    label = "Three-frequency flower",
    lengths = c(150, 95, 55),
    speeds = c(30, -90, 150)
  ),
  five_lobed_weave = list(
    label = "Five-lobed weave",
    lengths = c(150, 100, 60),
    speeds = c(48, -120, 192)
  ),
  four_arm_lace = list(
    label = "Four-arm lace",
    lengths = c(150, 100, 65, 38),
    speeds = c(18, -54, 108, -198)
  ),
  dense_rosette = list(
    label = "Dense rosette",
    lengths = c(150, 105, 70, 45),
    speeds = c(45, -120, 195, -315)
  ),
  slowly_evolving_orbit = list(
    label = "Slowly evolving orbit",
    lengths = c(150, 95, 60),
    speeds = c(37, 15.3, -112.2)
  )
)

preset_choices <- function() {
  labels <- vapply(penduloom_presets, `[[`, character(1), "label")
  stats::setNames(c("custom", names(penduloom_presets)), c("Custom", labels))
}

selected_preset <- function(value) {
  if (length(value) != 1L || identical(value, "custom")) {
    return(NULL)
  }
  penduloom_presets[[value]]
}

