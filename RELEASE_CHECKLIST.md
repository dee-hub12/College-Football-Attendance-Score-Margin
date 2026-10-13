# Release validation checklist

This file records checks that must be completed **before claiming a fully validated release**. It is not an assertion that the latest revision has passed them.

- [ ] With the original eight inputs (five workbooks, championship and rivalry CSVs, plus correction log), run `source("run_all.R")` to completion.
- [ ] Confirm the original-study derived sample: 809 eligible games after 15 championship exclusions; check 17 fields and missingness.
- [ ] Compare the principal pooled estimate with the original run (approximately 0.375059 per 10,000 spectators), including confidence intervals and sensitivity analyses.
- [ ] Review all hierarchical results, numerical diagnostics, and figures against the original study.
- [ ] Test the seven-input case (omit the correction log) using independently confirmed correction-free workbooks. Check that all independent comparisons still run.
- [ ] Test the seven-input case using workbooks with real discrepancies. Confirm that the script stops and writes `corrections_needing_verification.csv` with useful explanations.
- [ ] Confirm that a complete, correctly matched correction log allows a justified correction and that the source Excel workbooks remain unchanged.
- [ ] Check the championship and rivalry classification sources and the accuracy of any links before publication.
- [ ] Verify no populated third-party datasets, confidential materials, or manuscript submission records are present in the public archive.
- [ ] Record R version, package versions, and operating system for a successful run.

**Limitation:** This version's input-processing logic is study-specific. Testing another conference requires deliberate adaptation, not simply swapping in another workbook.
