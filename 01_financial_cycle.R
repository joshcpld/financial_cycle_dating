################################################################################
################################################################################
# 01_financial_cycle.R
#
# Estimates the medium-term financial cycle for each country using:
#   (a) Christiano-Fitzgerald band-pass at 32-120 quarter periodicity, applied
#       to annual log differences of real credit, credit-to-GDP and real
#       property prices, then cumulated and averaged.
#   (b) Bry-Boschan/Harding-Pagan turning-point dating per series, plus the
#       Harding-Pagan (2006) multivariate common-cycle algorithm with the
#       cluster-width rule from DBT Annex.
#
# Two helper functions are used:
#   bb_dater()              dates one series. Used 3 times per country.
#   multivariate_hp_dater() combines per-series turning points into a common
#                           cycle. Custom because no R package implements DBT's
#                           specific cluster-width rule.
#
# Produces in env: fc (list with $filtered and $common_tps)
################################################################################
################################################################################

library(tidyverse)
library(lubridate)
library(mFilter)
library(here)

if (!exists("panel_final")) source(here("00_data_cleaning.R"))
panel <- panel_final

# DBT pass-band for the medium-term financial cycle, in quarters.
mt_pl <- 32
mt_pu <- 120


###############################################################################
###############################################################################
# Helper: Bry-Boschan / Harding-Pagan dating for one series
###############################################################################
###############################################################################

# Identifies turning points in a single series using the Harding-Pagan
# implementation of the Bry-Boschan algorithm. Defaults match the medium-term
# parameters in DBT (2012, Annex):
#   window     9 quarters (peak if value >= value at +/- 1..4 quarters)
#   min_cycle  40 quarters (10 years)
#   min_phase  2 quarters
#
# Comparison is non-strict so flat extrema (common on integer-valued
# distance series) are detected. Consecutive ties collapse to one position.

bb_dater <- function(x, idx, window = 9, min_cycle = 40, min_phase = 2) {

  half <- (window - 1) / 2
  n <- length(x)


  # Step 1: candidate local extrema #########################################
  # Non-strict comparison so flat local extrema are not silently dropped.
  # Critical for the integer-valued median-distance series used inside the
  # multivariate dater, where the joint peak often lands on a 2-3 quarter
  # plateau of median_peak = 1. Strict ">" misses every such plateau.
  nbhd_at <- function(t) {
    lo <- max(1, t - half)
    hi <- min(n, t + half)
    x[lo:hi][-(t - lo + 1)]
  }
  is_peak   <- map_lgl(seq_len(n),
                       ~ !is.na(x[.x]) && all(x[.x] >= nbhd_at(.x), na.rm = TRUE))
  is_trough <- map_lgl(seq_len(n),
                       ~ !is.na(x[.x]) && all(x[.x] <= nbhd_at(.x), na.rm = TRUE))

  # Collapse consecutive same-type ties to the middle position. A 3-quarter
  # plateau therefore contributes one candidate, not three duplicates.
  collapse_runs <- function(flag) {
    if (!any(flag)) return(integer())
    r <- rle(flag)
    ends   <- cumsum(r$lengths)
    starts <- ends - r$lengths + 1L
    keep   <- which(r$values)
    map_int(keep, ~ as.integer(round((starts[.x] + ends[.x]) / 2)))
  }

  peak_pos   <- collapse_runs(is_peak)
  trough_pos <- collapse_runs(is_trough)

  # If the same position gets flagged as both peak and trough the window is
  # entirely flat. Drop it.
  both <- intersect(peak_pos, trough_pos)
  peak_pos   <- setdiff(peak_pos, both)
  trough_pos <- setdiff(trough_pos, both)

  tps <- bind_rows(
    tibble(idx = idx[peak_pos],   value = x[peak_pos],   type = "peak"),
    tibble(idx = idx[trough_pos], value = x[trough_pos], type = "trough")
  ) %>% arrange(idx)

  if (nrow(tps) == 0) return(tps)


  # Step 2: enforce alternation (drop the weaker of consecutive same-type) ##
  repeat {
    if (nrow(tps) < 2) break
    same_type <- tps$type == lag(tps$type)
    same_type[1] <- FALSE
    if (!any(same_type, na.rm = TRUE)) break

    # For each run of same-type, drop the weaker of the two adjacent points.
    drop_idx <- map_int(which(same_type), function(i) {
      prev <- i - 1
      if (tps$type[i] == "peak") {
        if (tps$value[i] >= tps$value[prev]) prev else i
      } else {
        if (tps$value[i] <= tps$value[prev]) prev else i
      }
    })
    tps <- tps[-unique(drop_idx), ]
  }


  # Step 3: enforce min_phase and min_cycle ##################################
  # Iteratively drop the smaller-amplitude turning point in any violating pair.
  repeat {
    if (nrow(tps) < 3) break

    gap <- diff(tps$idx)
    short_phase <- gap < min_phase
    cycle_gap <- diff(tps$idx, lag = 2)
    short_cycle <- cycle_gap < min_cycle

    if (!any(short_phase) && !any(short_cycle)) break

    # Drop the turning point with the smallest amplitude vs its neighbours.
    violators <- which(c(FALSE, short_phase) | c(FALSE, FALSE, short_cycle) |
                       c(short_phase, FALSE) | c(short_cycle, FALSE, FALSE))
    amp <- abs(tps$value - lag(tps$value, default = tps$value[1]))
    drop_one <- violators[which.min(amp[violators])]
    tps <- tps[-drop_one, ]
  }


  # Step 4: trough < preceding peak, peak > preceding trough ################
  repeat {
    if (nrow(tps) < 2) break
    bad <- (tps$type == "trough" & tps$value >= lag(tps$value)) |
           (tps$type == "peak"   & tps$value <= lag(tps$value))
    bad[1] <- FALSE
    if (!any(bad, na.rm = TRUE)) break
    tps <- tps[-which(bad)[1], ]
  }

  tps %>% select(idx, type, value)
}


###############################################################################
###############################################################################
# Helper: multivariate Harding-Pagan common-cycle dating
###############################################################################
###############################################################################

# Identifies common-cycle turning points across N component series, following
# Harding-Pagan (2006) and the cluster-width adaptation in DBT (2012, Annex).
#
# Inputs:
#   tps_list:      named list of tibbles, each with cols (idx, type, value).
#                  Output of bb_dater() applied to each component series.
#   n_obs:         total number of dates in the panel.
#   max_cluster:   regular threshold. Every per-component own-peak must lie
#                  within this many quarters of the common-cycle candidate.
#                  Default 6 quarters per DBT (2012, Annex).
#   max_weak:      weak threshold. At least one per-component own-peak lies
#                  between max_cluster and max_weak quarters from the candidate
#                  while all remain within max_weak. Default 12 quarters per
#                  DBT (2012, Annex).
#   min_cycle:     same as bb_dater. Default 40.
#
# Returns: tibble of (idx, type, strength) where strength is "regular" or
#          "weak".

multivariate_hp_dater <- function(tps_list, n_obs,
                                  max_cluster = 6, max_weak = 12,
                                  min_cycle = 40) {


  # Step 1: distance to nearest own-peak (and trough) for each series ########
  series_names <- names(tps_list)
  all_idx <- seq_len(n_obs)

  dist_to <- function(idx, targets) {
    if (length(targets) == 0) NA_integer_
    else min(abs(idx - targets))
  }

  build_dist_matrix <- function(extreme_type) {
    map_dfc(series_names, function(s) {
      targets <- tps_list[[s]] %>% filter(type == extreme_type) %>% pull(idx)
      tibble(!!s := map_int(all_idx, ~ dist_to(.x, targets)))
    })
  }

  dist_peak   <- build_dist_matrix("peak")
  dist_trough <- build_dist_matrix("trough")


  # Step 2: median distance across series ####################################
  median_peak   <- apply(dist_peak,   1, median, na.rm = TRUE)
  median_trough <- apply(dist_trough, 1, median, na.rm = TRUE)


  # Step 3: local minima of the median distance series ######################
  # A candidate common peak is where median_peak attains a local minimum.
  # We negate and look for peaks: peaks of -med = local minima of med.
  # We discard troughs of -med (= local maxima of med = furthest from any
  # own-peak) because they cannot be joint peaks by construction.
  candidates <- function(med, tp_type) {

    cand_idx <- bb_dater(-med, all_idx, window = 9,
                         min_cycle = min_cycle) %>%
      filter(type == "peak") %>%
      pull(idx)

    map_dfr(cand_idx, function(i) {

      # Cluster check (DBT 2012, Annex). Per-component own-peak must lie within
      # max_weak quarters of the candidate. "Regular" if every component is
      # within max_cluster of the candidate, "weak" if at least one component
      # is between max_cluster and max_weak. We compare distance-from-candidate,
      # not spread between component peaks: the spread version is strictly
      # tighter and would silently drop e.g. GB 2007-08 (max distance 8q,
      # spread 15q).
      own_idx <- map(series_names, function(s) {
        own_tps <- tps_list[[s]] %>% filter(type == !!tp_type) %>% pull(idx)
        own_tps[abs(own_tps - i) <= max_weak]
      })

      if (any(map_int(own_idx, length) == 0)) return(NULL)

      nearest  <- map_int(own_idx, function(z) z[which.min(abs(z - i))])
      max_dist <- max(abs(nearest - i))

      strength <- case_when(max_dist <= max_cluster ~ "regular",
                            max_dist <= max_weak    ~ "weak",
                            TRUE                    ~ NA_character_)
      if (is.na(strength)) return(NULL)

      tibble(idx = i, type = tp_type, strength = strength,
             max_dist = max_dist)
    })
  }

  bind_rows(candidates(median_peak,   "peak"),
            candidates(median_trough, "trough")) %>%
    arrange(idx)
}


###############################################################################
###############################################################################
# Estimate the financial cycle for each country
###############################################################################
###############################################################################

# Compute filtered cycles country-by-country ##################################
fc_estimate <- function(df) {

  # Trim to dates where all three FC components are non-NA. Otherwise the
  # cumsum picks up sustained drift from whichever component starts first
  # (most visibly Germany, where credit data starts in 1949 but property only
  # in 1970, leaving the credit cumsum elevated by the post-war boom by the
  # time property arrives).
  df <- df %>%
    filter(!is.na(credit_log_norm),
           !is.na(credit_to_gdp_log_norm),
           !is.na(property_log_norm)) %>%
    arrange(date)

  components <- list(credit   = df$credit_log_norm,
                     ratio    = df$credit_to_gdp_log_norm,
                     property = df$property_log_norm)

  # CF band-pass on annual log-difference of each component, then cumulated.
  filtered <- map(components, function(x) {
    g <- x - lag(x, 4)
    g[is.na(g)] <- 0
    cyc <- cffilter(g, pl = mt_pl, pu = mt_pu, root = FALSE,
                    drift = FALSE)$cycle %>% as.numeric()
    cumsum(cyc)
  })

  composite <- reduce(filtered, `+`) / length(filtered)

  # Anchor cumulated cycles on 1985 Q1 = 0 (DBT 2012, Section 1.1). Without
  # this, finite-sample drift in the cumsum leaves countries with persistent
  # post-war booms (DE, JP) sitting visibly above zero.
  base_q <- as.Date("1985-01-01")
  base_idx <- which(df$date == base_q)
  if (length(base_idx) == 1) {
    filtered  <- map(filtered, ~ .x - .x[base_idx])
    composite <- composite - composite[base_idx]
  }

  # Sequential idx local to the trimmed sample (used by the dating helpers).
  # We translate back to dates before returning.
  local_idx <- seq_len(nrow(df))

  tps_list   <- map(filtered, ~ bb_dater(.x, local_idx))
  common_tps <- multivariate_hp_dater(tps_list, n_obs = nrow(df))

  attach_date <- function(x) x %>% mutate(date = df$date[idx]) %>% select(-idx)

  list(filtered   = as_tibble(filtered) %>% mutate(date = df$date,
                                                   composite = composite),
       tps_list   = map(tps_list, attach_date),
       common_tps = attach_date(common_tps))
}

results <- panel %>%
  group_by(country) %>%
  group_split() %>%
  set_names(map_chr(., ~ unique(.x$country))) %>%
  map(fc_estimate)


###############################################################################
# Stitch results back together
###############################################################################

filtered_long   <- imap_dfr(results, ~ mutate(.x$filtered,   country = .y))
common_tps_long <- imap_dfr(results, ~ mutate(.x$common_tps, country = .y))

fc <- list(filtered = filtered_long, common_tps = common_tps_long)

message("Financial cycle estimated for ", length(results), " countries.")
