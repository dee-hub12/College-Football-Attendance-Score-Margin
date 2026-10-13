source(file.path("R", "00_functions.R"))

games <- load_games()
refs <- readRDS(file.path("data", "derived", "reference_teams.rds"))

rows <- list()
for (c in conf_order) {
  d <- games[games$conference == c, ]
  m <- fit_conf(d, refs$reference_team[refs$conference == c], home_term = TRUE)
  vc <- vcov(m)
  a_bar <- mean(d$attendance[d$hf == 1]) / 10000
  edge <- coef(m)[["Mhome"]] + a_bar * coef(m)[["Mattendance"]]
  edge_se <- sqrt(vc["Mhome", "Mhome"] + a_bar^2 * vc["Mattendance", "Mattendance"] + 2 * a_bar * vc["Mhome", "Mattendance"])
  h <- coef_row(m, "home")
  a <- coef_row(m, "attendance")
  rows[[c]] <- data.frame(
    conference = c, games = nrow(d),
    home_estimate = h$estimate, home_se = h$se, home_p = h$p,
    attendance_estimate = a$estimate, attendance_se = a$se, attendance_p = a$p,
    mean_home_attendance = a_bar * 10000,
    edge_at_mean_attendance = edge, edge_se = edge_se,
    corr_home_attendance = cov2cor(vc)["Mhome", "Mattendance"]
  )
}
tab <- do.call(rbind, rows)
save_table(tab, "table4_home_intercept_by_conference")

pool <- function(y, se, label) cbind(quantity = label, meta_row(rma(yi = y, sei = se, method = "REML")))
pooled <- rbind(
  pool(tab$home_estimate, tab$home_se, "Home effect with no crowd"),
  pool(tab$attendance_estimate, tab$attendance_se, "Attendance effect per 10,000"),
  pool(tab$edge_at_mean_attendance, tab$edge_se, "Home edge at the average crowd")
)
save_table(pooled, "table4b_home_intercept_pooled")
