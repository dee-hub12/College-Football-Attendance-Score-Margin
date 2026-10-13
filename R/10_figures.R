source(file.path("R", "00_functions.R"))

games <- load_games()
reml <- readRDS(file.path("data", "derived", "meta_reml.rds"))
os <- readRDS(file.path("data", "derived", "one_stage_terms.rds"))

bands <- read.csv(file.path("output", "tables", "descriptives_by_attendance_band.csv"))
bands$attendance_band <- factor(bands$attendance_band, bands$attendance_band)
p2 <- ggplot(bands, aes(attendance_band, mean_margin)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.12) +
  geom_point(size = 2.6) +
  geom_text(aes(y = upper + 1, label = paste0("n = ", games, "\n", sprintf("%.0f%%", home_win_pct), " home wins")),
            vjust = 0, family = "serif", size = 3.1, lineheight = 0.9) +
  scale_y_continuous(limits = c(-7, 13), breaks = seq(-6, 12, 3)) +
  labs(x = "Attendance at the game", y = "Average home score margin (points)") +
  theme_pub()
save_figure(p2, "figure2_margin_by_crowd_size", 6.5, 4)

grid <- data.frame(attendance = seq(0, 110000, by = 1000))
grid$A <- grid$attendance / 10000
b <- os$common$coef[["A"]]
v <- os$common$vcov["A", "A"]
fit1 <- data.frame(model = "Attendance only (main model)", attendance = grid$attendance,
                   edge = grid$A * b, se = abs(grid$A) * sqrt(v))
h <- os$home$coef
V <- os$home$vcov
fit2 <- data.frame(model = "Attendance plus a separate home effect", attendance = grid$attendance,
                   edge = h[["hf"]] + grid$A * h[["A"]],
                   se = sqrt(V["hf", "hf"] + grid$A^2 * V["A", "A"] + 2 * grid$A * V["hf", "A"]))
fits <- rbind(fit1, fit2)
fits$model <- factor(fits$model, unique(fits$model))
fits$lower <- fits$edge - 1.96 * fits$se
fits$upper <- fits$edge + 1.96 * fits$se
p3 <- ggplot(fits, aes(attendance / 1000, edge)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_ribbon(aes(ymin = lower, ymax = upper, fill = model), alpha = 0.2) +
  geom_line(aes(linetype = model), linewidth = 0.8) +
  geom_rug(data = games[games$hf == 1, ], aes(x = attendance / 1000), inherit.aes = FALSE,
           sides = "b", alpha = 0.25, length = unit(0.02, "npc")) +
  scale_fill_manual(values = c("grey20", "grey60"), name = NULL) +
  scale_linetype_manual(values = c("solid", "dashed"), name = NULL) +
  scale_x_continuous(breaks = seq(0, 110, 20)) +
  labs(x = "Attendance (thousands)", y = "Predicted home edge in score margin (points)") +
  theme_pub() +
  theme(legend.position = c(0.02, 0.98), legend.justification = c(0, 1))
save_figure(p3, "figure3_home_edge_by_attendance", 6.5, 4.2)

rob <- read.csv(file.path("output", "tables", "table6_robustness_pooled.csv"))
loo <- read.csv(file.path("output", "tables", "tableS_leave_one_conference_out.csv"))
os_tab <- read.csv(file.path("output", "tables", "table5_one_stage_models.csv"))
pool_tab <- read.csv(file.path("output", "tables", "table2_pooled_attendance_effect.csv"))
hier <- read.csv(file.path("output", "tables", "table8_hierarchical_models.csv"))
hier <- hier[hier$term == "attendance", ]
spec <- rbind(
  data.frame(group = "Main", label = "Main analysis (REML)", rob[rob$scenario == "Main analysis", c("estimate", "lower", "upper")]),
  data.frame(group = "Pooling method", label = c("DerSimonian-Laird", "Hartung-Knapp", "Common effect"),
             pool_tab[2:4, c("estimate", "lower", "upper")]),
  data.frame(group = "One-stage models", label = c("Common slope", "Conference random slope"),
             os_tab[1:2, c("estimate", "lower", "upper")]),
  data.frame(group = "Hierarchical model", label = c("Attendance only", "With separate home term"),
             hier[match(c("Hierarchical, attendance only", "Hierarchical, with home term"), hier$model) , c("estimate", "lower", "upper")]),
  data.frame(group = "Sensitivity analyses", label = c("Robust (HC3) standard errors", "2019 and 2021 only", "Adjusted for pregame Elo and rivalry",
                                                  "Rivalry games removed", "Neutral site games removed",
                                                  "High influence games removed", "Championship games kept"),
             rob[match(c("Robust (HC3) standard errors", "2019 and 2021 only", "Adjusted for pregame Elo ratings and rivalry",
                         "Rivalry games removed", "Neutral site games removed",
                         "High influence games removed (Cook's distance > 4/n)", "Championship games kept"), rob$scenario),
                 c("estimate", "lower", "upper")]),
  data.frame(group = "Leave-one-conference-out", label = paste("Without", loo$conference_left_out),
             loo[, c("estimate", "lower", "upper")])
)
spec$group <- factor(spec$group, unique(spec$group))
rows <- do.call(rbind, lapply(levels(spec$group), function(g) {
  x <- spec[spec$group == g, ]
  hdr <- data.frame(group = g, label = g, estimate = NA, lower = NA, upper = NA, header = TRUE)
  if (g == "Main") return(cbind(x, header = FALSE))
  rbind(hdr, cbind(x, header = FALSE))
}))
rows$y <- rev(seq_len(nrow(rows)))
rows$label <- ifelse(rows$header, rows$label, paste0("   ", rows$label))
rows$text <- ifelse(rows$header, "", sprintf("%.2f [%.2f, %.2f]", rows$estimate, rows$lower, rows$upper))
main_est <- rows$estimate[1]
pts <- rows[!rows$header, ]
ord <- order(rows$y)
p4 <- ggplot(pts, aes(estimate, y)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = main_est, colour = "grey80") +
  geom_errorbarh(aes(xmin = lower, xmax = upper), height = 0.3) +
  geom_point(aes(shape = group == "Main", size = group == "Main")) +
  scale_shape_manual(values = c(16, 18)) +
  scale_size_manual(values = c(2, 4)) +
  scale_y_continuous(breaks = rows$y[ord], labels = rows$label[ord], expand = expansion(add = 0.6),
                     sec.axis = dup_axis(labels = rows$text[ord], name = NULL)) +
  labs(x = "Change in home score margin per 10,000 attendees (points)", y = NULL) +
  theme_pub() +
  theme(axis.ticks.y = element_blank(), axis.line.y = element_blank(),
        axis.text.y.left = suppressWarnings(element_text(hjust = 0, face = ifelse(rows$header[ord], "bold", "plain"))),
        axis.text.y.right = element_text(hjust = 0))
save_figure(p4, "figure4_robustness", 7.5, 7.5)

est <- readRDS(file.path("data", "derived", "conference_estimates.rds"))
cb <- read.csv(file.path("output", "tables", "tableS_competitive_balance_by_conference.csv"))
est$cb <- cb$cb[match(est$conference, cb$conference)]
mr <- rma(yi = estimate, sei = se, mods = ~cb, data = est, method = "REML")
line <- data.frame(cb = seq(min(est$cb) - 0.3, max(est$cb) + 0.3, length.out = 100))
pr <- predict(mr, newmods = line$cb)
line$fit <- pr$pred
line$lower <- pr$ci.lb
line$upper <- pr$ci.ub
p5 <- ggplot(est, aes(cb, estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_ribbon(data = line, aes(cb, ymin = lower, ymax = upper), inherit.aes = FALSE, fill = "grey85") +
  geom_line(data = line, aes(cb, fit)) +
  geom_point(aes(size = 1 / se^2)) +
  geom_text(aes(label = conference), nudge_y = 0.1, nudge_x = 0.15, family = "serif", size = 3.3) +
  scale_size_continuous(range = c(2, 5)) +
  labs(x = "Competitive balance (average SD of team score margins, points)",
       y = "Attendance effect per 10,000 (points)") +
  theme_pub()
save_figure(p5, "figure_S5_competitive_balance", 6, 4)

season <- read.csv(file.path("output", "tables", "descriptives_by_conference_season.csv"))
season$conference <- factor(season$conference, conf_order)
p6 <- ggplot(season, aes(factor(year), mean_margin)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.15) +
  geom_point(size = 2) +
  facet_wrap(~conference, nrow = 1) +
  labs(x = "Season", y = "Average home score margin (points)") +
  theme_pub()
save_figure(p6, "figure_S6_margin_by_season", 9, 3.2)
