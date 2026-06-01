## ----setup, include=FALSE-----------------------------------------------------
NOT_CRAN <- identical(tolower(Sys.getenv("NOT_CRAN")), "true")
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", eval = NOT_CRAN)

## ----simulate-----------------------------------------------------------------
# library(smoothbp)
# 
# dat <- simulate_smoothbp(
#   n_subj    = 20,
#   n_obs     = 8,
#   b0        = 5.0,   # level at change-point
#   b1        = -0.3,  # pre-change slope
#   b2        =  1.2,  # slope change (delta_1)
#   omega     =  3.0,  # change-point location
#   rho       =  4.0,  # transition sharpness
#   sigma     =  0.4,  # residual SD
#   sigma_u   =  0.5,  # between-subject SD
#   tau_range = c(0, 6),
#   seed      = 42
# )
# 
# head(dat)
# true_params(dat)

## ----fit-zero-bp--------------------------------------------------------------
# fit0 <- smoothbp(
#   formula = y ~ tau,
#   b0      = ~ 1 + (1 | subject),
#   b1      = ~ 1,
#   deltas  = list(),   # no change-points
#   omega   = list(),
#   rho     = list(),
#   data    = dat,
#   chains  = 2L, iter = 1000L, warmup = 500L, seed = 42L, .verbose = FALSE
# )
# summary(fit0)

## ----fit-one-bp---------------------------------------------------------------
# fit1 <- smoothbp(
#   formula = y ~ tau,
#   b0      = ~ 1 + (1 | subject),
#   b1      = ~ 1,
#   deltas  = list(~ 1),          # one slope change
#   omega   = list(~ 1),          # one change-point location
#   rho     = list(~ 1),          # one sharpness
#   data    = dat,
#   priors  = smoothbp_priors(
#     omega = list(prior_normal(3, 2, lb = 0))
#   ),
#   chains  = 4L, iter = 2000L, warmup = 1000L, seed = 42L
# )
# summary(fit1)

## ----fit-multi-bp-------------------------------------------------------------
# # Fit a model with 3 candidate breakpoints
# fit3 <- smoothbp(
#   formula = y ~ tau,
#   b0      = ~ 1 + (1 | subject),
#   b1      = ~ 1,
#   # Each segment gets its own formula (here, just an intercept)
#   deltas  = list(~ 1, ~ 1, ~ 1),
#   omega   = list(~ 1, ~ 1, ~ 1),
#   rho     = list(~ 1, ~ 1, ~ 1),
#   data    = dat,
#   priors  = smoothbp_priors(
#     # Use the space_omega_priors helper to initialize the search
#     omega = space_omega_priors(K = 3, tau_min = 0, tau_max = 6)
#   )
# )

## ----fit-fixed----------------------------------------------------------------
# # Test for a hard kink at exactly tau = 3.0
# fit_fixed <- smoothbp_ss(
#   formula = y ~ tau,
#   omega   = list(fixed(3.0)),   # Location is known
#   rho     = list(fixed(100)),   # Sharpness is fixed (hard kink)
#   data    = dat
# )
# 
# # The PIP tells us the probability that the intervention had an effect
# pip(fit_fixed)

## ----fit-parallel-------------------------------------------------------------
# fit1 <- smoothbp(
#   formula = y ~ tau,
#   b0      = ~ 1 + (1 | subject),
#   data    = dat,
#   chains  = 4L, iter = 2000L, warmup = 1000L, seed = 42L,
#   cores   = 4L    # run all 4 chains concurrently
# )

## ----rprofile, eval=FALSE-----------------------------------------------------
# options(smoothbp.cores = parallel::detectCores())

## ----summary------------------------------------------------------------------
# print(fit1)                                        # fixed + ran_pars (default)
# print(fit1, effects = "fixed")                     # population-level only
# summary(fit1, effects = "all")                     # returns everything, including u[j]

## ----trace--------------------------------------------------------------------
# plot(fit1)        # alias for trace_plot(fit1)
# trace_plot(fit1, type = "both")   # trace + density

## ----trace-strict-------------------------------------------------------------
# trace_plot(fit1, rhat_thresh = 1.01, ess_thresh = 400)

## ----pp-check-----------------------------------------------------------------
# pp_check(fit1)

## ----priors-------------------------------------------------------------------
# smoothbp_priors(
#   b0    = prior_normal(0, 10),
#   b1    = prior_normal(0, 5),
#   omega = list(
#     prior_normal(2, 1),   # change-point 1
#     prior_normal(5, 1)    # change-point 2
#   ),
#   rho   = list(
#     prior_normal(4, 2, lb = 0),
#     prior_normal(4, 2, lb = 0)
#   ),
#   sigma = prior_invgamma(shape = 2, scale = 1)
# )

## ----ss-overview--------------------------------------------------------------
# fit_ss <- smoothbp_ss(
#   formula = y ~ tau,
#   b0      = ~ 1 + (1 | subject),
#   b1      = ~ 1,
#   deltas  = list(~ 1, ~ 1, ~ 1),   # 3 candidate breakpoints
#   omega   = list(~ 1, ~ 1, ~ 1),
#   rho     = list(~ 1, ~ 1, ~ 1),
#   data    = dat,
#   spike   = prior_spike_slab(pi = 0.1, learn_pi = TRUE),
#   chains  = 4L, iter = 2000L, warmup = 1000L, seed = 42L
# )
# 
# # Posterior inclusion probabilities per breakpoint
# pip(fit_ss)
# #> gamma_delta1_(Intercept) gamma_delta2_(Intercept) gamma_delta3_(Intercept)
# #>                    0.987                    0.063                    0.041

## ----hypothesis-directional---------------------------------------------------
# # Is the slope change at breakpoint 1 positive?
# smoothbp::hypothesis(fit1, "delta1_(Intercept) > 0")
# 
# # Complex linear hypothesis: is the final slope (b1 + delta1) negative?
# smoothbp::hypothesis(fit1, "b1_(Intercept) + delta1_(Intercept) < 0")
# 
# # Does the change-point fall before time 4?
# smoothbp::hypothesis(fit1, "omega1_(Intercept) < 4")

## ----loo----------------------------------------------------------------------
# # Compare 0-BP (linear) vs 1-BP vs 3-BP models
# loo0 <- loo(fit0)
# loo1 <- loo(fit1)
# loo3 <- loo(fit3)
# 
# loo::loo_compare(loo0, loo1, loo3)

## ----bridge-sampler-----------------------------------------------------------
# library(bridgesampling)
# bs0 <- bridge_sampler(fit0)
# bs1 <- bridge_sampler(fit1)
# bayes_factor(bs1, bs0)

## ----fitted-training----------------------------------------------------------
# # Posterior mean + 95% CI at training observations
# fitted(fit1)
# 
# # Full posterior draws matrix (n_draws × n_obs)
# draws_mat <- fitted(fit1, summary = FALSE)

## ----draws-manip--------------------------------------------------------------
# library(posterior)
# 
# # Convert to a data frame for use with ggplot2
# draws_df <- as_draws_df(fit1$draws)
# 
# # Extract a specific parameter
# b1_draws <- draws_df$`b1_(Intercept)`
# 
# # Compute custom summaries
# summarise_draws(fit1$draws, "mean", "sd", ~quantile(.x, c(0.1, 0.9)))

## ----fitted-marginal----------------------------------------------------------
# # Population-level predictions at new time points
# newdata_marginal <- data.frame(tau = seq(0, 6, by = 0.1))
# fitted(fit1, newdata = newdata_marginal)

## ----fitted-conditional-------------------------------------------------------
# # Subject-specific predictions
# fitted(fit1, newdata = data.frame(tau = seq(0, 6, by = 0.1), subject = "1"))

