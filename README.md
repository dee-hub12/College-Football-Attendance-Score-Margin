# Attendance and the Home Score Margin in College Football

**Research code and reproducibility documentation** for *Attendance and the Home Score Margin in College Football: Evidence from the COVID-19 Seasons*.

This repository contains the R scripts used to study associations between stadium attendance and the home-team score margin in the Atlantic Coast Conference (ACC), Big Ten, Big 12, Pac-12, and Southeastern Conference (SEC) during the 2019–2021 seasons. The workflow prepares game records, checks them against independent schedules, fits conference-specific regression models, pools attendance estimates using restricted maximum likelihood (REML) random-effects meta-analysis, and generates sensitivity analyses, hierarchical models, tables, figures, and numerical diagnostics. The results describe **associations, not causal effects**.

> **Scope:** This is the original study's reproducibility workflow, **not a general-purpose tool for arbitrary conferences or seasons**. Conference names, workbook filenames, championship-game matching rules, 2019–2021 independent schedule files, and some study-specific corrections are coded in `R/01_clean_data.R`. Applying the approach to different conferences, years, or schemas requires reviewing and adapting those rules and validating the revised analysis. The original study's sample sizes and estimates are benchmarks **only for equivalent original-study inputs**.

## Reading this documentation

This file is written in Markdown for GitHub. On GitHub it is displayed as a formatted page. In RStudio, open it in Markdown Preview (if available), or read it as plain text. Section names below are written out rather than linked to file-like `#section` paths, to avoid navigation errors in some RStudio views.

## Quick start

1. Install R (RStudio is optional). Download or clone the repository, and open `college-football-attendance.Rproj` if using RStudio.
2. Obtain the five conference workbooks and prepare the two required, completed classification files described below. Put them directly in `data/raw/`. The public repository does **not** include populated study datasets.
3. If your data require corrections, prepare `data/raw/verification_log.csv` with the documented sources. If no corrections are proposed by the implemented checks, that log is not required.
4. From the repository root, run:

   ```r
   source("run_all.R")
   ```

   Or from a terminal whose working directory is the repository root: `Rscript run_all.R`.
5. If validation stops, read the section titled **What to do when validation stops** in this README. Investigate the reported discrepancy before changing any data or code.
6. After completion, review the generated sample, diagnostics, tables, and figures. Completion alone does not establish that the input data or resulting inferences are correct.

The hierarchical fitting and simulation steps may take considerably longer than the initial regressions. `R/00_setup.R` checks for required packages (`readxl`, `metafor`, `ggplot2`, `sandwich`, `lmtest`, and `lme4`) and attempts to install missing packages from CRAN. Record the R and package versions for your analysis.

## Input files and when they are needed

The **seven required local inputs** are five conference workbooks plus two classification CSVs. The correction log is **conditional**, not universally required.

| File in `data/raw/` | Purpose | Requirement |
| --- | --- | --- |
| `SEC data merged.xlsx` | SEC game records | Required |
| `big 10 merged .xlsx` | Big Ten game records | Required; note the space before `.xlsx` |
| `big 12 merged data.xlsx` | Big 12 game records | Required |
| `Atlantic coast merged data.xlsx` | ACC game records | Required |
| `pac 12 fmerged_BG.xlsx` | Pac-12 game records | Required |
| `championship_games_sources.csv` | Sourced championship-game identification, attendance, and venue classifications | Required |
| `rivalries.csv` | Documented rivalry team-pair classifications for sensitivity analyses | Required |
| `verification_log.csv` | Sources for **proposed corrections** to submitted game records | **Only required if corrections are proposed** |

All five workbooks must contain a worksheet called `total`. See `data/README.md` for the exact field names, CSV template columns, and source-documentation expectations. **The files in `templates/` contain headers only.** They guide preparation of the completed CSVs; they do not contain verified games or classifications and cannot replace populated required inputs.

### What is checked independently?

`R/01_clean_data.R` retrieves the 2019, 2020, and 2021 schedule CSVs from the [SportsDataverse `cfbfastR-data` project](https://github.com/sportsdataverse/cfbfastR-data), saves them in `data/raw/independent/`, and checks their MD5 hashes against values recorded in the script. It matches games using season and team identifiers (including defined alias and reversal rules), compares available scores and attendance, and obtains **pregame home- and away-team Elo ratings**. An independent-source disagreement is a **candidate discrepancy**, not proof that the submitted record is wrong. A checksum mismatch or ambiguous match is a reason to investigate, not to disable the check.

**Elo and rivalry are different variables.** Elo is a team-strength measure supplied by the independent schedules. The rivalry indicator comes from `rivalries.csv`: the code assigns `rivalry = 1` when the unordered home/away pair matches a listed team pair, and `0` otherwise. The original study's list contains **34 documented rivalry pairs** selected using NCAA trophy-game and most-played rivalry records. The list is study-specific and should not be treated as an exhaustive definition of all rivalries. Researchers must check the sources and exact team names when reconstructing it; the populated list is not distributed here.

### Championship games and corrections are not the same thing

The required `championship_games_sources.csv` records the study's championship-game decisions. The cleaning script also uses **explicitly coded game-identification rules** for the original five conferences and seasons. This file is needed even if the workbooks contain no errors. The required `rivalries.csv` defines a separate analysis covariate.

By contrast, `verification_log.csv` documents **changes proposed after comparing input records with the independent schedules and study-specific rules**. It can be absent when those checks propose no corrections. If corrections are proposed and the log is missing or lacks matching source references, the script intentionally stops before saving the final derived analysis dataset. The original Excel workbooks are not overwritten.

## What to do when validation stops

An error during `01_clean_data.R` is usually a request to **inspect the inputs or a matching rule**, not evidence that the entire statistical model failed. In particular, a message reporting a number of proposed corrections does **not** mean that many workbook values are definitely incorrect.

**If the script reports proposed corrections:**

1. Open `output/tables/corrections_needing_verification.csv`. Review the `conference`, `year`, `away`, `home`, `field`, `old_value`, `new_value`, and `reason` columns. The proposed `source_url` is blank until documented.
2. Compare each proposed change with appropriate authoritative records. Check team-name aliases, season, scores, attendance, venue, neutral-site status, and home/away assignment. The independent source or the matching rule may itself be wrong.
3. **If the proposed correction is justified**, copy `templates/verification_log_template.csv` to `data/raw/verification_log.csv` and complete a corresponding row. The code matches `conference`, `year`, `away`, `home`, and `field`, and requires a real, nonempty `source_url` for each proposed correction. Include the old/new values and supporting notes for a transparent audit. Do not invent citations.
4. **If the submitted value is already correct**, do not fabricate a correction entry. Investigate and resolve the comparison or matching rule. This version has no separate accept-as-is override file; a justified code change must be reviewed and checked against the original study results.
5. Rerun `source("run_all.R")`. Inspect `output/tables/data_fixes.csv`, `data_verification.csv`, and the derived dataset before interpreting the model outputs.

**If no corrections are proposed:** The code proceeds without `verification_log.csv` while still performing the independent schedule matching and other implemented checks. Passing these checks does **not** guarantee that every data value is correct.

| Error or warning | Interpretation and response |
| --- | --- |
| Missing Excel workbook, `total` sheet, or required column | Check exact filenames and field names in `data/README.md`. |
| Championship source file missing or missing `source_url` | Complete `championship_games_sources.csv` from independently checked records; the template alone is insufficient. |
| Rivalry file missing or team names do not match | Supply a completed `rivalries.csv`; check both team-name columns against the workbook identifiers. |
| No independent game match or ambiguous match | Inspect season, home/away team names, aliases, venue, and duplicate fixtures. Do not force a guessed match. |
| Download or MD5 mismatch | Investigate connectivity or upstream source changes; do not silently bypass the integrity check. |
| Proposed corrections without a complete log | Review `corrections_needing_verification.csv`, resolve disagreements, and document only justified corrections. |
| R package built under another R version | Often a compatibility warning rather than a stopping error; record versions and verify the run. |
| `geom_errorbarh()` deprecated or `height` translated to `width` | Plotting/formatting notices; distinguish them from data-validation errors. |
| Long hierarchical run | Optimization and simulation can be computationally intensive; wait for the completion message. |

## Analysis scripts

`run_all.R` runs the following scripts in dependency order. `R/00_functions.R` contains shared helpers.

| Script | Purpose |
| --- | --- |
| `R/00_setup.R` | Package checks and output directories |
| `R/01_clean_data.R` | Read inputs, match independent schedules, audit proposed corrections, build derived datasets |
| `R/02_descriptives.R` | Descriptive summaries |
| `R/03_conference_models.R` | Conference-specific regressions |
| `R/04_meta_analysis.R` | REML random-effects meta-analysis and sensitivity estimates |
| `R/05_home_intercept.R` | Home-stadium specifications |
| `R/06_one_stage.R` | One-stage models |
| `R/07_robustness.R` | Robustness checks, including rivalry-based analyses |
| `R/08_competitive_balance.R` | Competitive-balance analyses |
| `R/09_diagnostics.R` | Model diagnostics |
| `R/12_hierarchical.R` | Hierarchical fitting and numerical optimization checks |
| `R/13_hierarchical_check.R` | Simulation-based implementation checks |
| `R/10_figures.R` | Figure generation |

## Outputs

The scripts create `data/derived/`, `output/tables/`, `output/figures/`, and `output/diagnostics/hierarchical/` as needed. Generated results and local input data are excluded by `.gitignore`.

- **Derived datasets and model objects:** `data/derived/`, including `games.rds`, `games_with_titles.rds`, model fits, and intermediate results.
- **Tables and audits:** `output/tables/`, including conference estimates, pooled effects, sensitivity analyses, `data_fixes.csv`, `data_verification.csv`, `championship_games_removed.csv`, and `rivalry_games_list.csv`. These audit tables are **outputs**, not substitutes for input CSVs.
- **Figures:** `output/figures/`, in PNG/PDF formats.
- **Hierarchical diagnostics:** `output/diagnostics/hierarchical/`. The original simulation-check script uses 18 datasets by default; diagnostics do not prove a global optimum or guarantee model adequacy.

## Reproducibility checks and interpretation

For **any dataset supported by a properly reviewed version of this workflow**, examine the final game count, inclusion/exclusion decisions, missingness, duplicates, attendance and score validity, independent matches, source documentation, model estimates, uncertainty intervals, diagnostics, and figures. Repeating the analysis with the same input data and software environment should produce consistent results. The expected sample size and estimates depend on the supplied data and any justified code adaptations.

**Original-study benchmark (not a requirement for other datasets):** The previously tested original-data workflow produced 824 source games, excluded 15 championship games, and retained 809 eligible games. Its main pooled attendance estimate was approximately 0.375059 points per 10,000 spectators. These numbers apply only to equivalent original-study inputs and should not be expected when analyzing other datasets. The conditional-correction-log revision has not yet been verified by a complete end-to-end run.

## Repository contents and data access

```text
README.md
run_all.R
college-football-attendance.Rproj
R/                       # original analysis scripts
  00_setup.R
  00_functions.R
  01_clean_data.R
  02_descriptives.R
  03_conference_models.R
  04_meta_analysis.R
  05_home_intercept.R
  06_one_stage.R
  07_robustness.R
  08_competitive_balance.R
  09_diagnostics.R
  10_figures.R
  12_hierarchical.R
  13_hierarchical_check.R
templates/               # blank CSV headers only
  championship_games_sources_template.csv
  rivalries_template.csv
  verification_log_template.csv
data/
  README.md
  raw/.gitkeep
.gitignore
```

**Data access and licensing:** This code-focused repository intentionally omits the populated conference workbooks, completed championship and rivalry records, and populated correction logs. Researchers must obtain or reconstruct inputs from sources they are authorized to use. Providing a citation or source URL does not itself grant redistribution rights. Exact numerical reproduction requires equivalent inputs and decisions; the public ZIP alone cannot reproduce the article's numerical results.

## Citation and attribution

If you use this research code, cite *Attendance and the Home Score Margin in College Football: Evidence from the COVID-19 Seasons* using its final bibliographic information when available. Cite the original game-data and verification sources as appropriate. This repository does not claim a publication DOI or a code license that has not been established.
