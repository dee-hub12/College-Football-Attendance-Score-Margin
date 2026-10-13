source(file.path("R", "00_functions.R"))

games <- load_games()
with_titles <- readRDS(file.path("data", "derived", "games_with_titles.rds"))
published <- readRDS(file.path("data", "derived", "games_as_published.rds"))
refs <- readRDS(file.path("data", "derived", "reference_teams.rds"))
ref_of <- function(c) refs$reference_team[refs$conference == c]

run_scenario <- function(data, label, robust = FALSE, adjust = FALSE) {
  est <- do.call(rbind, lapply(conf_order, function(c) {
    d <- data[data$conference == c, ]
    m <- fit_conf(d, ref_of(c), adjust = adjust)
    vc <- if (robust) vcovHC(m, type = "HC3") else vcov(m)
    cbind(scenario = label, conference = c, games = nrow(d), coef_row(m, "attendance", vc))
  }))
  pr <- rma(yi = est$estimate, sei = est$se, method = "REML")
  list(conf = est, pooled = cbind(scenario = label, games = sum(est$games), meta_row(pr)))
}

influential <- do.call(rbind, lapply(conf_order, function(c) {
  d <- games[games$conference == c, ]
  m <- fit_conf(d, ref_of(c))
  cd <- cooks.distance(m)
  d[is.na(cd) | cd <= 4 / nrow(d), ]
}))

scen <- list(
  run_scenario(games, "Main analysis"),
  run_scenario(games, "Robust (HC3) standard errors", robust = TRUE),
  run_scenario(games[games$year %in% c(2019, 2021), ], "2019 and 2021 only"),
  run_scenario(games[games$year == 2020, ], "2020 only"),
  run_scenario(games[games$hf == 1, ], "Neutral site games removed"),
  run_scenario(games, "Adjusted for pregame Elo ratings and rivalry", adjust = TRUE),
  run_scenario(games[games$rivalry == 0, ], "Rivalry games removed"),
  run_scenario(influential, "High influence games removed (Cook's distance > 4/n)"),
  run_scenario(with_titles[!is.na(with_titles$attendance), ], "Championship games kept"),
  run_scenario(published, "Data exactly as used in the submitted manuscript")
)
save_table(do.call(rbind, lapply(scen, `[[`, "pooled")), "table6_robustness_pooled")
save_table(do.call(rbind, lapply(scen, `[[`, "conf")), "tableS_robustness_by_conference")

ref_check <- do.call(rbind, lapply(conf_order, function(c) {
  d <- games[games$conference == c, ]
  teams <- sort(unique(c(d$home, d$away)))
  th <- sapply(teams, function(t) coef(fit_conf(d, t))[["Mattendance"]])
  data.frame(conference = c, reference_teams_tried = length(teams), min_estimate = min(th), max_estimate = max(th))
}))
save_table(ref_check, "tableS_reference_team_check")
