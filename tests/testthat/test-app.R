test_that("package exposes a Shiny app object", {
  expect_s3_class(penduloom_app(), "shiny.appobj")
})

test_that("browser assets are declared as an HTML dependency", {
  dependency <- penduloom:::penduloom_dependency()

  expect_s3_class(dependency, "html_dependency")
  expect_equal(dependency$name, "penduloom-assets")
  expect_equal(dependency$script, "app.js")
  expect_equal(dependency$stylesheet, "styles.css")
  expect_true(file.exists(file.path(dependency$src$file, dependency$script)))
})

