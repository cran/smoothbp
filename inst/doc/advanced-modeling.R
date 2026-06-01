## ----setup, include=FALSE-----------------------------------------------------
NOT_CRAN <- identical(tolower(Sys.getenv("NOT_CRAN")), "true")
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = NOT_CRAN,
  fig.width = 8,
  fig.height = 6
)

## ----libs, message=FALSE, warning=FALSE---------------------------------------
# library(smoothbp)
# library(ggplot2)
# library(dplyr)
# library(posterior)
# library(tidyr)

## ----real-data----------------------------------------------------------------
# dat_market <- data.frame(
#   month  = rep(1:15, 3),
#   ticker = rep(c("NVDA", "MSFT", "AAPL"), each = 15),
#   price  = c(
#     13.50, 16.50, 14.60, 19.52, 23.19, 27.75, 27.72, 37.80, 42.27, 46.69, 49.32, 43.47, 40.75, 46.74, 49.49,
#     232, 255, 240, 241.47, 243.65, 281.63, 300.15, 321.49, 333.39, 328.87, 321.56, 309.77, 331.71, 372.49, 369.67,
#     153, 148, 130, 142.01, 145.30, 162.55, 167.26, 174.96, 191.46, 193.91, 185.69, 169.23, 168.79, 188.00, 190.55
#   )
# )
# dat_market$ticker <- factor(dat_market$ticker, levels = c("AAPL", "MSFT", "NVDA"))

## ----fit-market---------------------------------------------------------------
# fit_market <- smoothbp(
#   formula = price ~ month, b0 = ~ ticker,
#   deltas = list(~ ticker, ~ ticker, ~ ticker, ~ ticker, ~ ticker),
#   omega  = list(~ ticker, ~ ticker, ~ ticker, ~ ticker, ~ ticker),
#   rho    = list(~ 1, ~ 1, ~ 1, ~ 1, ~ 1),
#   data   = dat_market,
#     priors = smoothbp_priors(
#       b0 = prior_normal(200, 500), b1 = prior_normal(0, 50), deltas = prior_normal(0, 80),
#       # Constrain omegas: intercepts centered on windows, narrow priors for ticker offsets
#       omega = lapply(list(3, 6, 9, 12, 14), function(m) {
#         list("(Intercept)" = prior_normal(m, 1, lb = 1, ub = 15),
#              "tickerMSFT"  = prior_normal(0, 1),
#              "tickerNVDA"  = prior_normal(0, 1))
#       }),
#       rho = prior_normal(20, 5, lb = 5)
#     ),
#   chains = 4, iter = 4000, warmup = 2000
# )

## ----event-omegas-------------------------------------------------------------
# n_bp    <- 5
# draws   <- as_draws_matrix(fit_market$draws)
# tickers <- levels(dat_market$ticker)
# 
# # Helper to safely extract a named draw column (handles special chars via grep)
# val <- function(d, pat) {
#   v <- d[grep(paste0("^", pat, "$"), names(d))]
#   if (length(v) == 0) return(0)
#   unname(v[1])
# }
# 
# # Extract omega_k for each ticker from a single draw row
# get_omegas <- function(d, tk) {
#   sapply(1:n_bp, function(k) {
#     base <- val(d, paste0("omega", k, "_\\(Intercept\\)"))
#     off  <- if (tk == tickers[1]) 0 else val(d, paste0("omega", k, "_ticker", tk))
#     base + off
#   })
# }
# 
# # Extract all ticker-specific parameters for a single draw row
# get_params <- function(d, tk) {
#   b1 <- val(d, "b1_\\(Intercept\\)")
#   if (tk != tickers[1]) b1 <- b1 + val(d, paste0("b1_ticker", tk))
# 
#   deltas <- omegas <- rhos <- numeric(n_bp)
#   for (k in 1:n_bp) {
#     deltas[k] <- val(d, paste0("delta", k, "_\\(Intercept\\)"))
#     omegas[k] <- val(d, paste0("omega", k, "_\\(Intercept\\)"))
#     rhos[k]   <- val(d, paste0("rho", k, "_\\(Intercept\\)"))
# 
#     if (tk != tickers[1]) {
#       deltas[k] <- deltas[k] + val(d, paste0("delta", k, "_ticker", tk))
#       omegas[k] <- omegas[k] + val(d, paste0("omega", k, "_ticker", tk))
#       rhos[k]   <- rhos[k]   + val(d, paste0("rho", k, "_ticker", tk))
#     }
#   }
#   list(b1 = b1, deltas = deltas, omegas = omegas, rhos = rhos)
# }
# 
# # Posterior summary of omega_k per ticker
# omega_summary <- do.call(rbind, lapply(tickers, function(tk) {
#   om_mat <- t(apply(draws, 1, get_omegas, tk = tk))
#   do.call(rbind, lapply(1:n_bp, function(k) {
#     data.frame(
#       ticker = tk, bp = k,
#       mean  = mean(om_mat[, k]),
#       Q2.5  = quantile(om_mat[, k], 0.025),
#       Q97.5 = quantile(om_mat[, k], 0.975)
#     )
#   }))
# })) |> mutate(ticker = factor(ticker, levels = levels(dat_market$ticker)))
# print(omega_summary)

## ----plot-events--------------------------------------------------------------
# pred_orig        <- fitted(fit_market)
# dat_market$y_fit <- pred_orig$fitted_mean
# dat_market$lo    <- pred_orig$fitted_Q2.5
# dat_market$hi    <- pred_orig$fitted_Q97.5
# 
# # Compute y-position on the mean curve at each omega
# omega_plot <- omega_summary |>
#   rowwise() |>
#   mutate(y_val = approx(
#     dat_market$month[dat_market$ticker == ticker],
#     dat_market$y_fit[dat_market$ticker  == ticker],
#     xout = mean)$y) |>
#   ungroup()
# 
# month_labels <- c("Oct22","Nov","Dec","Jan23","Feb","Mar","Apr","May",
#                   "Jun","Jul","Aug","Sep","Oct","Nov","Dec")
# 
# ggplot(dat_market, aes(x = month, y = price, color = ticker)) +
#   geom_point(alpha = 0.5) +
#   geom_ribbon(aes(ymin = lo, ymax = hi, fill = ticker), alpha = 0.1, color = NA) +
#   geom_line(aes(y = y_fit), size = 1) +
#   geom_point(
#     data = omega_plot, aes(x = mean, y = y_val),
#     color = "red", shape = 4, size = 4, stroke = 1.5, inherit.aes = FALSE
#   ) +
#   geom_errorbarh(
#     data = omega_plot, aes(xmin = Q2.5, xmax = Q97.5, y = y_val),
#     color = "red", height = 0, alpha = 0.4, inherit.aes = FALSE
#   ) +
#   scale_x_continuous(breaks = 1:15, labels = month_labels) +
#   facet_wrap(~ticker, scales = "free_y") +
#   theme_minimal() + theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
#   labs(
#     title    = "Structural Events: Point of Maximum Curvature (omega_k)",
#     subtitle = "Red X = posterior mean omega_k; bars = 95% CI."
#   )

## ----leadership-analysis------------------------------------------------------
# # Extract omegas for all draws for the targeted indices
# om_nvda <- t(apply(draws, 1, get_omegas, tk = "NVDA"))
# om_msft <- t(apply(draws, 1, get_omegas, tk = "MSFT"))
# om_aapl <- t(apply(draws, 1, get_omegas, tk = "AAPL"))
# 
# # 1. Early Pivot (BP 1)
# p1_nvda_msft <- mean(om_nvda[, 1] < om_msft[, 1])
# p1_nvda_aapl <- mean(om_nvda[, 1] < om_aapl[, 1])
# 
# # 2. Autumn Shift (BP 4)
# p4_nvda_msft <- mean(om_nvda[, 4] < om_msft[, 4])
# p4_msft_aapl <- mean(om_msft[, 4] < om_aapl[, 4])
# 
# # 3. Cross-Event: NVDA Surge (BP 2) vs AAPL Recovery (BP 1)
# p_cross <- mean(om_nvda[, 2] < om_aapl[, 1])
# 
# cat("--- Event 1: Early Pivot (BP 1) ---\n")
# message(sprintf("Prob NVDA led MSFT: %.2f", p1_nvda_msft))
# message(sprintf("Prob NVDA led AAPL: %.2f", p1_nvda_aapl))
# 
# cat("\n--- Event 2: Autumn Shift (BP 4) ---\n")
# message(sprintf("Prob NVDA led MSFT: %.2f", p4_nvda_msft))
# message(sprintf("Prob MSFT led AAPL: %.2f", p4_msft_aapl))
# 
# cat("\n--- Cross-Event Dynamics ---\n")
# message(sprintf("Prob NVDA AI Surge (BP 2) led AAPL Recovery (BP 1): %.2f", p_cross))

## ----sim-hier-----------------------------------------------------------------
# set.seed(42)
# n_tickers <- 10
# n_months  <- 25
# dat_sim   <- expand.grid(
#   month  = 1:n_months,
#   ticker = paste0("T", formatC(1:n_tickers, width = 2, flag = "0"))
# )
# 
# # True shared market events: rally at month 7, correction at month 18
# om_true <- c(7, 18)
# 
# # Ticker-specific timing offsets (mean 0, SD 0.8 months)
# timing_offsets <- matrix(rnorm(n_tickers * 2, 0, 0.8), n_tickers, 2)
# 
# # Rally magnitude varies by ticker (all positive = same direction)
# rally_mag      <- runif(n_tickers, 1.5, 3.5)
# # Correction magnitude (all negative = same direction)
# correction_mag <- runif(n_tickers, 1.0, 2.5)
# 
# # Simulate using smooth logistic transitions (matches the model)
# # Event 2 REVERSES the rally: delta_2 cancels delta_1 and adds a negative slope
# # so prices genuinely fall after month 18, creating a clear inverted-U shape.
# rho_true <- 3
# dat_sim$price <- unlist(lapply(1:n_tickers, function(i) {
#   t     <- 1:n_months
#   om1_k <- om_true[1] + timing_offsets[i, 1]
#   om2_k <- om_true[2] + timing_offsets[i, 2]
#   y <- 10 +
#     rally_mag[i]                       * (t - om1_k) * plogis(rho_true * (t - om1_k)) -
#     (rally_mag[i] + correction_mag[i]) * (t - om2_k) * plogis(rho_true * (t - om2_k)) +
#     rnorm(n_months, 0, 0.5)
#   y
# }))
# 
# ggplot(dat_sim, aes(x = month, y = price, color = ticker)) +
#   geom_line(linewidth = 0.7) +
#   geom_vline(xintercept = om_true, linetype = "dashed", alpha = 0.4) +
#   theme_minimal() +
#   theme(legend.position = "none") +
#   labs(
#     title    = "Simulated Market Data: 10 Tickers, 2 Shared Events",
#     subtitle = "Dashed lines = true event times (month 7 and 18). Individual timing varies slightly."
#   )

## ----fit-sim-hier-------------------------------------------------------------
# my_spike <- prior_spike_slab(
#   pi = 2/8
# )
# 
# t_min <- min(dat_sim$month)
# t_max <- max(dat_sim$month)
# 
# # Use the space_omega_priors helper to initialize 8 candidate breakpoints.
# # The function automatically names the priors `(Intercept)` so they apply correctly
# # to the global mean, while random effects are handled automatically by the model.
# omega_priors_hier <- space_omega_priors(
#   K       = 8,
#   tau_min = t_min,
#   tau_max = t_max
# )
# 
# 
# fit_hier <- smoothbp_ss(
#   formula = price ~ month,
#   b0      = ~ (1 | ticker),
#   # (1 | ticker): intercept = market mean, ticker columns = random deviations
#   deltas  = replicate(8, ~ ticker, simplify = FALSE),
#   omega   = replicate(8, ~ (1 | ticker), simplify = FALSE),
#   rho     = replicate(8, ~ 1,            simplify = FALSE),
#   data    = dat_sim,
#   spike   = my_spike,
#   priors  = smoothbp_priors(
#     sigma_re_om = prior_invgamma(2, 1),
#     omega       = omega_priors_hier),
#   chains  = 2L, iter = 4000, warmup = 2000, cores = 4L
# )

## ----pip-sim-hier-------------------------------------------------------------
# draws_hier  <- as_draws_df(fit_hier$draws)
# 
# # PIP = P(market-level delta is non-zero) = mean of the (Intercept) gamma.
# # Using 'any ticker active' would inflate PIPs due to 10-ticker multiplicity.
# pip_summary <- data.frame(
#   bp  = 1:8,
#   pip = sapply(1:8, function(k) {
#     col <- paste0("gamma_delta", k, "_(Intercept)")
#     if (!col %in% names(draws_hier)) return(0)
#     mean(draws_hier[[col]])
#   })
# )
# 
# ggplot(pip_summary, aes(x = factor(bp), y = pip)) +
#   geom_col(aes(fill = pip > 0.5), show.legend = FALSE) +
#   geom_hline(yintercept = 0.5, linetype = "dashed") +
#   scale_fill_manual(values = c("FALSE" = "grey70", "TRUE" = "#2166ac")) +
#   scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
#   theme_minimal() +
#   labs(
#     x        = "Candidate breakpoint",
#     y        = "PIP",
#     title    = "Posterior Inclusion Probabilities (market-level intercept gamma)",
#     subtitle = "Blue = selected (PIP > 0.5). Prior: Beta(1,9) ≈ 10% expected inclusion."
#   )

## ----plot-sim-hier------------------------------------------------------------
# pred_hier        <- fitted(fit_hier)
# dat_sim$y_fit    <- pred_hier$fitted_mean
# dat_sim$lo       <- pred_hier$fitted_Q2.5
# dat_sim$hi       <- pred_hier$fitted_Q97.5
# 
# active_bps  <- pip_summary$bp[pip_summary$pip > 0.5]
# tickers_sim <- levels(factor(dat_sim$ticker))
# ref_ticker  <- tickers_sim[1]   # reference level in design matrix
# 
# if (length(active_bps) > 0) {
#   # With (1 | ticker), the design matrix has:
#   #   column "(Intercept)"  = market mean (fixed)
#   #   columns "tickerT01", "tickerT02", ... = per-ticker RE deviations
#   # Ticker-specific omega = market mean + that ticker's RE column
#   tickers_sim <- levels(factor(dat_sim$ticker))
# 
#   omega_summary_sim <- do.call(rbind, lapply(tickers_sim, function(tk) {
#     om_vals <- as.matrix(sapply(active_bps, function(k) {
#       mu  <- draws_hier[[paste0("omega", k, "_(Intercept)")]]
#       u_k <- draws_hier[[paste0("omega", k, "_ticker", tk)]]
#       if (is.null(u_k)) mu else mu + u_k
#     }))
#     do.call(rbind, lapply(seq_along(active_bps), function(j) {
#       data.frame(
#         ticker = tk, bp = active_bps[j],
#         mean  = mean(om_vals[, j]),
#         Q2.5  = quantile(om_vals[, j], 0.025),
#         Q97.5 = quantile(om_vals[, j], 0.975)
#       )
#     }))
#   }))
# 
#   omega_plot_sim <- omega_summary_sim |>
#     rowwise() |>
#     mutate(y_val = approx(
#       dat_sim$month[dat_sim$ticker == ticker],
#       dat_sim$y_fit[dat_sim$ticker == ticker],
#       xout = mean)$y) |>
#     ungroup()
# } else {
#   omega_plot_sim <- data.frame()
# }
# 
# ggplot(dat_sim, aes(x = month, color = ticker, fill = ticker)) +
#   geom_point(aes(y = price), alpha = 0.25, size = 0.8) +
#   geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.1, color = NA) +
#   geom_line(aes(y = y_fit), linewidth = 0.8) +
#   {if (nrow(omega_plot_sim) > 0)
#     geom_point(
#       data = omega_plot_sim, aes(x = mean, y = y_val),
#       color = "black", shape = 18, size = 3.5, inherit.aes = FALSE
#     )
#   } +
#   {if (nrow(omega_plot_sim) > 0)
#     geom_errorbarh(
#       data = omega_plot_sim,
#       aes(xmin = Q2.5, xmax = Q97.5, y = y_val),
#       height = 0, color = "black", alpha = 0.4, inherit.aes = FALSE
#     )
#   } +
#   facet_wrap(~ ticker, ncol = 5) +
#   theme_minimal() +
#   theme(legend.position = "none") +
#   labs(
#     x        = "Month",
#     y        = "Price",
#     title    = "Hierarchical Event Discovery: Fitted Curves",
#     subtitle = "Black diamonds = discovered market events (PIP > 0.5); bars = 95% CI."
#   )

