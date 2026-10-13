source(file.path("R", "00_functions.R"))

games <- load_games()
est <- readRDS(file.path("data", "derived", "conference_estimates.rds"))

cb_season <- do.call(rbind, lapply(split(games, list(games$conference, games$year), drop = TRUE), function(d) {
  long <- rbind(data.frame(team = d$home, m = d$margin), data.frame(team = d$away, m = -d$margin))
  data.frame(conference = d$conference[1], year = d$year[1], competitive_balance = sd(tapply(long$m, long$team, mean)))
}))
cb_season$conference <- factor(cb_season$conference, conf_order)
cb_season <- cb_season[order(cb_season$conference, cb_season$year), ]
save_table(cb_season, "tableS_competitive_balance_by_season")

est$cb <- tapply(cb_season$competitive_balance, cb_season$conference, mean)[est$conference]
mr <- rma(yi = estimate, sei = se, mods = ~cb, data = est, method = "REML")
pred <- predict(mr, newmods = mean(est$cb))
out <- data.frame(
  slope = mr$beta[2], slope_se = mr$se[2], slope_p = mr$pval[2],
  residual_Q = mr$QE, residual_Q_df = mr$k - mr$p, residual_Q_p = mr$QEp,
  mean_cb = mean(est$cb), adjusted_estimate = pred$pred, adjusted_lower = pred$ci.lb, adjusted_upper = pred$ci.ub
)
save_table(cbind(conference = est$conference, cb = est$cb), "tableS_competitive_balance_by_conference")
save_table(out, "table7_competitive_balance_meta_regression")
