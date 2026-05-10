################################################################################
################################################################################
# 02_business_cycle.R
#
# Estimates the short-term business cycle in real GDP using a CF band-pass at
# 5-32 quarter periodicity, applied to annual log differences and cumulated.
# Mirrors the red line in Borio (2012) Graph 1.
#
# Produces in env: bc (tibble with country, date, gdp_real, bc_level)
################################################################################
################################################################################

library(tidyverse)
library(lubridate)
library(mFilter)
library(here)

if (!exists("panel_final")) source(here("00_data_cleaning.R"))
panel <- panel_final


# CF pass-band for the business cycle, in quarters.
st_pl <- 5
st_pu <- 32


###############################################################################
# Filter real GDP per country
###############################################################################

bc_long <- panel %>%
  group_by(country) %>%
  arrange(date, .by_group = TRUE) %>%
  mutate(gdp_log = log(gdp_real),
         gdp_g   = gdp_log - lag(gdp_log, 4)) %>%
  mutate(gdp_g_imp = if_else(is.na(gdp_g), 0, gdp_g),
         bc_growth = as.numeric(cffilter(gdp_g_imp,
                                         pl = st_pl, pu = st_pu,
                                         root = FALSE, drift = FALSE)$cycle),
         bc_level  = cumsum(bc_growth)) %>%
  ungroup() %>%
  select(country, date, gdp_real, bc_level)


bc <- bc_long

message("Business cycle estimated for ", n_distinct(bc$country),
        " countries.")
