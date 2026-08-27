/*
  NEXUS 360 — Verification & Acceptance Tests
  Validates data volumes, AI enrichment, moments, health, NBA, and demo flow
*/

USE WAREHOUSE SHAN_WH;
USE DATABASE SFK_HACKATHON;
USE SCHEMA SFK_HACK_1;

----------------------------------------------------------------------
-- 1. Data Volume Checks
----------------------------------------------------------------------
SELECT 'CUSTOMER' AS TABLE_NAME, COUNT(*) AS ROW_COUNT, 10000 AS TARGET FROM CUSTOMER
UNION ALL
SELECT 'POLICY', COUNT(*), 25000 FROM POLICY
UNION ALL
SELECT 'CLAIM', COUNT(*), 15000 FROM CLAIM
UNION ALL
SELECT 'PAYMENT', COUNT(*), 60000 FROM PAYMENT
UNION ALL
SELECT 'INTERACTION', COUNT(*), 50000 FROM INTERACTION
UNION ALL
SELECT 'TRANSCRIPT', COUNT(*), 8000 FROM TRANSCRIPT
UNION ALL
SELECT 'EMAIL', COUNT(*), 10000 FROM EMAIL
UNION ALL
SELECT 'NOTE', COUNT(*), 12000 FROM NOTE
UNION ALL
SELECT 'SURVEY', COUNT(*), 5000 FROM SURVEY;

----------------------------------------------------------------------
-- 2. AI Enrichment Check
----------------------------------------------------------------------
SELECT
    'AI_ENRICHMENT' AS CHECK_NAME,
    COUNT(*) AS TOTAL_ENRICHMENTS,
    SUM(CASE WHEN SENTIMENT_SCORE IS NOT NULL THEN 1 ELSE 0 END) AS WITH_SENTIMENT,
    SUM(CASE WHEN ENTITIES IS NOT NULL THEN 1 ELSE 0 END) AS WITH_ENTITIES,
    SUM(CASE WHEN INTENTS IS NOT NULL THEN 1 ELSE 0 END) AS WITH_INTENTS,
    SUM(CASE WHEN CLASSIFICATION IS NOT NULL THEN 1 ELSE 0 END) AS WITH_CLASSIFICATION,
    SUM(CASE WHEN SUMMARY IS NOT NULL THEN 1 ELSE 0 END) AS WITH_SUMMARY
FROM CUSTOMER_AI_ENRICHMENT;

----------------------------------------------------------------------
-- 3. Customer Events Populated
----------------------------------------------------------------------
SELECT
    'CUSTOMER_EVENTS' AS CHECK_NAME,
    COUNT(*) AS TOTAL_EVENTS,
    COUNT(DISTINCT CUSTOMER_ID) AS UNIQUE_CUSTOMERS,
    COUNT(DISTINCT EVENT_TYPE) AS UNIQUE_EVENT_TYPES,
    COUNT(DISTINCT SOURCE_TABLE) AS SOURCE_TABLES
FROM CUSTOMER_EVENT;

----------------------------------------------------------------------
-- 4. Moments Detected
----------------------------------------------------------------------
SELECT
    'CUSTOMER_MOMENTS' AS CHECK_NAME,
    COUNT(*) AS TOTAL_MOMENTS,
    COUNT(DISTINCT CUSTOMER_ID) AS AFFECTED_CUSTOMERS,
    SUM(CASE WHEN MOMENT_TYPE = 'CHURN' THEN 1 ELSE 0 END) AS CHURN_MOMENTS,
    SUM(CASE WHEN MOMENT_TYPE = 'CLAIM_FRICTION' THEN 1 ELSE 0 END) AS FRICTION_MOMENTS,
    SUM(CASE WHEN MOMENT_TYPE = 'PRICE_SENSITIVITY' THEN 1 ELSE 0 END) AS PRICE_MOMENTS
FROM CUSTOMER_MOMENT;

----------------------------------------------------------------------
-- 5. Health Scores Generated
----------------------------------------------------------------------
SELECT
    'CUSTOMER_HEALTH' AS CHECK_NAME,
    COUNT(*) AS SCORED_CUSTOMERS,
    ROUND(AVG(HEALTH_SCORE), 2) AS AVG_HEALTH,
    ROUND(AVG(CHURN_RISK), 4) AS AVG_CHURN_RISK,
    SUM(CASE WHEN RISK_LEVEL = 'CRITICAL' THEN 1 ELSE 0 END) AS CRITICAL,
    SUM(CASE WHEN RISK_LEVEL = 'AT_RISK' THEN 1 ELSE 0 END) AS AT_RISK,
    SUM(CASE WHEN RISK_LEVEL = 'MONITOR' THEN 1 ELSE 0 END) AS MONITOR,
    SUM(CASE WHEN RISK_LEVEL = 'HEALTHY' THEN 1 ELSE 0 END) AS HEALTHY
FROM CUSTOMER_HEALTH;

----------------------------------------------------------------------
-- 6. NBA Recommendations Generated
----------------------------------------------------------------------
SELECT
    'NBA_RECOMMENDATIONS' AS CHECK_NAME,
    COUNT(*) AS TOTAL_ACTIONS,
    SUM(CASE WHEN ACTION_TYPE = 'RETENTION_OFFER' THEN 1 ELSE 0 END) AS RETENTION,
    SUM(CASE WHEN ACTION_TYPE = 'CLAIMS_ESCALATION' THEN 1 ELSE 0 END) AS CLAIMS_ESC,
    SUM(CASE WHEN ACTION_TYPE = 'COMPETITOR_RETENTION_CAMPAIGN' THEN 1 ELSE 0 END) AS COMPETITOR_RET,
    SUM(CASE WHEN ACTION_TYPE = 'CROSS_SELL' THEN 1 ELSE 0 END) AS CROSS_SELL,
    SUM(CASE WHEN ACTION_TYPE = 'PAYMENT_ASSISTANCE' THEN 1 ELSE 0 END) AS PAYMENT_ASSIST,
    SUM(CASE WHEN SUPPRESSED = TRUE THEN 1 ELSE 0 END) AS SUPPRESSED
FROM NEXT_BEST_ACTION;

----------------------------------------------------------------------
-- 7. End-to-End Demo Customer Check
----------------------------------------------------------------------
SELECT
    C.CUSTOMER_ID,
    C.FIRST_NAME || ' ' || C.LAST_NAME AS NAME,
    C.SEGMENT,
    H.HEALTH_SCORE,
    H.CHURN_RISK,
    H.RISK_LEVEL,
    (SELECT COUNT(*) FROM POLICY WHERE CUSTOMER_ID = C.CUSTOMER_ID) AS POLICIES,
    (SELECT COUNT(*) FROM CLAIM WHERE CUSTOMER_ID = C.CUSTOMER_ID) AS CLAIMS,
    (SELECT COUNT(*) FROM INTERACTION WHERE CUSTOMER_ID = C.CUSTOMER_ID) AS INTERACTIONS,
    (SELECT COUNT(*) FROM CUSTOMER_MOMENT WHERE CUSTOMER_ID = C.CUSTOMER_ID) AS MOMENTS,
    (SELECT COUNT(*) FROM NEXT_BEST_ACTION WHERE CUSTOMER_ID = C.CUSTOMER_ID AND SUPPRESSED = FALSE) AS NBAS
FROM CUSTOMER C
LEFT JOIN CUSTOMER_HEALTH H ON C.CUSTOMER_ID = H.CUSTOMER_ID
WHERE C.CUSTOMER_ID = 'CUST-000001';

----------------------------------------------------------------------
-- 8. Cortex Search Service Status
----------------------------------------------------------------------
SHOW CORTEX SEARCH SERVICES LIKE 'NEXUS360_EVIDENCE_SEARCH' IN SCHEMA SFK_HACKATHON.SFK_HACK_1;

----------------------------------------------------------------------
-- 9. Evidence Source View Count
----------------------------------------------------------------------
SELECT
    'EVIDENCE_SOURCE' AS CHECK_NAME,
    COUNT(*) AS TOTAL_DOCUMENTS,
    COUNT(DISTINCT CUSTOMER_ID) AS UNIQUE_CUSTOMERS,
    COUNT(DISTINCT SOURCE_TYPE) AS SOURCE_TYPES
FROM EVIDENCE_SOURCE;

----------------------------------------------------------------------
-- 10. Summary Report
----------------------------------------------------------------------
SELECT '=== NEXUS 360 VERIFICATION COMPLETE ===' AS STATUS;
