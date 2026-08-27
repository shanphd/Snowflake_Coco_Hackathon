# NEXUS 360 — Requirements Specification

## 1. Project Overview

**Project:** NEXUS 360  
**Platform:** Snowflake  
**Database:** `SFK_HACKATHON`  
**Schema:** `SFK_HACK_1`  
**Warehouse:** `SHAN_WH`

NEXUS 360 is an insurance Customer 360 and employee decision-support platform. It combines structured customer data, unstructured customer interactions, Cortex AI enrichment, customer-moment detection, health scoring, Next Best Action (NBA) recommendations, evidence retrieval, semantic analytics, and an AI-powered employee copilot.

The system must support a complete demonstration flow:

**Portfolio → Ask → Open Customer → Timeline → Evidence → NBA → Approve → Simulate → Outcome**

---

## 2. Goals

The system shall:

1. Provide a unified 360-degree view of insurance customers.
2. Consolidate customer, policy, claim, payment, interaction, transcript, email, note, and survey data.
3. Enrich unstructured customer content using Snowflake Cortex AI.
4. Detect important customer moments such as churn risk and claim friction.
5. Calculate a composite customer health score and churn risk.
6. Recommend deterministic Next Best Actions with confidence and suppression logic.
7. Retrieve supporting evidence from customer interactions.
8. Answer portfolio-level analytical questions through Cortex Analyst.
9. Provide an AI employee copilot through Cortex Agent.
10. Provide a Streamlit-in-Snowflake dashboard for portfolio and customer workflows.
11. Support human approval and outcome tracking for recommended actions.
12. Demonstrate risk updates through a real-time interaction simulation.

---

## 3. Scope

### 3.1 In Scope

- Synthetic insurance customer data generation.
- Customer 360 data model.
- Structured and unstructured data storage in Snowflake.
- Cortex AI enrichment.
- Unified customer event timeline.
- Customer moment detection.
- Customer health and churn-risk scoring.
- Deterministic NBA decision engine.
- Action suppression and confidence scoring.
- Human approval workflow.
- NBA outcome tracking.
- Cortex Search evidence retrieval.
- Cortex Analyst semantic model.
- Cortex Agent orchestration.
- Streamlit dashboard.
- Real-time simulation.
- Verification and demo flow.

### 3.2 Out of Scope

The initial implementation does not require:
- Production customer data integration.
- External CRM integration.
- Actual insurance policy issuance or modification.
- Autonomous execution of customer-facing actions without human approval.
- Production-grade predictive model training beyond the specified AI/rule-based enrichment.
- Mobile application development.

---

# 4. Functional Requirements

## FR-001 — Customer Data Foundation

The system shall maintain a `CUSTOMER` table containing core customer information, including appropriate identifiers, segment, region, tenure, and other attributes required for Customer 360 analytics.

## FR-002 — Policy Management

The system shall maintain a `POLICY` table containing customer insurance policies, including:

- Policy identifier
- Customer identifier
- Policy type
- Premium
- Start date
- End date
- Status

## FR-003 — Claims Management

The system shall maintain a `CLAIM` table containing claims, including:

- Claim identifier
- Customer identifier
- Claim type
- Claim amount
- Claim status
- Resolution duration

## FR-004 — Payment Tracking

The system shall maintain a `PAYMENT` table containing premium payments and payment outcomes, including payment failures.

## FR-005 — Interaction Tracking

The system shall maintain an `INTERACTION` table representing customer touchpoints such as:

- Calls
- Emails
- Chats

Interaction records shall support relevant metadata for downstream analytics and AI processing.

## FR-006 — Transcript Storage

The system shall maintain a `TRANSCRIPT` table containing full call transcript text for AI processing.

Transcripts should support insurance-specific language and signals such as:

- Competitor mentions
- Frustration
- Cancellation intent
- Product requests
- Payment issues

## FR-007 — Email Storage

The system shall maintain an `EMAIL` table containing customer email information, including:

- Subject
- Body
- Direction
- Customer association

## FR-008 — Agent Notes

The system shall maintain a `NOTE` table for free-text agent notes associated with customers and relevant interactions.

## FR-009 — Survey Storage

The system shall maintain a `SURVEY` table containing customer survey responses, including NPS/CSAT information.

## FR-010 — Unified Customer Events

The system shall maintain a `CUSTOMER_EVENT` table that provides a unified event stream across source tables.

Each event shall support at minimum:

- Customer identifier
- Event type
- Event timestamp
- Event payload

## FR-011 — Customer Moment Detection

The system shall maintain a `CUSTOMER_MOMENT` table containing detected customer moments.

The system shall support moments including, but not limited to:

- `CHURN`
- `CLAIM_FRICTION`
- `PRICE_SENSITIVITY`

Customer moments shall be generated using business rules and/or AI classification.

## FR-012 — Customer Health

The system shall maintain a `CUSTOMER_HEALTH` table containing a composite customer health score and churn risk.

The health score shall consider weighted signals including:

- Churn risk
- Sentiment trend
- Claim status
- Payment health
- Engagement

## FR-013 — AI Sentiment Analysis

The system shall use Snowflake Cortex AI, including `CORTEX.COMPLETE`, to analyze transcripts and emails.

The system shall derive:

- Sentiment score
- Sentiment label

## FR-014 — Entity and Intent Extraction

The AI enrichment process shall identify relevant entities and intents, including:

- Competitor mentions
- Cancellation intent
- Payment issues
- Product requests

## FR-015 — Interaction Classification

The system shall classify interactions into customer moments such as:

- Churn
- Claim friction
- Price sensitivity
- Other relevant business moments

## FR-016 — Customer Summarization

The system shall generate per-customer interaction summaries from relevant unstructured customer content.

AI enrichment results shall be stored in enrichment columns or a dedicated `CUSTOMER_AI_ENRICHMENT` table.

---

# 5. Data Volume Requirements

The synthetic dataset shall approximately contain:

| Entity | Target Volume |
|---|---:|
| Customers | 10,000 |
| Policies | 25,000 |
| Claims | 15,000 |
| Interactions | 50,000 |

The generated data shall be realistic and insurance-specific.

Unstructured content shall include realistic examples of:

- Competitor mentions
- Customer frustration
- Cancellation intent
- Payment problems
- Product requests
- Claims-related issues

---

# 6. Customer Event and Moment Requirements

## FR-017 — Event Population

The system shall populate `CUSTOMER_EVENT` from all relevant source tables.

## FR-018 — Rule-Based Moment Detection

The system shall support business rules for detecting customer moments.

Example:

> If a competitor is mentioned and the customer's renewal is less than 45 days away, create a `CHURN` customer moment.

## FR-019 — Moment Context

Detected moments should retain enough contextual information to explain why the moment was generated.

---

# 7. Next Best Action Requirements

## FR-020 — NBA Engine

The system shall implement a deterministic Next Best Action decision engine.

The initial rules shall include:

| Rule | Condition | Action |
|---|---|---|
| 1 | High churn + negative sentiment + renewal < 60 days | `RETENTION_OFFER` |
| 2 | Open claim > 14 days + negative sentiment | `CLAIMS_ESCALATION` |
| 3 | Competitor mention + renewal < 45 days | `COMPETITOR_RETENTION_CAMPAIGN` |
| 4 | Premium segment + positive sentiment + eligible | `CROSS_SELL` |
| 5 | Multiple payment failures | `PAYMENT_ASSISTANCE` |

## FR-021 — Confidence Scoring

Each NBA recommendation shall include a confidence score.

## FR-022 — Action Suppression

The NBA engine shall suppress inappropriate actions.

Example:

- Do not recommend cross-sell actions to customers currently showing strong negative sentiment or active service friction.

## FR-023 — Human Approval

NBA recommendations shall support human approval before execution.

Users shall be able to:

- Approve an action
- Reject an action
- Review supporting evidence
- Review the recommendation rationale

## FR-024 — NBA Audit Trail

The system shall maintain `NEXT_BEST_ACTION_LOG` containing:

- Recommended action
- Recommendation timestamp
- Approval/rejection status
- Approver information where applicable
- Execution/outcome information
- Relevant audit metadata

## FR-025 — Outcome Tracking

The system shall track the outcome of approved NBA actions so that action effectiveness can be analyzed.

---

# 8. Cortex Search Requirements

## FR-026 — Evidence Index

A Cortex Search service shall index:

- Transcripts
- Emails
- Notes
- Surveys

## FR-027 — Evidence Retrieval

The system shall retrieve relevant evidence to support customer and NBA recommendations.

## FR-028 — Metadata Filtering

Evidence retrieval shall support filtering by:

- Customer ID
- Date range
- Sentiment
- Customer moment type

The retrieved evidence shall be usable to explain and substantiate recommendations.

---

# 9. Cortex Analyst Requirements

## FR-029 — Semantic Model

The system shall provide a semantic model YAML for portfolio analytics.

The semantic layer shall support:

- Customer health distribution
- Churn risk by segment
- Churn risk by region
- NBA effectiveness
- "What changed?" analysis
- Retention metrics

## FR-030 — Portfolio Questions

Cortex Analyst shall answer business questions using the structured Customer 360 data.

---

# 10. Cortex Agent Requirements

## FR-031 — Agent Orchestration

The system shall provide a Cortex Agent that combines:

1. Cortex Analyst for structured data queries.
2. Cortex Search for unstructured evidence retrieval.
3. Customer 360 lookup tools.
4. NBA recommendation functionality.
5. Action approval functionality.

## FR-032 — Role-Aware Responses

The agent shall support role-aware responses for:

- Retention Manager
- Claims Analyst
- Service Agent

Responses should prioritize information and recommendations relevant to the selected role.

---

# 11. Streamlit Dashboard Requirements

The system shall provide a Streamlit-in-Snowflake application.

## FR-033 — Portfolio View

The Portfolio View shall display:

- Total customer population
- Risk distribution
- Critical alerts
- Relevant portfolio-level metrics

The target population is approximately 10,000 customers.

## FR-034 — Customer 360

The Customer 360 page shall provide a deep-dive view containing:

- Customer health
- Churn risk
- Customer timeline
- Detected moments
- Relevant policies
- Claims
- Payments
- Interactions
- Supporting evidence
- NBA recommendations

## FR-035 — Employee Copilot

The application shall provide a chat interface powered by Cortex Agent.

## FR-036 — NBA Dashboard

The NBA Dashboard shall provide an action queue where users can:

- Review recommendations
- Inspect confidence
- View evidence
- Approve actions
- Reject actions

## FR-037 — Real-Time Simulation

The application shall allow a new interaction to be injected for a customer.

The simulation shall demonstrate the resulting update to:

- Customer sentiment
- Customer moment
- Health/risk
- NBA recommendation

---

# 12. Non-Functional Requirements

## NFR-001 — Traceability

Recommendations should be explainable through the underlying customer data, detected moments, and retrieved evidence.

## NFR-002 — Auditability

NBA recommendations and human approval decisions shall be auditable through `NEXT_BEST_ACTION_LOG`.

## NFR-003 — Data Consistency

Customer identifiers shall remain consistent across Customer 360 tables and event records.

## NFR-004 — Synthetic Data Quality

Synthetic records shall be internally consistent and realistic enough to support the demonstration scenarios.

## NFR-005 — Role Awareness

Agent responses and dashboard workflows shall respect the selected employee role.

## NFR-006 — Human-in-the-Loop

Customer-facing or consequential actions shall require human approval within the initial implementation.

---

# 13. Technical Requirements

The implementation shall use:

- Snowflake
- Snowflake database: `SFK_HACKATHON`
- Snowflake schema: `SFK_HACK_1`
- Snowflake warehouse: `SHAN_WH`
- Snowflake Cortex AI
- Cortex Search
- Cortex Analyst
- Cortex Agent
- Streamlit-in-Snowflake

The implementation shall include appropriate SQL, procedures, semantic model YAML, agent configuration, and Streamlit application code.

---

# 14. Required Database Objects

The following core tables shall be created:

1. `CUSTOMER`
2. `POLICY`
3. `CLAIM`
4. `PAYMENT`
5. `INTERACTION`
6. `TRANSCRIPT`
7. `EMAIL`
8. `NOTE`
9. `SURVEY`
10. `CUSTOMER_EVENT`
11. `CUSTOMER_MOMENT`
12. `CUSTOMER_HEALTH`
13. `NEXT_BEST_ACTION`
14. `NEXT_BEST_ACTION_LOG`

An additional `CUSTOMER_AI_ENRICHMENT` table may be created if AI enrichment results are not stored directly in source tables.

---

# 15. Implementation Deliverables

The project shall produce the following implementation artifacts:

1. **Table DDL and synthetic data generation scripts**
   - Database/schema setup
   - Table creation
   - Synthetic data generation
   - Data loading

2. **AI enrichment procedures**
   - Sentiment analysis
   - Entity extraction
   - Intent extraction
   - Interaction classification
   - Summarization

3. **Decision engine**
   - NBA stored procedure or equivalent implementation
   - Rule evaluation
   - Confidence scoring
   - Suppression logic
   - Approval workflow
   - Outcome logging

4. **Cortex Search service**
   - Search definition
   - Indexed source content
   - Metadata filtering

5. **Cortex Analyst semantic model**
   - Semantic model YAML
   - Required dimensions/measures
   - Portfolio analytics definitions

6. **Cortex Agent**
   - Agent definition
   - Cortex Analyst integration
   - Cortex Search integration
   - Customer 360 tools
   - NBA recommendation tool
   - Approval tool

7. **Streamlit application**
   - Portfolio View
   - Customer 360
   - Employee Copilot
   - NBA Dashboard
   - Real-Time Simulation

---

# 16. Verification and Acceptance Criteria

## AC-001 — Customer 360

Given a sample customer such as **Rajesh**, the system shall display a coherent customer journey across the available structured and unstructured data.

## AC-002 — Portfolio Analytics

The system shall display customer health and churn-risk distributions for the overall portfolio and allow analysis by segment and region.

## AC-003 — Evidence Retrieval

Given a customer or recommendation context, Cortex Search shall return relevant supporting evidence from transcripts, emails, notes, and/or surveys.

## AC-004 — Analyst Queries

Cortex Analyst shall successfully answer supported portfolio-level questions, including retention and churn-risk questions.

## AC-005 — Agent Orchestration

The Cortex Agent shall successfully combine structured analytics, unstructured evidence, Customer 360 information, and NBA functionality.

## AC-006 — NBA Recommendation

For customers meeting an NBA rule condition, the system shall generate the corresponding recommended action with confidence and rationale.

## AC-007 — Suppression

The system shall suppress inappropriate actions when suppression conditions are met.

## AC-008 — Human Approval

A user shall be able to approve or reject an NBA recommendation.

## AC-009 — Audit Trail

The approval/rejection and resulting outcome shall be recorded in the NBA audit log.

## AC-010 — Simulation

Injecting a new interaction shall demonstrate an updated customer risk/health state and potentially update the recommended NBA.

## AC-011 — End-to-End Demo

The following flow shall execute successfully:

**Portfolio → Ask → Open Customer → Timeline → Evidence → NBA → Approve → Simulate → Outcome**

---

# 17. Suggested Implementation Sequence

1. Create Snowflake database, schema, and warehouse configuration.
2. Create all foundational tables.
3. Generate and load synthetic insurance data.
4. Validate data relationships and volumes.
5. Implement Cortex AI enrichment.
6. Build the unified customer event stream.
7. Implement customer-moment detection.
8. Implement customer health and churn-risk scoring.
9. Implement the deterministic NBA engine.
10. Add confidence, suppression, approval, and audit logic.
11. Configure Cortex Search.
12. Build the Cortex Analyst semantic model.
13. Configure the Cortex Agent.
14. Build the Streamlit dashboard.
15. Implement real-time simulation.
16. Execute verification and acceptance tests.
17. Run the complete demonstration flow.

---

# 18. Dependencies

The following components depend on earlier implementation stages:

| Component | Depends On |
|---|---|
| AI enrichment | Transcripts, emails, notes |
| Customer events | Source tables |
| Customer moments | Events + AI enrichment |
| Customer health | Customer moments + claims + payments + engagement |
| NBA engine | Customer health + moments + policy data |
| Cortex Search | Unstructured content |
| Cortex Analyst | Structured data + semantic definitions |
| Cortex Agent | Analyst + Search + customer/NBA tools |
| Streamlit dashboard | All major backend components |
| Real-time simulation | Event layer + health + NBA engine |

---

# 19. Success Criteria

NEXUS 360 is considered successfully implemented when:

- The target synthetic customer dataset is available.
- Customer 360 information can be retrieved for individual customers.
- AI enrichment produces usable sentiment, entity, intent, classification, and summary results.
- Customer moments and health scores are generated.
- NBA rules generate appropriate recommendations.
- Suppression prevents inappropriate recommendations.
- Human approval and audit logging work.
- Cortex Search provides supporting evidence.
- Cortex Analyst answers supported portfolio questions.
- Cortex Agent orchestrates the available capabilities.
- The Streamlit dashboard supports all required pages.
- The real-time simulation demonstrates a measurable change.
- The complete end-to-end demo flow works successfully.
