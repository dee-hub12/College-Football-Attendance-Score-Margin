# Packages used by the analysis scripts.
pkgs <- c("readxl", "metafor", "ggplot2", "sandwich", "lmtest", "lme4")
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  message("Installing R packages: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
}

# Create working directories if they do not exist.
for (d in c("data/raw", "data/raw/independent", "data/derived",
            "output/tables", "output/figures", "output/diagnostics/hierarchical")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}
