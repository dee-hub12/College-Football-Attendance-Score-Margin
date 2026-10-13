source(file.path("R", "00_functions.R"))

games <- load_games()
refs <- readRDS(file.path("data", "derived", "reference_teams.rds"))

fits <- list()
main <- list()
abilities <- list()
for (c in conf_order) {
  d <- games[games$conference == c, ]
  ref <- refs$reference_team[refs$conference == c]
  m <- fit_conf(d, ref)
  fits[[c]] <- m
  main[[c]] <- cbind(conference = c, reference_team = ref, games = nrow(d), coef_row(m, "attendance"))
  s <- summary(m)$coefficients
  s <- s[rownames(s) != "Mattendance", , drop = FALSE]
  abilities[[c]] <- data.frame(
    conference = c, reference_team = ref,
    season = substr(sub("^M", "", rownames(s)), 1, 4),
    team = substring(sub("^M", "", rownames(s)), 6),
    estimate = s[, 1], se = s[, 2], t = s[, 3], p = s[, 4]
  )
}

table1 <- do.call(rbind, main)
saveRDS(fits, file.path("data", "derived", "conference_fits.rds"))
saveRDS(table1, file.path("data", "derived", "conference_estimates.rds"))
save_table(table1, "table1_conference_attendance_effects")
save_table(do.call(rbind, abilities), "tableS_team_abilities")
