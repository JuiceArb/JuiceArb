<div align="center">

# 🧃 Juice

**Cross-Platform Prediction Market Arbitrage & +EV Detection Engine**

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat&logo=python&logoColor=white)](https://python.org)
[![Go](https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat&logo=go&logoColor=white)](https://golang.org)
[![Next.js](https://img.shields.io/badge/Next.js-14+-000000?style=flat&logo=nextdotjs&logoColor=white)](https://nextjs.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Neon-4169E1?style=flat&logo=postgresql&logoColor=white)](https://neon.tech)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)

*Built at Hacklanta · Georgia State University*

</div>

---

## Overview

**Juice** is a real-time intelligence engine that continuously monitors prediction markets across multiple platforms, identifies matching events using a three-layer NLP + LLM pipeline, and surfaces actionable arbitrage and positive expected value (+EV) opportunities on a live dashboard — faster than any human trader can.

Juice targets three classes of market inefficiencies:

| Type | Description |
|------|-------------|
| **Internal Arb** | YES + NO prices for the same event sum to < $1.00 across platforms → guaranteed profit regardless of outcome |
| **Cross-Platform Arb** | Identical event priced differently on Kalshi vs. Polymarket → instant edge |
| **+EV Detection** | Markets mispriced relative to true probability → statistically advantageous position |

---

## Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                      Data Ingestion Layer                   │
│   Python · Kalshi API · Polymarket Gamma · PredictIt · ODDS │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                   Matching Engine (Python)                  │
│  sentence-transformers → Date Guard → Gemini 2.5 Flash LLM  │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│               PostgreSQL on Neon (AWS us-east-1)            │
│            markets · matched_pairs · arb_opportunities      │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│              Arbitrage Calculator (Go · WebSocket)          │
│          Real-time spread calculation                       │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│               Live Dashboard (Next.js · Auth)               │
│         Real-time opportunity alerts · Portfolio view       │
└─────────────────────────────────────────────────────────────┘
```

---

## Three-Layer Matching Pipeline

Juice uses a progressive filtering pipeline to ensure only high-confidence, genuine arbitrage pairs reach the database.

### Layer 1 — NLP Cosine Similarity
Every market title is encoded using `sentence-transformers/all-MiniLM-L6-v2`. A cosine similarity matrix is computed across all cross-platform pairs. Only pairs scoring ≥ 0.75 advance to Layer 2.

### Layer 2 — Date Guard
End-date consistency is enforced. Pairs where market resolution dates are clearly mismatched are eliminated before expensive LLM verification.

### Layer 3 — Gemini 2.5 Flash LLM Verification
The remaining candidates are batched and sent to Gemini 2.5 Flash with a carefully engineered prompt. Gemini confirms whether both titles describe the **same underlying bet** — accounting for phrasing differences, platform-specific naming conventions, and edge cases (occurrence vs. outcome markets, different offices or roles, etc.). Only Gemini-confirmed pairs are written to the database.

Additional filters applied before Layer 1:
- **Volume ratio gate** — pairs where `max_volume / min_volume > 50` are skipped (scale mismatch signal)
- **Occurrence market filter** — markets asking "will X happen?" are not paired with markets asking "who wins X?"
- **Placeholder name filter** — anonymized markets ("Player U", "Person X") are excluded
- **Categorical market filter** — multi-outcome categoricals are not paired with binary contracts

---

## Performance

- **8 concurrent Gemini LLM batches** run in parallel via `ThreadPoolExecutor` + `asyncio.gather` — not sequentially
- **Incremental embedding cache** — only newly ingested markets are re-encoded per scan cycle
- **Alternating scan modes** — quick scans (3 event pages, ~30s) and full scans (15 event pages, ~5min) alternate on a configurable cadence (`FULL_SCAN_EVERY`)
- **Immediate DB writes** — each batch writes confirmed pairs to PostgreSQL as soon as it completes, without waiting for all batches to finish
- Handles **10,000+ active markets** across all platforms per full scan

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Data Ingestion | Python 3.11, `httpx`, `asyncpg` |
| NLP Matching | `sentence-transformers` (all-MiniLM-L6-v2), `numpy` cosine similarity |
| LLM Verification | Google Gemini 2.5 Flash (`google-genai`) |
| Database | PostgreSQL on [Neon](https://neon.tech) with SSL, `asyncpg` |
| Arb Calculator | Go 1.22, WebSocket (`gorilla/websocket`) |
| Dashboard | Next.js 14, TypeScript, Tailwind CSS |
| Auth | Next.js Auth |
| Platform APIs | Kalshi (RSA-PSS signed), Polymarket Gamma, PredictIt, The Odds API |

---

## Project Structure
```
JuiceArb/
├── MatchingEngine/
│   ├── scanner.py          # Main scan loop — orchestrates full pipeline
│   ├── matcher.py          # NLP matching engine + concurrent LLM verification
│   ├── llm_verify.py       # Gemini 2.5 Flash batch verification
│   ├── date_guard.py       # End-date consistency checker
│   ├── db.py               # asyncpg database utilities
│   ├── fetchers/
│   │   ├── kalshi.py       # Kalshi API client (RSA-PSS auth)
│   │   ├── polymarket.py   # Polymarket Gamma API client
│   │   ├── predictit.py    # PredictIt API client
│   │   └── odds.py         # The Odds API client
│   └── requirements.txt
├── ArbitrageEngine/        # Go WebSocket arb calculator
├── Dashboard/              # Next.js frontend
├── schema.sql              # PostgreSQL schema
└── README.md
```

---

## Getting Started

### Prerequisites

- Python 3.11+
- PostgreSQL database (recommended: [Neon](https://neon.tech) free tier)
- Gemini API key ([Google AI Studio](https://aistudio.google.com))
- Kalshi account + RSA key pair (for authenticated endpoints)
- The Odds API key (optional, for sportsbook data)

### Installation
```bash
git clone https://github.com/JuiceArb/JuiceArb.git
cd JuiceArb/MatchingEngine

python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

pip install -r requirements.txt
```

### Database Setup

Run the schema against your Neon (or any PostgreSQL) database:
```bash
psql "$DATABASE_URL" -f ../schema.sql
```

### Configuration

Copy `.env.example` to `.env` and fill in your credentials:
```env
# Database
DATABASE_URL=postgresql://user:password@host/dbname?sslmode=require

# Gemini LLM
GEMINI_API_KEY=your_gemini_api_key

# Kalshi
KALSHI_API_KEY_ID=your_kalshi_key_id
KALSHI_PRIVATE_KEY_PATH=./kalshi_private_key.pem

# The Odds API (optional)
ODDS_API_KEY=your_odds_api_key

# Scan tuning
POLYMARKET_MAX_EVENT_PAGES=15
KALSHI_SERIES_MAX_PAGES=12
KALSHI_EVENTS_MAX_PAGES=12
FULL_SCAN_EVERY=10

# Performance
TRANSFORMERS_OFFLINE=1   # Set after first model download to skip HuggingFace HEAD requests
```

### Running the Scanner
```bash
cd MatchingEngine
python scanner.py
```

The scanner will:
1. Fetch all active markets from configured platforms
2. Upsert new markets into PostgreSQL
3. Run the three-layer matching pipeline
4. Write confirmed arbitrage pairs to `matched_pairs`
5. Sleep and repeat (alternating quick/full scan modes)

---

## Kalshi Authentication

Kalshi's API requires RSA-PSS request signing. Generate your key pair:
```bash
openssl genrsa -out kalshi_private_key.pem 2048
openssl rsa -in kalshi_private_key.pem -pubout -out kalshi_public_key.pem
```

Upload `kalshi_public_key.pem` to your Kalshi account settings, then set `KALSHI_API_KEY_ID` in your `.env`.

> **Note:** Kalshi uses RSA-PSS with `MGF1(SHA-256)` padding — not PKCS1v15.

---

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | required | PostgreSQL connection string |
| `GEMINI_API_KEY` | required | Google Gemini API key |
| `KALSHI_API_KEY_ID` | required | Kalshi API key ID |
| `KALSHI_PRIVATE_KEY_PATH` | `./kalshi_private_key.pem` | Path to RSA private key |
| `ODDS_API_KEY` | optional | The Odds API key |
| `POLYMARKET_MAX_EVENT_PAGES` | `15` | Max event pages fetched per full Polymarket scan |
| `KALSHI_SERIES_MAX_PAGES` | `12` | Max pages per targeted Kalshi series |
| `KALSHI_EVENTS_MAX_PAGES` | `12` | Max pages for Kalshi events endpoint |
| `FULL_SCAN_EVERY` | `10` | Run a full scan every N cycles (others are quick scans) |
| `TRANSFORMERS_OFFLINE` | `0` | Set to `1` after first model download to prevent HuggingFace HEAD requests |

---

## Roadmap

- [ ] Automated trade execution via Kalshi and Polymarket APIs
- [ ] Kelly Criterion position sizing with confidence decay
- [ ] Portfolio-level risk controls and exposure limits
- [ ] Mobile push notifications for high-confidence arb alerts
- [ ] PredictIt and Manifold Markets deeper integration
- [ ] Backtesting framework for strategy validation
- [ ] Multi-user dashboard with team portfolios

---

## Team

| Name | Role |
|------|------|
| **Máté Dort** | Matching engine, NLP pipeline, Kalshi/Polymarket integrations |
| **Harrison Stadler** | Full-stack engineering, dashboard, infrastructure |
| **Stephen Sulimani** | Quantitative finance, arb math, backend development |

*Built at Hacklanta · Georgia State University*

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">
<sub>Juice — turning market inefficiency into a systematic edge.</sub>
</div>
