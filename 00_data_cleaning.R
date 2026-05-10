################################################################################
################################################################################
# 00_data_cleaning.R
#
# Pulls all input data automatically:
#   BIS  -> credit, property prices, policy rates, CPI   (BIS package)
#   FRED -> real GDP                                     (fredr package)
#
# Raw downloads are cached to input/ as .csv files (delete a cached file to
# force a fresh pull). The cleaned panel itself is held in memory only and
# consumed downstream by sourcing this script.
#
# Requires a FRED API key in the FRED_API_KEY environment variable.
# Register at https://fredaccount.stlouisfed.org/apikey, then either:
#   - In a session: Sys.setenv(FRED_API_KEY = "your_key_here")
#   - Permanently:  add FRED_API_KEY=... to your .Renviron file
#
# Produces in env: panel_final
################################################################################
################################################################################

library(tidyverse)
library(lubridate)
library(BIS)
library(fredr)
library(here)

countries <- c("US", "GB", "JP", "AU", "DE", "ES")
base_q <- yq("1985 Q1")

if (Sys.getenv("FRED_API_KEY") == "") {
  stop("Set FRED_API_KEY environment variable. ",
       "Register at https://fredaccount.stlouisfed.org/apikey")
}
fredr_set_key(Sys.getenv("FRED_API_KEY"))


###############################################################################
# Helper: cache-or-fetch
###############################################################################

# Used six times below. Inline would mean copying the same if/save/read block
# repeatedly.

cache <- function(file, fetch_fn) {
  path <- here("input", file)
  if (!file.exists(path)) write_csv(fetch_fn(), path)
  read_csv(path, show_col_types = FALSE)
}


###############################################################################
###############################################################################
# Pull BIS data
###############################################################################
###############################################################################

# URLs from BIS::get_datasets(). BIS hosts bulk CSVs at data.bis.org.
bis_urls <- list(
  total_credit = "https://data.bis.org/static/bulk/WS_TC_csv_flat.zip",
  property     = "https://data.bis.org/static/bulk/WS_SPP_csv_flat.zip",
  policy_rates = "https://data.bis.org/static/bulk/WS_CBPOL_csv_flat.zip",
  cpi          = "https://data.bis.org/static/bulk/WS_LONG_CPI_csv_flat.zip"
)

# BIS bulk files are huge (cbpol alone is ~470 MB uncompressed). The cache
# pre-filters to our six countries and the frequency we actually use, which
# keeps the on-disk files small enough to open in Excel. Delete the relevant
# input/*.csv if you change the country list above.

bis_credit_raw <- cache("bis_credit.csv", function() {
  get_bis(bis_urls$total_credit) %>%
    filter(str_extract(borrowers_cty, "^[A-Z]{2}") %in% countries,
           freq == "Q: Quarterly")
})

bis_property_raw <- cache("bis_property.csv", function() {
  get_bis(bis_urls$property) %>%
    filter(str_extract(ref_area, "^[A-Z]{2}") %in% countries)
})

bis_cbpol_raw <- cache("bis_cbpol.csv", function() {
  get_bis(bis_urls$policy_rates) %>%
    filter(str_extract(ref_area, "^[A-Z]{2}") %in% countries,
           freq == "M: Monthly")
})

bis_cpi_raw <- cache("bis_cpi.csv", function() {
  get_bis(bis_urls$cpi) %>%
    filter(str_extract(ref_area, "^[A-Z]{2}") %in% countries,
           freq == "M: Monthly")
})


###############################################################################
# Filter BIS data
###############################################################################

# BIS uses "XX: Country name" for area codes and "YYYY-Qn" for time period.
# Strip prefixes once at the top, then filter on the relevant dimension fields.

bis_credit <- bis_credit_raw %>%
  mutate(country = str_extract(borrowers_cty, "^[A-Z]{2}"),
         date    = yq(str_replace(time_period, "-", " "))) %>%
  filter(country %in% countries,
         freq         == "Q: Quarterly",
         tc_borrowers == "P: Private non-financial sector",
         tc_lenders   == "A: All sectors",
         valuation    == "M: Market value",
         tc_adjust    == "A: Adjusted for breaks")

credit_level <- bis_credit %>%
  filter(str_detect(unit_type, "^XDC:")) %>%
  transmute(country, date, credit_lc = obs_value)

credit_ratio <- bis_credit %>%
  filter(unit_type == "770: Percentage of GDP") %>%
  transmute(country, date, credit_to_gdp = obs_value)

property_nominal <- bis_property_raw %>%
  mutate(country = str_extract(ref_area, "^[A-Z]{2}"),
         date    = yq(str_replace(time_period, "-", " "))) %>%
  filter(country %in% countries,
         value        == "N: Nominal",
         unit_measure == "628: Index, 2010 = 100") %>%
  transmute(country, date, property_nominal = obs_value)

# Monthly BIS policy rates aggregated to quarterly mean.
policy_rates <- bis_cbpol_raw %>%
  mutate(country = str_extract(ref_area, "^[A-Z]{2}")) %>%
  filter(country %in% countries, freq == "M: Monthly") %>%
  mutate(date = floor_date(ym(time_period), "quarter")) %>%
  group_by(country, date) %>%
  summarise(policy_rate = mean(obs_value, na.rm = TRUE), .groups = "drop")

# Monthly BIS CPI (index, 2010 = 100) aggregated to quarterly mean.
cpi <- bis_cpi_raw %>%
  mutate(country = str_extract(ref_area, "^[A-Z]{2}")) %>%
  filter(country %in% countries,
         freq         == "M: Monthly",
         unit_measure == "628: Index, 2010 = 100") %>%
  mutate(date = floor_date(ym(time_period), "quarter")) %>%
  group_by(country, date) %>%
  summarise(cpi = mean(obs_value, na.rm = TRUE), .groups = "drop")


###############################################################################
###############################################################################
# Pull FRED data
###############################################################################
###############################################################################

# Real GDP per country (mixed sources, country-native).
# Note: JP GDP starts 1994, DE GDP starts 1991, ES GDP (Eurostat via FRED)
# starts 1995. Pre-1990 panels for ES and part of DE/JP will be GDP-less
# until credit/property windows align. The financial-cycle trim uses all
# three FC components; see 01_financial_cycle.R.

fred_ids <- tribble(
  ~country, ~indicator, ~series_id,
  "US", "gdp_real", "GDPC1",
  "GB", "gdp_real", "NGDPRSAXDCGBQ",
  "JP", "gdp_real", "JPNRGDPEXP",
  "AU", "gdp_real", "NGDPRSAXDCAUQ",
  "DE", "gdp_real", "CLVMNACSCAB1GQDE",
  "ES", "gdp_real", "CLVMNACSCAB1GQES"
)

# FRED occasionally returns 5xx errors on IFS-derived series. Retry up to 3
# times with a short backoff to ride through transient failures.
fred_with_retry <- function(id, attempts = 5) {
  for (i in seq_len(attempts)) {
    res <- tryCatch(fredr(id, observation_start = ymd("1960-01-01")),
                    error = function(e) e)
    if (!inherits(res, "error")) return(res)
    message("FRED ", id, " attempt ", i, " failed: ",
            conditionMessage(res), ". Retrying...")
    Sys.sleep(3 * i)
  }
  stop("FRED retry exhausted for series ", id, ": ", conditionMessage(res))
}

fred_raw <- cache("fred_data.csv", function() {
  fred_ids %>%
    mutate(data = map(series_id, fred_with_retry)) %>%
    select(-series_id) %>%
    unnest(data) %>%
    transmute(country, indicator,
              date = floor_date(date, "quarter"),
              value)
})

fred_panel <- fred_raw %>%
  pivot_wider(names_from = indicator, values_from = value)


###############################################################################
###############################################################################
# Build the panel
###############################################################################
###############################################################################

panel <- credit_level %>%
  full_join(credit_ratio,     by = c("country", "date")) %>%
  full_join(property_nominal, by = c("country", "date")) %>%
  full_join(policy_rates,     by = c("country", "date")) %>%
  full_join(cpi,              by = c("country", "date")) %>%
  full_join(fred_panel,       by = c("country", "date")) %>%
  arrange(country, date)


###############################################################################
# Deflate, log, normalise
###############################################################################

# DBT (2012) deflate credit and property by CPI, take logs, normalise to
# 1985Q1 = 1. Credit-to-GDP ratio stays in percentage points.

panel_clean <- panel %>%
  group_by(country) %>%
  mutate(credit_real      = credit_lc / cpi,
         property_real    = property_nominal / cpi,
         inflation_yoy    = (cpi / lag(cpi, 4) - 1) * 100,
         gdp_growth_yoy   = (gdp_real / lag(gdp_real, 4) - 1) * 100,
         real_policy_rate = policy_rate - inflation_yoy) %>%
  ungroup()

norm_factors <- panel_clean %>%
  filter(date == base_q) %>%
  select(country,
         credit_real_85    = credit_real,
         property_real_85  = property_real,
         credit_to_gdp_85  = credit_to_gdp)

# Credit-to-GDP also gets log-normalised so all three FC components share
# the same units. DBT (2012, Section 1.1) keep credit/GDP in pp in the data
# tables but their composite-cycle amplitudes only make sense if the inputs
# are unit-consistent (logs).
panel_final <- panel_clean %>%
  left_join(norm_factors, by = "country") %>%
  mutate(credit_log_norm        = log(credit_real / credit_real_85),
         property_log_norm      = log(property_real / property_real_85),
         credit_to_gdp_log_norm = log(credit_to_gdp / credit_to_gdp_85)) %>%
  select(-credit_real_85, -property_real_85, -credit_to_gdp_85)


message("Panel built with ", nrow(panel_final), " rows across ",
        n_distinct(panel_final$country), " countries.")
