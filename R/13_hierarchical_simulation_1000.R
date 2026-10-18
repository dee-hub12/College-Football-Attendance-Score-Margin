# R/13_hierarchical_check.R
# Hierarchical-model parameter recovery, checkpointing, tables, and plots.
# Run from project root: source("R/13_hierarchical_check.R")
# Existing batches are ALWAYS reused. Set HIER_SIM_FORCE=1 only to refit deliberately.
# Set HIER_SIM_RECOVER_ONLY=1 to prohibit any new simulation fits.

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(project_root, "R", "00_functions.R"))) {
  stop("Run from the GitHub project root (the folder containing R/00_functions.R).")
}
source(file.path(project_root, "R", "00_functions.R"))

read_positive_integer <- function(name, default) {
  value <- Sys.getenv(name, as.character(default))
  if (!grepl("^[0-9]+$", value)) stop(name, " must be a positive integer")
  number <- suppressWarnings(as.integer(value))
  if (is.na(number) || number < 1L) stop(name, " must be a positive integer")
  number
}

n_sim <- read_positive_integer("HIER_SIM_N", 1000L)
batch_size <- read_positive_integer("HIER_SIM_BATCH", 10L)
n_starts <- read_positive_integer("HIER_SIM_NSTARTS", 1L)
force_refit <- identical(Sys.getenv("HIER_SIM_FORCE", "0"), "1")
recover_only <- identical(Sys.getenv("HIER_SIM_RECOVER_ONLY", "1"), "1")
if (force_refit && recover_only) stop("Cannot force refitting in recovery-only mode")

sim_dir <- file.path(project_root, "data", "derived", "hierarchical_simulation_v2",
                     sprintf("batch%03d_starts%02d", batch_size, n_starts))
table_dir <- file.path(project_root, "output", "tables")
plot_dir <- file.path(project_root, "output", "diagnostics", "hierarchical")
for (folder in c(sim_dir, table_dir, plot_dir))
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)

truth <- c(home = 0, attendance = 0.5)
sd_team <- 9
sd_season <- 5
sd_error <- 14
n_batches <- ceiling(n_sim / batch_size)
paths <- file.path(sim_dir, sprintf("batch_%04d.rds", seq_len(n_batches)))

# Only prepare the observed game design if a simulation actually needs fitting.
prepare_simulation <- function() {
  d <- load_games()
  d <- d[order(match(d$conference, conf_order)), , drop = FALSE]
  attendance <- d$hf * d$attendance / 10000
  Z_team <- team_Z(d, function(x, side) paste(x$conference, x[[side]]))
  Z_season <- team_Z(d, function(x, side) paste(x$conference, x[[side]], x$year))
  if (anyNA(attendance) || any(!is.finite(attendance)) || anyNA(d$hf))
    stop("The attendance design or home indicator contains invalid values")
  list(d = d, attendance = attendance, Z_team = Z_team, Z_season = Z_season)
}

run_simulation <- function(id, design) {
  set.seed(20260000L + id)
  simulated <- design$d
  simulated$margin <- as.numeric(
    design$Z_team %*% rnorm(ncol(design$Z_team), sd = sd_team) +
      design$Z_season %*% rnorm(ncol(design$Z_season), sd = sd_season) +
      truth[["home"]] * simulated$hf +
      truth[["attendance"]] * design$attendance +
      rnorm(nrow(simulated), sd = sd_error)
  )
  tryCatch({
    fit <- fit_hier(simulated,
                    cbind(home = simulated$hf, attendance = design$attendance),
                    nstarts = n_starts)
    terms <- names(truth)
    if (!all(terms %in% names(fit$coef)) || !all(terms %in% names(fit$se)))
      stop("fit_hier() did not return both coefficients and standard errors")
    estimates <- fit$coef[terms]
    errors <- fit$se[terms]
    if (any(!is.finite(estimates)) || any(!is.finite(errors)) || any(errors <= 0))
      stop("Non-finite coefficients or invalid standard errors")
    data.frame(sim_id = id, status = "ok", error = NA_character_,
               converged = isTRUE(fit$converged),
               home = unname(estimates[["home"]]),
               attendance = unname(estimates[["attendance"]]),
               se.home = unname(errors[["home"]]),
               se.attendance = unname(errors[["attendance"]]))
  }, error = function(e) {
    data.frame(sim_id = id, status = "failed", error = conditionMessage(e),
               converged = FALSE, home = NA_real_, attendance = NA_real_,
               se.home = NA_real_, se.attendance = NA_real_)
  })
}

chunk <- Sys.getenv("CHUNK", "")
if (nzchar(chunk)) {
  if (!grepl("^[0-9]+(,[0-9]+)*$", chunk))
    stop("CHUNK must be a comma-separated list of batch numbers")
  batch_ids <- unique(as.integer(strsplit(chunk, ",", fixed = TRUE)[[1L]]))
  if (anyNA(batch_ids) || any(batch_ids < 1L | batch_ids > n_batches))
    stop("CHUNK contains an invalid batch number")
} else {
  batch_ids <- seq_len(n_batches)
}

message("Simulation checkpoints: ", sim_dir)
message("Existing checkpoints will be reused; recovery-only mode: ", recover_only)
need_fit <- force_refit || any(!file.exists(paths[batch_ids]))
if (need_fit && recover_only) {
  missing <- paths[batch_ids][!file.exists(paths[batch_ids])]
  stop("Recovery-only mode: missing checkpoint(s):\n", paste(missing, collapse = "\n"),
       "\nNo models were refitted.")
}
design <- if (need_fit) prepare_simulation() else NULL

for (batch_id in batch_ids) {
  ids <- seq.int((batch_id - 1L) * batch_size + 1L,
                 min(batch_id * batch_size, n_sim))
  path <- paths[batch_id]
  if (file.exists(path) && !force_refit) {
    previous <- tryCatch(readRDS(path), error = function(e) NULL)
    if (!is.data.frame(previous) ||
        !identical(as.integer(previous$sim_id), as.integer(ids)))
      stop("Invalid existing checkpoint: ", path)
    message("Reusing batch ", batch_id, "/", n_batches)
    next
  }
  message("Fitting batch ", batch_id, "/", n_batches)
  batch <- do.call(rbind, lapply(ids, run_simulation, design = design))
  temporary <- paste0(path, ".tmp")
  saveRDS(batch, temporary)
  if (file.exists(path) && !file.remove(path)) stop("Cannot replace ", path)
  if (!file.rename(temporary, path)) stop("Cannot save ", path)
  message("Completed: ", sum(batch$status == "ok"), " fitted; ",
          sum(batch$status == "failed"), " failed")
}

if (!all(file.exists(paths))) {
  message("Not all batches exist; aggregation will run when all are present.")
} else {
  results <- do.call(rbind, lapply(paths, readRDS))
  results <- results[order(results$sim_id), , drop = FALSE]
  if (!identical(as.integer(results$sim_id), seq_len(n_sim)))
    stop("Checkpoint IDs are missing, duplicated, or out of order")
  successful <- results[results$status == "ok", , drop = FALSE]
  if (nrow(successful) == 0L) stop("All fits failed")
  if (anyNA(successful$converged))
    warning("Missing convergence indicators among successful fits")
  
  simulation_summary <- do.call(rbind, lapply(names(truth), function(term) {
    estimate <- successful[[term]]
    standard_error <- successful[[paste0("se.", term)]]
    target <- unname(truth[[term]])
    covered <- abs(estimate - target) <= 1.96 * standard_error
    data.frame(term = term, true_value = target,
               mean_estimate = mean(estimate),
               bias = mean(estimate - target),
               sd_estimate = if (length(estimate) > 1L) sd(estimate) else NA_real_,
               mean_se = mean(standard_error),
               rmse = sqrt(mean((estimate - target)^2)),
               coverage_95 = mean(covered),
               coverage_mcse = sqrt(mean(covered) * (1 - mean(covered)) / length(covered)),
               simulations_requested = n_sim,
               simulations_successful = nrow(successful),
               simulations_failed = n_sim - nrow(successful),
               simulations_converged = sum(successful$converged))
  }))
  
  # Save both full data and table-ready summaries in the checkpoint directory.
  results_path <- file.path(sim_dir, sprintf("simulation_results_n%04d.csv", n_sim))
  summary_path <- file.path(sim_dir, sprintf("simulation_summary_n%04d.csv", n_sim))
  write.csv(results, results_path, row.names = FALSE)
  write.csv(simulation_summary, summary_path, row.names = FALSE)
  # Explicit table output, independent of save_table() helper implementation.
  write.csv(simulation_summary,
            file.path(table_dir, "tableS_hierarchical_simulation_check.csv"),
            row.names = FALSE)
  message("Saved complete results: ", results_path)
  message("Saved simulation summary: ", summary_path)
  print(simulation_summary, row.names = FALSE, digits = 4)
  
  # Simulation-specific figures, using saved estimates (no refitting).
  for (term in names(truth)) {
    estimates <- successful[[term]]
    target <- unname(truth[[term]])
    png(file.path(plot_dir, paste0("simulation_estimates_", term, ".png")),
        width = 1600, height = 1100, res = 160)
    tryCatch({
      hist(estimates, breaks = "FD", col = "gray85", border = "white",
           main = paste("Simulation estimates:", term),
           xlab = if (term == "attendance") "Points per 10,000 attendees" else "Home intercept (points)")
      abline(v = target, col = "firebrick", lwd = 3, lty = 2)
      abline(v = mean(estimates), col = "steelblue4", lwd = 3)
      legend("topright", legend = c("True value", "Mean estimate"),
             col = c("firebrick", "steelblue4"), lty = c(2, 1), lwd = 3, bty = "n")
    }, finally = dev.off())
  }
  # Coverage visualization by parameter.
  png(file.path(plot_dir, "simulation_coverage_95.png"),
      width = 1500, height = 1000, res = 160)
  tryCatch({
    bp <- barplot(100 * simulation_summary$coverage_95,
                  names.arg = simulation_summary$term, ylim = c(0, 105),
                  col = "gray70", ylab = "Empirical coverage (%)",
                  main = "Nominal 95% confidence interval coverage")
    abline(h = 95, lty = 2, col = "firebrick", lwd = 2)
    text(bp, 100 * simulation_summary$coverage_95 + 2,
         labels = sprintf("%.1f%%", 100 * simulation_summary$coverage_95))
  }, finally = dev.off())
  message("Saved simulation plots to: ", plot_dir)
  
  if (any(results$status == "failed"))
    warning("Some simulations failed. Summary excludes failed fits")
  if (any(!successful$converged))
    warning("Some successful fits have converged=FALSE; inspect optimizer status")
}

# Numerical diagnostics from saved empirical fits, if available.
fits_path <- file.path(project_root, "data", "derived", "hierarchical_fits.rds")
if (!file.exists(fits_path)) {
  message("Empirical optimizer plots skipped: hierarchical_fits.rds not found")
} else {
  fits <- readRDS(fits_path)
  records <- do.call(rbind, lapply(names(fits), function(name) {
    data.frame(model = name, fits[[name]]$diagnostics, row.names = NULL)
  }))
  write.csv(records, file.path(plot_dir, "refined_multistart_results.csv"),
            row.names = FALSE)
  
  plot_diagnostics <- function(filename, get_y, y_label, log_scale = FALSE) {
    png(file.path(plot_dir, filename), width = 1600, height = 1100, res = 160)
    old_par <- par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
    tryCatch({
      for (name in names(fits)) {
        diagnostic <- fits[[name]]$diagnostics
        plot(diagnostic$start_id, get_y(diagnostic), type = "b", pch = 19,
             log = if (log_scale) "y" else "",
             xlab = "Starting value", ylab = y_label, main = name)
        if (!log_scale) abline(h = 0, lty = 2, col = "gray50")
      }
    }, finally = {
      par(old_par)
      dev.off()
    })
  }
  plot_diagnostics("hierarchical_objective_gaps.png",
                   function(x) x$objective_gap, "Objective minus best")
  plot_diagnostics("hierarchical_gradients.png",
                   function(x) pmax(x$max_abs_gradient, .Machine$double.eps),
                   "Maximum absolute gradient", log_scale = TRUE)
  message("Saved empirical optimizer diagnostics to: ", plot_dir)
}
message("Hierarchical simulation check complete. No completed batches were refitted.")







