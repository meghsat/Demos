---
name: rnd-stock
description: |
  Stock analysis agent for the startup dummy dataset.
  Reads price, tech, market, and fundamentals data to build
  a weighted ML prediction pipeline and interactive dashboard.
routing: local-35b
sensitivity: low
models:
  primary: Qwen3.6-35B-A3B-GGUF
---

# R&D Stock Agent — ACME Technologies

## Core Rules

1. **Data Sources**
   - OHLC prices: `${HOME}/Downloads/projects/router-configs/data/stock_acme_ohlc.csv`
   - Tech signals: `${HOME}/Downloads/projects/router-configs/data/tech_factors_monthly.csv`
   - Market signals: `${HOME}/Downloads/projects/router-configs/data/market_factors_monthly.csv`
   - Fundamentals: `${HOME}/Downloads/projects/router-configs/data/company_fundamentals_quarterly.csv`

2. **Prediction Pipeline**
   - Merge monthly/quarterly factors to daily prices (forward-fill)
   - Statistical baselines: LinReg (trend), EMA crossover (momentum), ARIMA(5,1,0)
   - ML models: XGBoost (market + OHLC features), LSTM (price sequence, lookback=20)
   - Weighted ensemble: optimize weights on 20% holdout (SLSQP, Σw=1, w≥0)
   - Report per-model RMSE + MAE before combining

3. **Outputs** — write both to `${HOME}/Downloads/projects/router-configs/data/`
   - `dashboard_data.js` — all Python-computed arrays as JS `const` declarations
   - `dashboard_acme.html` — Chart.js dark dashboard that loads `dashboard_data.js` via `<script src>`

---

## Implementation Reference

Follow this 8-section structure exactly. Do not deviate — these patterns resolve all known pitfalls.

### Section 1 — Imports
```python
import os, json, warnings; warnings.filterwarnings("ignore")
import numpy as np, pandas as pd
from scipy.optimize import minimize
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error, mean_absolute_error
np.random.seed(42)
DATA_DIR = os.path.expanduser("~/Downloads/projects/router-configs/data/")
```

### Section 2 — Load & Merge
```python
# Quarter format is "Q4-2024" — parse with:
parts = df["quarter"].str.split('-', n=1, expand=True)
q_num = parts[0].str.extract(r'(\d+)')[0].astype(int)
year  = parts[1].astype(int)
df["quarter"] = pd.to_datetime(dict(year=year, month=(q_num-1)*3+1, day=1))

# Add month/quarter keys to OHLC, then merge each factor df, then ffill+dropna
merged["month"]   = merged["date"].dt.to_period("M").dt.start_time
merged["quarter"] = merged["date"].dt.to_period("Q").dt.start_time
merged = merged.ffill().dropna()
```

### Section 3 — Feature Engineering
Compute on `merged["close"]`: `returns`, `volatility_5/20`, `ema_12/26/50`, `ema_spread`, `sma_20/50`, `sma_ratio`, `rsi_14`, `bb_pct`, `vol_ratio`, `sma20_slope`, `sma50_slope`, `momentum_5/10/20`.
Target: `merged["target"] = merged["close"].shift(-1) / merged["close"] - 1`
Drop `("date","target","month","quarter","open","high","low","close","volume","adj_close")` from feature_cols.
After dropna: ~327 rows, ~47 features.

### Section 4 — Train/Val Split
```python
train_end = int(len(merged) * 0.8)   # ~261
X_train, X_val = merged[feature_cols].iloc[:train_end].values, merged[feature_cols].iloc[train_end:].values
y_train, y_val = merged["target"].iloc[:train_end].values,     merged["target"].iloc[train_end:].values
scaler = StandardScaler()
X_train_s, X_val_s = scaler.fit_transform(X_train), scaler.transform(X_val)
```

### Section 5 — Train Models
- **LinReg**: `LinearRegression().fit(X_train_s, y_train)`
- **XGBoost**: `n_estimators=300, max_depth=6, learning_rate=0.05, subsample=0.8, colsample_bytree=0.7, random_state=42` — wrap in try/except
- **LSTM**: 2-layer (64→32 units), dropout=0.2, lookback=20, EarlyStopping(patience=8)
  - **Critical alignment**: `seq_train_end = train_end - lookback` (NOT `int(total_seq * 0.8)`)
  - Fit `scaler_all = StandardScaler()` on all `merged[feature_cols]` separately for LSTM
  - Clip all return predictions to `(-0.1, 0.1)`
- **ARIMA**: `from statsmodels.tsa.arima.model import ARIMA` — wrap in try/except; convert price forecasts to returns

### Section 6 — Ensemble (SLSQP)
```python
preds_matrix = np.column_stack([pred_lr, pred_xgb, pred_lstm_aligned, pred_arima])
opt = minimize(lambda w: np.sqrt(mean_squared_error(y_val, preds_matrix @ w)),
               np.ones(n) / n, method="SLSQP",
               bounds=[(0,1)]*n, constraints={"type":"eq","fun": lambda w: w.sum()-1})
ensemble_weights = {name: float(w) for name, w in zip(model_names, opt.x)}
```

### Section 7 — Forecast (90-day) + Monte Carlo bands
Retrain each model on full dataset. Step forward day-by-day applying weighted ensemble returns.
Monte Carlo: 500 GBM paths using `vol_mean`/`vol_std` from last 20 days → p10/p90 arrays.

### Section 8 — Two-file output (CRITICAL PATTERN)
**Never embed JS inside a Python f-string.** Instead:

```python
# Step A: write all data as JS consts to dashboard_data.js
js_data = f"""
const closeHist = {json.dumps(close_vals)};
const datesHist = {json.dumps(dates_hist)};
const pricesForecast = {json.dumps(forecast_prices[1:])};
const p10Forecast = {json.dumps(p10_forecast)};
const p90Forecast = {json.dumps(p90_forecast)};
const ensembleWeights = {json.dumps(ensemble_weights)};
const modelMetrics = {json.dumps(metrics_dict)};
const histLen = {len(dates_hist)};
const valStartIndex = {len(dates_hist) - len(y_val)};
const valLen = {len(y_val)};
// ... sma20Hist, sma50Hist, rsiHist, volHist, predEnsembleVal, predLstmVal, predLinregVal
"""
with open(DATA_DIR + "dashboard_data.js", "w") as f: f.write(js_data)

# Step B: write HTML as a plain string (no f-string), use {{ }} only for CSS/JS braces,
# then at save time convert {{ → { and }} → }
html_template = """<!DOCTYPE html>...
<script src="dashboard_data.js"></script>
<script>
// JS uses {{  }} for object literals and for-loops — these get unescaped at write time
for (let i = 0; i < histLen; i++) {{ allEnsemble[valStartIndex + i] = predEnsembleVal[i]; }}
</script>"""
with open(DATA_DIR + "dashboard_acme.html", "w") as f:
    f.write(html_template.replace("{{", "{").replace("}}", "}"))
```

### Dashboard Layout (dark theme — use these exact colors)
- Background `#0d1117`, cards `#161b22`, borders `#21262d`, text `#c9d1d9`, muted `#8b949e`
- Accent colors: close `#58a6ff`, SMA20 `#f0883e`, SMA50 `#bc8cff`, ensemble `#3fb950`, LSTM `#f85149`, LinReg `#d29922`
- Grid: `grid-template-columns: 1fr 320px` (main chart + side panel)
- Side panel: metrics table → ensemble weights bar chart → ARR/NRR/API sparklines (use inline SVG polyline)
- Bottom row: RSI(14) with overbought(70)/oversold(30) lines + Volume bars (green if close↑, red if close↓)
- Controls: horizon toggle buttons `[14d][30d][90d]` + series toggles via `chart.setDatasetVisibility()`
- Keyboard: `1/2/3` → set horizon 14/30/90d

---

## Examples

```
User: @rnd-stock build a stock prediction model from the startup data and visualize it

Actions:
- Read all 4 CSVs, forward-fill and merge to daily (~327 rows after dropna)
- Engineer ~47 features; target = next-day return
- Train LinReg, XGBoost, LSTM, ARIMA on 80% split; evaluate on 20% holdout
- SLSQP weight optimization → ensemble
- 90-day forecast + 500-path Monte Carlo bands
- Write dashboard_data.js + dashboard_acme.html
→ RMSE: XGB $0.027, LSTM $0.025, ARIMA $0.026, Ensemble $0.024
   Weights: LSTM 74%, ARIMA 21%, LinReg 5%, XGBoost 0%
```

```
User: @rnd-stock what's driving the recovery since mid-2025?

Actions:
- Identify recovery period (Jun–Sep 2025): VIX 31→16, Fed rate 5.25%→4.75%, ARR $8.3M→$11.8M, API calls 4.9M→8.6M
- XGBoost feature importance → market sentiment + NRR are top drivers
- Run 30-day forward ensemble forecast
→ Factor attribution table + forecast $113 ± $6 (90% CI $104–$122)
```

```
User: @rnd-stock show me the dashboard with all model lines and 90-day view

Actions:
- Full pipeline; horizon default = 90d; all series visible
→ dashboard_acme.html with per-model RMSE degradation table
```

---

## Workshop Challenges

- Swap LSTM for a Transformer (PyTorch, 2-layer self-attention, same lookback=20)
- Add a "What If" panel: slide NRR from 124% → 140%, recompute ensemble forecast
- Add macro correlation heatmap: which market factors correlate most with ACME price?
- Extend to 90-day forecast; compare per-model RMSE degradation as horizon grows
