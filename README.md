# Financial cycle dating

A plain-English readout of where the major economies sit on the medium-term
financial cycle, using the framework from Borio (2012) and Drehmann, Borio &
Tsatsaronis (2012) extended through the latest available data (2025 Q3).

## Why the financial cycle matters

The business cycle is the familiar 1-8 year up-and-down in GDP. The financial
cycle is a different, longer-running thing. It tracks the joint co-movement of
real bank credit, the credit-to-GDP ratio and real residential property prices
over 8-30 year periods. When all three climb together, financial conditions are
quietly stretching. When all three roll over together, a systemic banking crisis
usually follows within a year or two.

The policy hook: standard output gaps watch inflation, so they only flag
overheating once prices rise. A financial boom can build for years with
inflation quiet and headline gaps near zero. The financial cycle is the
complementary thermometer. The 2008 crisis (US, UK, Spain), the 1991 Japanese bust
and the 1989 Australian banking-sector blow-up were all visible in this
measure long before they showed up in GDP or CPI.

## The two charts

All charts live in `output/charts/`. Each has a matching CSV in
`output/data/` with the underlying line and marker data.

### `chart_fc_vs_bc_panel.png`: financial vs business cycle, six countries

![Financial cycle vs business cycle, six-country panel](output/charts/chart_fc_vs_bc_panel.png)

Medium-term financial cycle (blue) and short-term business cycle in real GDP
(red) for US, UK, Japan, Australia, Germany and Spain. Vertical bars mark
common turning points in the financial cycle (orange peaks, green troughs).

What to look for: the two cycles sit on different time scales everywhere. The
medium-term financial swing is slower and larger than the short GDP cycle. A
recession on top of a financial-cycle downturn (1991, 2008) is a different
event from a recession inside a financial-cycle expansion (2001). The
financial cycle dwarfs the business cycle in amplitude in most panels.
Country shapes vary a lot. Germany is small and lopsided. Japan is dominated by
the late-1980s bubble. Australia shows two distinct cycles: a deregulation
boom-bust into 1989, then a mining-and-property cycle peaking around 2008-2010
and troughing in 2013 alongside the end of the mining-investment boom. Spain
runs a classic boom into the GFC, a dated weak peak at the 2008 Q3 systemic
start, then a long unwind to a mid-2010s trough and a gradual climb back. The US
and UK show the cleanest two-bust pattern.

### `chart_fc_with_crises.png`: the empirical hook

![Financial cycle with banking crises overlaid](output/charts/chart_fc_with_crises.png)

Financial cycle for each country with banking-crisis dates marked as black
vertical lines.

What to look for: eight of the nine black lines sit on or beside an orange
peak. The exception is DE 2007. Germany was the creditor in the 2008
episode, not the borrower. Its domestic credit-and-property cycle was flat
through the mid-2000s, and the distress at Hypo Real Estate, IKB and the
Landesbanks came from holdings of US subprime, not a home build-up. A
medium-term financial-cycle dater on German credit and property correctly
finds no home peak in 2007. This is the chart the policy argument rests on.
Where a country runs a home-grown credit-and-property build-up, the
financial-cycle peak and the systemic banking crisis are essentially the same
event seen two ways. Spain's systemic start (2008 Q3) lines up on the dated
weak peak from the joint dater.

The peak labels distinguish "regular" from "weak":

- **Regular peak**: every component has an own-peak within 6 quarters of the
  common-cycle date.
- **Weak peak**: every component is within 12 quarters of the common-cycle
  date and at least one is more than 6 away.

## What the latest data says

Composite financial cycle level at 2025 Q3, expressed as deviation from the
1985 Q1 baseline:

| Country | FC level | Most recent turning point | Status |
|---|---|---|---|
| Australia | ≈ 0 | 2013 Q2 trough | Mid-cycle, near baseline |
| Germany | ≈ 0 | 2022 Q2 peak | Past the peak, unwinding |
| Japan | +0.59 | 2022 Q4 peak | Past the peak, persistently elevated |
| Spain | +0.15 | 2015 Q3 trough (weak) | Mid-cycle, climbing after GFC trough |
| UK | ≈ 0 | 2020 Q3 peak | Past the peak, unwinding |
| US | +0.19 | 2025 Q3 trough (live) | Mid-cycle, modestly elevated |

### Spain and Germany: opposing European archetypes

Spain is the **borrower-side** archetype inside the euro area. Domestic credit,
the credit-to-GDP ratio and real house prices rose together for much of the
2000s. The Laeven–Valencia-style systemic start (2008 Q3) sits on a dated joint
financial-cycle peak (weak in the three-series sense). The empirical story is
unified: same quarter reads as both a medium-term financial crest and the
opening of a banking crisis.

Germany is the **creditor / flat domestic-cycle** opposite. Through the
mid-2000s the composite financial cycle stayed comparatively muted: no large
joint build-up in the three ingredients the chart averages. The crisis marker
for 2007 Q3 still appears (Hypo, IKB, Landesbank subprime and liquidity stress),
yet it does **not** sit on an orange peak. The point is not to deny German bank
distress. It is to separate a **home-grown domestic financial cycle peak** from
**systemic stress driven by foreign exposures and wholesale funding**. One
economy flags both in the same place; the other does not.

The UK sits in between for 2008: a clear domestic Anglo-housing and leverage
episode, so the crisis line lines up with a peak the way Spain’s does, without
sharing Spain’s post-sovereign decade. In today’s levels, Germany and the UK
both show a rollover from early-2020s peaks, while Spain remains on a shallower
recovery leg after a much deeper trough.

Four themes emerge.

**Australia** sits on the 1985 baseline with no dated joint peak since the
post-mining trough. The composite drifted down gently after COVID without
flagging a new medium-term turning point: a quiet mid-cycle read, not a fresh
boom or bust.

**Europe.** See the Spain–Germany contrast above. In the latest window, Germany
and the UK both turned over in the early 2020s. Those cycles have rolled but
not fully unwound: the post-COVID cool-down in the north looks more like orderly
deflation than outright bust. Spain is further along in calendar time after its
mid-2010s trough, with the composite only modestly above zero.

**The US is closer to neutral.** It sits modestly above the 1985 baseline,
with an end-of-sample trough marker. The honest read is the cycle is somewhere
near the bottom of a mild downswing. The hiking cycle of 2022-2024 took some
heat out without forcing a financial bust.

**Japan remains elevated for stock reasons.** It is still well above the 1985
base because the 1990 bubble peaked at extraordinary levels and three decades
of stagnation have only chipped away at the stock of credit and the level of
real property prices.

The takeaway: the medium-term build-up is not a single global story. Spain and
Germany illustrate opposite ways a European banking crisis can line up—or
fail to line up—with the domestic financial cycle. The US is roughly neutral.
Australia is quiet near baseline. Japan continues to carry the largest
medium-term financial overhang in level terms.

## Caveats on the latest readings

- **Filter edge effects.** The Christiano-Fitzgerald band-pass for an 8-30 year
  cycle has large endpoint distortions in the final roughly five years. Recent
  peaks and troughs will revise as more data arrives.
- **Two-sided filter.** This is a full-sample retrospective view. It is not
  what would have been visible to a policymaker in real time.
- **Australian GDP.** ABS recently revised its national-accounts methodology.
  Long-run real GDP back-data may differ slightly from BIS-archived series.

## Reproduce

| Script | What it does |
| --- | --- |
| `00_data_cleaning.R` | Pulls quarterly credit, property, GDP, CPI and policy rates for the six countries. Caches raw downloads to `input/`. |
| `01_financial_cycle.R` | Runs the medium-term band-pass filter and the multivariate Harding-Pagan turning-point dater. |
| `02_business_cycle.R` | Runs the short-term band-pass filter on real GDP. |
| `03_charts.R` | Builds the two charts and matching CSVs. The last script in the chain. Run this to reproduce everything. |

One-time setup: a free FRED API key stored as `FRED_API_KEY` in your
`.Renviron`. See `input/README.md`.

## Methodology in brief

The composite financial cycle is the simple average of three medium-term
cycles: real credit, credit-to-GDP and real property prices. Each component is
run through a Christiano-Fitzgerald band-pass on its annual log-difference,
with a 32-120 quarter pass-band, then cumulated to a log-level cycle and
anchored to zero at 1985 Q1.

Common turning points come from a multivariate Harding-Pagan algorithm. A peak
is "regular" if every component has an own-peak within 6 quarters of the
common-cycle date, "weak" if every component is within 12 quarters and at
least one is more than 6 away. The rule is on per-component distance from the
common-cycle date, not on the spread between component peaks, per DBT (2012,
Annex). Full implementation in `01_financial_cycle.R`.

## Papers

- `papers/Borio (2012).pdf`: *The financial cycle and macroeconomics: what have
  we learnt?* BIS Working Paper No. 395. The conceptual paper.
- `papers/Drehmann Borio Tsatsaronis (2012).pdf`: *Characterising the financial
  cycle: don't lose sight of the medium term!* BIS Working Paper No. 380. The
  empirical method.
