suppressPackageStartupMessages({
  library(readxl)
  library(metafor)
  library(ggplot2)
  library(sandwich)
  library(lmtest)
  library(lme4)
})

conf_order <- c("SEC", "Big Ten", "Big 12", "ACC", "Pac-12")

theme_pub <- function() {
  theme_classic(base_size = 11, base_family = "serif") +
    theme(
      axis.text = element_text(colour = "black"),
      strip.background = element_blank(),
      strip.text = element_text(face = "bold"),
      legend.position = "none"
    )
}

save_table <- function(x, name) {
  write.csv(x, file.path("output", "tables", paste0(name, ".csv")), row.names = FALSE, fileEncoding = "UTF-8")
}

save_figure <- function(p, name, width, height) {
  ggsave(file.path("output", "figures", paste0(name, ".png")), p, width = width, height = height, dpi = 600)
  ggsave(file.path("output", "figures", paste0(name, ".pdf")), p, width = width, height = height)
}

load_games <- function() {
  readRDS(file.path("data", "derived", "games.rds"))
}

build_X <- function(d, ref) {
  teams <- sort(setdiff(unique(c(d$home, d$away)), ref))
  years <- sort(unique(d$year))
  X <- matrix(0, nrow(d), length(teams) * length(years))
  colnames(X) <- paste(rep(years, each = length(teams)), teams, sep = "_")
  for (i in seq_len(nrow(d))) {
    b <- (match(d$year[i], years) - 1) * length(teams)
    if (d$home[i] %in% teams) X[i, b + match(d$home[i], teams)] <- 1
    if (d$away[i] %in% teams) X[i, b + match(d$away[i], teams)] <- -1
  }
  X[, colSums(abs(X)) > 0, drop = FALSE]
}

controls <- function(d) {
  cbind(elo_diff = (d$elo_home - d$elo_away) / 100, elo_mean = ((d$elo_home + d$elo_away) / 2 - 1500) / 100, rivalry = d$rivalry)
}

fit_conf <- function(d, ref, home_term = FALSE, adjust = FALSE) {
  X <- build_X(d, ref)
  A <- d$hf * d$attendance / 10000
  if (adjust) X <- cbind(X, controls(d))
  M <- if (home_term) cbind(X, home = d$hf, attendance = A) else cbind(X, attendance = A)
  lm(d$margin ~ M - 1)
}

team_Z <- function(d, levels_fun) {
  h <- levels_fun(d, "home")
  a <- levels_fun(d, "away")
  lv <- sort(unique(c(h, a)))
  Z <- matrix(0, nrow(d), length(lv))
  Z[cbind(seq_len(nrow(d)), match(h, lv))] <- 1
  Z[cbind(seq_len(nrow(d)), match(a, lv))] <- -1
  Z
}

fit_hier <- function(d, X, slope = TRUE, nstarts = 4L, seed = 20261009L) {
  # Gaussian REML with reproducible multistart BFGS and refinement.
  # Same covariance structure as the original hierarchical model.
  X <- as.matrix(X)
  if (is.null(colnames(X)) || qr(X)$rank < ncol(X)) stop("Invalid or rank-deficient hierarchical design matrix")
  Zt <- team_Z(d, function(d, s) paste(d$conference, d[[s]]))
  Zs <- team_Z(d, function(d, s) paste(d$conference, d[[s]], d$year))
  A <- d$hf * d$attendance / 10000
  Zc <- sapply(conf_order, function(c) A * (d$conference == c))
  K <- list(team = tcrossprod(Zt), team_season = tcrossprod(Zs), slope = tcrossprod(Zc))
  if (!slope) K$slope <- NULL
  y <- as.numeric(d$margin); n <- length(y)
  evaluate <- function(lp, details = FALSE) {
    if (any(!is.finite(lp)) || any(lp < -35) || any(lp > 35)) return(1e20)
    V <- diag(exp(lp[1]), n)
    for (j in seq_along(K)) V <- V + exp(lp[j + 1L]) * K[[j]]
    R <- tryCatch(chol(V), error = function(e) NULL)
    if (is.null(R)) return(1e20)
    Xs <- backsolve(R, X, transpose = TRUE)
    ys <- backsolve(R, y, transpose = TRUE)
    RX <- tryCatch(chol(crossprod(Xs)), error = function(e) NULL)
    if (is.null(RX)) return(1e20)
    beta <- backsolve(RX, forwardsolve(t(RX), crossprod(Xs, ys)))
    r <- ys - Xs %*% beta
    obj <- as.numeric(0.5 * (2 * sum(log(diag(R))) + 2 * sum(log(diag(RX))) + sum(r^2)))
    if (!details) return(obj)
    cov_b <- chol2inv(RX)
    b <- as.numeric(beta); names(b) <- colnames(X)
    se <- sqrt(diag(cov_b)); names(se) <- colnames(X)
    list(objective = obj, coef = b, se = se, cov = cov_b)
  }
  fd_gradient <- function(lp, h = 1e-4) {
    vapply(seq_along(lp), function(j) {
      up <- down <- lp; up[j] <- up[j] + h; down[j] <- down[j] - h
      (evaluate(up) - evaluate(down)) / (2 * h)
    }, numeric(1))
  }
  nstarts <- as.integer(nstarts)
  if (!is.finite(nstarts) || nstarts < 1L) stop("nstarts must be >= 1")
  baseline <- c(log(var(y)), rep(log(10), length(K)))
  if (slope) baseline[length(baseline)] <- log(0.01)
  starts <- matrix(baseline, nrow = 1L)
  if (nstarts >= 2L) {
    alternative <- baseline
    if (length(alternative) >= 3L) alternative[2:3] <- alternative[2:3] + c(log(2), -log(2))
    if (slope) alternative[length(alternative)] <- alternative[length(alternative)] + log(10)
    starts <- rbind(starts, alternative)
  }
  if (nstarts > 2L) {
    # Local seed: do not change the caller's RNG stream (important for simulations).
    had_seed <- exists('.Random.seed', envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) old_seed <- get('.Random.seed', envir = .GlobalEnv)
    set.seed(seed)
    extras <- matrix(rep(baseline, nstarts - 2L), nrow = nstarts - 2L, byrow = TRUE)
    extras <- extras + matrix(rnorm((nstarts - 2L) * length(baseline), sd = 1), ncol = length(baseline))
    if (had_seed) assign('.Random.seed', old_seed, envir = .GlobalEnv) else rm('.Random.seed', envir = .GlobalEnv)
    starts <- rbind(starts, extras)
  }
  attempts <- vector('list', nstarts)
  for (i in seq_len(nstarts)) {
    initial <- tryCatch(optim(starts[i, ], evaluate, method = 'BFGS',
      control = list(maxit = 500, reltol = 1e-9)), error = function(e) NULL)
    if (is.null(initial) || !is.finite(initial$value)) next
    refined <- tryCatch(optim(initial$par, evaluate, method = 'BFGS',
      control = list(maxit = 2000, reltol = 1e-12)), error = function(e) NULL)
    best <- if (!is.null(refined) && is.finite(refined$value) && refined$value <= initial$value) refined else initial
    attempts[[i]] <- list(start_id = i, par = best$par, objective = best$value,
      convergence = best$convergence, gradient = max(abs(fd_gradient(best$par))))
  }
  valid <- which(vapply(attempts, function(x) !is.null(x) && is.finite(x$objective), logical(1)))
  if (!length(valid)) stop('All hierarchical optimizations failed')
  best_idx <- valid[which.min(vapply(attempts[valid], function(x) x$objective, numeric(1)))]
  best <- attempts[[best_idx]]
  val <- evaluate(best$par, details = TRUE)
  diagnostics <- do.call(rbind, lapply(valid, function(i) {
    z <- attempts[[i]]
    data.frame(start_id = z$start_id, objective = z$objective,
      objective_gap = z$objective - best$objective,
      convergence_code = z$convergence, max_abs_gradient = z$gradient,
      residual_sd = sqrt(exp(z$par[1])), team_sd = sqrt(exp(z$par[2])),
      team_season_sd = sqrt(exp(z$par[3])),
      slope_sd = if (slope) sqrt(exp(z$par[length(z$par)])) else NA_real_)
  }))
  list(coef = val$coef, se = val$se, cov = val$cov,
       var = setNames(exp(best$par), c('residual', names(K))),
       converged = best$convergence == 0, loglik = -val$objective,
       best_start_id = best_idx, gradient = best$gradient,
       diagnostics = diagnostics)
}

coef_row <- function(m, term, vc = vcov(m)) {
  nm <- paste0("M", term)
  est <- coef(m)[[nm]]
  se <- sqrt(vc[nm, nm])
  df <- m$df.residual
  t <- est / se
  data.frame(
    estimate = est, se = se, t = t, df = df,
    p = 2 * pt(-abs(t), df),
    lower = est - qt(0.975, df) * se,
    upper = est + qt(0.975, df) * se
  )
}

meta_row <- function(r) {
  data.frame(
    estimate = as.numeric(r$b), se = r$se, z = r$zval, p = r$pval,
    lower = r$ci.lb, upper = r$ci.ub,
    tau2 = r$tau2, I2 = r$I2, Q = r$QE, Q_df = r$k - r$p, Q_p = r$QEp
  )
}

best_record_team <- function(d) {
  long <- rbind(
    data.frame(team = d$home, year = d$year, win = d$margin > 0),
    data.frame(team = d$away, year = d$year, win = d$margin < 0)
  )
  seasons <- tapply(long$year, long$team, function(x) length(unique(x)))
  long <- long[long$team %in% names(seasons)[seasons == 3], ]
  pct <- tapply(long$win, long$team, mean)
  names(which.max(pct))
}
