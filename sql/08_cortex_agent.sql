/*
  NEXUS 360 — Cortex Agent & UDF Tools
  UDFs for customer lookup, NBA retrieval
  Cortex Agent combining Analyst (semantic view) and Search tools
*/

USE WAREHOUSE SHAN_WH;
USE DATABASE SFK_HACKATHON;
USE SCHEMA SFK_HACK_1;

----------------------------------------------------------------------
-- 1. UDF: CUSTOMER_360_LOOKUP
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION CUSTOMER_360_LOOKUP(CUST_ID VARCHAR)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    SELECT OBJECT_CONSTRUCT(
        'customer', (SELECT OBJECT_CONSTRUCT('customer_id', CUSTOMER_ID, 'name', FIRST_NAME || ' ' || LAST_NAME, 'email', EMAIL, 'segment', SEGMENT, 'region', REGION, 'state', STATE, 'tenure_months', TENURE_MONTHS, 'lifetime_value', LIFETIME_VALUE) FROM CUSTOMER WHERE CUSTOMER_ID = CUST_ID),
        'health', (SELECT OBJECT_CONSTRUCT('health_score', HEALTH_SCORE, 'churn_risk', CHURN_RISK, 'risk_level', RISK_LEVEL, 'sentiment_score', SENTIMENT_SCORE, 'claims_score', CLAIMS_SCORE, 'payment_score', PAYMENT_SCORE, 'engagement_score', ENGAGEMENT_SCORE) FROM CUSTOMER_HEALTH WHERE CUSTOMER_ID = CUST_ID),
        'active_moments', (SELECT ARRAY_AGG(OBJECT_CONSTRUCT('moment_type', MOMENT_TYPE, 'confidence', CONFIDENCE, 'detected_at', DETECTED_AT, 'context', CONTEXT)) FROM CUSTOMER_MOMENT WHERE CUSTOMER_ID = CUST_ID AND (EXPIRES_AT IS NULL OR EXPIRES_AT > CURRENT_TIMESTAMP())),
        'policies', (SELECT ARRAY_AGG(OBJECT_CONSTRUCT('policy_id', POLICY_ID, 'policy_type', POLICY_TYPE, 'premium', PREMIUM_AMOUNT, 'status', STATUS, 'end_date', END_DATE)) FROM POLICY WHERE CUSTOMER_ID = CUST_ID),
        'recent_claims', (SELECT ARRAY_AGG(OBJECT_CONSTRUCT('claim_id', CLAIM_ID, 'claim_type', CLAIM_TYPE, 'amount', CLAIM_AMOUNT, 'status', STATUS, 'filed_date', FILED_DATE)) FROM CLAIM WHERE CUSTOMER_ID = CUST_ID AND FILED_DATE >= DATEADD('month', -6, CURRENT_DATE()))
    )
$$;

----------------------------------------------------------------------
-- 2. UDF: GET_NBA_RECOMMENDATION
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION GET_NBA_RECOMMENDATION(CUST_ID VARCHAR)
RETURNS ARRAY
LANGUAGE SQL
AS
$$
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
        'action_id', ACTION_ID, 'action_type', ACTION_TYPE, 'confidence', CONFIDENCE,
        'rationale', RATIONALE, 'priority', PRIORITY, 'status', STATUS, 'evidence', EVIDENCE
    ))
    FROM NEXT_BEST_ACTION
    WHERE CUSTOMER_ID = CUST_ID AND SUPPRESSED = FALSE AND STATUS = 'PENDING'
      AND (EXPIRES_AT IS NULL OR EXPIRES_AT > CURRENT_TIMESTAMP())
$$;

----------------------------------------------------------------------
-- 3. Semantic View (for Cortex Analyst)
----------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW NEXUS360_ANALYTICS
  TABLES (
    customer_health AS SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH
      PRIMARY KEY (CUSTOMER_ID) COMMENT = 'Customer health scores and risk levels',
    customers AS SFK_HACKATHON.SFK_HACK_1.CUSTOMER
      PRIMARY KEY (CUSTOMER_ID) COMMENT = 'Customer master data',
    nba AS SFK_HACKATHON.SFK_HACK_1.NEXT_BEST_ACTION
      PRIMARY KEY (ACTION_ID) COMMENT = 'Current NBA recommendations'
  )
  RELATIONSHIPS (
    health_to_customer AS customer_health (CUSTOMER_ID) REFERENCES customers,
    nba_to_customer AS nba (CUSTOMER_ID) REFERENCES customers
  )
  DIMENSIONS (
    customer_health.risk_level AS RISK_LEVEL WITH SYNONYMS = ('risk category') COMMENT = 'Risk level: CRITICAL, AT_RISK, MONITOR, HEALTHY',
    customers.segment AS SEGMENT WITH SYNONYMS = ('customer segment', 'tier') COMMENT = 'Customer segment',
    customers.region AS REGION WITH SYNONYMS = ('geographic region') COMMENT = 'Customer region',
    nba.action_type AS ACTION_TYPE WITH SYNONYMS = ('action', 'recommendation type') COMMENT = 'NBA action type',
    nba.nba_status AS STATUS WITH SYNONYMS = ('action status') COMMENT = 'NBA status'
  )
  METRICS (
    customer_health.customer_count AS COUNT(DISTINCT customer_health.CUSTOMER_ID) WITH SYNONYMS = ('total customers') COMMENT = 'Unique customer count',
    customer_health.avg_health AS AVG(customer_health.HEALTH_SCORE) WITH SYNONYMS = ('average health') COMMENT = 'Average health score (0-100)',
    customer_health.avg_churn_risk AS AVG(customer_health.CHURN_RISK) WITH SYNONYMS = ('average churn risk') COMMENT = 'Average churn risk (0-1)',
    customer_health.critical_count AS COUNT_IF(customer_health.RISK_LEVEL = 'CRITICAL') WITH SYNONYMS = ('critical alerts') COMMENT = 'Critical risk customer count',
    nba.action_count AS COUNT(DISTINCT nba.ACTION_ID) WITH SYNONYMS = ('recommendation count') COMMENT = 'NBA recommendation count'
  );

----------------------------------------------------------------------
-- 4. Cortex Agent
----------------------------------------------------------------------
CREATE OR REPLACE AGENT NEXUS360_AGENT
  COMMENT = 'NEXUS 360 Insurance Customer 360 AI Employee Copilot'
  PROFILE = '{"display_name": "NEXUS 360 Copilot", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    budget:
      seconds: 60
      tokens: 32000

  instructions:
    response: "You are the NEXUS 360 AI Employee Copilot for an insurance company. Help employees make informed decisions about customer relationships, risk management, and next best actions. Support three roles: Retention Manager (churn prevention, health trends), Claims Analyst (claims status, escalations), Service Agent (customer lookup, policy details). Always ground answers in data, cite evidence, recommend actions, and flag critical situations."
    orchestration: "For portfolio-level metrics use Analyst. For customer evidence/interactions use EvidenceSearch."
    sample_questions:
      - question: "How many customers are at critical risk?"
      - question: "What is the average health score by segment?"
      - question: "What is the churn rate by region?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "Analyst"
        description: "Answers portfolio-level analytics questions about customer health, churn risk, NBA effectiveness"
    - tool_spec:
        type: "cortex_search"
        name: "EvidenceSearch"
        description: "Searches customer transcripts, emails, notes, and surveys for supporting evidence"

  tool_resources:
    Analyst:
      semantic_view: "SFK_HACKATHON.SFK_HACK_1.NEXUS360_ANALYTICS"
    EvidenceSearch:
      search_service: "SFK_HACKATHON.SFK_HACK_1.NEXUS360_EVIDENCE_SEARCH"
      max_results: "5"
  $$;
