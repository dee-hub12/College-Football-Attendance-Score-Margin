source(file.path("R", "00_functions.R"))

games <- load_games()
d <- games[order(match(games$conference, conf_order)), ]
A <- d$hf * d$attendance / 10000
Zt <- team_Z(d, function(d, s) paste(d$conference, d[[s]]))
Zs <- team_Z(d, function(d, s) paste(d$conference, d[[s]], d$year))
truth <- c(home = 0, attendance = 0.5)
chunks <- if (nzchar(Sys.getenv("CHUNK"))) as.integer(Sys.getenv("CHUNK")) else 1:2

for (k in chunks) {
  set.seed(2026 + k)
  res <- t(replicate(9, {
    d$margin <- as.numeric(Zt %*% rnorm(ncol(Zt), 0, 9) + Zs %*% rnorm(ncol(Zs), 0, 5) +
                           truth[["home"]] * d$hf + truth[["attendance"]] * A + rnorm(nrow(d), 0, 14))
    f <- fit_hier(d, cbind(home = d$hf, attendance = A), nstarts = 1L)
    c(f$coef, se = f$se)
  }))
  saveRDS(res, file.path("data", "derived", paste0("hierarchical_simulation_", k, ".rds")))
}

files <- list.files(file.path("data", "derived"), pattern = "^hierarchical_simulation_[0-9]+\\.rds$", full.names = TRUE)
res <- do.call(rbind, lapply(files, readRDS))
check <- do.call(rbind, lapply(c("home", "attendance"), function(t) data.frame(
  term = t, true_value = truth[[t]], mean_estimate = mean(res[, t]), sd_estimate = sd(res[, t]),
  mean_se = mean(res[, paste0("se.", t)]),
  coverage_95 = mean(abs(res[, t] - truth[[t]]) < 1.96 * res[, paste0("se.", t)]),
  simulations = nrow(res))))
save_table(check, "tableS_hierarchical_simulation_check")


fits_path <- file.path('data', 'derived', 'hierarchical_fits.rds')
if (!file.exists(fits_path)) stop('Run R/12_hierarchical.R before script 13')
fits <- readRDS(fits_path)
outdir <- file.path('output', 'diagnostics', 'hierarchical')
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
records <- do.call(rbind, lapply(names(fits), function(nm) {
  data.frame(model = nm, fits[[nm]]$diagnostics, row.names = NULL)
}))
write.csv(records, file.path(outdir, 'refined_multistart_results.csv'), row.names = FALSE)

png(file.path(outdir, 'hierarchical_objective_gaps.png'), width = 1600, height = 1100, res = 160)
op <- par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
for (nm in names(fits)) {
  z <- fits[[nm]]$diagnostics
  plot(z$start_id, z$objective_gap, type = 'b', pch = 19,
       xlab = 'Starting value', ylab = 'Objective minus best', main = nm)
  abline(h = 0, lty = 2, col = 'gray50')
}
par(op); dev.off()

png(file.path(outdir, 'hierarchical_gradients.png'), width = 1600, height = 1100, res = 160)
op <- par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
for (nm in names(fits)) {
  z <- fits[[nm]]$diagnostics
  plot(z$start_id, pmax(z$max_abs_gradient, .Machine$double.eps),
       type = 'b', pch = 19, log = 'y',
       xlab = 'Starting value', ylab = 'Maximum absolute gradient', main = nm)
}
par(op); dev.off()

message('Hierarchical validation complete. Final estimates: output/tables/table8_hierarchical_models.csv')
message('Numerical diagnostics: ', outdir)
