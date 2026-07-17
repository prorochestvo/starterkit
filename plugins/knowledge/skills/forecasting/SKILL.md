---
name: forecasting
description: Time-series forecasting doctrine - baseline-first discipline, data profiling (stationarity, ACF/PACF), model escalation ladder, walk-forward backtesting, metrics (MAE/RMSE/MAPE/MASE/directional accuracy), leakage traps, and Go ecosystem guidance. Load when building, evaluating, or reviewing forecasting or prediction code.
---

# Time-series forecasting

General doctrine for any predictor of future values from history. Project specifics (interfaces, schemas, data access) belong in the project's own agent/CLAUDE.md — this skill is the method.

## Doctrine

- **A forecaster without a backtest is half a feature.** Prediction code and its validation rig ship in the same change; accuracy claims are numbers on a named window, not adjectives.
- **Baseline first.** Naive last-value and (if the series has a season) seasonal-naive are the mandatory bar. A model that doesn't beat `price[t-1]` on the backtest is not shipped — and an embarrassing share of "ML forecasts" in production doesn't.
- **Interpretable beats clever.** Escalate only on demonstrated failure of the simpler model, with the numbers in the commit body: moving average → linear regression → AR(p) / exponential smoothing → Holt-Winters (trend+season) → gradient boosting on lag features → deep learning (rarely worth it below massive scale).
- **Profile before fitting.** Model choice is justified by the data, not by what's easiest to implement.

## Profiling the series

- **Stationarity**: mean/variance roughly constant over rolling windows? Trend or seasonality visible? AR-family models assume stationarity — difference (`y[t]=x[t]-x[t-1]`) and/or log-transform to reach it.
- **ACF**: slow decay = trend/non-stationary; sharp cutoff after lag q = MA-friendly. **PACF**: cutoff after lag p = AR(p) candidate. Pick order from the PACF, not from a hunch.
- Know the series' calendar: weekends/holidays gaps, intraday spikes, regime changes (a rate peg breaking, a product launch). A model fitted across a regime change is fitted to fiction.

## Backtesting (where forecasts are won or lost)

- **Walk-forward only.** Train on `[0..i]`, predict `i+1` (or `i+h`), advance. Random k-fold leaks the future into training — never use it on time series.
- **Untouched holdout**: keep the most recent window out of all model selection; repeated tuning against the test window is leakage-by-iteration.
- **Leakage traps**: features computed over the full series (global mean/std normalization), lag features that peek past the cut, timestamps in local time crossing DST, backfilled/revised historical data that didn't exist at prediction time.
- **Inverse-transform discipline**: if the series was differenced/logged, reverse the transform before computing metrics — inverse-transform bugs are where "MAE = 355.20" disasters come from. Review that step twice.
- Evaluate per horizon (h=1 vs h=7 are different problems) and per segment (per currency pair / per product) — aggregates hide the segment where the model is garbage.

## Metrics (report several; each lies alone)

| Metric | Reading | Trap |
|--------|---------|------|
| MAE | same units as the target, most interpretable | scale-bound, can't compare across series |
| RMSE | penalizes big misses | one spike dominates |
| MAPE | scale-free, comparable across series | explodes near zero values, asymmetric |
| MASE | error relative to naive baseline (<1 = beats naive) | needs the naive errors computed on the same window |
| R² | variance captured; <0 = worse than predicting the mean | misleading on trended series |
| Directional accuracy | % of correct up/down calls | ignores magnitude; often the metric that matters for trading-style decisions |

Point forecasts hide uncertainty — when decisions have asymmetric costs, produce intervals or quantiles, not just the point.

## Go ecosystem honesty

- `gonum.org/v1/gonum` (`stat`, `mat`) covers the classical toolbox: OLS/AR(p) via `mat.Solve` on the lag design matrix, `stat.Mean/Variance/Correlation/RSquaredFrom`. Prefer it over new deps.
- `golearn`, `gota`, and most 2015-2018-era Go ML libraries are unmaintained — don't add them. No production-grade native ARIMA exists in Go; ship AR + document the MA gap rather than pulling in a half-dead dep.
- Serious model training in Go is masochism. The load-bearing pattern: train elsewhere (Python), serve via ONNX runtime in Go, or run a forecasting sidecar — the Go service owns data, backtesting, and decisions.
- Anomaly detection is a separate concern from forecasting — a parallel detector, not a `Forecaster` implementation. Cheapest credible start: residual threshold `|observed - predicted| > k·σ` over an existing forecaster.

## Review checklist

- [ ] Backtest ships with the forecaster; walk-forward; holdout untouched.
- [ ] Baselines (naive, seasonal-naive) in the same table; MASE < 1 or the model doesn't ship.
- [ ] No leakage: features, normalization, and lags computed only from data available at prediction time.
- [ ] Metrics per horizon and per segment; inverse-transform verified.
- [ ] Model order/family justified by the profile (stationarity, ACF/PACF), documented in the plan or commit.
- [ ] No new ML dependency where gonum suffices; no unmaintained libraries.
