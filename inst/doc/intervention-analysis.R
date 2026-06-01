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

## ----rdd-data-----------------------------------------------------------------
# set.seed(123)
# n <- 200
# x <- runif(n, -5, 5)
# # True effect: slope increases by 2 after x=0
# y <- 5 + 1 * x + 2 * (x - 0) * (x > 0) + rnorm(n, 0, 1)
# 
# dat_rdd <- data.frame(x = x, y = y)
# 
# ggplot(dat_rdd, aes(x, y)) +
#   geom_point(alpha = 0.6) +
#   geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
#   theme_minimal() +
#   labs(title = "Simulated RDD Data", subtitle = "Red line marks the known threshold at x = 0")

## ----rdd-fit------------------------------------------------------------------
# fit_rdd <- smoothbp_ss(
#   formula = y ~ x,
#   omega   = list(fixed(0)),
#   rho     = list(fixed(100)), # Sharp transition
#   data    = dat_rdd,
#   iter    = 2000,
#   warmup  = 1000
# )
# 
# # Posterior Inclusion Probability (PIP)
# pip(fit_rdd)

## ----sw-data------------------------------------------------------------------
# n_clusters <- 5
# n_time     <- 24
# dat_sw <- expand.grid(
#   time    = 1:n_time,
#   cluster = paste0("Cluster_", 1:n_clusters)
# )
# 
# # Pre-determined intervention times
# switch_times <- setNames(c(6, 10, 14, 18, 22), paste0("Cluster_", 1:n_clusters))
# dat_sw$interv_t <- switch_times[dat_sw$cluster]
# 
# # Simulate data: intervention adds +1.5 to the slope
# dat_sw$y <- unlist(lapply(1:nrow(dat_sw), function(i) {
#   t      <- dat_sw$time[i]
#   switch <- dat_sw$interv_t[i]
#   # Base slope = 0.5, Intervention effect = +1.5
#   5 + 0.5 * t + 1.5 * (t - switch) * (t > switch) + rnorm(1, 0, 1)
# }))
# 
# ggplot(dat_sw, aes(x = time, y = y, color = cluster)) +
#   geom_line() +
#   geom_point(aes(shape = time >= interv_t), size = 2) +
#   theme_minimal() +
#   labs(title = "Simulated Stepped-Wedge Trial", shape = "Intervention Active")

## ----sw-fit-------------------------------------------------------------------
# fit_sw <- smoothbp_ss(
#   formula = y ~ time,
#   b0      = ~ cluster, # Cluster-specific intercepts
#   omega   = list(fixed(dat_sw$interv_t)),
#   rho     = list(fixed(100)),
#   data    = dat_sw
# )
# 
# # Probability of intervention effect
# pip(fit_sw)

