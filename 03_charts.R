################################################################################
################################################################################
# 03_charts.R
#
# Builds two replication charts:
#   Chart 1: Financial vs business cycle (panel of 6)   -> Borio (2012) Graph 1
#   Chart 2: Financial cycle with crises (6 countries)   -> Borio (2012) Graph 2
#
# Outputs PNG + matching CSV files to output/. The CSVs hold the line and
# marker data behind each chart so the figures are fully reproducible.
################################################################################
################################################################################

library(tidyverse)
library(lubridate)
library(here)

if (!exists("fc")) source(here("01_financial_cycle.R"))
if (!exists("bc")) source(here("02_business_cycle.R"))

dir.create(here("output", "charts"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "data"),   showWarnings = FALSE, recursive = TRUE)

# Fixed x window from 1960 through the last financial-cycle quarter (GDP can
# run slightly later; see 01_financial_cycle.R). No multiplicative ggplot
# expand. Breaks every 5 years on Jan-1 so ticks stay evenly spaced and do
# not pile up at the end.
x_start <- make_date(1960L, 1L, 1L)
x_end   <- max(fc$filtered$date, na.rm = TRUE)
x_date_lim <- c(x_start, x_end)

x_year_breaks <- make_date(seq(1960L, year(x_end), by = 5L), 1L, 1L)

country_facet_lab <- c(
  US = "US", GB = "GB", JP = "JP", AU = "AU", DE = "DE", ES = "Spain"
)
################################################################################
################################################################################
# Chart 1: Financial vs business cycle, faceted across the panel
################################################################################
################################################################################

# Blue line: composite medium-term financial cycle (CF filter average).
# Red line:  short-term business cycle in real GDP.
# Bars:      multivariate Harding-Pagan peaks (orange) and troughs (green).
# Free y scales because amplitude differs across countries.

cycles_panel <- fc$filtered %>%
  select(country, date, financial_cycle = composite) %>%
  full_join(bc %>% select(country, date, business_cycle = bc_level),
            by = c("country", "date")) %>%
  pivot_longer(c(financial_cycle, business_cycle),
               names_to = "cycle", values_to = "value")

tps_panel <- fc$common_tps

p_chart1 <- ggplot(cycles_panel, aes(date, value, colour = cycle)) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_vline(data = filter(tps_panel, type == "peak"),
             aes(xintercept = date),
             colour = "darkorange", alpha = 0.6, linewidth = 0.4) +
  geom_vline(data = filter(tps_panel, type == "trough"),
             aes(xintercept = date),
             colour = "forestgreen", alpha = 0.6, linewidth = 0.4) +
  geom_line(linewidth = 0.6) +
  scale_colour_manual(values = c(financial_cycle = "steelblue",
                                 business_cycle  = "firebrick"),
                      labels = c("Business cycle (GDP, 5-32q)",
                                 "Financial cycle (composite, 32-120q)")) +
  scale_x_date(breaks = x_year_breaks, date_labels = "%Y",
               limits = x_date_lim,
               expand = expansion(mult = 0, add = c(45, 45))) +
  facet_wrap(~ country, ncol = 2, scales = "free_y",
              labeller = labeller(country = country_facet_lab)) +
  labs(title = "Financial and business cycles, panel",
       subtitle = "Replication of Borio (2012) Graph 1, faceted",
       x = NULL, y = "Cyclical component (log scale)",
       colour = NULL,
       caption = "Vertical bars: peaks (orange) and troughs (green) from multivariate Harding-Pagan dating.") +
  theme_minimal() +
  theme(legend.position = "bottom",
        plot.caption = element_text(hjust = 0),
        strip.text = element_text(face = "bold"))

ggsave(here("output", "charts", "chart_fc_vs_bc_panel.png"), p_chart1,
       width = 12, height = 9, dpi = 150)

cycles_panel %>%
  pivot_wider(names_from = cycle, values_from = value) %>%
  left_join(tps_panel %>%
              filter(type == "peak") %>%
              transmute(country, date, fc_peak = strength),
            by = c("country", "date")) %>%
  left_join(tps_panel %>%
              filter(type == "trough") %>%
              transmute(country, date, fc_trough = strength),
            by = c("country", "date")) %>%
  arrange(country, date) %>%
  write_csv(here("output", "data", "chart_fc_vs_bc_panel.csv"))


################################################################################
################################################################################
# Chart 2: Financial cycle with crises (6 countries)  -> Borio (2012) Graph 2
################################################################################
################################################################################

# Banking crisis dates from Laeven & Valencia (2018) and DBT (2012) Table 5.
# Mark the start quarter of each systemic banking crisis.

crises <- tribble(
  ~country, ~date,
  "US", "1988 Q1",
  "US", "2007 Q3",
  "GB", "1973 Q4",
  "GB", "1991 Q3",
  "GB", "2007 Q3",
  "JP", "1992 Q4",
  "AU", "1989 Q4",
  "DE", "2007 Q3",
  "ES", "2008 Q3"
) %>%
  mutate(date = yq(date))

fc_long <- fc$filtered %>%
  select(country, date, composite)

tps <- fc$common_tps %>%
  select(country, date, type, strength)

p_chart2 <- ggplot(fc_long, aes(date, composite)) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_vline(data = crises, aes(xintercept = date),
             colour = "black", linewidth = 0.5) +
  geom_vline(data = filter(tps, type == "peak"),
             aes(xintercept = date, alpha = strength),
             colour = "darkorange", linewidth = 0.4) +
  geom_vline(data = filter(tps, type == "trough"),
             aes(xintercept = date, alpha = strength),
             colour = "forestgreen", linewidth = 0.4) +
  geom_line(colour = "steelblue", linewidth = 0.7) +
  scale_alpha_manual(values = c(regular = 0.7, weak = 0.3), guide = "none") +
  scale_x_date(breaks = x_year_breaks, date_labels = "%Y",
               limits = x_date_lim,
               expand = expansion(mult = 0, add = c(45, 45))) +
  facet_wrap(~ country, ncol = 2, scales = "free_y",
              labeller = labeller(country = country_facet_lab)) +
  labs(title = "Financial cycle and banking crises",
       subtitle = "Replication of Borio (2012) Graph 2",
       x = NULL, y = "Composite financial cycle",
       caption = paste0(
         "Blue line: composite medium-term financial cycle. ",
         "Black bar: banking-crisis start.\n",
         "Orange bar: financial-cycle peak. ",
         "Green bar: financial-cycle trough. ",
         "Darker bars are regular, lighter bars are weak.")) +
  theme_minimal() +
  theme(legend.position = "bottom",
        plot.caption = element_text(hjust = 0),
        strip.text = element_text(face = "bold"))

ggsave(here("output", "charts", "chart_fc_with_crises.png"), p_chart2,
       width = 10, height = 8, dpi = 150)

peak_markers <- tps %>%
  filter(type == "peak")   %>% transmute(country, date, fc_peak   = strength)
trough_markers <- tps %>%
  filter(type == "trough") %>% transmute(country, date, fc_trough = strength)
crisis_markers <- crises %>% mutate(crisis = 1L)

fc_long %>%
  rename(financial_cycle = composite) %>%
  left_join(peak_markers,   by = c("country", "date")) %>%
  left_join(trough_markers, by = c("country", "date")) %>%
  left_join(crisis_markers, by = c("country", "date")) %>%
  mutate(crisis = replace_na(crisis, 0L)) %>%
  arrange(country, date) %>%
  write_csv(here("output", "data", "chart_fc_with_crises.csv"))


message("Saved 2 PNG charts and 2 CSVs to output/")
