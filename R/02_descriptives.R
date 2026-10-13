source(file.path("R", "00_functions.R"))

games <- load_games()

desc <- do.call(rbind, lapply(split(games, list(games$conference, games$year), drop = TRUE), function(d) {
  n <- nrow(d)
  m <- mean(d$margin)
  s <- sd(d$margin)
  data.frame(
    conference = d$conference[1], year = d$year[1], games = n,
    mean_attendance = mean(d$attendance),
    median_attendance = median(d$attendance),
    home_win_pct = 100 * mean(d$margin > 0),
    mean_margin = m, sd_margin = s,
    min_margin = min(d$margin), max_margin = max(d$margin),
    lower = m - qt(0.975, n - 1) * s / sqrt(n),
    upper = m + qt(0.975, n - 1) * s / sqrt(n)
  )
}))
desc$conference <- factor(desc$conference, conf_order)
desc <- desc[order(desc$conference, desc$year), ]
save_table(desc, "descriptives_by_conference_season")

home <- games[games$hf == 1, ]
home$conference <- factor(home$conference, conf_order)
p <- ggplot(home, aes(factor(year), attendance / 1000)) +
  geom_boxplot(outlier.shape = NA, width = 0.6, colour = "grey30") +
  geom_jitter(width = 0.15, height = 0, size = 0.7, alpha = 0.5) +
  facet_wrap(~conference, nrow = 1) +
  labs(x = "Season", y = "Attendance (thousands)") +
  theme_pub()
save_figure(p, "figure_S1_attendance_by_season", 9, 3.5)

band_breaks <- c(-Inf, 0, 19999, 49999, Inf)
band_labels <- c("Empty stadium", "1 to 19,999", "20,000 to 49,999", "50,000 or more")
home$band <- cut(home$attendance, band_breaks, band_labels)
bands <- do.call(rbind, lapply(split(home, home$band, drop = TRUE), function(d) {
  n <- nrow(d)
  m <- mean(d$margin)
  s <- sd(d$margin)
  data.frame(
    attendance_band = as.character(d$band[1]), games = n,
    seasons = paste(sort(unique(d$year)), collapse = ", "),
    home_win_pct = 100 * mean(d$margin > 0),
    mean_margin = m, sd_margin = s,
    lower = m - qt(0.975, n - 1) * s / sqrt(n),
    upper = m + qt(0.975, n - 1) * s / sqrt(n)
  )
}))
save_table(bands, "descriptives_by_attendance_band")

empty <- home[home$attendance == 0, ]
empty_tab <- do.call(rbind, lapply(split(empty, empty$conference, drop = TRUE), function(d) {
  data.frame(conference = as.character(d$conference[1]), games = nrow(d),
             home_win_pct = 100 * mean(d$margin > 0), mean_margin = mean(d$margin), sd_margin = sd(d$margin))
}))
empty_tab <- rbind(empty_tab, data.frame(conference = "All", games = nrow(empty),
                                         home_win_pct = 100 * mean(empty$margin > 0),
                                         mean_margin = mean(empty$margin), sd_margin = sd(empty$margin)))
save_table(empty_tab, "descriptives_empty_stadium_games")

home$season <- factor(home$year)
p2 <- ggplot(home, aes(attendance / 1000, margin)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_point(aes(shape = season), size = 1, alpha = 0.6) +
  geom_smooth(method = "lm", formula = y ~ x, colour = "black", linewidth = 0.6, se = TRUE) +
  facet_wrap(~conference, nrow = 1) +
  scale_shape_manual(values = c(16, 1, 17), name = "Season") +
  labs(x = "Attendance (thousands)", y = "Home score margin (points)") +
  theme_pub() +
  theme(legend.position = "bottom")
save_figure(p2, "figure_S2_margin_by_attendance", 9, 3.8)
