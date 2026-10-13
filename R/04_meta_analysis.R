source(file.path("R", "00_functions.R"))

est <- readRDS(file.path("data", "derived", "conference_estimates.rds"))

reml <- rma(yi = estimate, sei = se, data = est, method = "REML", slab = conference)
dl <- rma(yi = estimate, sei = se, data = est, method = "DL", slab = conference)
hk <- rma(yi = estimate, sei = se, data = est, method = "REML", test = "knha", slab = conference)
fe <- rma(yi = estimate, sei = se, data = est, method = "FE", slab = conference)

pooled <- rbind(
  cbind(method = "Random effects, REML (main)", meta_row(reml)),
  cbind(method = "Random effects, DerSimonian-Laird", meta_row(dl)),
  cbind(method = "Random effects, REML with Hartung-Knapp", meta_row(hk)),
  cbind(method = "Common effect", meta_row(fe))
)
save_table(pooled, "table2_pooled_attendance_effect")

ci_tau <- confint(reml)$random
het <- data.frame(
  tau2 = reml$tau2, tau2_lower = ci_tau["tau^2", "ci.lb"], tau2_upper = ci_tau["tau^2", "ci.ub"],
  tau = sqrt(reml$tau2), I2 = reml$I2, I2_lower = ci_tau["I^2(%)", "ci.lb"], I2_upper = ci_tau["I^2(%)", "ci.ub"],
  H2 = reml$H2, Q = reml$QE, Q_df = reml$k - 1, Q_p = reml$QEp
)
save_table(het, "table3_heterogeneity")

loo <- leave1out(reml)
save_table(data.frame(conference_left_out = est$conference, estimate = loo$estimate, se = loo$se,
                      p = loo$pval, lower = loo$ci.lb, upper = loo$ci.ub, tau2 = loo$tau2, I2 = loo$I2),
           "tableS_leave_one_conference_out")

w <- weights(reml)
fp <- data.frame(
  label = c(est$conference, "Pooled (random effects)"),
  estimate = c(est$estimate, as.numeric(reml$b)),
  lower = c(est$estimate - 1.96 * est$se, reml$ci.lb),
  upper = c(est$estimate + 1.96 * est$se, reml$ci.ub),
  weight = c(w, NA),
  pooled = c(rep(FALSE, nrow(est)), TRUE)
)
fp$text <- sprintf("%.2f [%.2f, %.2f]", fp$estimate, fp$lower, fp$upper)
fp$y <- c(rev(seq_len(nrow(est))) + 0.3, 0)
diamond <- data.frame(
  x = c(reml$ci.lb, as.numeric(reml$b), reml$ci.ub, as.numeric(reml$b)),
  y = c(0, 0.25, 0, -0.25)
)
p <- ggplot(fp[!fp$pooled, ]) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_errorbarh(aes(y = y, xmin = lower, xmax = upper), height = 0.15) +
  geom_point(aes(x = estimate, y = y, size = weight), shape = 15) +
  geom_polygon(data = diamond, aes(x, y), fill = "black") +
  scale_y_continuous(breaks = fp$y, labels = fp$label,
                     sec.axis = dup_axis(labels = fp$text, name = NULL)) +
  scale_x_continuous(breaks = seq(-0.5, 1.25, 0.25)) +
  scale_size_continuous(range = c(1.5, 4)) +
  labs(x = "Change in home score margin per 10,000 attendees (points)", y = NULL) +
  theme_pub() +
  theme(axis.line.y = element_blank(), axis.ticks.y = element_blank(),
        axis.text.y.right = element_text(hjust = 0))
save_figure(p, "figure1_forest_plot", 7, 3.4)
saveRDS(reml, file.path("data", "derived", "meta_reml.rds"))
