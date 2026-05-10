# Input data

All data downloads happen automatically inside `00_data_cleaning.R`. Raw pulls
are cached to this folder as `.rds` files. Delete a cached file to force a
fresh pull.

## What gets downloaded

| File | Source | Package | Contents |
| --- | --- | --- | --- |
| `bis_credit.rds` | BIS | `BIS` | Total credit to non-financial sector (level + % GDP) |
| `bis_property.rds` | BIS | `BIS` | Selected residential property prices |
| `bis_cbpol.rds` | BIS | `BIS` | Central bank policy rates (daily) |
| `fred_data.csv` | FRED | `fredr` | Real GDP for six countries |

## One-time setup

### R packages

```r
install.packages(c("BIS", "fredr", "tidyverse", "lubridate", "mFilter",
                   "here"))
```

### FRED API key

FRED requires a free API key.

1. Register at https://fredaccount.stlouisfed.org/apikey.
2. Add to your `.Renviron` (run `usethis::edit_r_environ()` to open):

```
FRED_API_KEY=your_key_here
```

3. Restart R.

## Banking crisis dates

Hard-coded in `03_charts.R`. Sourced from Laeven & Valencia
(2018, IMF WP/18/206) cross-checked against DBT (2012) Table 5.
