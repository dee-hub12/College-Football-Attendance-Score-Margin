# Run from the repository root (open college-football-attendance.Rproj in RStudio).
source(file.path("R", "00_setup.R"))

scripts <- c(
  "01_clean_data.R",
  "02_descriptives.R",
  "03_conference_models.R",
  "04_meta_analysis.R",
  "05_home_intercept.R",
  "06_one_stage.R",
  "07_robustness.R",
  "08_competitive_balance.R",
  "09_diagnostics.R",
  "12_hierarchical.R",
  "13_hierarchical_check.R",
  "10_figures.R"
)
for (script in scripts) {
  message("Running ", script)
  source(file.path("R", script), local = FALSE)
}
message("Finished. Tables: output/tables; figures: output/figures; hierarchical diagnostics: output/diagnostics/hierarchical")
