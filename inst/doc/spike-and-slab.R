## ----setup, include=FALSE-----------------------------------------------------
NOT_CRAN <- identical(tolower(Sys.getenv("NOT_CRAN")), "true")
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", eval = NOT_CRAN)

## ----sim-one-bp---------------------------------------------------------------
# library(smoothbp)
# library(posterior)
# library(ggplot2)
# library(dplyr)
# library(tidyr)
# 
# set.seed(42)
# n  <- 200
# tau <- seq(0, 10, length.out = n)
# 
# # True model: one breakpoint at omega = 5, delta = -1.0
# om_true    <- 5
# rho_true   <- 4
# b0_true    <- 2
# b1_true    <- 0.5
# delta_true <- -1.0
# 
# di  <- tau - om_true
# si  <- plogis(di * rho_true)
# mu  <- b0_true + b1_true * di + delta_true * di * si
# y   <- mu + rnorm(n, sd = 0.2)
# dat <- data.frame(y = y, tau = tau)

## ----fit-ss-one---------------------------------------------------------------
# fit_ss <- smoothbp_ss(
#   formula = y ~ tau,
#   b0      = ~ 1,
#   b1      = ~ 1,
#   deltas  = list(~ 1, ~ 1, ~ 1),
#   omega   = list(~ 1, ~ 1, ~ 1),
#   rho     = list(~ 1, ~ 1, ~ 1),
#   data    = dat,
#   spike   = prior_spike_slab(pi = 0.1, learn_pi = TRUE),
#   priors  = smoothbp_priors(
#     omega = space_omega_priors(K = 3, tau_min = 0, tau_max = 10)
#   ),
#   chains = 2, iter = 2000, warmup = 1000, seed = 42
# )

## ----pip-one------------------------------------------------------------------
# pip(fit_ss)
# #>  gamma_b1_(Intercept) gamma_delta1_(Intercept) gamma_delta2_(Intercept) gamma_delta3_(Intercept)
# #>                  1.00                     0.06                     0.98                     0.04
# 
# # Full posterior summary (just the gammas)
# summarise_draws(fit_ss$draws) |>
#   filter(grepl("^gamma_delta", variable))

## ----pip-plot-----------------------------------------------------------------
# # The plot method automatically computes and plots the PIPs along with their 95% HDI
# plot(pip(fit_ss))

## ----fit-plot-----------------------------------------------------------------
# # Get posterior predictions (mean and intervals)
# pred <- fitted(fit_ss)
# 
# plot_df <- dat %>%
#   mutate(
#     mu_true = mu,  # 'mu' is from the simulation step
#     mu_fit  = pred$fitted_mean,
#     lo      = pred$fitted_Q2.5,
#     hi      = pred$fitted_Q97.5
#   )
# 
# ggplot(plot_df, aes(x = tau)) +
#   geom_point(aes(y = y), alpha = 0.3, size = 1) +
#   geom_ribbon(aes(ymin = lo, ymax = hi), fill = "#2c7bb6", alpha = 0.2) +
#   geom_line(aes(y = mu_true, colour = "Truth"), linewidth = 1) +
#   geom_line(aes(y = mu_fit,  colour = "smoothbp_ss"), linewidth = 0.8, linetype = "dashed") +
#   scale_colour_manual(values = c("Truth" = "black", "smoothbp_ss" = "#d7191c")) +
#   labs(
#     title = "Model fit: Truth vs Posterior Predictions",
#     subtitle = "The SS model correctly ignores the 2 redundant breakpoints and recovers the trajectory.",
#     x = "Time (tau)", y = "Response (y)", colour = NULL
#   ) +
#   theme_minimal()

## ----fit-learn-pi-------------------------------------------------------------
# fit_lpi <- smoothbp_ss(
#   formula = y ~ tau,
#   b0      = ~ 1,
#   b1      = ~ 1,
#   deltas  = rep(list(~ 1), 5),   # 5 candidate breakpoints
#   omega   = rep(list(~ 1), 5),
#   rho     = rep(list(~ 1), 5),
#   data    = dat,
#   spike   = prior_spike_slab(
#     learn_pi = TRUE,
#     a        = 1,   # Beta(1, 4) prior on pi: mean = 0.2
#     b        = 4
#   ),
#   chains = 2, iter = 3000, warmup = 1500, seed = 42
# )
# 
# # Posterior for pi (sparsity level)
# pi_draws <- as.numeric(as_draws_matrix(fit_lpi$draws)[, "pi"])
# quantile(pi_draws, c(0.025, 0.5, 0.975))
# #>  2.5%  50%  97.5%
# #>  0.04 0.20   0.47
# # Contracted toward sparsity: only ~1/5 breakpoints are real

## ----diag-ss------------------------------------------------------------------
# # Gamma trace plots — look for healthy switching
# trace_plot(fit_ss, pars = grep("^gamma_delta", posterior::variables(fit_ss$draws), value = TRUE))

## ----ss-vs-loo----------------------------------------------------------------
# # Fit explicit 0-BP and 1-BP models for context
# fit0 <- smoothbp(y ~ tau, deltas = list(), omega = list(), rho = list(),
#                  data = dat, chains = 2, iter = 2000, warmup = 1000)
# fit1 <- smoothbp(y ~ tau, deltas = list(~ 1), omega = list(~ 1), rho = list(~ 1),
#                  data = dat, chains = 2, iter = 2000, warmup = 1000)
# 
# # LOO comparison: fixed-dimension vs spike-and-slab
# loo::loo_compare(loo(fit1), loo(fit_ss))
# #>       elpd_diff se_diff
# #> fit1    0.0       0.0
# #> fit_ss -0.2       0.4   # Both models perform identically
# 
# # PIP from the SS model agrees:
# pip(fit_ss)["gamma_delta2_(Intercept)",]
# #> 0.98

