source(file.path("R", "00_functions.R"))

files <- c(
  "SEC" = "SEC data merged.xlsx",
  "Big Ten" = "big 10 merged .xlsx",
  "Big 12" = "big 12 merged data.xlsx",
  "ACC" = "Atlantic coast merged data.xlsx",
  "Pac-12" = "pac 12 fmerged_BG.xlsx"
)

clean_text <- function(x) {
  x <- gsub("\u00a0", " ", as.character(x))
  x <- gsub("\\s*\u2022\\s*", ", ", x)
  x <- gsub("\\s+,", ",", x)
  trimws(gsub("\\s+", " ", x))
}

read_one <- function(conf) {
  x <- read_excel(file.path("data", "raw", files[[conf]]), sheet = "total")
  names(x) <- trimws(names(x))
  site_col <- intersect(c("Site", "Location"), names(x))[1]
  att <- x$Attendance
  data.frame(
    conference = conf,
    year = as.integer(x$Year),
    away = clean_text(x$Visitingteam),
    home = clean_text(x$Hometeam),
    score_away = as.numeric(x[[grep("^score1", names(x))]]),
    score_home = as.numeric(x[[grep("^score2", names(x))]]),
    site = clean_text(x[[site_col]]),
    attendance_raw = clean_text(att),
    attendance = if (is.numeric(att)) att else as.numeric(gsub("[^0-9]", "", as.character(att))),
    hf = as.integer(x$Hfvariable),
    stringsAsFactors = FALSE
  )
}

raw <- do.call(rbind, lapply(names(files), read_one))

published <- raw
published$attendance[grepl(",", published$attendance_raw)] <- 0

titles <- data.frame(
  conference = rep(c("SEC", "Big Ten", "Big 12", "ACC", "Pac-12"), each = 3),
  year = rep(2019:2021, 5),
  away = c("Georgia", "Alabama", "Georgia", "Ohio State", "Northwestern", "Michigan",
           "Baylor", "Oklahoma", "Baylor", "Virginia", "Clemson", "Pittsburgh", "Oregon", "Oregon", "Oregon"),
  home = c("LSU", "Florida", "Alabama", "Wisconsin", "Ohio State", "Iowa",
           "Oklahoma", "Iowa State", "Oklahoma State", "Clemson", "Notre Dame", "Wake Forest", "Utah", "USC", "Utah"),
  site_key = c(rep("Mercedes", 3), rep("Lucas Oil", 3), rep("AT&T", 3), rep("Charlotte", 3), "Levi", "Coliseum", "Allegiant"),
  stringsAsFactors = FALSE
)
find_game <- function(d, conf, yr, away, home, site_key) {
  i <- which(d$conference == conf & d$year == yr & d$away == away & d$home == home & grepl(site_key, d$site, fixed = TRUE))
  if (length(i) != 1) stop(paste("Expected one game:", conf, yr, away, "at", home))
  i
}
titles$row <- mapply(function(c, y, a, h, s) find_game(raw, c, y, a, h, s),
                     titles$conference, titles$year, titles$away, titles$home, titles$site_key)
raw$title_game <- seq_len(nrow(raw)) %in% titles$row
published$title_game <- raw$title_game

ind_md5 <- c("2019" = "279d33e3fd369b1ffe102d44a1367989", "2020" = "423f9f9a5a04eb5fafba8d9a93610b1e",
             "2021" = "db5152e5707de9f72556cbcd07d5e1bf")
ind_files <- file.path("data", "raw", "independent", sprintf("cfb_schedules_%d.csv", 2019:2021))
for (k in 1:3) {
  if (!file.exists(ind_files[k])) {
    download.file(sprintf("https://raw.githubusercontent.com/sportsdataverse/cfbfastR-data/main/schedules/csv/cfb_schedules_%d.csv",
                          2018 + k), ind_files[k], mode = "wb", quiet = TRUE)
  }
  if (unname(tools::md5sum(ind_files[k])) != ind_md5[k]) stop(paste("Checksum does not match the published file:", ind_files[k]))
}
ind <- do.call(rbind, lapply(ind_files, read.csv))
ind <- ind[ind$home_division == "fbs" & ind$away_division == "fbs", ]
ind$neutral_site <- as.logical(ind$neutral_site)
alias <- function(x) ifelse(x == "Texas Christian University", "TCU", x)
match_one <- function(k) {
  h <- alias(raw$home[k]); a <- alias(raw$away[k])
  same <- which(ind$season == raw$year[k] & ind$home_team == h & ind$away_team == a)
  rev <- which(ind$season == raw$year[k] & ind$home_team == a & ind$away_team == h)
  cand <- c(same, rev)
  if (length(cand) == 0) stop(paste("No independent record:", raw$year[k], raw$away[k], "at", raw$home[k]))
  if (length(cand) > 1) cand <- cand[ind$neutral_site[cand] == raw$title_game[k]]
  if (length(cand) != 1) stop(paste("Ambiguous independent record:", raw$year[k], raw$away[k], "at", raw$home[k]))
  c(cand, cand %in% rev)
}
mm <- t(sapply(seq_len(nrow(raw)), match_one))
src <- ind[mm[, 1], ]
reversed <- mm[, 2] == 1
src_home <- ifelse(reversed, src$away_points, src$home_points)
src_away <- ifelse(reversed, src$home_points, src$away_points)

games_all <- raw
games_all$date <- as.Date(substr(src$start_date, 1, 10))
games_all$week <- src$week
games_all$elo_home <- ifelse(reversed, src$away_pregame_elo, src$home_pregame_elo)
games_all$elo_away <- ifelse(reversed, src$home_pregame_elo, src$away_pregame_elo)

log_fix <- function(i, field, old, new, reason) {
  data.frame(conference = raw$conference[i], year = raw$year[i], away = raw$away[i], home = raw$home[i],
             field = field, old_value = as.character(old), new_value = as.character(new), reason = reason)
}
fixes <- list()
sc <- which(!raw$title_game & (src_home != raw$score_home | src_away != raw$score_away))
for (i in sc) {
  fixes[[length(fixes) + 1]] <- log_fix(i, "score (away-home)", paste0(raw$score_away[i], "-", raw$score_home[i]),
                                        paste0(src_away[i], "-", src_home[i]), "Differs from the independent game record")
  games_all$score_home[i] <- src_home[i]
  games_all$score_away[i] <- src_away[i]
}
at <- which(!raw$title_game & !is.na(src$attendance) & (is.na(raw$attendance) | src$attendance != raw$attendance))
for (i in at) {
  why <- if (grepl(",", raw$attendance_raw[i]) && as.numeric(gsub("[^0-9]", "", raw$attendance_raw[i])) == src$attendance[i]) {
    "Stored as text in the source file"
  } else {
    "Differs from the independent game record"
  }
  fixes[[length(fixes) + 1]] <- log_fix(i, "attendance", raw$attendance_raw[i], src$attendance[i], why)
  games_all$attendance[i] <- src$attendance[i]
}
txt <- which(!raw$title_game & grepl(",", raw$attendance_raw) & !(seq_len(nrow(raw)) %in% at))
# Correctly parsed comma-formatted attendance is not a data correction.
hf_fix <- data.frame(conference = c("SEC", "SEC"), year = c(2021L, 2021L), away = c("Kentucky", "Georgia"),
                     home = c("Mississippi State", "Florida"), site_key = c("Davis Wade", "Jacksonville"), new = c(1L, 0L),
                     reason = c("Played at the home team's own stadium but coded as neutral",
                                "Played at a neutral site (Jacksonville) but coded as a home game"))
n_hf_corrected <- 0L
for (r in seq_len(nrow(hf_fix))) {
  i <- find_game(raw, hf_fix$conference[r], hf_fix$year[r], hf_fix$away[r], hf_fix$home[r], hf_fix$site_key[r])
  if (is.na(raw$hf[i]) || raw$hf[i] != hf_fix$new[r]) {
    fixes[[length(fixes) + 1]] <- log_fix(i, "home stadium indicator", raw$hf[i], hf_fix$new[r], hf_fix$reason[r])
    games_all$hf[i] <- hf_fix$new[r]
    n_hf_corrected <- n_hf_corrected + 1L
  }
}
tsrc <- read.csv(file.path("data", "raw", "championship_games_sources.csv"), stringsAsFactors = FALSE)
tsrc <- tsrc[match(paste(titles$conference, titles$year), paste(tsrc$conference, tsrc$year)), ]
if (anyNA(tsrc$conference) || any(tsrc$source_url == "")) stop("A championship game has no source in data/raw/championship_games_sources.csv")
titles$submitted_hf <- raw$hf[titles$row]
titles$source <- tsrc$source_short
n_before <- length(fixes)
for (r in seq_len(nrow(titles))) {
  i <- titles$row[r]
  if (tsrc$away_table_s1[r] != raw$away[i]) {
    fixes[[length(fixes) + 1]] <- log_fix(i, "home and away teams", paste(raw$away[i], "at", raw$home[i]),
                                          paste(raw$home[i], "at", raw$away[i]), "Home and away teams reversed in the source file")
    games_all[i, c("away", "home", "score_away", "score_home", "elo_away", "elo_home")] <-
      games_all[i, c("home", "away", "score_home", "score_away", "elo_home", "elo_away")]
  }
  if (tsrc$attendance_table_s1[r] != raw$attendance[i]) {
    fixes[[length(fixes) + 1]] <- log_fix(i, "attendance", raw$attendance_raw[i], tsrc$attendance_table_s1[r],
                                          "Differs from the official attendance")
    games_all$attendance[i] <- tsrc$attendance_table_s1[r]
  }
  if (tsrc$hf_table_s1[r] != raw$hf[i]) {
    fixes[[length(fixes) + 1]] <- log_fix(i, "home stadium indicator", raw$hf[i], tsrc$hf_table_s1[r],
                                          "Championship game at a neutral site but coded as a home game")
    games_all$hf[i] <- tsrc$hf_table_s1[r]
  }
}
n_title_fix <- length(fixes) - n_before

# Verification is always performed against the independent schedules.
# A correction log is required only if actual corrections are proposed.
fix_cols <- c("conference", "year", "away", "home", "field", "old_value", "new_value", "reason")
if (length(fixes)) {
  fixes <- do.call(rbind, fixes)
} else {
  fixes <- as.data.frame(setNames(replicate(length(fix_cols), character(), simplify = FALSE), fix_cols),
                         stringsAsFactors = FALSE)
}
fixes$conference <- factor(fixes$conference, levels = conf_order)
fixes <- fixes[order(fixes$field, fixes$conference, fixes$year), , drop = FALSE]
verification_file <- file.path("data", "raw", "verification_log.csv")
fix_key <- function(d) paste(d$conference, d$year, d$away, d$home, d$field, sep = "\r")
if (file.exists(verification_file)) {
  vlog <- read.csv(verification_file, stringsAsFactors = FALSE)
  required_cols <- c("conference", "year", "away", "home", "field", "source_url")
  absent <- setdiff(required_cols, names(vlog))
  if (length(absent)) stop("verification_log.csv is missing columns: ", paste(absent, collapse = ", "))
  if (anyDuplicated(fix_key(vlog))) stop("Duplicate correction keys in verification_log.csv")
  fixes$source <- vlog$source_url[match(fix_key(fixes), fix_key(vlog))]
  if (nrow(fixes) && any(is.na(fixes$source) | !nzchar(trimws(fixes$source)))) {
    missing_rows <- fixes[is.na(fixes$source) | !nzchar(trimws(fixes$source)), , drop = FALSE]
    review_file <- file.path("output", "tables", "corrections_needing_verification.csv")
    missing_rows$source_url <- ""
    write.csv(missing_rows, review_file, row.names = FALSE, na = "")
    stop("VERIFICATION LOG INCOMPLETE: ", nrow(missing_rows),
         " proposed corrections lack a matching nonempty source_url.\n",
         "Review ", review_file, " and compare conference, year, away, home, field ",
         "with data/raw/verification_log.csv.\n",
         "Confirm the corrections against reliable sources; do not add invented URLs.")
  }
  message("Correction log checked: ", nrow(fixes), " documented corrections.")
} else if (nrow(fixes) == 0L) {
  fixes$source <- character()
  message("Independent cross-check complete; no corrections identified. ",
          "No verification_log.csv required.")
} else {
  # Fail safely instead of silently applying unsourced corrections.
  review_file <- file.path("output", "tables", "corrections_needing_verification.csv")
  review <- fixes
  review$source_url <- rep("", nrow(review))
  write.csv(review, review_file, row.names = FALSE, na = "")
  stop(
    "DATA VERIFICATION REQUIRES REVIEW: ", nrow(fixes),
    " proposed corrections were identified when comparing the conference ",
    "workbooks with independent schedules and study-specific classification records.\n",
    "This does not automatically mean the workbook values are wrong.\n",
    "1. Open: ", review_file, "\n",
    "2. Check each proposed old/new value against reliable sources.\n",
    "3. If the submitted value is wrong, document the justified correction ",
    "in data/raw/verification_log.csv (see templates/verification_log_template.csv).\n",
    "4. If the submitted value is already correct, investigate the matching ",
    "or comparison rule; do not invent a source or accept an incorrect change.\n",
    "5. Rerun source('run_all.R') after resolving the discrepancies.\n",
    "No source workbook has been overwritten. See README.md > Troubleshooting."
  )
}

riv <- read.csv(file.path("data", "raw", "rivalries.csv"))
pair <- function(a, b) paste(pmin(a, b), pmax(a, b))
games_all$rivalry <- as.integer(pair(games_all$home, games_all$away) %in% pair(riv$team1, riv$team2))
games_all$margin <- games_all$score_home - games_all$score_away
published$margin <- published$score_home - published$score_away

missing <- is.na(games_all$attendance) | is.na(games_all$margin)
games <- games_all[!games_all$title_game & !missing, ]

check <- data.frame(
  check = c("Games compared with the independent record", "Games matched", "Scores corrected", "Attendance values corrected",
            "Attendance read from text", "Home stadium indicator corrected", "Championship games checked against published sources",
            "Championship game values corrected", "Games with pregame Elo for both teams", "Rivalry games"),
  n = c(sum(!raw$title_game), sum(!is.na(mm[!raw$title_game, 1])), length(sc), length(at), length(txt), n_hf_corrected, nrow(titles), n_title_fix,
        sum(!is.na(games$elo_home) & !is.na(games$elo_away)), sum(games$rivalry))
)

counts <- do.call(rbind, lapply(split(games_all, list(games_all$conference, games_all$year), drop = TRUE), function(d) {
  a <- d[!d$title_game & !(is.na(d$attendance) | is.na(d$margin)), ]
  data.frame(
    conference = d$conference[1], year = d$year[1],
    teams = length(unique(c(a$home, a$away))),
    games_in_file = nrow(d),
    championship_removed = sum(d$title_game),
    missing_removed = sum(!d$title_game & (is.na(d$attendance) | is.na(d$margin))),
    games_analyzed = nrow(a),
    home_stadium_games = sum(a$hf == 1),
    neutral_site_games = sum(a$hf == 0),
    zero_attendance_games = sum(a$attendance == 0)
  )
}))
counts$conference <- factor(counts$conference, conf_order)
counts <- counts[order(counts$conference, counts$year), ]
totals <- data.frame(conference = "Total", year = NA, teams = NA,
                     t(colSums(counts[, c("games_in_file", "championship_removed", "missing_removed",
                                          "games_analyzed", "home_stadium_games", "neutral_site_games",
                                          "zero_attendance_games")])))
counts <- rbind(counts, totals)

refs <- data.frame(conference = conf_order,
                   reference_team = sapply(conf_order, function(c) best_record_team(games[games$conference == c, ])))

titles$away <- games_all$away[titles$row]
titles$home <- games_all$home[titles$row]
titles$site <- games_all$site[titles$row]
titles$attendance <- games_all$attendance[titles$row]
titles$coded_hf <- games_all$hf[titles$row]

saveRDS(games, file.path("data", "derived", "games.rds"))
saveRDS(games_all, file.path("data", "derived", "games_with_titles.rds"))
saveRDS(published, file.path("data", "derived", "games_as_published.rds"))
saveRDS(refs, file.path("data", "derived", "reference_teams.rds"))

save_table(fixes, "data_fixes")
save_table(check, "data_verification")
save_table(titles[, c("conference", "year", "away", "home", "site", "attendance", "coded_hf", "submitted_hf", "source")], "championship_games_removed")
save_table(counts, "games_by_conference_season")
save_table(refs, "reference_teams")
save_table(riv[, c("conference", "team1", "team2", "trophy", "source")], "rivalry_games_list")
