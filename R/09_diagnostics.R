source(file.path("R", "00_functions.R"))

fits <- readRDS(file.path("data", "derived", "conference_fits.rds"))

diag <- do.call(rbind, lapply(names(fits), function(c) {
  m <- fits[[c]]
  e <- residuals(m)
  cd <- cooks.distance(m)
  data.frame(
    conference = c, games = length(e), residual_sd = sd(e),
    shapiro_W = shapiro.test(e)$statistic, shapiro_p = shapiro.test(e)$p.value,
    breusch_pagan = bptest(m)$statistic, breusch_pagan_p = bptest(m)$p.value,
    max_cooks_distance = max(cd, na.rm = TRUE), games_cooks_above_4_over_n = sum(cd > 4 / length(e), na.rm = TRUE)
  )
}))
save_table(diag, "tableS_model_diagnostics")

res <- do.call(rbind, lapply(names(fits), function(c) {
  m <- fits[[c]]
  data.frame(conference = factor(c, conf_order), fitted = fitted(m), residual = residuals(m))
}))
p1 <- ggplot(res, aes(sample = residual)) +
  stat_qq(size = 0.7) +
  stat_qq_line() +
  facet_wrap(~conference, nrow = 1) +
  labs(x = "Theoretical quantiles", y = "Residuals (points)") +
  theme_pub()
p2 <- ggplot(res, aes(fitted, residual)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_point(size = 0.7, alpha = 0.6) +
  facet_wrap(~conference, nrow = 1) +
  labs(x = "Fitted score margin (points)", y = "Residuals (points)") +
  theme_pub()
save_figure(p1, "figure_S3_residual_qq", 9, 3)
save_figure(p2, "figure_S4_residual_vs_fitted", 9, 3)
