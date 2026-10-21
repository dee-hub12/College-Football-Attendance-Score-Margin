
# Attendance and the Home Score Margin in College Football

**Research code and reproducibility documentation** for *Attendance and the Home Score Margin in College Football: Evidence from the COVID-19 Seasons*.

## Overview

This repository contains the R code used to investigate the association between stadium attendance and home-team score margin in college football during the 2019–2021 seasons.

The study includes games from five Power Five conferences: the Atlantic Coast Conference (ACC), Big Ten, Big 12, Pac-12, and Southeastern Conference (SEC).

The analyses include:

- Data cleaning, independent game verification, and descriptive statistics.
- Conference-specific regression models.
- Random-effects meta-analysis using restricted maximum likelihood (REML).
- Separate home-intercept and attendance-effect specifications.
- One-stage hierarchical modeling.
- Robustness and sensitivity analyses.
- Model diagnostics and numerical optimization checks.
- A final 1,000-replicate hierarchical simulation study assessing parameter recovery and confidence-interval coverage.

**Important:** The findings describe statistical associations, not causal effects of attendance.

## Study Data

The original dataset contained 824 games from the 2019–2021 seasons. After excluding 15 conference championship games, the final analytical sample contained **809 games**, including **67 spectator-free games**.

The main pooled attendance association was approximately **0.375 points in home-team score margin per additional 10,000 attendees** (95% CI: 0.149–0.601).

This estimate is associational and should not be interpreted as evidence that increasing attendance causes a corresponding change in score margin.

## Repository Structure

```text
College-Football-Attendance-Score-Margin/
├── README.md
├── run_all.R
├── college-football-attendance.Rproj
├── R/
│   ├── 00_setup.R
│   ├── 00_functions.R
│   ├── 01_clean_data.R
│   ├── 02_descriptives.R
│   ├── 03_conference_models.R
│   ├── 04_meta_analysis.R
│   ├── 05_home_intercept.R
│   ├── 06_one_stage.R
│   ├── 07_robustness.R
│   ├── 08_competitive_balance.R
│   ├── 09_diagnostics.R
│   ├── 10_figures.R
│   ├── 12_hierarchical.R
│   ├── 13_hierarchical_check_preliminary_18.R
│   ├── 13_hierarchical_simulation_1000.R
│   └── 14_summarize_hierarchical_simulations_1000.R
├── templates/
│   ├── championship_games_sources_template.csv
│   ├── rivalries_template.csv
│   └── verification_log_template.csv
└── data/
    ├── README.md
    └── raw/
```

The structure above describes the intended organization. Generated datasets, simulation checkpoints, and output files may exist only in the local working environment.

## Required Input Data

The original analysis requires five conference workbooks and two completed classification files in `data/raw/`.

| Input file | Description |
|---|---|
| `SEC data merged.xlsx` | SEC game records |
| `big 10 merged .xlsx` | Big Ten game records |
| `big 12 merged data.xlsx` | Big 12 game records |
| `Atlantic coast merged data.xlsx` | ACC game records |
| `pac 12 fmerged_BG.xlsx` | Pac-12 game records |
| `championship_games_sources.csv` | Verified conference championship-game classifications |
| `rivalries.csv` | Documented rivalry team-pair classifications |
| `verification_log.csv` | Conditional file documenting proposed data corrections |

All five workbooks must contain a worksheet named `total`.

The files in `templates/` provide CSV structures only. They are not completed datasets or verified classifications.

The public code-only repository does not distribute populated original study datasets, derived RDS files, generated outputs, or the 100 simulation checkpoint batches. Researchers must obtain or reconstruct equivalent study inputs from sources they are authorized to use. The original completed 1,000-replicate outputs are reported in the manuscript and supplement; reproducing them requires executing the simulation or obtaining the original checkpoint files separately.

## Data Verification

The data-cleaning workflow compares game records with independent schedules from the [SportsDataverse cfbfastR-data repository](https://github.com/sportsdataverse/cfbfastR-data).

The verification process examines game matching, team names, home/away assignments, scores, attendance, and venue classifications. It also obtains pregame Elo ratings for team-strength adjustment.

Independent-source discrepancies are treated as candidates for investigation, not automatically accepted as corrections. Proposed changes must be reviewed and supported by documented sources.

The cleaning script preserves the original Excel workbooks and writes derived datasets separately.

The rivalry indicator is based on a study-specific list of 34 documented rivalry pairs; it is not intended as an exhaustive classification of every rivalry.

## Running the Main Analysis

Install R and the required packages, including:

- `readxl`
- `metafor`
- `ggplot2`
- `sandwich`
- `lmtest`
- `lme4`

From the repository root, run:

```r
source("run_all.R")
```

Alternatively, from a terminal:

```bash
Rscript run_all.R
```

Review any validation errors before proceeding. Do not bypass failed game-matching checks or undocumented correction requirements merely to complete a run.

**Note:** The final 1,000-replicate simulation is a separate workflow and does not execute automatically through `run_all.R`.

## Hierarchical Models and Numerical Diagnostics

The empirical analysis includes hierarchical specifications that account for variation in team strength and team-season performance.

Numerical optimization checks were conducted to assess computational stability. These are documented separately from the simulation study and correspond to **Supplementary Figures S7 and S8**.

Numerical convergence does not, by itself, establish causal identification, global optimality, or model adequacy.

## Final Hierarchical Simulation Study: 1,000 Replicates

The final simulation study evaluates parameter recovery and confidence-interval coverage under a prespecified data-generating mechanism using the observed study design.

A total of **1,000 simulated datasets** were analyzed, organized into **100 batches of 10 replicates**.

The data-generating settings were:

| Parameter | True value |
|---|---:|
| Home-intercept coefficient | 0.000 |
| Attendance coefficient (points per 10,000 attendees) | 0.500 |
| Between-team standard deviation | 9 |
| Team-season standard deviation | 5 |
| Residual standard deviation | 14 |

All **1,000 of 1,000 model fits converged** in the completed simulation study.

### Simulation Results

| Parameter | True value | Mean estimate | Bias | Empirical SD | Mean SE | 95% CI coverage |
|---|---:|---:|---:|---:|---:|---:|
| Home intercept | 0.000 | 0.0089 | 0.0089 | 0.8644 | 0.8939 | 96.7% |
| Attendance | 0.500 | 0.4933 | -0.0067 | 0.1752 | 0.1868 | 97.1% |

The simulation results indicate small empirical bias and coverage slightly above the nominal 95% level under the specified simulation design.

These findings assess the performance of the estimation procedure under the simulated conditions. They do not establish that the observational attendance association is causal or that the model performs equally well under other data-generating mechanisms.

### Corresponding Supplementary Materials

- **Supplementary Table S14:** Hierarchical parameter recovery, bias, empirical variability, and confidence-interval coverage.
- **Supplementary Figure S9:** Distributions of hierarchical parameter estimates across 1,000 simulations.
- **Supplementary Figure S10:** Empirical confidence-interval coverage across 1,000 simulations.

Supplementary Figures S7–S8 concern numerical optimization diagnostics and are not simulation-study figures.

## Reproducing the 1,000 Simulations

The main simulation script is:

```text
R/13_hierarchical_simulation_1000.R
```

After preparing the required original-study data and derived objects, run the following from the repository root to permit fitting or resuming simulations:

```r
Sys.setenv(
  HIER_SIM_N = "1000",
  HIER_SIM_BATCH = "10",
  HIER_SIM_NSTARTS = "1",
  HIER_SIM_RECOVER_ONLY = "0"
)

source("R/13_hierarchical_simulation_1000.R")
```

Completed batches are checkpointed under:

```text
data/derived/hierarchical_simulation_v2/batch010_starts01/
```

The checkpointing design supports resuming interrupted work without unnecessarily refitting completed batches. Existing batches should not be overwritten unless a deliberate rerun is intended.

To recover results from existing checkpoints without fitting new models:

```r
Sys.setenv(HIER_SIM_RECOVER_ONLY = "1")
source("R/13_hierarchical_simulation_1000.R")
```

To recover and summarize the completed 100 batches:

```r
source("R/14_summarize_hierarchical_simulations_1000.R")
```

The recovery script expects files named `batch_0001.rds` through `batch_0100.rds` in the checkpoint directory. **Those checkpoints are not included in this code-only release.** Run the simulation to create them before using recovery mode. The summarizer does not fit models.

It generates summary files including:

```text
simulation_results_n1000.csv
simulation_summary_n1000.csv
```

The script also produces figures and saves the recovered outputs to a local `Documents/HFA_hierarchical_simulation_outputs/` directory. These outputs are not automatically uploaded to GitHub.

The full simulation may require substantial computing time, depending on the system.

## Preliminary Simulation Check: 18 Replicates

The repository also retains:

```text
R/13_hierarchical_check_preliminary_18.R
```

This script represents an earlier preliminary implementation check involving 18 simulated datasets.

**The 18-replicate check is not the final simulation study reported in the revised manuscript.**

The final reported parameter-recovery and coverage results are based exclusively on the 1,000-replicate study.

The preliminary script is retained for transparency and development history.

## Sensitivity Analyses

The analysis includes checks involving:

- Alternative specifications of home advantage.
- Pregame Elo team-strength adjustment.
- Rivalry-game adjustments and exclusions.
- Heteroskedasticity-consistent standard errors.
- Analyses excluding the 2020 season.
- Conference-level heterogeneity.
- Hierarchical model specifications.
- Numerical optimization and influence diagnostics.

The analyses help assess robustness to modeling decisions but do not eliminate the possibility of residual confounding.

## Generated Outputs

Depending on the scripts executed, the workflow creates:

```text
data/derived/
output/tables/
output/figures/
output/diagnostics/hierarchical/
```

Generated outputs include derived game records, model objects, conference estimates, pooled meta-analysis results, sensitivity analyses, data-verification reports, diagnostic summaries, and figures.

Simulation checkpoints and recovered summaries are generated separately. The public code-only package intentionally excludes `output/`, `data/derived/`, and `HFA_hierarchical_simulation_outputs/`; keep these locally as your validated analysis record.

Users should inspect the resulting sample sizes, estimates, uncertainty intervals, and diagnostics rather than assuming that a completed script establishes successful reproduction.

## Reproducibility and Limitations

This repository documents the analytical procedures used in the original study. It is not a general-purpose pipeline for arbitrary seasons, conferences, or data formats.

The original analysis includes study-specific cleaning rules, championship classifications, rivalry definitions, and independent schedule checks. Applying the workflow elsewhere requires reviewing and adapting those rules.

Because populated study input files are not included in this code-focused repository, exact numerical reproduction requires access to equivalent original-study inputs and classification decisions.

The study's main attendance association should not be interpreted causally. The COVID-19 seasons involved changes in scheduling, stadium policies, team conditions, and other factors that may affect both attendance and game outcomes.

## Citation

If you use this repository, please cite:

*Attendance and the Home Score Margin in College Football: Evidence from the COVID-19 Seasons.*

Use the article's final bibliographic details when available. Cite the original data and verification sources as appropriate.

No publication DOI or software license is claimed here unless separately established.
