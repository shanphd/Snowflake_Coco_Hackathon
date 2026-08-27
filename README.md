# NEXUS 360 — AI-Powered Insurance Customer 360 Platform

An end-to-end insurance Customer 360 and employee decision-support platform built entirely on Snowflake. NEXUS 360 unifies structured customer data with unstructured interactions (transcripts, emails, notes, surveys), applies AI enrichment, detects customer moments, computes health scores, generates Next Best Action recommendations, and delivers an AI-powered employee copilot — all within Snowflake's ecosystem.

## Problem Statement

Insurance companies struggle with fragmented customer data across silos. NEXUS 360 provides:

- A unified 360-degree view of each customer
- Automated detection of churn risk, claim friction, and price sensitivity
- AI-driven Next Best Action recommendations with human-in-the-loop approval
- Natural language querying of portfolio analytics
- Evidence-grounded decision support for employees (Retention Managers, Claims Analysts, Service Agents)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         NEXUS 360 — Architecture                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                    Streamlit-in-Snowflake (5 Pages)                       │   │
│  │  Portfolio │ Customer 360 │ Employee Copilot │ NBA Dashboard │ Simulation │   │
│  └──────────────────────────────┬───────────────────────────────────────────┘   │
│                                 │                                               │
│  ┌──────────────────────────────▼───────────────────────────────────────────┐   │
│  │                         Cortex Agent                                      │   │
│  │              (NEXUS360_AGENT — Role-Aware Copilot)                        │   │
│  │                                                                           │   │
│  │    ┌─────────────────┐          ┌─────────────────────────┐              │   │
│  │    │  Cortex Analyst  │          │     Cortex Search        │              │   │
│  │    │  (Text-to-SQL)   │          │  (Evidence Retrieval)    │              │   │
│  │    │  Semantic View:  │          │  NEXUS360_EVIDENCE_SEARCH│              │   │
│  │    │  NEXUS360_       │          │  (transcripts, emails,   │              │   │
│  │    │  ANALYTICS       │          │   notes, surveys)        │              │   │
│  │    └─────────────────┘          └─────────────────────────┘              │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                      AI Enrichment Layer                                  │   │
│  │  Cortex SENTIMENT │ Cortex COMPLETE (mistral-large2)                      │   │
│  │  Entity Extraction │ Intent Detection │ Classification │ Summarization    │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                      Processing Engine                                    │   │
│  │  Event Stream │ Moment Detection │ Health Scoring │ NBA Generation        │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                      Data Layer (15 Tables)                               │   │
│  │  CUSTOMER │ POLICY │ CLAIM │ PAYMENT │ INTERACTION │ TRANSCRIPT           │   │
│  │  EMAIL │ NOTE │ SURVEY │ CUSTOMER_EVENT │ CUSTOMER_MOMENT                 │   │
│  │  CUSTOMER_HEALTH │ NEXT_BEST_ACTION │ NEXT_BEST_ACTION_LOG               │   │
│  │  CUSTOMER_AI_ENRICHMENT                                                   │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  Database: SFK_HACKATHON │ Schema: SFK_HACK_1 │ Warehouse: SHAN_WH             │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Snowflake Features Used

| Feature | Usage |
|---------|-------|
| **Cortex AI — SENTIMENT** | Sentiment scoring on transcripts and emails |
| **Cortex AI — COMPLETE (mistral-large2)** | Entity extraction, intent detection, classification, summarization |
| **Cortex Search Service** | Full-text evidence retrieval with metadata filtering |
| **Cortex Analyst (Semantic View)** | Text-to-SQL portfolio analytics |
| **Cortex Agent** | Orchestrates Analyst + Search as tools; role-aware copilot |
| **Streamlit-in-Snowflake** | 5-page interactive dashboard |
| **Stored Procedures** | Event population, moment detection, health scoring, NBA engine |
| **UDFs** | `CUSTOMER_360_LOOKUP`, `GET_NBA_RECOMMENDATION` |
| **Synthetic Data Generation** | `TABLE(GENERATOR(ROWCOUNT => N))` |

## Project Structure

```
├── sql/
│   ├── 01_schema_and_tables.sql      # Database, schema, and 15 tables
│   ├── 02_synthetic_data.sql          # Generate ~185K rows of synthetic insurance data
│   ├── 03_ai_enrichment.sql           # AI enrichment procedures (sentiment, NER, intent)
│   ├── 04_events_moments_health.sql   # Event stream, moment detection, health scoring
│   ├── 05_nba_engine.sql              # Next Best Action generation and approval workflow
│   ├── 06_cortex_search.sql           # Evidence source view + Cortex Search service
│   ├── 07_cortex_analyst.sql          # Semantic model upload + Cortex Analyst setup
│   ├── 08_cortex_agent.sql            # UDFs, semantic view, and Cortex Agent creation
│   ├── 09_deploy_streamlit.sql        # Stage creation and Streamlit deployment
│   └── 10_verification.sql            # End-to-end validation checks
├── semantic_model/
│   └── nexus360_analyst.yaml          # Cortex Analyst semantic model definition
├── streamlit/
│   ├── nexus360_app.py                # Streamlit application (5 pages)
│   └── environment.yml                # Python dependencies
├── NEXUS_360_CoCo_CLI_Hackathon_6_Slide_Deck.pptx  # Presentation
└── README.md
```

## Prerequisites

- Snowflake account with access to:
  - Cortex AI functions (`SENTIMENT`, `COMPLETE` with `mistral-large2`)
  - Cortex Search
  - Cortex Agent
  - Streamlit-in-Snowflake
- A warehouse (default: `SHAN_WH`)
- SnowSQL or Snowsight SQL worksheet access
- Permissions to create databases, schemas, stages, procedures, and UDFs

## Implementation Steps

Execute the SQL scripts in order (01 through 10). Each script builds on the previous one.

### Step 1: Create Schema and Tables

```sql
-- Run sql/01_schema_and_tables.sql
-- Creates database SFK_HACKATHON, schema SFK_HACK_1, and 15 tables
```

### Step 2: Generate Synthetic Data

```sql
-- Run sql/02_synthetic_data.sql
-- Populates ~185K rows across all tables:
--   CUSTOMER (10K), POLICY (25K), CLAIM (15K), PAYMENT (60K),
--   INTERACTION (50K), TRANSCRIPT (8K), EMAIL (10K), NOTE (12K), SURVEY (5K)
```

### Step 3: Run AI Enrichment

```sql
-- Run sql/03_ai_enrichment.sql
-- Then execute:
CALL RUN_ALL_ENRICHMENT();
-- Applies sentiment analysis, entity extraction, intent detection,
-- classification, and summarization across unstructured data
```

### Step 4: Build Events, Moments, and Health Scores

```sql
-- Run sql/04_events_moments_health.sql
-- Then execute:
CALL RUN_EVENTS_MOMENTS_HEALTH();
-- Populates CUSTOMER_EVENT (~150K+), detects CUSTOMER_MOMENT entries,
-- and calculates CUSTOMER_HEALTH scores (composite 0-100)
```

### Step 5: Generate Next Best Actions

```sql
-- Run sql/05_nba_engine.sql
-- Then execute:
CALL GENERATE_NBA_RECOMMENDATIONS();
-- Generates recommendations based on 5 rules:
--   RETENTION_OFFER, CLAIMS_ESCALATION, COMPETITOR_RETENTION_CAMPAIGN,
--   CROSS_SELL, PAYMENT_ASSISTANCE
```

### Step 6: Create Cortex Search Service

```sql
-- Run sql/06_cortex_search.sql
-- Creates EVIDENCE_SOURCE view and NEXUS360_EVIDENCE_SEARCH service
-- Enables full-text search across transcripts, emails, notes, surveys
```

### Step 7: Deploy Cortex Analyst

```sql
-- Run sql/07_cortex_analyst.sql
-- Upload semantic model:
PUT file://semantic_model/nexus360_analyst.yaml @NEXUS360_SEMANTIC_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
```

### Step 8: Create Cortex Agent

```sql
-- Run sql/08_cortex_agent.sql
-- Creates UDFs (CUSTOMER_360_LOOKUP, GET_NBA_RECOMMENDATION),
-- semantic view NEXUS360_ANALYTICS, and NEXUS360_AGENT
```

### Step 9: Deploy Streamlit Application

```sql
-- Run sql/09_deploy_streamlit.sql
-- Upload application files:
PUT file://streamlit/nexus360_app.py @NEXUS360_STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://streamlit/environment.yml @NEXUS360_STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- Creates NEXUS360_APP Streamlit application
```

### Step 10: Verify Deployment

```sql
-- Run sql/10_verification.sql
-- Validates data volumes, enrichment results, event/moment/health/NBA outputs,
-- and performs end-to-end demo verification
```

## Application Pages

| Page | Description |
|------|-------------|
| **Portfolio View** | KPIs (total customers, avg health, avg churn, critical alerts), risk distribution, health by segment |
| **Customer 360** | Deep-dive per customer: health metrics, policies, claims, timeline, evidence, NBA |
| **Employee Copilot** | Chat interface with `NEXUS360_AGENT`; role selector (Retention Manager, Claims Analyst, Service Agent) |
| **NBA Dashboard** | Action queue with filters, approve/reject workflow, effectiveness tracking |
| **Real-Time Simulation** | Inject interactions and observe health/risk/NBA updates live |

## Health Score Model

Weighted composite score (0–100):

| Component | Weight |
|-----------|--------|
| Sentiment Score | 25% |
| Claims Score | 20% |
| Payment Score | 20% |
| Engagement Score | 15% |
| (1 − Churn Risk) × 100 | 20% |

Risk levels: **CRITICAL** (>=0.7) | **AT_RISK** (>=0.4) | **MONITOR** (>=0.2) | **HEALTHY** (<0.2)

## NBA Engine Rules

| # | Condition | Action | Priority |
|---|-----------|--------|----------|
| 1 | High churn risk + negative sentiment + renewal < 60 days | `RETENTION_OFFER` | 1 |
| 2 | Open claim > 14 days + negative sentiment | `CLAIMS_ESCALATION` | 2 |
| 3 | Competitor mention + renewal < 45 days | `COMPETITOR_RETENTION_CAMPAIGN` | 2 |
| 4 | Premium/Enterprise + positive sentiment + healthy | `CROSS_SELL` | 3 |
| 5 | 2+ payment failures in last 3 months | `PAYMENT_ASSISTANCE` | 2 |

## Demo Flow

```
Portfolio → Ask → Open Customer → Timeline → Evidence → NBA → Approve → Simulate → Outcome
```

## License

This project was built for the Snowflake CoCo CLI Hackathon.
