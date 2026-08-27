/*
  NEXUS 360 — AI Enrichment Procedures
  Uses SNOWFLAKE.CORTEX.COMPLETE (mistral-large2) and SNOWFLAKE.CORTEX.SENTIMENT
  for sentiment, entity extraction, intent extraction, classification, summarization.
*/

USE WAREHOUSE SHAN_WH;
USE DATABASE SFK_HACKATHON;
USE SCHEMA SFK_HACK_1;

----------------------------------------------------------------------
-- 1. Sentiment Analysis on Transcripts
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE ENRICH_TRANSCRIPT_SENTIMENT()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO CUSTOMER_AI_ENRICHMENT (
        ENRICHMENT_ID, CUSTOMER_ID, SOURCE_TABLE, SOURCE_ID,
        SENTIMENT_SCORE, SENTIMENT_LABEL, ENRICHED_AT
    )
    SELECT
        'ENR-T-' || TRANSCRIPT_ID AS ENRICHMENT_ID,
        CUSTOMER_ID,
        'TRANSCRIPT' AS SOURCE_TABLE,
        TRANSCRIPT_ID AS SOURCE_ID,
        SNOWFLAKE.CORTEX.SENTIMENT(TRANSCRIPT_TEXT) AS SENTIMENT_SCORE,
        CASE
            WHEN SNOWFLAKE.CORTEX.SENTIMENT(TRANSCRIPT_TEXT) >= 0.3 THEN 'POSITIVE'
            WHEN SNOWFLAKE.CORTEX.SENTIMENT(TRANSCRIPT_TEXT) <= -0.3 THEN 'NEGATIVE'
            ELSE 'NEUTRAL'
        END AS SENTIMENT_LABEL,
        CURRENT_TIMESTAMP()
    FROM TRANSCRIPT
    WHERE TRANSCRIPT_ID NOT IN (
        SELECT SOURCE_ID FROM CUSTOMER_AI_ENRICHMENT
        WHERE SOURCE_TABLE = 'TRANSCRIPT' AND SENTIMENT_SCORE IS NOT NULL
    )
    LIMIT 1000;

    RETURN 'Transcript sentiment enrichment complete';
END;
$$;

----------------------------------------------------------------------
-- 2. Sentiment Analysis on Emails
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE ENRICH_EMAIL_SENTIMENT()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO CUSTOMER_AI_ENRICHMENT (
        ENRICHMENT_ID, CUSTOMER_ID, SOURCE_TABLE, SOURCE_ID,
        SENTIMENT_SCORE, SENTIMENT_LABEL, ENRICHED_AT
    )
    SELECT
        'ENR-E-' || EMAIL_ID AS ENRICHMENT_ID,
        CUSTOMER_ID,
        'EMAIL' AS SOURCE_TABLE,
        EMAIL_ID AS SOURCE_ID,
        SNOWFLAKE.CORTEX.SENTIMENT(BODY) AS SENTIMENT_SCORE,
        CASE
            WHEN SNOWFLAKE.CORTEX.SENTIMENT(BODY) >= 0.3 THEN 'POSITIVE'
            WHEN SNOWFLAKE.CORTEX.SENTIMENT(BODY) <= -0.3 THEN 'NEGATIVE'
            ELSE 'NEUTRAL'
        END AS SENTIMENT_LABEL,
        CURRENT_TIMESTAMP()
    FROM EMAIL
    WHERE EMAIL_ID NOT IN (
        SELECT SOURCE_ID FROM CUSTOMER_AI_ENRICHMENT
        WHERE SOURCE_TABLE = 'EMAIL' AND SENTIMENT_SCORE IS NOT NULL
    )
    LIMIT 1000;

    RETURN 'Email sentiment enrichment complete';
END;
$$;

----------------------------------------------------------------------
-- 3. Entity Extraction (competitors, products)
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE ENRICH_ENTITY_EXTRACTION()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Extract entities from transcripts
    INSERT INTO CUSTOMER_AI_ENRICHMENT (
        ENRICHMENT_ID, CUSTOMER_ID, SOURCE_TABLE, SOURCE_ID,
        ENTITIES, ENRICHED_AT
    )
    SELECT
        'ENR-ENT-' || TRANSCRIPT_ID AS ENRICHMENT_ID,
        CUSTOMER_ID,
        'TRANSCRIPT' AS SOURCE_TABLE,
        TRANSCRIPT_ID AS SOURCE_ID,
        TRY_PARSE_JSON(
            SNOWFLAKE.CORTEX.COMPLETE('mistral-large2',
                'Extract entities from the following insurance customer interaction transcript. Return a JSON object with keys: "competitors" (array of competitor insurance company names mentioned), "products" (array of insurance product types mentioned like auto, home, life, umbrella), "people" (array of people mentioned). Only include entities actually present in the text. Return ONLY valid JSON, no other text.\n\nTranscript: ' || TRANSCRIPT_TEXT
            )
        ) AS ENTITIES,
        CURRENT_TIMESTAMP()
    FROM TRANSCRIPT
    WHERE TRANSCRIPT_ID NOT IN (
        SELECT SOURCE_ID FROM CUSTOMER_AI_ENRICHMENT
        WHERE SOURCE_TABLE = 'TRANSCRIPT' AND ENTITIES IS NOT NULL
    )
    LIMIT 500;

    RETURN 'Entity extraction complete';
END;
$$;

----------------------------------------------------------------------
-- 4. Intent Extraction (cancellation, payment issues, product requests)
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE ENRICH_INTENT_EXTRACTION()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Extract intents from transcripts
    INSERT INTO CUSTOMER_AI_ENRICHMENT (
        ENRICHMENT_ID, CUSTOMER_ID, SOURCE_TABLE, SOURCE_ID,
        INTENTS, ENRICHED_AT
    )
    SELECT
        'ENR-INT-' || TRANSCRIPT_ID AS ENRICHMENT_ID,
        CUSTOMER_ID,
        'TRANSCRIPT' AS SOURCE_TABLE,
        TRANSCRIPT_ID AS SOURCE_ID,
        TRY_PARSE_JSON(
            SNOWFLAKE.CORTEX.COMPLETE('mistral-large2',
                'Analyze the following insurance customer transcript and identify customer intents. Return a JSON object with these boolean keys: "cancellation_intent" (customer wants to cancel), "payment_issue" (customer has payment problems), "product_request" (customer wants new product/coverage), "complaint" (customer is complaining), "price_sensitivity" (customer mentions pricing/cost concerns), "competitor_comparison" (customer comparing with competitors). Return ONLY valid JSON, no other text.\n\nTranscript: ' || TRANSCRIPT_TEXT
            )
        ) AS INTENTS,
        CURRENT_TIMESTAMP()
    FROM TRANSCRIPT
    WHERE TRANSCRIPT_ID NOT IN (
        SELECT SOURCE_ID FROM CUSTOMER_AI_ENRICHMENT
        WHERE SOURCE_TABLE = 'TRANSCRIPT' AND INTENTS IS NOT NULL
    )
    LIMIT 500;

    -- Extract intents from emails
    INSERT INTO CUSTOMER_AI_ENRICHMENT (
        ENRICHMENT_ID, CUSTOMER_ID, SOURCE_TABLE, SOURCE_ID,
        INTENTS, ENRICHED_AT
    )
    SELECT
        'ENR-INT-E-' || EMAIL_ID AS ENRICHMENT_ID,
        CUSTOMER_ID,
        'EMAIL' AS SOURCE_TABLE,
        EMAIL_ID AS SOURCE_ID,
        TRY_PARSE_JSON(
            SNOWFLAKE.CORTEX.COMPLETE('mistral-large2',
                'Analyze the following insurance customer email and identify customer intents. Return a JSON object with these boolean keys: "cancellation_intent" (customer wants to cancel), "payment_issue" (customer has payment problems), "product_request" (customer wants new product/coverage), "complaint" (customer is complaining), "price_sensitivity" (customer mentions pricing/cost concerns), "competitor_comparison" (customer comparing with competitors). Return ONLY valid JSON, no other text.\n\nEmail Subject: ' || SUBJECT || '\nEmail Body: ' || BODY
            )
        ) AS INTENTS,
        CURRENT_TIMESTAMP()
    FROM EMAIL
    WHERE EMAIL_ID NOT IN (
        SELECT SOURCE_ID FROM CUSTOMER_AI_ENRICHMENT
        WHERE SOURCE_TABLE = 'EMAIL' AND INTENTS IS NOT NULL
    )
    LIMIT 500;

    RETURN 'Intent extraction complete';
END;
$$;

----------------------------------------------------------------------
-- 5. Interaction Classification into Moment Types
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE ENRICH_INTERACTION_CLASSIFICATION()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO CUSTOMER_AI_ENRICHMENT (
        ENRICHMENT_ID, CUSTOMER_ID, SOURCE_TABLE, SOURCE_ID,
        CLASSIFICATION, ENRICHED_AT
    )
    SELECT
        'ENR-CLS-' || TRANSCRIPT_ID AS ENRICHMENT_ID,
        CUSTOMER_ID,
        'TRANSCRIPT' AS SOURCE_TABLE,
        TRANSCRIPT_ID AS SOURCE_ID,
        TRIM(
            SNOWFLAKE.CORTEX.COMPLETE('mistral-large2',
                'Classify the following insurance customer interaction into exactly ONE of these moment types: CHURN (customer likely to leave), CLAIM_FRICTION (frustrated with claims process), PRICE_SENSITIVITY (concerned about cost/premiums), CROSS_SELL_OPPORTUNITY (open to additional products), PAYMENT_ISSUE (having payment problems), POSITIVE_ENGAGEMENT (satisfied customer interaction), GENERAL_INQUIRY (routine question). Return ONLY the classification label, nothing else.\n\nTranscript: ' || TRANSCRIPT_TEXT
            )
        ) AS CLASSIFICATION,
        CURRENT_TIMESTAMP()
    FROM TRANSCRIPT
    WHERE TRANSCRIPT_ID NOT IN (
        SELECT SOURCE_ID FROM CUSTOMER_AI_ENRICHMENT
        WHERE SOURCE_TABLE = 'TRANSCRIPT' AND CLASSIFICATION IS NOT NULL
    )
    LIMIT 500;

    RETURN 'Interaction classification complete';
END;
$$;

----------------------------------------------------------------------
-- 6. Per-Customer Summarization
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE ENRICH_CUSTOMER_SUMMARY()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO CUSTOMER_AI_ENRICHMENT (
        ENRICHMENT_ID, CUSTOMER_ID, SOURCE_TABLE, SOURCE_ID,
        SUMMARY, ENRICHED_AT
    )
    SELECT
        'ENR-SUM-' || C.CUSTOMER_ID AS ENRICHMENT_ID,
        C.CUSTOMER_ID,
        'CUSTOMER' AS SOURCE_TABLE,
        C.CUSTOMER_ID AS SOURCE_ID,
        SNOWFLAKE.CORTEX.COMPLETE('mistral-large2',
            'Summarize the following customer interaction history for an insurance company employee. Provide a concise 2-3 sentence summary highlighting key themes, concerns, and relationship health.\n\nCustomer: ' || C.CUSTOMER_ID ||
            '\nRecent interactions:\n' ||
            COALESCE(INTERACTIONS_TEXT, 'No recent interactions recorded.')
        ) AS SUMMARY,
        CURRENT_TIMESTAMP()
    FROM CUSTOMER C
    LEFT JOIN (
        SELECT
            CUSTOMER_ID,
            LISTAGG(
                '- [' || SOURCE_TABLE || '] ' || LEFT(CONTENT, 200),
                '\n'
            ) WITHIN GROUP (ORDER BY ENRICHED_AT DESC) AS INTERACTIONS_TEXT
        FROM (
            SELECT CUSTOMER_ID, 'Transcript' AS SOURCE_TABLE, TRANSCRIPT_TEXT AS CONTENT, CREATED_AT AS ENRICHED_AT
            FROM TRANSCRIPT
            UNION ALL
            SELECT CUSTOMER_ID, 'Email' AS SOURCE_TABLE, SUBJECT || ': ' || BODY AS CONTENT, SENT_AT AS ENRICHED_AT
            FROM EMAIL
            UNION ALL
            SELECT CUSTOMER_ID, 'Note' AS SOURCE_TABLE, NOTE_TEXT AS CONTENT, CREATED_AT AS ENRICHED_AT
            FROM NOTE
        )
        GROUP BY CUSTOMER_ID
    ) I ON C.CUSTOMER_ID = I.CUSTOMER_ID
    WHERE C.CUSTOMER_ID NOT IN (
        SELECT SOURCE_ID FROM CUSTOMER_AI_ENRICHMENT
        WHERE SOURCE_TABLE = 'CUSTOMER' AND SUMMARY IS NOT NULL
    )
    LIMIT 200;

    RETURN 'Customer summarization complete';
END;
$$;

----------------------------------------------------------------------
-- 7. Master Enrichment Procedure (runs all in sequence)
----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE RUN_ALL_ENRICHMENT()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    CALL ENRICH_TRANSCRIPT_SENTIMENT();
    CALL ENRICH_EMAIL_SENTIMENT();
    CALL ENRICH_ENTITY_EXTRACTION();
    CALL ENRICH_INTENT_EXTRACTION();
    CALL ENRICH_INTERACTION_CLASSIFICATION();
    CALL ENRICH_CUSTOMER_SUMMARY();
    RETURN 'All enrichment procedures completed successfully';
END;
$$;
