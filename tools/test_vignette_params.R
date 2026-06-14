suppressPackageStartupMessages({ library(posterior) })
devtools::load_all(quiet = TRUE)

set.seed(42)
J <- 15L; n_j <- 6L; N <- J * n_j
omega_bar_true <- 3.0; sigma_re_true <- 0.10
delta_true <- 1.8; rho_true <- 2.5; sigma_y_true <- 0.4

u_omega_true <- rnorm(J, 0, sigma_re_true)
subject_id   <- rep(seq_len(J), each = n_j)
tau_vals     <- rep(seq(0.5, 5.5, length.out = n_j), times = J)
omega_i <- omega_bar_true + u_omega_true[subject_id]
d_i     <- tau_vals - omega_i
y_i     <- delta_true * d_i * plogis(rho_true * d_i) + rnorm(N, 0, sigma_y_true)
dat <- data.frame(subject = factor(subject_id), tau = tau_vals, y = y_i)

priors_used <- smoothbp_priors(omega = prior_normal(3, 1.5, lb = 0),
                               sigma_re_om = prior_invgamma(2, 1))

cat("--- Centred ---\n")
fit_cent <- smoothbp(y ~ tau, b0 = ~ 1 + (1 | subject),
  omega = list(~ 1 + (1 | subject)), deltas = list(~ 1), data = dat,
  priors = priors_used, chains = 4L, iter = 2000L, warmup = 1000L,
  reparameterise = "none", seed = 42L, .verbose = FALSE)
s <- summarise_draws(subset_draws(fit_cent$draws,
  variable = c("omega1_(Intercept)", "sigma_re_omega1")), rhat, ess_bulk)
cat(sprintf("divergences: %d\n", fit_cent$n_divergent))
print(s[, c("variable", "rhat", "ess_bulk")], row.names = FALSE)

cat("\n--- Full NC ---\n")
fit_nc <- smoothbp(y ~ tau, b0 = ~ 1 + (1 | subject),
  omega = list(~ 1 + (1 | subject)), deltas = list(~ 1), data = dat,
  priors = priors_used, chains = 4L, iter = 2000L, warmup = 1000L,
  reparameterise = "omega", seed = 42L, .verbose = FALSE)
s2 <- summarise_draws(subset_draws(fit_nc$draws,
  variable = c("omega1_(Intercept)", "sigma_re_omega1")), rhat, ess_bulk)
cat(sprintf("divergences: %d\n", fit_nc$n_divergent))
print(s2[, c("variable", "rhat", "ess_bulk")], row.names = FALSE)
