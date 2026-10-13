# Preparing and verifying study inputs

This document describes the **current original-study R implementation**. The code is tied to five named conferences and 2019–2021; it does not automatically generalize to arbitrary teams, years, or data structures. To use other inputs, first review and adapt the hard-coded game-matching, championship, and independent-schedule logic in `R/01_clean_data.R` and revalidate the downstream models.

## Where files go

Put the five Excel workbooks and **two completed classification CSVs** directly in `data/raw/`. The optional correction log goes in the same folder **only if proposed corrections require documentation**. See the main `README.md` in the repository root for the exact workbook filenames. The three files in `templates/` are **blank headers**, not verified observations.

## Excel workbook schema

Each workbook must contain a sheet named `total`, with these case-sensitive fields:

| Column | Interpretation |
| --- | --- |
| `Year` | Season, 2019, 2020, or 2021 in the current code |
| `Visitingteam` | Away-team identifier |
| `Hometeam` | Home-team identifier |
| `Attendance` | Attendance, numeric or parseable numeric text |
| `Hfvariable` | Home-stadium indicator: 1 = home-team stadium, 0 = otherwise |
| `Site` **or** `Location` | Venue |
| Column beginning `score1` | Away-team score |
| Column beginning `score2` | Home-team score |

Consistent team names are essential for schedule matching and rivalry classification. The script includes only specific name aliases, not a general fuzzy matcher. Inspect records for duplicates, missing fields, implausible scores, attendance values, and venue inconsistencies before running.

## Required: `championship_games_sources.csv`

Start with `templates/championship_games_sources_template.csv`, then verify and complete the records. The original study expects one row for each conference-season combination (**15** in total). `R/01_clean_data.R` uses `conference`, `year`, `source_url`, `source_short`, `away_table_s1`, `attendance_table_s1`, and `hf_table_s1` to match and check the championship records. The template also contains additional columns for documenting provenance and audit decisions.

**Do not use an empty template as the required file.** The code identifies the original study's championship games using hard-coded team/season/venue rules and compares them with this completed source table. These rules would need revision for different conferences or seasons.

## Required: `rivalries.csv`

Start with `templates/rivalries_template.csv`, then supply the documented team pairs. The code reads `team1` and `team2` to classify a matchup regardless of home/away order. The audit output also uses `conference`, `trophy`, and `source`. Team identifiers must agree with those in the game records.

**How the original study constructed the classification:** The study-specific list comprises 34 pairs drawn from documented NCAA trophy-game listings and most-played rivalry records. The list represents a particular operational definition, not every possible rivalry. Its recorded source categories should be checked against the underlying NCAA references when reconstructing the populated CSV. The rivalry indicator is **not** computed from Elo ratings.

## Conditional: `verification_log.csv`

The script compares available game scores and attendance against downloaded independent schedules and applies documented home-stadium and championship checks. These are implemented checks, not proof that every source record is accurate. If those checks **propose no corrections**, the log may be omitted.

If corrections are proposed, the script requires `data/raw/verification_log.csv`, prepared from `templates/verification_log_template.csv`. The columns `conference`, `year`, `away`, `home`, `field`, and `source_url` are used to match and document each proposed change; retain `old_value`, `new_value`, and explanatory notes as well. A blank template is insufficient.

**When the log is absent and corrections are proposed:**

1. The script writes `output/tables/corrections_needing_verification.csv` and stops.
2. Open that file and check each submitted value against reliable records. A disagreement may reflect a workbook error, a difference in definitions, or a matching error.
3. If the correction is justified, document a corresponding log row with a real supporting URL.
4. If the submitted value is correct, investigate the comparison or matching rule. **Do not invent a URL or approve an incorrect correction.** The current code has no separate accept-as-is override mechanism.
5. Rerun `source("run_all.R")` and review the generated audit tables and derived data.

The code changes only the derived data objects; it does **not** overwrite the original Excel workbooks. A no-error run indicates that the data passed the implemented checks, not that all records have been proven accurate.

## Independently retrieved schedules and Elo

The script retrieves `cfb_schedules_2019.csv`, `cfb_schedules_2020.csv`, and `cfb_schedules_2021.csv` from [SportsDataverse `cfbfastR-data`](https://github.com/sportsdataverse/cfbfastR-data) into `data/raw/independent/`, if absent, and checks their recorded MD5 hashes. It matches game records to these schedules to compare available attendance and scores and extract **pregame home- and away-team Elo**. Elo measures relative team strength; it does **not** define rivalry status. Do not silently bypass checksum or ambiguous-match errors.

## Generated audits and availability

After successful validation, the workflow saves `data/derived/games.rds` and generated tables including `output/tables/data_fixes.csv`, `data_verification.csv`, `championship_games_removed.csv`, and `rivalry_games_list.csv`. These are **outputs**, not required source CSVs. The original study's 809-game sample is a benchmark for equivalent original-study inputs only.

This public repository does not include populated third-party game data or completed source lists. Obtain or reconstruct the inputs from sources you are authorized to use. The templates are aids to documentation, not substitute datasets.
