/*
  NEXUS 360 — Next Best Action Decision Engine
  5 deterministic rules with confidence scoring, suppression logic,
  human approval workflow, and outcome tracking.
*/

USE WAREHOUSE SHAN_WH;
USE DATABASE SFK_HACKATHON;
USE SCHEMA SFK_HACK_1;

----------------------------------------------------------------------
-- 1. NBA Generation Procedure
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE GENERATE_NBA_RECOMMENDATIONS()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Clear existing pending recommendations
    DELETE FROM NEXT_BEST_ACTION WHERE STATUS = 'PENDING';

    -- Rule 1: RETENTION_OFFER
    -- High churn risk + negative sentiment + renewal < 60 days
    INSERT INTO NEXT_BEST_ACTION (
        ACTION_ID, CUSTOMER_ID, ACTION_TYPE, CONFIDENCE, RATIONALE,
        PRIORITY, STATUS, SUPPRESSED, EVIDENCE, CREATED_AT, EXPIRES_AT
    )
    SELECT
        'NBA-RET-' || H.CUSTOMER_ID || '-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        H.CUSTOMER_ID,
        'RETENTION_OFFER',
        LEAST(0.95, 0.5 + (H.CHURN_RISK * 0.5)),
        'High churn risk (' || ROUND(H.CHURN_RISK * 100, 1) || '%) with negative sentiment (' || ROUND(H.SENTIMENT_SCORE, 1) || ') and policy renewal within 60 days. Recommend proactive retention outreach with discount offer.',
        1,
        'PENDING',
        FALSE,
        OBJECT_CONSTRUCT('churn_risk', H.CHURN_RISK, 'sentiment', H.SENTIMENT_SCORE, 'renewal_days', DATEDIFF('day', CURRENT_DATE(), P.END_DATE)),
        CURRENT_TIMESTAMP(),
        DATEADD('day', 14, CURRENT_TIMESTAMP())
    FROM CUSTOMER_HEALTH H
    JOIN POLICY P ON H.CUSTOMER_ID = P.CUSTOMER_ID AND P.STATUS = 'Active'
    WHERE H.CHURN_RISK >= 0.4
      AND H.SENTIMENT_SCORE < 50
      AND DATEDIFF('day', CURRENT_DATE(), P.END_DATE) BETWEEN 1 AND 60
      AND H.CUSTOMER_ID NOT IN (SELECT CUSTOMER_ID FROM NEXT_BEST_ACTION WHERE ACTION_TYPE = 'RETENTION_OFFER' AND STATUS IN ('PENDING', 'APPROVED'));

    -- Rule 2: CLAIMS_ESCALATION
    -- Open claim > 14 days + negative sentiment
    INSERT INTO NEXT_BEST_ACTION (
        ACTION_ID, CUSTOMER_ID, ACTION_TYPE, CONFIDENCE, RATIONALE,
        PRIORITY, STATUS, SUPPRESSED, EVIDENCE, CREATED_AT, EXPIRES_AT
    )
    SELECT
        'NBA-CLM-' || C.CUSTOMER_ID || '-' || C.CLAIM_ID,
        C.CUSTOMER_ID,
        'CLAIMS_ESCALATION',
        LEAST(0.90, 0.6 + (DATEDIFF('day', C.FILED_DATE, CURRENT_DATE()) - 14) * 0.01),
        'Open claim (' || C.CLAIM_ID || ') pending for ' || DATEDIFF('day', C.FILED_DATE, CURRENT_DATE()) || ' days with negative customer sentiment. Escalate to claims manager for expedited resolution.',
        2,
        'PENDING',
        FALSE,
        OBJECT_CONSTRUCT('claim_id', C.CLAIM_ID, 'days_open', DATEDIFF('day', C.FILED_DATE, CURRENT_DATE()), 'claim_amount', C.CLAIM_AMOUNT, 'sentiment', H.SENTIMENT_SCORE),
        CURRENT_TIMESTAMP(),
        DATEADD('day', 7, CURRENT_TIMESTAMP())
    FROM CLAIM C
    JOIN CUSTOMER_HEALTH H ON C.CUSTOMER_ID = H.CUSTOMER_ID
    WHERE C.STATUS IN ('Open', 'Under Review')
      AND DATEDIFF('day', C.FILED_DATE, CURRENT_DATE()) > 14
      AND H.SENTIMENT_SCORE < 50
      AND C.CUSTOMER_ID NOT IN (SELECT CUSTOMER_ID FROM NEXT_BEST_ACTION WHERE ACTION_TYPE = 'CLAIMS_ESCALATION' AND STATUS IN ('PENDING', 'APPROVED'));

    -- Rule 3: COMPETITOR_RETENTION_CAMPAIGN
    -- Competitor mention + renewal < 45 days
    INSERT INTO NEXT_BEST_ACTION (
        ACTION_ID, CUSTOMER_ID, ACTION_TYPE, CONFIDENCE, RATIONALE,
        PRIORITY, STATUS, SUPPRESSED, EVIDENCE, CREATED_AT, EXPIRES_AT
    )
    SELECT
        'NBA-CRC-' || E.CUSTOMER_ID || '-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        E.CUSTOMER_ID,
        'COMPETITOR_RETENTION_CAMPAIGN',
        0.80,
        'Customer mentioned competitor(s) in recent interaction with policy renewal within 45 days. Initiate targeted retention campaign with competitive comparison and loyalty benefits.',
        2,
        'PENDING',
        FALSE,
        OBJECT_CONSTRUCT('competitors_mentioned', E.ENTITIES:competitors, 'renewal_days', DATEDIFF('day', CURRENT_DATE(), P.END_DATE)),
        CURRENT_TIMESTAMP(),
        DATEADD('day', 10, CURRENT_TIMESTAMP())
    FROM CUSTOMER_AI_ENRICHMENT E
    JOIN POLICY P ON E.CUSTOMER_ID = P.CUSTOMER_ID AND P.STATUS = 'Active'
    WHERE E.ENTITIES IS NOT NULL
      AND ARRAY_SIZE(E.ENTITIES:competitors) > 0
      AND DATEDIFF('day', CURRENT_DATE(), P.END_DATE) BETWEEN 1 AND 45
      AND E.CUSTOMER_ID NOT IN (SELECT CUSTOMER_ID FROM NEXT_BEST_ACTION WHERE ACTION_TYPE = 'COMPETITOR_RETENTION_CAMPAIGN' AND STATUS IN ('PENDING', 'APPROVED'));

    -- Rule 4: CROSS_SELL
    -- Premium segment + positive sentiment + eligible (no active friction)
    INSERT INTO NEXT_BEST_ACTION (
        ACTION_ID, CUSTOMER_ID, ACTION_TYPE, CONFIDENCE, RATIONALE,
        PRIORITY, STATUS, SUPPRESSED, SUPPRESSION_REASON, EVIDENCE, CREATED_AT, EXPIRES_AT
    )
    SELECT
        'NBA-XSL-' || C.CUSTOMER_ID || '-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        C.CUSTOMER_ID,
        'CROSS_SELL',
        0.70,
        'Premium segment customer with positive sentiment and good engagement. Eligible for cross-sell of additional coverage products.',
        3,
        CASE
            WHEN H.SENTIMENT_SCORE < 40 OR H.RISK_LEVEL IN ('CRITICAL', 'AT_RISK') THEN 'SUPPRESSED'
            ELSE 'PENDING'
        END,
        CASE
            WHEN H.SENTIMENT_SCORE < 40 OR H.RISK_LEVEL IN ('CRITICAL', 'AT_RISK') THEN TRUE
            ELSE FALSE
        END,
        CASE
            WHEN H.SENTIMENT_SCORE < 40 THEN 'Suppressed: negative sentiment detected'
            WHEN H.RISK_LEVEL IN ('CRITICAL', 'AT_RISK') THEN 'Suppressed: customer at churn risk'
            ELSE NULL
        END,
        OBJECT_CONSTRUCT('segment', C.SEGMENT, 'sentiment', H.SENTIMENT_SCORE, 'health_score', H.HEALTH_SCORE),
        CURRENT_TIMESTAMP(),
        DATEADD('day', 30, CURRENT_TIMESTAMP())
    FROM CUSTOMER C
    JOIN CUSTOMER_HEALTH H ON C.CUSTOMER_ID = H.CUSTOMER_ID
    WHERE C.SEGMENT IN ('Premium', 'Enterprise')
      AND H.HEALTH_SCORE >= 60
      AND C.CUSTOMER_ID NOT IN (SELECT CUSTOMER_ID FROM NEXT_BEST_ACTION WHERE ACTION_TYPE = 'CROSS_SELL' AND STATUS IN ('PENDING', 'APPROVED'));

    -- Rule 5: PAYMENT_ASSISTANCE
    -- Multiple payment failures
    INSERT INTO NEXT_BEST_ACTION (
        ACTION_ID, CUSTOMER_ID, ACTION_TYPE, CONFIDENCE, RATIONALE,
        PRIORITY, STATUS, SUPPRESSED, EVIDENCE, CREATED_AT, EXPIRES_AT
    )
    SELECT
        'NBA-PAY-' || PA.CUSTOMER_ID || '-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        PA.CUSTOMER_ID,
        'PAYMENT_ASSISTANCE',
        LEAST(0.90, 0.5 + (PA.FAILED_COUNT * 0.15)),
        'Customer has ' || PA.FAILED_COUNT || ' failed payments in recent period. Proactive outreach to resolve payment method issues and prevent policy lapse.',
        2,
        'PENDING',
        FALSE,
        OBJECT_CONSTRUCT('failed_payments', PA.FAILED_COUNT, 'total_payments', PA.TOTAL_COUNT, 'failure_rate', ROUND(PA.FAILED_COUNT::FLOAT / PA.TOTAL_COUNT, 3)),
        CURRENT_TIMESTAMP(),
        DATEADD('day', 7, CURRENT_TIMESTAMP())
    FROM (
        SELECT
            CUSTOMER_ID,
            SUM(CASE WHEN STATUS = 'Failed' THEN 1 ELSE 0 END) AS FAILED_COUNT,
            COUNT(*) AS TOTAL_COUNT
        FROM PAYMENT
        WHERE PAYMENT_DATE >= DATEADD('month', -3, CURRENT_DATE())
        GROUP BY CUSTOMER_ID
        HAVING SUM(CASE WHEN STATUS = 'Failed' THEN 1 ELSE 0 END) >= 2
    ) PA
    WHERE PA.CUSTOMER_ID NOT IN (SELECT CUSTOMER_ID FROM NEXT_BEST_ACTION WHERE ACTION_TYPE = 'PAYMENT_ASSISTANCE' AND STATUS IN ('PENDING', 'APPROVED'));

    RETURN 'NBA recommendations generated';
END;
$$;

----------------------------------------------------------------------
-- 2. Approval Procedure
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE APPROVE_NBA_ACTION(
    P_ACTION_ID VARCHAR,
    P_APPROVER VARCHAR,
    P_DECISION VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Validate decision
    IF (:P_DECISION NOT IN ('APPROVED', 'REJECTED')) THEN
        RETURN 'Error: Decision must be APPROVED or REJECTED';
    END IF;

    -- Update the action status
    UPDATE NEXT_BEST_ACTION
    SET STATUS = :P_DECISION
    WHERE ACTION_ID = :P_ACTION_ID
      AND STATUS = 'PENDING';

    -- Log the decision
    INSERT INTO NEXT_BEST_ACTION_LOG (
        LOG_ID, ACTION_ID, CUSTOMER_ID, ACTION_TYPE,
        DECISION, DECIDED_BY, DECIDED_AT, CREATED_AT
    )
    SELECT
        'LOG-' || :P_ACTION_ID || '-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        ACTION_ID,
        CUSTOMER_ID,
        ACTION_TYPE,
        :P_DECISION,
        :P_APPROVER,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
    FROM NEXT_BEST_ACTION
    WHERE ACTION_ID = :P_ACTION_ID;

    RETURN 'Action ' || :P_ACTION_ID || ' ' || :P_DECISION || ' by ' || :P_APPROVER;
END;
$$;

----------------------------------------------------------------------
-- 3. Outcome Tracking Procedure
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE RECORD_NBA_OUTCOME(
    P_ACTION_ID VARCHAR,
    P_OUTCOME VARCHAR,
    P_NOTES VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Update the log with outcome
    UPDATE NEXT_BEST_ACTION_LOG
    SET OUTCOME = :P_OUTCOME,
        OUTCOME_DATE = CURRENT_TIMESTAMP(),
        NOTES = :P_NOTES
    WHERE ACTION_ID = :P_ACTION_ID
      AND OUTCOME IS NULL;

    -- Update action status
    UPDATE NEXT_BEST_ACTION
    SET STATUS = 'COMPLETED'
    WHERE ACTION_ID = :P_ACTION_ID
      AND STATUS = 'APPROVED';

    RETURN 'Outcome recorded for action ' || :P_ACTION_ID || ': ' || :P_OUTCOME;
END;
$$;

----------------------------------------------------------------------
-- 4. Get NBA for a specific customer
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE GET_CUSTOMER_NBA(P_CUSTOMER_ID VARCHAR)
RETURNS TABLE (
    ACTION_ID VARCHAR,
    ACTION_TYPE VARCHAR,
    CONFIDENCE FLOAT,
    RATIONALE VARCHAR,
    PRIORITY INTEGER,
    STATUS VARCHAR,
    CREATED_AT TIMESTAMP_NTZ
)
LANGUAGE SQL
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (
        SELECT ACTION_ID, ACTION_TYPE, CONFIDENCE, RATIONALE, PRIORITY, STATUS, CREATED_AT
        FROM NEXT_BEST_ACTION
        WHERE CUSTOMER_ID = :P_CUSTOMER_ID
          AND SUPPRESSED = FALSE
          AND (EXPIRES_AT IS NULL OR EXPIRES_AT > CURRENT_TIMESTAMP())
        ORDER BY PRIORITY ASC, CONFIDENCE DESC
    );
    RETURN TABLE(res);
END;
$$;
