---
name: rnd
description: |
  Stock analysis agent for the Laren Technologies dataset.
  Computes statistical indicators and writes a self-contained Chart.js dashboard HTML.
---

# R&D Stock Agent — Laren Technologies

## Core Rules

1. **Data Source**
   - `${HOME}/Downloads/projects/router-configs/data/stock_Laren_ohlc.csv`
   - Columns: date, open, high, low, close, volume, adj_close | 382 rows (Jan 2025 – Jun 2026)

2. **Analysis** — pure stats, pandas + numpy only (no sklearn, no model training)
   - SMA(20), SMA(50) — trend context
   - EMA(12), EMA(26) crossover — momentum signal
   - RSI(14) — overbought / oversold
   - Bollinger Bands(20, 2σ) — volatility bands and %B position
   - Simple forward projection: extend the last EMA(12) slope for 14/30 days
   - Weighted signal score (fixed weights, no fitting):
     `Score = 0.5 × EMA_signal + 0.3 × RSI_signal + 0.2 × BB_signal`
     where each signal is normalized to [-1, +1]

3. **Output** — single file: `${HOME}/Downloads/projects/router-configs/data/dashboard_Laren.html`
   - Self-contained, dark theme, Chart.js 4.4.x from cdnjs
   - All data inlined — no external fetch calls

## Build Steps (execute in this order)

```
1. DATA_DIR = os.path.expanduser("~/Downloads/projects/router-configs/data/")
   # Never use $HOME — always expanduser

2. df = read_csv(DATA_DIR + "stock_Laren_ohlc.csv", parse_dates=["date"]), sort by date

3. Compute on df["close"] series:
   sma20, sma50          → rolling(20/50).mean()
   ema12, ema26          → ewm(span=12/26, adjust=False).mean()
   rsi14                 → 14-period RSI via avg_gain / avg_loss
   bb_upper, bb_lower    → sma20 ± 2 * rolling(20).std()
   bb_pct                → (close - bb_lower) / (bb_upper - bb_lower)

4. Signals from LAST valid row (clip each to [-1, 1]):
   ema_sig  = (ema12[-1] - ema26[-1]) / close[-1]
   rsi_sig  = (50 - rsi14[-1]) / 50
   bb_sig   = 0.5 - bb_pct[-1]
   score    = 0.5*ema_sig + 0.3*rsi_sig + 0.2*bb_sig

5. Forward projection (14 and 30 days):
   slope        = ema12[-1] - ema12[-2]
   proj_14/30   = [close[-1] + slope*(i+1) for i in range(N)]
   future_dates = pd.date_range(last_date + 1 day, periods=30, freq="B")

6. Replace NaN in all arrays before JSON: fillna("") or slice from first valid index
   DATA = { "dates": [...], "close": [...], "sma20": [...], ... all arrays ... }

7. data_script  = f'<script>const DATA={json.dumps(DATA)};</script>'
   HTML_BODY    = """..."""   # plain string, use {{ }} for every JS brace
   output       = (data_script + HTML_BODY).replace("{{","{").replace("}}","}")
   write output to DATA_DIR + "dashboard_Laren.html"
```

## Key Reminders

- **Never f-string JS blocks** — inject all data via `json.dumps()` in Step 7, then plain string for HTML
- **NaN breaks json.dumps** — call `.fillna(None).tolist()` on every pandas Series before packing DATA
- **`{{ }}`** in HTML_BODY → real `{ }` after the replace at save time

## Dashboard Layout (dark theme)
- Colors: bg `#0d1117`, cards `#161b22`, borders `#21262d`, accent `#58a6ff`, green `#3fb950`, orange `#f0883e`, purple `#bc8cff`
- Header: company name, current price, bullish/bearish/neutral badge from score, horizon toggle [14d / 30d]
- Main chart: close + SMA20 + SMA50 + Bollinger Bands (upper/lower shaded) + EMA projection
- Side panel: signal score + direction, RSI reading, BB %B position, signal weights bar chart
- Bottom row: RSI chart (with 70/30 lines) + EMA(12)/EMA(26) crossover chart
- Controls: horizon toggle buttons + keyboard `1`/`2` for 14d/30d

---