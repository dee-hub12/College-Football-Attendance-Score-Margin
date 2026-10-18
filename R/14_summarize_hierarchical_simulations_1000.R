# RECOVER HIERARCHICAL SIMULATION OUTPUTS — NO MODEL FITTING
# Run from the project root using source("R/14_recover_hierarchical_outputs.R")

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
sim_dir <- file.path(project_root, "data", "derived", "hierarchical_simulation_v2", "batch010_starts01")
paths <- file.path(sim_dir, sprintf("batch_%04d.rds", 1:100))
if (!all(file.exists(paths))) stop("Missing batches: ", paste(basename(paths[!file.exists(paths)]), collapse = ", "))

# Choose a writable local folder. Do not write into the S: checkpoint directory.
user_home <- Sys.getenv("USERPROFILE", unset = path.expand("~"))
output_dir <- file.path(user_home, "Documents", "HFA_hierarchical_simulation_outputs")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(output_dir)) stop("Cannot create local output folder: ", output_dir)
probe <- tempfile(tmpdir = output_dir)
if (!file.create(probe)) stop("Local output folder is not writable: ", output_dir)
unlink(probe)
figure_dir <- file.path(output_dir, "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

results <- do.call(rbind, lapply(paths, readRDS))
results <- results[order(results$sim_id), , drop = FALSE]
if (!identical(as.integer(results$sim_id), 1:1000)) stop("Missing or duplicated simulation IDs")
if (!all(c("status", "converged", "home", "attendance", "se.home", "se.attendance") %in% names(results))) stop("Unexpected batch data columns")
successful <- results[results$status == "ok", , drop = FALSE]
if (!nrow(successful)) stop("No successful fits")
truth <- c(home = 0, attendance = 0.5)
summary_table <- do.call(rbind, lapply(names(truth), function(term) {
  estimate <- successful[[term]]
  se <- successful[[paste0("se.", term)]]
  target <- unname(truth[[term]])
  if (any(!is.finite(estimate)) || any(!is.finite(se)) || any(se <= 0)) stop("Invalid estimates or SEs for ", term)
  covered <- abs(estimate - target) <= 1.96 * se
  p <- mean(covered)
  data.frame(term = term, true_value = target,
             mean_estimate = mean(estimate), bias = mean(estimate - target),
             sd_estimate = sd(estimate), mean_se = mean(se),
             rmse = sqrt(mean((estimate - target)^2)),
             coverage_95 = p, coverage_mcse = sqrt(p * (1 - p) / length(covered)),
             simulations_requested = 1000L, simulations_successful = nrow(successful),
             simulations_failed = 1000L - nrow(successful),
             simulations_converged = sum(successful$converged, na.rm = TRUE))
}))
write.csv(results, file.path(output_dir, "simulation_results_n1000.csv"), row.names = FALSE)
write.csv(summary_table, file.path(output_dir, "simulation_summary_n1000.csv"), row.names = FALSE)
write.csv(summary_table, file.path(output_dir, "tableS_hierarchical_simulation_check.csv"), row.names = FALSE)

# Distribution plots for each recovered coefficient
for (term in names(truth)) {
  values <- successful[[term]]
  target <- unname(truth[[term]])
  png(file.path(figure_dir, paste0("simulation_estimates_", term, ".png")), width = 1600, height = 1100, res = 160)
  tryCatch({
    hist(values, breaks = "FD", col = "gray85", border = "white",
         main = paste("Simulation estimates:", term),
         xlab = if (term == "attendance") "Points per 10,000 attendees" else "Home intercept (points)")
    abline(v = target, col = "firebrick", lwd = 3, lty = 2)
    abline(v = mean(values), col = "steelblue4", lwd = 3)
    legend("topright", legend = c("True value", "Mean estimate"),
           col = c("firebrick", "steelblue4"), lty = c(2, 1), lwd = 3, bty = "n")
  }, finally = dev.off())
}

png(file.path(figure_dir, "simulation_coverage_95.png"), width = 1500, height = 1000, res = 160)
tryCatch({
  bp <- barplot(100 * summary_table$coverage_95,
                names.arg = summary_table$term, ylim = c(0, 105),
                col = "gray70", ylab = "Empirical coverage (%)",
                main = "Nominal 95% confidence interval coverage")
  abline(h = 95, lty = 2, col = "firebrick", lwd = 2)
  text(bp, 100 * summary_table$coverage_95 + 2,
       labels = sprintf("%.1f%%", 100 * summary_table$coverage_95))
}, finally = dev.off())

# Recreate empirical optimizer diagnostics if prior fits are present
fits_path <- file.path(project_root, "data", "derived", "hierarchical_fits.rds")
if (file.exists(fits_path)) {
  fits <- readRDS(fits_path)
  records <- do.call(rbind, lapply(names(fits), function(name) {
    data.frame(model = name, fits[[name]]$diagnostics, row.names = NULL)
  }))
  write.csv(records, file.path(output_dir, "refined_multistart_results.csv"), row.names = FALSE)
  plot_diagnostics <- function(filename, get_y, y_label, log_scale = FALSE) {
    png(file.path(figure_dir, filename), width = 1600, height = 1100, res = 160)
    old_par <- par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
    tryCatch({
      for (name in names(fits)) {
        diagnostic <- fits[[name]]$diagnostics
        plot(diagnostic$start_id, get_y(diagnostic), type = "b", pch = 19,
             log = if (log_scale) "y" else "", xlab = "Starting value",
             ylab = y_label, main = name)
        if (!log_scale) abline(h = 0, lty = 2, col = "gray50")
      }
    }, finally = {par(old_par); dev.off()})
  }
  plot_diagnostics("hierarchical_objective_gaps.png", function(x) x$objective_gap, "Objective minus best")
  plot_diagnostics("hierarchical_gradients.png", function(x) pmax(x$max_abs_gradient, .Machine$double.eps), "Maximum absolute gradient", TRUE)
} else {
  message("Empirical optimizer plots skipped: hierarchical_fits.rds was not found")
}
cat("\nSUCCESS: recovered", nrow(results), "simulations; successful fits:", nrow(successful), "\n")
print(summary_table, row.names = FALSE, digits = 4)
cat("\nSaved all outputs locally to:\n", output_dir, "\n")
cat("Figures are in:\n", figure_dir, "\n")
cat("Optimizer converged flags:\n")
print(table(successful$converged, useNA = "ifany"))
