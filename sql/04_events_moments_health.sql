/*
  NEXUS 360 — Event Stream, Moment Detection & Health Scoring
  1. Populate CUSTOMER_EVENT from all source tables
  2. Business-rule moment detection
  3. Composite health score calculation
*/

USE WAREHOUSE SHAN_WH;
USE DATABASE SFK_HACKATHON;
USE SCHEMA SFK_HACK_1;

----------------------------------------------------------------------
-- 1. Populate CUSTOMER_EVENT from all source tables
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE POPULATE_CUSTOMER_EVENTS()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    TRUNCATE TABLE CUSTOMER_EVENT;

    -- Policy events
    INSERT INTO CUSTOMER_EVENT (EVENT_ID, CUSTOMER_ID, EVENT_TYPE, EVENT_TIMESTAMP, SOURCE_TABLE, SOURCE_ID, EVENT_PAYLOAD)
    SELECT
        'EVT-POL-' || POLICY_ID,
        CUSTOMER_ID,
        CASE STATUS
            WHEN 'Active' THEN 'POLICY_ACTIVE'
            WHEN 'Cancelled' THEN 'POLICY_CANCELLED'
            WHEN 'Expired' THEN 'POLICY_EXPIRED'
            ELSE 'POLICY_CREATED'
        END,
        CREATED_AT,
        'POLICY',
        POLICY_ID,
        OBJECT_CONSTRUCT('policy_type', POLICY_TYPE, 'premium', PREMIUM_AMOUNT, 'status', STATUS)
    FROM POLICY;

    -- Claim events
    INSERT INTO CUSTOMER_EVENT (EVENT_ID, CUSTOMER_ID, EVENT_TYPE, EVENT_TIMESTAMP, SOURCE_TABLE, SOURCE_ID, EVENT_PAYLOAD)
    SELECT
        'EVT-CLM-' || CLAIM_ID,
        CUSTOMER_ID,
        CASE STATUS
            WHEN 'Open' THEN 'CLAIM_FILED'
            WHEN 'Under Review' THEN 'CLAIM_REVIEW'
            WHEN 'Approved' THEN 'CLAIM_APPROVED'
            WHEN 'Denied' THEN 'CLAIM_DENIED'
            WHEN 'Settled' THEN 'CLAIM_SETTLED'
            ELSE 'CLAIM_CLOSED'
        END,
        COALESCE(CREATED_AT, CURRENT_TIMESTAMP()),
        'CLAIM',
        CLAIM_ID,
        OBJECT_CONSTRUCT('claim_type', CLAIM_TYPE, 'amount', CLAIM_AMOUNT, 'status', STATUS, 'resolution_days', RESOLUTION_DAYS)
    FROM CLAIM;

    -- Payment events
    INSERT INTO CUSTOMER_EVENT (EVENT_ID, CUSTOMER_ID, EVENT_TYPE, EVENT_TIMESTAMP, SOURCE_TABLE, SOURCE_ID, EVENT_PAYLOAD)
    SELECT
        'EVT-PAY-' || PAYMENT_ID,
        CUSTOMER_ID,
        CASE STATUS
            WHEN 'Completed' THEN 'PAYMENT_SUCCESS'
            WHEN 'Failed' THEN 'PAYMENT_FAILED'
            WHEN 'Refunded' THEN 'PAYMENT_REFUNDED'
            ELSE 'PAYMENT_PENDING'
        END,
        COALESCE(CREATED_AT, CURRENT_TIMESTAMP()),
        'PAYMENT',
        PAYMENT_ID,
        OBJECT_CONSTRUCT('amount', AMOUNT, 'status', STATUS, 'method', PAYMENT_METHOD, 'failure_reason', FAILURE_REASON)
    FROM PAYMENT;

    -- Interaction events
    INSERT INTO CUSTOMER_EVENT (EVENT_ID, CUSTOMER_ID, EVENT_TYPE, EVENT_TIMESTAMP, SOURCE_TABLE, SOURCE_ID, EVENT_PAYLOAD)
    SELECT
        'EVT-INT-' || INTERACTION_ID,
        CUSTOMER_ID,
        'INTERACTION_' || UPPER(CHANNEL),
        INTERACTION_DATE,
        'INTERACTION',
        INTERACTION_ID,
        OBJECT_CONSTRUCT('channel', CHANNEL, 'direction', DIRECTION, 'topic', TOPIC, 'disposition', DISPOSITION)
    FROM INTERACTION;

    -- Survey events
    INSERT INTO CUSTOMER_EVENT (EVENT_ID, CUSTOMER_ID, EVENT_TYPE, EVENT_TIMESTAMP, SOURCE_TABLE, SOURCE_ID, EVENT_PAYLOAD)
    SELECT
        'EVT-SRV-' || SURVEY_ID,
        CUSTOMER_ID,
        'SURVEY_SUBMITTED',
        SUBMITTED_AT,
        'SURVEY',
        SURVEY_ID,
        OBJECT_CONSTRUCT('survey_type', SURVEY_TYPE, 'nps_score', NPS_SCORE, 'csat_score', CSAT_SCORE)
    FROM SURVEY;

    RETURN 'Customer events populated from all source tables';
END;
$$;

----------------------------------------------------------------------
-- 2. Business-Rule Moment Detection
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DETECT_CUSTOMER_MOMENTS()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    TRUNCATE TABLE CUSTOMER_MOMENT;

    -- CHURN: Competitor mention + renewal < 45 days
    INSERT INTO CUSTOMER_MOMENT (MOMENT_ID, CUSTOMER_ID, MOMENT_TYPE, DETECTED_AT, CONFIDENCE, CONTEXT, SOURCE_EVENT_ID, EXPIRES_AT)
    SELECT DISTINCT
        'MOM-CHR-' || E.CUSTOMER_ID || '-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        E.CUSTOMER_ID,
        'CHURN',
        CURRENT_TIMESTAMP(),
        0.85,
        OBJECT_CONSTRUCT(
            'reason', 'Competitor mentioned with renewal approaching',
            'renewal_days', DATEDIFF('day', CURRENT_DATE(), P.END_DATE),
            'source', 'AI enrichment + policy data'
        ),
        E.ENRICHMENT_ID,
        DATEADD('day', 30, CURRENT_TIMESTAMP())
    FROM CUSTOMER_AI_ENRICHMENT E
    JOIN POLICY P ON E.CUSTOMER_ID = P.CUSTOMER_ID AND P.STATUS = 'Active'
    WHERE E.ENTITIES IS NOT NULL
      AND ARRAY_SIZE(E.ENTITIES:competitors) > 0
      AND DATEDIFF('day', CURRENT_DATE(), P.END_DATE) <= 45
      AND DATEDIFF('day', CURRENT_DATE(), P.END_DATE) > 0;

    -- CHURN: Negative sentiment + cancellation intent
    INSERT INTO CUSTOMER_MOMENT (MOMENT_ID, CUSTOMER_ID, MOMENT_TYPE, DETECTED_AT, CONFIDENCE, CONTEXT, SOURCE_EVENT_ID, EXPIRES_AT)
    SELECT DISTINCT
        'MOM-CHR2-' || E.CUSTOMER_ID || '-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        E.CUSTOMER_ID,
        'CHURN',
        CURRENT_TIMESTAMP(),
        0.90,
        OBJECT_CONSTRUCT(
            'reason', 'Negative sentiment with cancellation intent detected',
            'sentiment_score', E.SENTIMENT_SCORE,
            'source', 'Sentiment + intent analysis'
        ),
        E.ENRICHMENT_ID,
        DATEADD('day', 14, CURRENT_TIMESTAMP())
    FROM CUSTOMER_AI_ENRICHMENT E
    WHERE E.SENTIMENT_SCORE < -0.3
      AND E.INTENTS:cancellation_intent::BOOLEAN = TRUE
      AND E.CUSTOMER_ID NOT IN (SELECT CUSTOMER_ID FROM CUSTOMER_MOMENT WHERE MOMENT_TYPE = 'CHURN');

    -- CLAIM_FRICTION: Open claim > 14 days + negative sentiment
    INSERT INTO CUSTOMER_MOMENT (MOMENT_ID, CUSTOMER_ID, MOMENT_TYPE, DETECTED_AT, CONFIDENCE, CONTEXT, SOURCE_EVENT_ID, EXPIRES_AT)
    SELECT DISTINCT
        'MOM-CF-' || C.CUSTOMER_ID || '-' || C.CLAIM_ID,
        C.CUSTOMER_ID,
        'CLAIM_FRICTION',
        CURRENT_TIMESTAMP(),
        0.80,
        OBJECT_CONSTRUCT(
            'reason', 'Open claim exceeding 14 days with negative customer sentiment',
            'claim_id', C.CLAIM_ID,
            'days_open', DATEDIFF('day', C.FILED_DATE, CURRENT_DATE()),
            'avg_sentiment', AVG_SENT.AVG_SENTIMENT
        ),
        'EVT-CLM-' || C.CLAIM_ID,
        DATEADD('day', 7, CURRENT_TIMESTAMP())
    FROM CLAIM C
    JOIN (
        SELECT CUSTOMER_ID, AVG(SENTIMENT_SCORE) AS AVG_SENTIMENT
        FROM CUSTOMER_AI_ENRICHMENT
        WHERE SENTIMENT_SCORE IS NOT NULL
        GROUP BY CUSTOMER_ID
        HAVING AVG(SENTIMENT_SCORE) < -0.2
    ) AVG_SENT ON C.CUSTOMER_ID = AVG_SENT.CUSTOMER_ID
    WHERE C.STATUS IN ('Open', 'Under Review')
      AND DATEDIFF('day', C.FILED_DATE, CURRENT_DATE()) > 14;

    -- PRICE_SENSITIVITY: Price concerns in intents or low NPS with cost mentions
    INSERT INTO CUSTOMER_MOMENT (MOMENT_ID, CUSTOMER_ID, MOMENT_TYPE, DETECTED_AT, CONFIDENCE, CONTEXT, SOURCE_EVENT_ID, EXPIRES_AT)
    SELECT DISTINCT
        'MOM-PS-' || E.CUSTOMER_ID || '-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        E.CUSTOMER_ID,
        'PRICE_SENSITIVITY',
        CURRENT_TIMESTAMP(),
        0.75,
        OBJECT_CONSTRUCT(
            'reason', 'Customer expressed price sensitivity or cost concerns',
            'source', 'Intent analysis'
        ),
        E.ENRICHMENT_ID,
        DATEADD('day', 30, CURRENT_TIMESTAMP())
    FROM CUSTOMER_AI_ENRICHMENT E
    WHERE E.INTENTS:price_sensitivity::BOOLEAN = TRUE
      AND E.CUSTOMER_ID NOT IN (SELECT CUSTOMER_ID FROM CUSTOMER_MOMENT WHERE MOMENT_TYPE = 'PRICE_SENSITIVITY');

    RETURN 'Customer moments detected';
END;
$$;

----------------------------------------------------------------------
-- 3. Composite Health Score Calculation
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CALCULATE_CUSTOMER_HEALTH()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    TRUNCATE TABLE CUSTOMER_HEALTH;

    INSERT INTO CUSTOMER_HEALTH (
        CUSTOMER_ID, HEALTH_SCORE, CHURN_RISK, SENTIMENT_SCORE,
        CLAIMS_SCORE, PAYMENT_SCORE, ENGAGEMENT_SCORE, RISK_LEVEL, SCORED_AT
    )
    WITH SENTIMENT_AGG AS (
        SELECT
            CUSTOMER_ID,
            AVG(SENTIMENT_SCORE) AS AVG_SENTIMENT,
            COUNT(*) AS SENTIMENT_COUNT
        FROM CUSTOMER_AI_ENRICHMENT
        WHERE SENTIMENT_SCORE IS NOT NULL
        GROUP BY CUSTOMER_ID
    ),
    CLAIMS_AGG AS (
        SELECT
            CUSTOMER_ID,
            COUNT(*) AS TOTAL_CLAIMS,
            SUM(CASE WHEN STATUS IN ('Open', 'Under Review') THEN 1 ELSE 0 END) AS OPEN_CLAIMS,
            SUM(CASE WHEN STATUS = 'Denied' THEN 1 ELSE 0 END) AS DENIED_CLAIMS,
            AVG(RESOLUTION_DAYS) AS AVG_RESOLUTION
        FROM CLAIM
        GROUP BY CUSTOMER_ID
    ),
    PAYMENT_AGG AS (
        SELECT
            CUSTOMER_ID,
            COUNT(*) AS TOTAL_PAYMENTS,
            SUM(CASE WHEN STATUS = 'Failed' THEN 1 ELSE 0 END) AS FAILED_PAYMENTS,
            SUM(CASE WHEN STATUS = 'Failed' THEN 1.0 ELSE 0.0 END) / NULLIF(COUNT(*), 0) AS FAILURE_RATE
        FROM PAYMENT
        GROUP BY CUSTOMER_ID
    ),
    ENGAGEMENT_AGG AS (
        SELECT
            CUSTOMER_ID,
            COUNT(*) AS INTERACTION_COUNT,
            MAX(INTERACTION_DATE) AS LAST_INTERACTION,
            DATEDIFF('day', MAX(INTERACTION_DATE), CURRENT_TIMESTAMP()) AS DAYS_SINCE_LAST
        FROM INTERACTION
        GROUP BY CUSTOMER_ID
    ),
    MOMENT_AGG AS (
        SELECT
            CUSTOMER_ID,
            SUM(CASE WHEN MOMENT_TYPE = 'CHURN' THEN 1 ELSE 0 END) AS CHURN_MOMENTS,
            COUNT(*) AS TOTAL_MOMENTS
        FROM CUSTOMER_MOMENT
        GROUP BY CUSTOMER_ID
    ),
    SCORES AS (
        SELECT
            C.CUSTOMER_ID,
            -- Sentiment score (0-100, higher is better)
            COALESCE(GREATEST(0, LEAST(100, 50 + (S.AVG_SENTIMENT * 50))), 50) AS SENTIMENT_SCORE,
            -- Claims score (0-100, higher is better = fewer problems)
            COALESCE(GREATEST(0, LEAST(100,
                100 - (CL.OPEN_CLAIMS * 15) - (CL.DENIED_CLAIMS * 10) - LEAST(CL.AVG_RESOLUTION, 60) * 0.5
            )), 80) AS CLAIMS_SCORE,
            -- Payment score (0-100, higher is better)
            COALESCE(GREATEST(0, LEAST(100,
                100 - (PA.FAILURE_RATE * 200)
            )), 90) AS PAYMENT_SCORE,
            -- Engagement score (0-100, higher is better)
            COALESCE(GREATEST(0, LEAST(100,
                CASE
                    WHEN E.DAYS_SINCE_LAST <= 7 THEN 95
                    WHEN E.DAYS_SINCE_LAST <= 30 THEN 80
                    WHEN E.DAYS_SINCE_LAST <= 90 THEN 60
                    WHEN E.DAYS_SINCE_LAST <= 180 THEN 40
                    ELSE 20
                END
            )), 50) AS ENGAGEMENT_SCORE,
            -- Churn risk (0-1, higher is worse)
            COALESCE(
                LEAST(1.0,
                    (CASE WHEN M.CHURN_MOMENTS > 0 THEN 0.4 ELSE 0 END) +
                    (CASE WHEN S.AVG_SENTIMENT < -0.3 THEN 0.2 ELSE 0 END) +
                    (CASE WHEN PA.FAILURE_RATE > 0.2 THEN 0.15 ELSE 0 END) +
                    (CASE WHEN CL.OPEN_CLAIMS > 2 THEN 0.15 ELSE 0 END) +
                    (CASE WHEN E.DAYS_SINCE_LAST > 90 THEN 0.1 ELSE 0 END)
                ),
                0.1
            ) AS CHURN_RISK
        FROM CUSTOMER C
        LEFT JOIN SENTIMENT_AGG S ON C.CUSTOMER_ID = S.CUSTOMER_ID
        LEFT JOIN CLAIMS_AGG CL ON C.CUSTOMER_ID = CL.CUSTOMER_ID
        LEFT JOIN PAYMENT_AGG PA ON C.CUSTOMER_ID = PA.CUSTOMER_ID
        LEFT JOIN ENGAGEMENT_AGG E ON C.CUSTOMER_ID = E.CUSTOMER_ID
        LEFT JOIN MOMENT_AGG M ON C.CUSTOMER_ID = M.CUSTOMER_ID
    )
    SELECT
        CUSTOMER_ID,
        -- Composite health score: weighted average (0-100)
        ROUND(
            (SENTIMENT_SCORE * 0.25) +
            (CLAIMS_SCORE * 0.20) +
            (PAYMENT_SCORE * 0.20) +
            (ENGAGEMENT_SCORE * 0.15) +
            ((1 - CHURN_RISK) * 100 * 0.20),
            2
        ) AS HEALTH_SCORE,
        ROUND(CHURN_RISK, 4) AS CHURN_RISK,
        ROUND(SENTIMENT_SCORE, 2) AS SENTIMENT_SCORE,
        ROUND(CLAIMS_SCORE, 2) AS CLAIMS_SCORE,
        ROUND(PAYMENT_SCORE, 2) AS PAYMENT_SCORE,
        ROUND(ENGAGEMENT_SCORE, 2) AS ENGAGEMENT_SCORE,
        CASE
            WHEN CHURN_RISK >= 0.7 THEN 'CRITICAL'
            WHEN CHURN_RISK >= 0.4 THEN 'AT_RISK'
            WHEN CHURN_RISK >= 0.2 THEN 'MONITOR'
            ELSE 'HEALTHY'
        END AS RISK_LEVEL,
        CURRENT_TIMESTAMP() AS SCORED_AT
    FROM SCORES;

    RETURN 'Customer health scores calculated';
END;
$$;

----------------------------------------------------------------------
-- 4. Master Procedure: Run all event/moment/health logic
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE RUN_EVENTS_MOMENTS_HEALTH()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    CALL POPULATE_CUSTOMER_EVENTS();
    CALL DETECT_CUSTOMER_MOMENTS();
    CALL CALCULATE_CUSTOMER_HEALTH();
    RETURN 'Events, moments, and health scoring complete';
END;
$$;
