source(file.path("R", "00_functions.R"))

games <- load_games()
refs <- readRDS(file.path("data", "derived", "reference_teams.rds"))

blocks <- lapply(conf_order, function(c) {
  d <- games[games$conference == c, ]
  X <- build_X(d, refs$reference_team[refs$conference == c])
  colnames(X) <- paste(c, colnames(X), sep = "_")
  list(d = d, X = X)
})
d <- do.call(rbind, lapply(blocks, `[[`, "d"))
X <- matrix(0, nrow(d), sum(sapply(blocks, function(b) ncol(b$X))))
r0 <- 0
c0 <- 0
for (b in blocks) {
  X[r0 + seq_len(nrow(b$X)), c0 + seq_len(ncol(b$X))] <- b$X
  r0 <- r0 + nrow(b$X)
  c0 <- c0 + ncol(b$X)
}
d$A <- d$hf * d$attendance / 10000
d$conf <- factor(d$conference, conf_order)

m_common <- lm(d$margin ~ X + A - 1, data = d)
m_sep <- lm(d$margin ~ X + A:conf - 1, data = d)
m_home <- lm(d$margin ~ X + hf + A - 1, data = d)
m_home_sep <- lm(d$margin ~ X + hf + A:conf - 1, data = d)
m_quad <- lm(d$margin ~ X + A + I(A^2) - 1, data = d)

r <- function(m, term, label) {
  s <- summary(m)$coefficients[term, ]
  data.frame(model = label, term = term, estimate = s[1], se = s[2], t = s[3], p = s[4],
             lower = s[1] - qt(0.975, m$df.residual) * s[2], upper = s[1] + qt(0.975, m$df.residual) * s[2])
}

fit_mixed <- function(f) {
  suppressMessages(suppressWarnings(lmer(f, data = d, REML = TRUE)))
}
mm <- fit_mixed(margin ~ X + A + (0 + A | conf) - 1)
mm_home <- fit_mixed(margin ~ X + hf + A + (0 + A | conf) - 1)
mrow <- function(m, term, label) {
  est <- fixef(m)[[term]]
  se <- sqrt(vcov(m)[term, term])
  data.frame(model = label, term = term, estimate = est, se = se, t = est / se, p = 2 * pnorm(-abs(est / se)),
             lower = est - 1.96 * se, upper = est + 1.96 * se)
}

out <- rbind(
  r(m_common, "A", "One stage, common attendance effect"),
  mrow(mm, "A", "One stage, conference random slope"),
  r(m_home, "hf", "One stage with home term"),
  r(m_home, "A", "One stage with home term"),
  mrow(mm_home, "hf", "One stage with home term, conference random slope"),
  mrow(mm_home, "A", "One stage with home term, conference random slope"),
  r(m_quad, "A", "One stage with squared attendance"),
  r(m_quad, "I(A^2)", "One stage with squared attendance")
)
out$slope_sd <- NA
out$slope_sd[out$model == "One stage, conference random slope"] <- attr(VarCorr(mm)$conf, "stddev")
out$slope_sd[grepl("home term, conference random slope", out$model)] <- attr(VarCorr(mm_home)$conf, "stddev")
save_table(out, "table5_one_stage_models")

tests <- rbind(
  data.frame(test = "Equal attendance effect across conferences", F = anova(m_common, m_sep)$F[2],
             df1 = anova(m_common, m_sep)$Df[2], df2 = m_sep$df.residual, p = anova(m_common, m_sep)$`Pr(>F)`[2]),
  data.frame(test = "Equal attendance effect across conferences, with home term", F = anova(m_home, m_home_sep)$F[2],
             df1 = anova(m_home, m_home_sep)$Df[2], df2 = m_home_sep$df.residual, p = anova(m_home, m_home_sep)$`Pr(>F)`[2]),
  data.frame(test = "Squared attendance term", F = anova(m_common, m_quad)$F[2],
             df1 = anova(m_common, m_quad)$Df[2], df2 = m_quad$df.residual, p = anova(m_common, m_quad)$`Pr(>F)`[2])
)
save_table(tests, "table5b_one_stage_tests")

keep <- function(m, terms) list(coef = coef(m)[terms], vcov = vcov(m)[terms, terms, drop = FALSE])
saveRDS(list(common = keep(m_common, "A"), home = keep(m_home, c("hf", "A")),
             max_attendance = max(d$attendance)),
        file.path("data", "derived", "one_stage_terms.rds"))
