source(file.path("R", "00_functions.R"))

games <- load_games()
d <- games[order(match(games$conference, conf_order)), ]
A <- d$hf * d$attendance / 10000

specs <- list(
  "Hierarchical, attendance only" = list(X = cbind(attendance = A), slope = TRUE),
  "Hierarchical, with home term" = list(X = cbind(home = d$hf, attendance = A), slope = TRUE),
  "Hierarchical, attendance only, adjusted" = list(X = cbind(controls(d), attendance = A), slope = TRUE),
  "Hierarchical, with home term, adjusted" = list(X = cbind(controls(d), home = d$hf, attendance = A), slope = TRUE)
)
fits <- lapply(specs, function(s) fit_hier(d, s$X, s$slope, nstarts = 4L))
if (any(!vapply(fits, function(f) f$converged, logical(1))))
  stop('At least one hierarchical model failed convergence; inspect diagnostics')

est <- do.call(rbind, lapply(names(fits), function(n) {
  f <- fits[[n]]
  terms <- intersect(c("home", "attendance"), names(f$coef))
  do.call(rbind, lapply(terms, function(t) data.frame(
    model = n, term = t, estimate = f$coef[[t]], se = f$se[[t]],
    z = f$coef[[t]] / f$se[[t]], p = 2 * pnorm(-abs(f$coef[[t]] / f$se[[t]])),
    lower = f$coef[[t]] - 1.96 * f$se[[t]], upper = f$coef[[t]] + 1.96 * f$se[[t]],
    converged = f$converged)))
}))
vc <- do.call(rbind, lapply(names(fits), function(n) {
  v <- fits[[n]]$var
  data.frame(model = n, residual_sd = sqrt(v[["residual"]]), team_sd = sqrt(v[["team"]]),
             team_season_sd = sqrt(v[["team_season"]]), attendance_slope_sd = sqrt(v[["slope"]]))
}))
save_table(est, "table8_hierarchical_models")
save_table(vc, "tableS_hierarchical_variance_components")
saveRDS(fits, file.path("data", "derived", "hierarchical_fits.rds"))

diag <- do.call(rbind, lapply(names(fits), function(nm) {
  data.frame(model = nm, fits[[nm]]$diagnostics, row.names = NULL)
}))
dir.create(file.path('output', 'diagnostics', 'hierarchical'), recursive = TRUE, showWarnings = FALSE)
write.csv(diag, file.path('output', 'diagnostics', 'hierarchical', 'refined_multistart_results.csv'), row.names = FALSE)
