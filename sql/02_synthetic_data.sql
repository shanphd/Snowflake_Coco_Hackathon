/*
  NEXUS 360 — Synthetic Data Generation
  Generates ~10K customers, ~25K policies, ~15K claims, ~50K interactions,
  plus transcripts, emails, notes, surveys with insurance-specific content.
*/

USE WAREHOUSE SHAN_WH;
USE DATABASE SFK_HACKATHON;
USE SCHEMA SFK_HACK_1;

----------------------------------------------------------------------
-- 1. CUSTOMER (~10,000 rows)
----------------------------------------------------------------------
INSERT INTO CUSTOMER (
    CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE,
    DATE_OF_BIRTH, GENDER, SEGMENT, REGION, STATE, CITY, ZIP_CODE,
    TENURE_MONTHS, LIFETIME_VALUE, CREATED_AT, UPDATED_AT
)
SELECT
    'CUST-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS CUSTOMER_ID,
    ARRAY_CONSTRUCT('James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','David','Elizabeth',
                    'William','Barbara','Richard','Susan','Joseph','Jessica','Thomas','Sarah','Charles','Karen',
                    'Daniel','Lisa','Matthew','Nancy','Anthony','Betty','Mark','Margaret','Donald','Sandra')[UNIFORM(0, 29, RANDOM())]::VARCHAR AS FIRST_NAME,
    ARRAY_CONSTRUCT('Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez',
                    'Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin',
                    'Lee','Perez','Thompson','White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson')[UNIFORM(0, 29, RANDOM())]::VARCHAR AS LAST_NAME,
    LOWER('CUST-' || LPAD(SEQ4()::VARCHAR, 6, '0') || '@email.com') AS EMAIL,
    '+1-' || LPAD(UNIFORM(200, 999, RANDOM())::VARCHAR, 3, '0') || '-' ||
    LPAD(UNIFORM(100, 999, RANDOM())::VARCHAR, 3, '0') || '-' ||
    LPAD(UNIFORM(1000, 9999, RANDOM())::VARCHAR, 4, '0') AS PHONE,
    DATEADD('day', -UNIFORM(7300, 25550, RANDOM()), CURRENT_DATE()) AS DATE_OF_BIRTH,
    ARRAY_CONSTRUCT('Male','Female','Other')[UNIFORM(0, 2, RANDOM())]::VARCHAR AS GENDER,
    ARRAY_CONSTRUCT('Premium','Standard','Basic','Enterprise')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS SEGMENT,
    ARRAY_CONSTRUCT('Northeast','Southeast','Midwest','Southwest','West','Northwest')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS REGION,
    ARRAY_CONSTRUCT('CA','TX','FL','NY','PA','IL','OH','GA','NC','MI','NJ','VA','WA','AZ','MA','TN','IN','MO','MD','WI')[UNIFORM(0, 19, RANDOM())]::VARCHAR AS STATE,
    ARRAY_CONSTRUCT('New York','Los Angeles','Chicago','Houston','Phoenix','Philadelphia','San Antonio','San Diego','Dallas','San Jose',
                    'Austin','Jacksonville','Fort Worth','Columbus','Charlotte','Indianapolis','San Francisco','Seattle','Denver','Boston')[UNIFORM(0, 19, RANDOM())]::VARCHAR AS CITY,
    LPAD(UNIFORM(10000, 99999, RANDOM())::VARCHAR, 5, '0') AS ZIP_CODE,
    UNIFORM(1, 240, RANDOM()) AS TENURE_MONTHS,
    ROUND(UNIFORM(500, 150000, RANDOM())::FLOAT + UNIFORM(0, 99, RANDOM())::FLOAT / 100, 2) AS LIFETIME_VALUE,
    DATEADD('day', -UNIFORM(1, 2000, RANDOM()), CURRENT_TIMESTAMP()) AS CREATED_AT,
    CURRENT_TIMESTAMP() AS UPDATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

----------------------------------------------------------------------
-- 2. POLICY (~25,000 rows, ~2.5 per customer)
----------------------------------------------------------------------
INSERT INTO POLICY (
    POLICY_ID, CUSTOMER_ID, POLICY_TYPE, PREMIUM_AMOUNT,
    START_DATE, END_DATE, STATUS, COVERAGE_AMOUNT, DEDUCTIBLE, CREATED_AT
)
SELECT
    'POL-' || LPAD(SEQ4()::VARCHAR, 7, '0') AS POLICY_ID,
    'CUST-' || LPAD(UNIFORM(0, 9999, RANDOM())::VARCHAR, 6, '0') AS CUSTOMER_ID,
    ARRAY_CONSTRUCT('Auto','Home','Life','Health','Umbrella','Renters','Travel','Pet')[UNIFORM(0, 7, RANDOM())]::VARCHAR AS POLICY_TYPE,
    ROUND(UNIFORM(50, 5000, RANDOM())::FLOAT + UNIFORM(0, 99, RANDOM())::FLOAT / 100, 2) AS PREMIUM_AMOUNT,
    DATEADD('day', -UNIFORM(0, 730, RANDOM()), CURRENT_DATE()) AS START_DATE,
    DATEADD('day', UNIFORM(30, 365, RANDOM()), CURRENT_DATE()) AS END_DATE,
    ARRAY_CONSTRUCT('Active','Active','Active','Active','Cancelled','Expired','Pending')[UNIFORM(0, 6, RANDOM())]::VARCHAR AS STATUS,
    ROUND(UNIFORM(10000, 1000000, RANDOM())::FLOAT, 2) AS COVERAGE_AMOUNT,
    ROUND(UNIFORM(250, 5000, RANDOM())::FLOAT, 2) AS DEDUCTIBLE,
    DATEADD('day', -UNIFORM(0, 730, RANDOM()), CURRENT_TIMESTAMP()) AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 25000));

----------------------------------------------------------------------
-- 3. CLAIM (~15,000 rows)
----------------------------------------------------------------------
INSERT INTO CLAIM (
    CLAIM_ID, CUSTOMER_ID, POLICY_ID, CLAIM_TYPE, CLAIM_AMOUNT,
    STATUS, FILED_DATE, RESOLVED_DATE, RESOLUTION_DAYS, DESCRIPTION, CREATED_AT
)
WITH CLAIM_DATA AS (
    SELECT
        'CLM-' || LPAD(SEQ4()::VARCHAR, 7, '0') AS CLAIM_ID,
        'CUST-' || LPAD(UNIFORM(0, 9999, RANDOM())::VARCHAR, 6, '0') AS CUSTOMER_ID,
        'POL-' || LPAD(UNIFORM(0, 24999, RANDOM())::VARCHAR, 7, '0') AS POLICY_ID,
        ARRAY_CONSTRUCT('Collision','Theft','Water Damage','Fire','Medical','Liability','Windstorm','Vandalism')[UNIFORM(0, 7, RANDOM())]::VARCHAR AS CLAIM_TYPE,
        ROUND(UNIFORM(100, 50000, RANDOM())::FLOAT + UNIFORM(0, 99, RANDOM())::FLOAT / 100, 2) AS CLAIM_AMOUNT,
        ARRAY_CONSTRUCT('Open','Open','Under Review','Under Review','Approved','Denied','Settled','Closed')[UNIFORM(0, 7, RANDOM())]::VARCHAR AS STATUS,
        DATEADD('day', -UNIFORM(1, 365, RANDOM()), CURRENT_DATE()) AS FILED_DATE,
        UNIFORM(0, 10, RANDOM()) AS RND
    FROM TABLE(GENERATOR(ROWCOUNT => 15000))
)
SELECT
    CLAIM_ID, CUSTOMER_ID, POLICY_ID, CLAIM_TYPE, CLAIM_AMOUNT, STATUS, FILED_DATE,
    CASE WHEN STATUS IN ('Approved','Denied','Settled','Closed')
         THEN DATEADD('day', UNIFORM(3, 60, RANDOM()), FILED_DATE)
         ELSE NULL END AS RESOLVED_DATE,
    CASE WHEN STATUS IN ('Approved','Denied','Settled','Closed')
         THEN UNIFORM(3, 60, RANDOM())
         ELSE NULL END AS RESOLUTION_DAYS,
    ARRAY_CONSTRUCT(
        'Vehicle collision at intersection, minor damage to front bumper',
        'Water damage from burst pipe in basement, flooring affected',
        'Theft of personal belongings from parked vehicle',
        'Hail damage to roof shingles requiring replacement',
        'Medical expenses from slip and fall incident',
        'Fire damage to kitchen from electrical fault',
        'Wind damage to fence and siding during storm',
        'Vandalism to property, broken windows and graffiti'
    )[UNIFORM(0, 7, RANDOM())]::VARCHAR AS DESCRIPTION,
    DATEADD('day', -UNIFORM(1, 365, RANDOM()), CURRENT_TIMESTAMP()) AS CREATED_AT
FROM CLAIM_DATA;

----------------------------------------------------------------------
-- 4. PAYMENT (~60,000 rows, covering billing cycles)
----------------------------------------------------------------------
INSERT INTO PAYMENT (
    PAYMENT_ID, CUSTOMER_ID, POLICY_ID, AMOUNT, PAYMENT_DATE,
    DUE_DATE, STATUS, PAYMENT_METHOD, FAILURE_REASON, CREATED_AT
)
SELECT
    'PAY-' || LPAD(SEQ4()::VARCHAR, 7, '0') AS PAYMENT_ID,
    'CUST-' || LPAD(UNIFORM(0, 9999, RANDOM())::VARCHAR, 6, '0') AS CUSTOMER_ID,
    'POL-' || LPAD(UNIFORM(0, 24999, RANDOM())::VARCHAR, 7, '0') AS POLICY_ID,
    ROUND(UNIFORM(50, 2000, RANDOM())::FLOAT + UNIFORM(0, 99, RANDOM())::FLOAT / 100, 2) AS AMOUNT,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS PAYMENT_DATE,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS DUE_DATE,
    ARRAY_CONSTRUCT('Completed','Completed','Completed','Completed','Completed','Failed','Failed','Pending','Refunded')[UNIFORM(0, 8, RANDOM())]::VARCHAR AS STATUS,
    ARRAY_CONSTRUCT('Credit Card','Debit Card','Bank Transfer','ACH','Check','Auto-Pay')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS PAYMENT_METHOD,
    CASE
        WHEN UNIFORM(0, 8, RANDOM()) IN (5, 6) THEN
            ARRAY_CONSTRUCT('Insufficient funds','Card declined','Account closed','Invalid routing number','Payment limit exceeded')[UNIFORM(0, 4, RANDOM())]::VARCHAR
        ELSE NULL
    END AS FAILURE_REASON,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_TIMESTAMP()) AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 60000));

----------------------------------------------------------------------
-- 5. INTERACTION (~50,000 rows)
----------------------------------------------------------------------
INSERT INTO INTERACTION (
    INTERACTION_ID, CUSTOMER_ID, CHANNEL, DIRECTION, INTERACTION_DATE,
    DURATION_SECONDS, AGENT_ID, DISPOSITION, TOPIC, CREATED_AT
)
SELECT
    'INT-' || LPAD(SEQ4()::VARCHAR, 7, '0') AS INTERACTION_ID,
    'CUST-' || LPAD(UNIFORM(0, 9999, RANDOM())::VARCHAR, 6, '0') AS CUSTOMER_ID,
    ARRAY_CONSTRUCT('Phone','Email','Chat','Web Portal','Mobile App')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS CHANNEL,
    ARRAY_CONSTRUCT('Inbound','Outbound')[UNIFORM(0, 1, RANDOM())]::VARCHAR AS DIRECTION,
    DATEADD('second', -UNIFORM(0, 15552000, RANDOM()), CURRENT_TIMESTAMP()) AS INTERACTION_DATE,
    UNIFORM(30, 1800, RANDOM()) AS DURATION_SECONDS,
    'AGT-' || LPAD(UNIFORM(1, 200, RANDOM())::VARCHAR, 4, '0') AS AGENT_ID,
    ARRAY_CONSTRUCT('Resolved','Escalated','Follow-up Required','Transferred','Closed','Pending')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS DISPOSITION,
    ARRAY_CONSTRUCT('Billing Inquiry','Claim Status','Policy Change','Cancellation Request','New Quote',
                    'Payment Issue','Coverage Question','Complaint','Renewal','General Inquiry')[UNIFORM(0, 9, RANDOM())]::VARCHAR AS TOPIC,
    CURRENT_TIMESTAMP() AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 50000));

----------------------------------------------------------------------
-- 6. TRANSCRIPT (~8,000 rows — subset of phone interactions)
----------------------------------------------------------------------
INSERT INTO TRANSCRIPT (
    TRANSCRIPT_ID, INTERACTION_ID, CUSTOMER_ID, TRANSCRIPT_TEXT, SPEAKER_LABELS, CREATED_AT
)
SELECT
    'TRN-' || LPAD(SEQ4()::VARCHAR, 7, '0') AS TRANSCRIPT_ID,
    'INT-' || LPAD(UNIFORM(0, 49999, RANDOM())::VARCHAR, 7, '0') AS INTERACTION_ID,
    'CUST-' || LPAD(UNIFORM(0, 9999, RANDOM())::VARCHAR, 6, '0') AS CUSTOMER_ID,
    ARRAY_CONSTRUCT(
        'Customer: Hi, I am calling about my auto policy renewal. I got a quote from Geico that is $200 less per year. Agent: I understand your concern. Let me review your account and see what options we have to keep your business. Customer: I have been with you for 5 years but the premium keeps going up. I am seriously considering switching. Agent: I appreciate your loyalty. Let me check what discounts we can apply.',
        'Customer: I am extremely frustrated with how long my claim is taking. It has been over three weeks and I have not heard anything. Agent: I apologize for the delay. Let me look into your claim status right now. Customer: This is ridiculous. I am paying my premiums on time every month and this is how I get treated? Agent: I completely understand your frustration. Let me escalate this to our claims manager.',
        'Customer: I want to cancel my policy effective immediately. Agent: I am sorry to hear that. May I ask what prompted this decision? Customer: Your competitor Progressive offered me the same coverage for much less. Plus your customer service has been terrible lately. Agent: I would hate to lose you as a customer. Can I look into matching or beating that rate?',
        'Customer: My payment failed again this month and I do not know why. Agent: Let me check your payment method on file. Customer: I updated my card last month but it keeps declining. This is the third time this has happened. Agent: I see the issue. The card on file still shows the old expiration date. Let me update that for you.',
        'Customer: I am interested in adding umbrella coverage to my existing policies. Agent: That is a great idea for additional protection. Let me explain our umbrella policy options. Customer: I heard State Farm has a good bundling discount. What can you offer? Agent: We definitely have competitive bundling rates. Let me pull up some quotes for you.',
        'Customer: I need to file a claim for water damage in my basement. The pipe burst yesterday and there is significant damage. Agent: I am sorry to hear about that. Let me get your claim started right away. Customer: How long will this process take? My last claim took forever. Agent: We have improved our processing times. Most water damage claims are resolved within 10-14 business days.',
        'Customer: I am calling to complain about my rate increase. My premium went up 15% and I have had no claims in 3 years. Agent: I understand this is concerning. Rate changes can be affected by several factors in your area. Customer: That is not acceptable. Allstate quoted me $150 less per month. I am going to switch if you cannot match it. Agent: Let me review your policy to see what adjustments we can make.',
        'Customer: Hi, I just wanted to update my address and check on my renewal date. Agent: Of course, I can help you with both. What is your new address? Customer: I moved to 456 Oak Street. Also, when does my home policy renew? Agent: Your home policy renews on March 15th. Would you like me to review your coverage since you moved?',
        'Customer: I am so disappointed with your company. My claim was denied and I do not understand why. Agent: I am sorry about this experience. Let me review the denial reason with you. Customer: I have been a loyal customer for 12 years. This makes me want to cancel everything. Agent: I understand your frustration. Let me connect you with our claims review team to see if there is an appeal option.',
        'Customer: Can you explain my deductible options? I want to lower my monthly payment. Agent: Absolutely. Increasing your deductible is one way to reduce your premium. Customer: What about Lemonade? They seem to have really low rates. Agent: We can certainly be competitive. Let me show you some options with different deductible levels and compare total cost of ownership.'
    )[UNIFORM(0, 9, RANDOM())]::VARCHAR AS TRANSCRIPT_TEXT,
    PARSE_JSON('["Customer","Agent"]') AS SPEAKER_LABELS,
    CURRENT_TIMESTAMP() AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 8000));

----------------------------------------------------------------------
-- 7. EMAIL (~10,000 rows)
----------------------------------------------------------------------
INSERT INTO EMAIL (
    EMAIL_ID, INTERACTION_ID, CUSTOMER_ID, SUBJECT, BODY,
    DIRECTION, SENT_AT, CREATED_AT
)
SELECT
    'EML-' || LPAD(SEQ4()::VARCHAR, 7, '0') AS EMAIL_ID,
    'INT-' || LPAD(UNIFORM(0, 49999, RANDOM())::VARCHAR, 7, '0') AS INTERACTION_ID,
    'CUST-' || LPAD(UNIFORM(0, 9999, RANDOM())::VARCHAR, 6, '0') AS CUSTOMER_ID,
    ARRAY_CONSTRUCT(
        'Regarding my policy renewal',
        'Claim status inquiry - urgent',
        'Request to cancel my policy',
        'Payment issue - please help',
        'Question about coverage options',
        'Complaint about service',
        'Quote comparison request',
        'Address change notification',
        'Billing dispute',
        'Thank you for resolving my issue'
    )[UNIFORM(0, 9, RANDOM())]::VARCHAR AS SUBJECT,
    ARRAY_CONSTRUCT(
        'Dear Team, I received my renewal notice and the premium increase is unacceptable. I have been comparing rates with USAA and Liberty Mutual and both are offering significantly lower premiums for the same coverage. Unless you can match their pricing, I will be switching providers at renewal. Please contact me to discuss retention options.',
        'Hello, I filed a claim two weeks ago and have not received any update. This is extremely frustrating as I am dealing with significant damage to my property. I need someone to call me immediately to provide a status update. If this is not resolved within 48 hours, I will be filing a complaint with the insurance commissioner.',
        'To whom it may concern, I am writing to formally request cancellation of all my policies effective at the end of this billing cycle. I have found better rates with Progressive and their customer service has been much more responsive. Please confirm the cancellation and any refund owed.',
        'Hi, my autopay failed for the third consecutive month. I have verified my bank account has sufficient funds. This is causing me to receive late payment notices which is stressing me out. Please fix whatever technical issue is causing this and waive any late fees.',
        'Hi there, I would like to explore adding rental car coverage to my auto policy. I also heard that Nationwide has a vanishing deductible feature. Do you offer something similar? I would appreciate a comparison of options.',
        'I am writing to express my extreme dissatisfaction with the handling of my recent claim. After 30 days I still have no resolution and every time I call I get a different answer. This level of service is completely unacceptable for the premiums I pay. I am considering switching to Travelers.',
        'Good morning, I am shopping around for better insurance rates. Could you please provide me with a detailed quote comparison showing how your coverage compares to what Farmers and Erie are offering? I want to make an informed decision before my renewal.',
        'Just wanted to let you know I moved to a new address last week. New address is 789 Elm Drive, Springfield. Also, can you check if this changes my rate at all? My neighbor said they pay less with Amica for the same neighborhood.',
        'There is an error on my latest bill. I was charged twice for the same policy premium this month. I need this corrected immediately and a refund issued. This is not the first billing error I have experienced and it makes me question whether I should stay with your company.',
        'Thank you so much for your help last week resolving my coverage question. The agent was knowledgeable and patient. I appreciate the excellent service and look forward to continuing as a customer. The discount on my bundled policies was a nice bonus too.'
    )[UNIFORM(0, 9, RANDOM())]::VARCHAR AS BODY,
    ARRAY_CONSTRUCT('Inbound','Inbound','Inbound','Outbound')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS DIRECTION,
    DATEADD('second', -UNIFORM(0, 15552000, RANDOM()), CURRENT_TIMESTAMP()) AS SENT_AT,
    CURRENT_TIMESTAMP() AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

----------------------------------------------------------------------
-- 8. NOTE (~12,000 rows)
----------------------------------------------------------------------
INSERT INTO NOTE (
    NOTE_ID, CUSTOMER_ID, INTERACTION_ID, AGENT_ID, NOTE_TEXT, CREATED_AT
)
SELECT
    'NTE-' || LPAD(SEQ4()::VARCHAR, 7, '0') AS NOTE_ID,
    'CUST-' || LPAD(UNIFORM(0, 9999, RANDOM())::VARCHAR, 6, '0') AS CUSTOMER_ID,
    'INT-' || LPAD(UNIFORM(0, 49999, RANDOM())::VARCHAR, 7, '0') AS INTERACTION_ID,
    'AGT-' || LPAD(UNIFORM(1, 200, RANDOM())::VARCHAR, 4, '0') AS AGENT_ID,
    ARRAY_CONSTRUCT(
        'Customer expressed high frustration about claim processing time. Mentioned considering switch to competitor. Offered to escalate to claims manager. Follow-up required within 48 hours.',
        'Customer called about renewal pricing. Has quotes from Geico and Progressive that are lower. Applied multi-policy discount and safe driver discount. Customer agreed to stay if rate is maintained next year.',
        'Payment issue resolved. Updated expired card on file. Waived $25 late fee as goodwill gesture. Customer seemed satisfied with resolution.',
        'Customer requested policy cancellation. Attempted retention offer of 10% discount plus accident forgiveness. Customer declined - already signed with competitor. Process cancellation for end of billing cycle.',
        'Routine check-in call with premium customer. Reviewed coverage adequacy. Identified gap in umbrella coverage. Customer interested in quote - sending follow-up email.',
        'Claim filed for roof damage from recent storm. Sent adjuster appointment for Thursday. Customer anxious about timeline. Reassured about expedited processing for weather events.',
        'Customer unhappy about denied claim. Explained exclusion clause. Customer wants to appeal. Transferred to claims review department. High churn risk - flag for retention team.',
        'Cross-sell opportunity identified. Customer only has auto but recently purchased home. Mentioned bundling discount. Will send personalized quote via email.',
        'Customer had questions about deductible vs premium tradeoff. Explained options clearly. Customer decided to increase deductible from $500 to $1000 to save on monthly premium.',
        'Billing dispute resolved. Double charge confirmed as system error. Refund processed. Apologized for inconvenience. Customer appreciated quick resolution.'
    )[UNIFORM(0, 9, RANDOM())]::VARCHAR AS NOTE_TEXT,
    DATEADD('second', -UNIFORM(0, 15552000, RANDOM()), CURRENT_TIMESTAMP()) AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 12000));

----------------------------------------------------------------------
-- 9. SURVEY (~5,000 rows)
----------------------------------------------------------------------
INSERT INTO SURVEY (
    SURVEY_ID, CUSTOMER_ID, SURVEY_TYPE, NPS_SCORE, CSAT_SCORE,
    COMMENTS, SUBMITTED_AT, CREATED_AT
)
SELECT
    'SRV-' || LPAD(SEQ4()::VARCHAR, 7, '0') AS SURVEY_ID,
    'CUST-' || LPAD(UNIFORM(0, 9999, RANDOM())::VARCHAR, 6, '0') AS CUSTOMER_ID,
    ARRAY_CONSTRUCT('NPS','CSAT','Post-Claim','Post-Call','Annual')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS SURVEY_TYPE,
    UNIFORM(0, 10, RANDOM()) AS NPS_SCORE,
    UNIFORM(1, 5, RANDOM()) AS CSAT_SCORE,
    ARRAY_CONSTRUCT(
        'Very happy with the service. Quick resolution and friendly agent.',
        'Terrible experience. Claim took too long and nobody kept me informed.',
        'Average service. Nothing special but got the job done.',
        'Would recommend to friends. Great rates and easy to work with.',
        'Extremely disappointed. Switching to State Farm next month.',
        'The agent was helpful but the wait time was too long.',
        'Best insurance experience I have ever had. 10 out of 10.',
        'Frustrated with premium increase. Considering Allstate or Progressive.',
        'Claim process was smooth but the payout was less than expected.',
        'Good company overall but their app could use some improvement.',
        'I have been a customer for 10 years and loyalty means nothing to them.',
        'Recently compared with USAA and your rates are much higher for same coverage.'
    )[UNIFORM(0, 11, RANDOM())]::VARCHAR AS COMMENTS,
    DATEADD('second', -UNIFORM(0, 15552000, RANDOM()), CURRENT_TIMESTAMP()) AS SUBMITTED_AT,
    CURRENT_TIMESTAMP() AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 5000));
