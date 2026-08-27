"""
NEXUS 360 — Insurance Customer 360 Dashboard
Streamlit Community Cloud Version (uses st.connection for Snowflake)
"""

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import json
import pandas as pd

st.set_page_config(page_title="NEXUS 360", page_icon="🎯", layout="wide")

# Initialize Snowflake connection
conn = st.connection("snowflake")


def run_query(sql):
    """Execute SQL and return pandas DataFrame."""
    return conn.query(sql)


def run_query_safe(sql):
    """Execute SQL and return pandas DataFrame, empty on error."""
    try:
        return conn.query(sql)
    except Exception as e:
        st.error(f"Query error: {str(e)}")
        return pd.DataFrame()


# ─── Page Functions ───────────────────────────────────────────────────────────

def portfolio_view():
    st.title("📊 Portfolio View")
    st.caption("Real-time customer health and risk overview")

    # KPIs
    kpi_df = run_query("""
        SELECT
            COUNT(*) AS TOTAL_CUSTOMERS,
            ROUND(AVG(HEALTH_SCORE), 1) AS AVG_HEALTH,
            ROUND(AVG(CHURN_RISK) * 100, 1) AS AVG_CHURN_PCT,
            SUM(CASE WHEN RISK_LEVEL = 'CRITICAL' THEN 1 ELSE 0 END) AS CRITICAL_COUNT,
            SUM(CASE WHEN RISK_LEVEL = 'AT_RISK' THEN 1 ELSE 0 END) AS AT_RISK_COUNT
        FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH
    """)

    if not kpi_df.empty:
        row = kpi_df.iloc[0]
        c1, c2, c3, c4, c5 = st.columns(5)
        c1.metric("Total Customers", f"{int(row['TOTAL_CUSTOMERS']):,}")
        c2.metric("Avg Health Score", f"{row['AVG_HEALTH']}")
        c3.metric("Avg Churn Risk", f"{row['AVG_CHURN_PCT']}%")
        c4.metric("Critical Alerts", f"{int(row['CRITICAL_COUNT']):,}")
        c5.metric("At Risk", f"{int(row['AT_RISK_COUNT']):,}")

    st.divider()

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Risk Distribution")
        risk_df = run_query("""
            SELECT RISK_LEVEL, COUNT(*) AS COUNT
            FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH
            GROUP BY RISK_LEVEL
            ORDER BY CASE RISK_LEVEL
                WHEN 'CRITICAL' THEN 1
                WHEN 'AT_RISK' THEN 2
                WHEN 'MONITOR' THEN 3
                ELSE 4 END
        """)
        if not risk_df.empty:
            fig = px.pie(risk_df, names='RISK_LEVEL', values='COUNT',
                         color='RISK_LEVEL',
                         color_discrete_map={'CRITICAL': '#dc3545', 'AT_RISK': '#fd7e14',
                                             'MONITOR': '#ffc107', 'HEALTHY': '#28a745'})
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("Health by Segment")
        seg_df = run_query("""
            SELECT C.SEGMENT, ROUND(AVG(H.HEALTH_SCORE), 1) AS AVG_HEALTH,
                   COUNT(*) AS CUSTOMER_COUNT
            FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER C
            JOIN SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH H ON C.CUSTOMER_ID = H.CUSTOMER_ID
            GROUP BY C.SEGMENT
            ORDER BY AVG_HEALTH
        """)
        if not seg_df.empty:
            fig = px.bar(seg_df, x='SEGMENT', y='AVG_HEALTH', color='SEGMENT',
                         text='AVG_HEALTH')
            fig.update_layout(showlegend=False)
            st.plotly_chart(fig, use_container_width=True)

    # Critical alerts table
    st.subheader("Critical Customers Requiring Attention")
    critical_df = run_query("""
        SELECT C.CUSTOMER_ID, C.FIRST_NAME || ' ' || C.LAST_NAME AS NAME,
               C.SEGMENT, H.HEALTH_SCORE, H.CHURN_RISK, H.RISK_LEVEL,
               H.SENTIMENT_SCORE
        FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH H
        JOIN SFK_HACKATHON.SFK_HACK_1.CUSTOMER C ON H.CUSTOMER_ID = C.CUSTOMER_ID
        WHERE H.RISK_LEVEL = 'CRITICAL'
        ORDER BY H.CHURN_RISK DESC
        LIMIT 20
    """)
    if not critical_df.empty:
        st.dataframe(critical_df, use_container_width=True)


def customer_360():
    st.title("👤 Customer 360")
    st.caption("Deep-dive into individual customer profiles")

    customer_id = st.text_input("Enter Customer ID", value="CUST-000001", key="c360_search")

    if customer_id:
        cust_df = run_query(f"""
            SELECT C.*, H.HEALTH_SCORE, H.CHURN_RISK, H.RISK_LEVEL,
                   H.SENTIMENT_SCORE, H.CLAIMS_SCORE, H.PAYMENT_SCORE, H.ENGAGEMENT_SCORE
            FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER C
            LEFT JOIN SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH H ON C.CUSTOMER_ID = H.CUSTOMER_ID
            WHERE C.CUSTOMER_ID = '{customer_id}'
        """)

        if cust_df.empty:
            st.warning("Customer not found")
            return

        row = cust_df.iloc[0]
        st.subheader(f"{row['FIRST_NAME']} {row['LAST_NAME']}")

        hc1, hc2, hc3, hc4, hc5 = st.columns(5)
        hc1.metric("Health Score", f"{row['HEALTH_SCORE']}/100" if pd.notna(row['HEALTH_SCORE']) else "N/A")
        hc2.metric("Churn Risk", f"{round(row['CHURN_RISK']*100, 1)}%" if pd.notna(row['CHURN_RISK']) else "N/A")
        hc3.metric("Risk Level", row['RISK_LEVEL'] if pd.notna(row['RISK_LEVEL']) else "N/A")
        hc4.metric("Segment", row['SEGMENT'])
        hc5.metric("Tenure", f"{row['TENURE_MONTHS']} months")

        st.divider()

        tab1, tab2, tab3, tab4, tab5 = st.tabs(["Policies", "Claims", "Timeline", "Evidence", "NBA"])

        with tab1:
            policies = run_query(f"""
                SELECT POLICY_ID, POLICY_TYPE, PREMIUM_AMOUNT, STATUS, START_DATE, END_DATE
                FROM SFK_HACKATHON.SFK_HACK_1.POLICY
                WHERE CUSTOMER_ID = '{customer_id}'
                ORDER BY START_DATE DESC
            """)
            st.dataframe(policies, use_container_width=True)

        with tab2:
            claims = run_query(f"""
                SELECT CLAIM_ID, CLAIM_TYPE, CLAIM_AMOUNT, STATUS, FILED_DATE, RESOLUTION_DAYS
                FROM SFK_HACKATHON.SFK_HACK_1.CLAIM
                WHERE CUSTOMER_ID = '{customer_id}'
                ORDER BY FILED_DATE DESC
            """)
            st.dataframe(claims, use_container_width=True)

        with tab3:
            events = run_query(f"""
                SELECT EVENT_TYPE, EVENT_TIMESTAMP, SOURCE_TABLE, SOURCE_ID
                FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_EVENT
                WHERE CUSTOMER_ID = '{customer_id}'
                ORDER BY EVENT_TIMESTAMP DESC
                LIMIT 50
            """)
            st.dataframe(events, use_container_width=True)

        with tab4:
            st.subheader("Supporting Evidence")
            evidence = run_query(f"""
                SELECT SOURCE_TYPE, LEFT(CONTENT, 300) AS CONTENT_PREVIEW,
                       SENTIMENT, MOMENT_TYPE, EVENT_DATE
                FROM SFK_HACKATHON.SFK_HACK_1.EVIDENCE_SOURCE
                WHERE CUSTOMER_ID = '{customer_id}'
                ORDER BY EVENT_DATE DESC
                LIMIT 10
            """)
            st.dataframe(evidence, use_container_width=True)

        with tab5:
            st.subheader("Next Best Actions")
            nbas = run_query(f"""
                SELECT ACTION_ID, ACTION_TYPE, CONFIDENCE, RATIONALE, PRIORITY, STATUS
                FROM SFK_HACKATHON.SFK_HACK_1.NEXT_BEST_ACTION
                WHERE CUSTOMER_ID = '{customer_id}'
                  AND SUPPRESSED = FALSE
                ORDER BY PRIORITY ASC, CONFIDENCE DESC
            """)
            st.dataframe(nbas, use_container_width=True)

        # Active moments
        st.subheader("Active Moments")
        moments = run_query(f"""
            SELECT MOMENT_TYPE, CONFIDENCE, DETECTED_AT, CONTEXT
            FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_MOMENT
            WHERE CUSTOMER_ID = '{customer_id}'
              AND (EXPIRES_AT IS NULL OR EXPIRES_AT > CURRENT_TIMESTAMP())
            ORDER BY DETECTED_AT DESC
        """)
        if not moments.empty:
            st.dataframe(moments, use_container_width=True)
        else:
            st.info("No active moments detected")


def employee_copilot():
    st.title("🤖 Employee Copilot")
    st.caption("AI-powered assistant for customer insights and actions")

    # Role selector
    role = st.selectbox("Employee Role", [
        "Retention Manager",
        "Claims Analyst",
        "Service Agent"
    ], key="copilot_role")

    # Sample questions
    st.subheader("Try these sample questions:")
    sample_questions = {
        "Retention Manager": [
            "Which customers are at critical churn risk and need immediate attention?",
            "Show me customers with competitor mentions in the last 30 days",
            "What retention offers are pending approval?",
        ],
        "Claims Analyst": [
            "Which claims have been open for more than 14 days with negative sentiment?",
            "Show me the claim friction moments detected this week",
            "What is the average resolution time by claim type?",
        ],
        "Service Agent": [
            "Give me a 360 view of customer CUST-000001",
            "What are the top reasons customers are contacting us?",
            "Show me customers with payment assistance recommendations",
        ],
    }

    cols = st.columns(3)
    for i, q in enumerate(sample_questions.get(role, sample_questions["Service Agent"])):
        if cols[i].button(q, key=f"sample_{i}"):
            st.session_state["prefill_question"] = q
            st.rerun()

    st.divider()

    # Chat interface
    if "messages" not in st.session_state:
        st.session_state.messages = []

    for msg in st.session_state.messages:
        if msg["role"] == "user":
            st.info(f"**You:** {msg['content']}")
        else:
            st.success(f"**Copilot:** {msg['content']}")

    # Input form
    prefill = st.session_state.pop("prefill_question", "")
    with st.form("copilot_form", clear_on_submit=True):
        prompt = st.text_input("Ask about customers, portfolio health, or actions...", value=prefill)
        submitted = st.form_submit_button("Send")

    if submitted and prompt:
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.spinner("Thinking..."):
            full_prompt = f"[Role: {role}] {prompt}"
            try:
                # Step 1: Search for relevant evidence
                search_results = run_query(f"""
                    SELECT TOP 5 CONTENT, SOURCE_TYPE, CUSTOMER_ID, SENTIMENT
                    FROM TABLE(
                        SFK_HACKATHON.SFK_HACK_1.NEXUS360_EVIDENCE_SEARCH!SEARCH(
                            QUERY => '{prompt.replace("'", "''")}',
                            COLUMNS => ['CONTENT', 'SOURCE_TYPE', 'CUSTOMER_ID', 'SENTIMENT']
                        )
                    )
                """)

                context_text = ""
                for _, r in search_results.iterrows():
                    context_text += f"[{r['SOURCE_TYPE']}] (Customer: {r['CUSTOMER_ID']}, Sentiment: {r['SENTIMENT']}): {str(r['CONTENT'])[:300]}\n\n"

                # Step 2: Get portfolio stats
                stats_df = run_query("""
                    SELECT COUNT(*) AS TOTAL,
                           SUM(CASE WHEN RISK_LEVEL = 'CRITICAL' THEN 1 ELSE 0 END) AS CRITICAL,
                           SUM(CASE WHEN RISK_LEVEL = 'AT_RISK' THEN 1 ELSE 0 END) AS AT_RISK,
                           ROUND(AVG(HEALTH_SCORE), 1) AS AVG_HEALTH,
                           ROUND(AVG(CHURN_RISK), 3) AS AVG_CHURN
                    FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH
                """)
                stats_text = ""
                if not stats_df.empty:
                    s = stats_df.iloc[0]
                    stats_text = f"Portfolio: {int(s['TOTAL'])} customers, {int(s['CRITICAL'])} critical, {int(s['AT_RISK'])} at-risk, avg health {s['AVG_HEALTH']}, avg churn {s['AVG_CHURN']}"

                # Step 3: Use Cortex COMPLETE with RAG context
                system_prompt = f"""You are NEXUS 360 Employee Copilot for an insurance company.
Role: {role}. Answer based on the evidence and data provided.
Portfolio Stats: {stats_text}
Evidence from customer interactions:
{context_text}
Provide actionable insights. Be concise and specific."""

                result_df = run_query(f"""
                    SELECT SNOWFLAKE.CORTEX.COMPLETE(
                        'mistral-large2',
                        ARRAY_CONSTRUCT(
                            OBJECT_CONSTRUCT('role', 'system', 'content', '{system_prompt.replace("'", "''")}'),
                            OBJECT_CONSTRUCT('role', 'user', 'content', '{full_prompt.replace("'", "''")}')
                        ),
                        OBJECT_CONSTRUCT('temperature', 0.3, 'max_tokens', 1024)
                    ) AS RESPONSE
                """)

                if not result_df.empty:
                    resp_json = json.loads(result_df.iloc[0]['RESPONSE'])
                    choices = resp_json.get('choices', [])
                    if choices:
                        message = choices[0].get('message', choices[0].get('messages', ''))
                        if isinstance(message, dict):
                            response = message.get('content', str(message))
                        else:
                            response = str(message)
                    else:
                        response = str(resp_json)
                else:
                    response = "Unable to get response"
            except Exception as e:
                response = f"Error: {str(e)}"

            st.session_state.messages.append({"role": "assistant", "content": response})
            st.rerun()


def nba_dashboard():
    st.title("🎯 NBA Dashboard")
    st.caption("Next Best Action queue - review, approve, and track recommendations")

    # Summary metrics
    nba_stats = run_query("""
        SELECT
            COUNT(*) AS TOTAL,
            SUM(CASE WHEN STATUS = 'PENDING' THEN 1 ELSE 0 END) AS PENDING,
            SUM(CASE WHEN STATUS = 'APPROVED' THEN 1 ELSE 0 END) AS APPROVED,
            SUM(CASE WHEN STATUS = 'REJECTED' THEN 1 ELSE 0 END) AS REJECTED,
            SUM(CASE WHEN SUPPRESSED = TRUE THEN 1 ELSE 0 END) AS SUPPRESSED
        FROM SFK_HACKATHON.SFK_HACK_1.NEXT_BEST_ACTION
    """)

    if not nba_stats.empty:
        row = nba_stats.iloc[0]
        c1, c2, c3, c4, c5 = st.columns(5)
        c1.metric("Total Actions", int(row['TOTAL']))
        c2.metric("Pending", int(row['PENDING']))
        c3.metric("Approved", int(row['APPROVED']))
        c4.metric("Rejected", int(row['REJECTED']))
        c5.metric("Suppressed", int(row['SUPPRESSED']))

    st.divider()

    # Filter
    action_filter = st.selectbox("Filter by Action Type", [
        "All", "RETENTION_OFFER", "CLAIMS_ESCALATION",
        "COMPETITOR_RETENTION_CAMPAIGN", "CROSS_SELL", "PAYMENT_ASSISTANCE"
    ], key="nba_filter")

    where_clause = "" if action_filter == "All" else f"AND N.ACTION_TYPE = '{action_filter}'"

    actions_df = run_query(f"""
        SELECT N.ACTION_ID, N.CUSTOMER_ID,
               C.FIRST_NAME || ' ' || C.LAST_NAME AS CUSTOMER_NAME,
               N.ACTION_TYPE, N.CONFIDENCE, N.RATIONALE,
               N.PRIORITY, N.STATUS, N.CREATED_AT
        FROM SFK_HACKATHON.SFK_HACK_1.NEXT_BEST_ACTION N
        JOIN SFK_HACKATHON.SFK_HACK_1.CUSTOMER C ON N.CUSTOMER_ID = C.CUSTOMER_ID
        WHERE N.STATUS = 'PENDING' AND N.SUPPRESSED = FALSE
        {where_clause}
        ORDER BY N.PRIORITY ASC, N.CONFIDENCE DESC
        LIMIT 50
    """)

    if not actions_df.empty:
        st.subheader("Pending Actions")
        st.dataframe(actions_df, use_container_width=True)

        st.subheader("Take Action")
        col1, col2, col3 = st.columns(3)
        with col1:
            selected_action = st.selectbox("Select Action ID",
                                           actions_df['ACTION_ID'].tolist(),
                                           key="nba_select")
        with col2:
            approver = st.text_input("Approver Name", value="Admin", key="nba_approver")
        with col3:
            decision = st.selectbox("Decision", ["APPROVED", "REJECTED"], key="nba_decision")

        if st.button("Submit Decision", key="nba_submit"):
            try:
                run_query(f"""
                    CALL SFK_HACKATHON.SFK_HACK_1.APPROVE_NBA_ACTION(
                        '{selected_action}', '{approver}', '{decision}'
                    )
                """)
                st.success(f"Action {selected_action} {decision} by {approver}")
                st.rerun()
            except Exception as e:
                st.error(f"Error: {str(e)}")
    else:
        st.info("No pending actions in queue")

    # Effectiveness chart
    st.subheader("NBA Effectiveness by Type")
    eff_df = run_query("""
        SELECT ACTION_TYPE,
               COUNT(*) AS TOTAL,
               SUM(CASE WHEN DECISION = 'APPROVED' THEN 1 ELSE 0 END) AS APPROVED,
               SUM(CASE WHEN OUTCOME = 'SUCCESSFUL' THEN 1 ELSE 0 END) AS SUCCESSFUL
        FROM SFK_HACKATHON.SFK_HACK_1.NEXT_BEST_ACTION_LOG
        GROUP BY ACTION_TYPE
    """)
    if not eff_df.empty:
        fig = px.bar(eff_df, x='ACTION_TYPE', y=['TOTAL', 'APPROVED', 'SUCCESSFUL'],
                     barmode='group', title='Actions by Type and Outcome')
        st.plotly_chart(fig, use_container_width=True)


def realtime_simulation():
    st.title("⚡ Real-Time Simulation")
    st.caption("Inject a new interaction and observe how health, risk, and NBA update")

    customer_id = st.text_input("Customer ID to simulate", value="CUST-000001", key="sim_customer")

    if customer_id:
        st.subheader("Current State")
        current_df = run_query(f"""
            SELECT H.HEALTH_SCORE, H.CHURN_RISK, H.RISK_LEVEL,
                   H.SENTIMENT_SCORE, H.ENGAGEMENT_SCORE
            FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH H
            WHERE H.CUSTOMER_ID = '{customer_id}'
        """)

        if not current_df.empty:
            row = current_df.iloc[0]
            bc1, bc2, bc3, bc4 = st.columns(4)
            bc1.metric("Health", row['HEALTH_SCORE'])
            bc2.metric("Churn Risk", f"{round(row['CHURN_RISK']*100, 1)}%")
            bc3.metric("Risk Level", row['RISK_LEVEL'])
            bc4.metric("Sentiment", row['SENTIMENT_SCORE'])

        st.divider()

        st.subheader("Inject New Interaction")
        col1, col2 = st.columns(2)
        with col1:
            channel = st.selectbox("Channel", ["Phone", "Email", "Chat"], key="sim_channel")
            topic = st.selectbox("Topic", [
                "Cancellation Request", "Complaint", "Billing Inquiry",
                "Claim Status", "Policy Change", "New Quote"
            ], key="sim_topic")
        with col2:
            sentiment_sim = st.slider("Simulated Sentiment", -1.0, 1.0, -0.5, key="sim_sentiment")
            has_competitor = st.checkbox("Mentions Competitor", value=True, key="sim_competitor")

        transcript_text = st.text_area("Interaction Content",
            value="I have been looking at quotes from Progressive and they are much cheaper. "
                  "I am seriously thinking about switching all my policies. "
                  "Your service has been declining and I do not feel valued as a customer.",
            key="sim_transcript")

        if st.button("Run Simulation", type="primary", key="sim_run"):
            with st.spinner("Processing simulation..."):
                try:
                    sent_label = "POSITIVE" if sentiment_sim >= 0.3 else "NEGATIVE" if sentiment_sim <= -0.3 else "NEUTRAL"
                    classif = "CHURN" if topic == "Cancellation Request" else "CLAIM_FRICTION" if topic == "Claim Status" else "GENERAL_INQUIRY"

                    # Insert interaction
                    run_query(f"""
                        INSERT INTO SFK_HACKATHON.SFK_HACK_1.INTERACTION
                        (INTERACTION_ID, CUSTOMER_ID, CHANNEL, DIRECTION, INTERACTION_DATE, DURATION_SECONDS, TOPIC)
                        VALUES ('INT-SIM-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                                '{customer_id}', '{channel}', 'Inbound', CURRENT_TIMESTAMP(), 300, '{topic}')
                    """)

                    # Insert transcript
                    run_query(f"""
                        INSERT INTO SFK_HACKATHON.SFK_HACK_1.TRANSCRIPT
                        (TRANSCRIPT_ID, INTERACTION_ID, CUSTOMER_ID, TRANSCRIPT_TEXT)
                        VALUES ('TRN-SIM-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                                'INT-SIM-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                                '{customer_id}', '{transcript_text.replace("'", "''")}')
                    """)

                    # Insert enrichment
                    run_query(f"""
                        INSERT INTO SFK_HACKATHON.SFK_HACK_1.CUSTOMER_AI_ENRICHMENT
                        (ENRICHMENT_ID, CUSTOMER_ID, SOURCE_TABLE, SOURCE_ID,
                         SENTIMENT_SCORE, SENTIMENT_LABEL, CLASSIFICATION)
                        VALUES ('ENR-SIM-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                                '{customer_id}', 'TRANSCRIPT',
                                'TRN-SIM-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                                {sentiment_sim}, '{sent_label}', '{classif}')
                    """)

                    # Update health score
                    run_query(f"""
                        MERGE INTO SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH T
                        USING (
                            SELECT '{customer_id}' AS CUSTOMER_ID,
                                   GREATEST(0, LEAST(100,
                                       COALESCE((SELECT AVG(SENTIMENT_SCORE) FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_AI_ENRICHMENT WHERE CUSTOMER_ID = '{customer_id}' AND SENTIMENT_SCORE IS NOT NULL), 0) * 25 + 50
                                   )) AS NEW_SENTIMENT
                        ) S ON T.CUSTOMER_ID = S.CUSTOMER_ID
                        WHEN MATCHED THEN UPDATE SET
                            SENTIMENT_SCORE = S.NEW_SENTIMENT,
                            CHURN_RISK = LEAST(1.0, T.CHURN_RISK + 0.15),
                            HEALTH_SCORE = GREATEST(0, T.HEALTH_SCORE - 10),
                            RISK_LEVEL = CASE
                                WHEN LEAST(1.0, T.CHURN_RISK + 0.15) >= 0.7 THEN 'CRITICAL'
                                WHEN LEAST(1.0, T.CHURN_RISK + 0.15) >= 0.4 THEN 'AT_RISK'
                                WHEN LEAST(1.0, T.CHURN_RISK + 0.15) >= 0.2 THEN 'MONITOR'
                                ELSE 'HEALTHY'
                            END,
                            SCORED_AT = CURRENT_TIMESTAMP()
                    """)

                    st.success("Simulation complete! Interaction injected and scores updated.")

                    # Show updated state
                    st.subheader("Updated State")
                    updated_df = run_query(f"""
                        SELECT H.HEALTH_SCORE, H.CHURN_RISK, H.RISK_LEVEL,
                               H.SENTIMENT_SCORE, H.ENGAGEMENT_SCORE
                        FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH H
                        WHERE H.CUSTOMER_ID = '{customer_id}'
                    """)

                    if not updated_df.empty and not current_df.empty:
                        urow = updated_df.iloc[0]
                        old_health = row['HEALTH_SCORE']
                        old_churn = row['CHURN_RISK']
                        uc1, uc2, uc3, uc4 = st.columns(4)
                        uc1.metric("Health", urow['HEALTH_SCORE'],
                                   delta=f"{urow['HEALTH_SCORE'] - old_health:.1f}")
                        uc2.metric("Churn Risk", f"{round(urow['CHURN_RISK']*100, 1)}%",
                                   delta=f"{round((urow['CHURN_RISK'] - old_churn)*100, 1)}%")
                        uc3.metric("Risk Level", urow['RISK_LEVEL'])
                        uc4.metric("Sentiment", urow['SENTIMENT_SCORE'])
                except Exception as e:
                    st.error(f"Simulation error: {str(e)}")


# ─── Navigation ───────────────────────────────────────────────────────────────

with st.sidebar:
    st.title("NEXUS 360")
    st.caption("AI-Powered Insurance Customer 360")
    st.divider()
    page = st.radio("Navigate", [
        "📊 Portfolio View",
        "👤 Customer 360",
        "🤖 Employee Copilot",
        "🎯 NBA Dashboard",
        "⚡ Real-Time Simulation",
    ], key="nav")
    st.divider()
    st.caption("Built with Snowflake Cortex AI")

if page == "📊 Portfolio View":
    portfolio_view()
elif page == "👤 Customer 360":
    customer_360()
elif page == "🤖 Employee Copilot":
    employee_copilot()
elif page == "🎯 NBA Dashboard":
    nba_dashboard()
elif page == "⚡ Real-Time Simulation":
    realtime_simulation()
