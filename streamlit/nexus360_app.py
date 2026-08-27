"""
NEXUS 360 — Insurance Customer 360 Dashboard
Multi-page Streamlit-in-Snowflake application
"""

import streamlit as st
from snowflake.snowpark.context import get_active_session
import plotly.express as px
import plotly.graph_objects as go
import json

# Initialize session
session = get_active_session()

st.set_page_config(page_title="NEXUS 360", page_icon="🎯", layout="wide")


# ─── Page Functions ───────────────────────────────────────────────────────────

def portfolio_view():
    st.title("Portfolio View")
    st.caption("Real-time customer health and risk overview")

    # KPIs
    kpi_data = session.sql("""
        SELECT
            COUNT(*) AS total_customers,
            ROUND(AVG(HEALTH_SCORE), 1) AS avg_health,
            ROUND(AVG(CHURN_RISK) * 100, 1) AS avg_churn_pct,
            SUM(CASE WHEN RISK_LEVEL = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_count,
            SUM(CASE WHEN RISK_LEVEL = 'AT_RISK' THEN 1 ELSE 0 END) AS at_risk_count
        FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH
    """).collect()

    if kpi_data:
        row = kpi_data[0]
        c1, c2, c3, c4, c5 = st.columns(5)
        c1.metric("Total Customers", f"{row['TOTAL_CUSTOMERS']:,}")
        c2.metric("Avg Health Score", f"{row['AVG_HEALTH']}")
        c3.metric("Avg Churn Risk", f"{row['AVG_CHURN_PCT']}%")
        c4.metric("Critical Alerts", f"{row['CRITICAL_COUNT']:,}", delta=None)
        c5.metric("At Risk", f"{row['AT_RISK_COUNT']:,}")

    st.divider()

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Risk Distribution")
        risk_df = session.sql("""
            SELECT RISK_LEVEL, COUNT(*) AS COUNT
            FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH
            GROUP BY RISK_LEVEL
            ORDER BY CASE RISK_LEVEL
                WHEN 'CRITICAL' THEN 1
                WHEN 'AT_RISK' THEN 2
                WHEN 'MONITOR' THEN 3
                ELSE 4 END
        """).to_pandas()
        if not risk_df.empty:
            fig = px.pie(risk_df, names='RISK_LEVEL', values='COUNT',
                         color='RISK_LEVEL',
                         color_discrete_map={'CRITICAL': '#dc3545', 'AT_RISK': '#fd7e14',
                                             'MONITOR': '#ffc107', 'HEALTHY': '#28a745'})
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("Health by Segment")
        seg_df = session.sql("""
            SELECT C.SEGMENT, ROUND(AVG(H.HEALTH_SCORE), 1) AS AVG_HEALTH,
                   COUNT(*) AS CUSTOMER_COUNT
            FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER C
            JOIN SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH H ON C.CUSTOMER_ID = H.CUSTOMER_ID
            GROUP BY C.SEGMENT
            ORDER BY AVG_HEALTH
        """).to_pandas()
        if not seg_df.empty:
            fig = px.bar(seg_df, x='SEGMENT', y='AVG_HEALTH', color='SEGMENT',
                         text='AVG_HEALTH')
            fig.update_layout(showlegend=False)
            st.plotly_chart(fig, use_container_width=True)

    # Critical alerts table
    st.subheader("Critical Customers Requiring Attention")
    critical_df = session.sql("""
        SELECT C.CUSTOMER_ID, C.FIRST_NAME || ' ' || C.LAST_NAME AS NAME,
               C.SEGMENT, H.HEALTH_SCORE, H.CHURN_RISK, H.RISK_LEVEL,
               H.SENTIMENT_SCORE
        FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH H
        JOIN SFK_HACKATHON.SFK_HACK_1.CUSTOMER C ON H.CUSTOMER_ID = C.CUSTOMER_ID
        WHERE H.RISK_LEVEL = 'CRITICAL'
        ORDER BY H.CHURN_RISK DESC
        LIMIT 20
    """).to_pandas()
    if not critical_df.empty:
        st.dataframe(critical_df, use_container_width=True)


def customer_360():
    st.title("Customer 360")
    st.caption("Deep-dive into individual customer profiles")

    # Customer search
    customer_id = st.text_input("Enter Customer ID", value="CUST-000001", key="c360_search")

    if customer_id:
        # Customer profile
        cust = session.sql(f"""
            SELECT C.*, H.HEALTH_SCORE, H.CHURN_RISK, H.RISK_LEVEL,
                   H.SENTIMENT_SCORE, H.CLAIMS_SCORE, H.PAYMENT_SCORE, H.ENGAGEMENT_SCORE
            FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER C
            LEFT JOIN SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH H ON C.CUSTOMER_ID = H.CUSTOMER_ID
            WHERE C.CUSTOMER_ID = '{customer_id}'
        """).collect()

        if not cust:
            st.warning("Customer not found")
            return

        row = cust[0]
        st.subheader(f"{row['FIRST_NAME']} {row['LAST_NAME']}")

        # Health metrics
        hc1, hc2, hc3, hc4, hc5 = st.columns(5)
        hc1.metric("Health Score", f"{row['HEALTH_SCORE']}/100" if row['HEALTH_SCORE'] else "N/A")
        hc2.metric("Churn Risk", f"{round(row['CHURN_RISK']*100, 1)}%" if row['CHURN_RISK'] else "N/A")
        hc3.metric("Risk Level", row['RISK_LEVEL'] or "N/A")
        hc4.metric("Segment", row['SEGMENT'])
        hc5.metric("Tenure", f"{row['TENURE_MONTHS']} months")

        st.divider()

        # Tabs for detail
        tab1, tab2, tab3, tab4, tab5 = st.tabs(["Policies", "Claims", "Timeline", "Evidence", "NBA"])

        with tab1:
            policies = session.sql(f"""
                SELECT POLICY_ID, POLICY_TYPE, PREMIUM_AMOUNT, STATUS, START_DATE, END_DATE
                FROM SFK_HACKATHON.SFK_HACK_1.POLICY
                WHERE CUSTOMER_ID = '{customer_id}'
                ORDER BY START_DATE DESC
            """).to_pandas()
            st.dataframe(policies, use_container_width=True)

        with tab2:
            claims = session.sql(f"""
                SELECT CLAIM_ID, CLAIM_TYPE, CLAIM_AMOUNT, STATUS, FILED_DATE, RESOLUTION_DAYS
                FROM SFK_HACKATHON.SFK_HACK_1.CLAIM
                WHERE CUSTOMER_ID = '{customer_id}'
                ORDER BY FILED_DATE DESC
            """).to_pandas()
            st.dataframe(claims, use_container_width=True)

        with tab3:
            events = session.sql(f"""
                SELECT EVENT_TYPE, EVENT_TIMESTAMP, SOURCE_TABLE, SOURCE_ID
                FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_EVENT
                WHERE CUSTOMER_ID = '{customer_id}'
                ORDER BY EVENT_TIMESTAMP DESC
                LIMIT 50
            """).to_pandas()
            st.dataframe(events, use_container_width=True)

        with tab4:
            st.subheader("Supporting Evidence")
            evidence = session.sql(f"""
                SELECT SOURCE_TYPE, LEFT(CONTENT, 300) AS CONTENT_PREVIEW,
                       SENTIMENT, MOMENT_TYPE, EVENT_DATE
                FROM SFK_HACKATHON.SFK_HACK_1.EVIDENCE_SOURCE
                WHERE CUSTOMER_ID = '{customer_id}'
                ORDER BY EVENT_DATE DESC
                LIMIT 10
            """).to_pandas()
            st.dataframe(evidence, use_container_width=True)

        with tab5:
            st.subheader("Next Best Actions")
            nbas = session.sql(f"""
                SELECT ACTION_ID, ACTION_TYPE, CONFIDENCE, RATIONALE, PRIORITY, STATUS
                FROM SFK_HACKATHON.SFK_HACK_1.NEXT_BEST_ACTION
                WHERE CUSTOMER_ID = '{customer_id}'
                  AND SUPPRESSED = FALSE
                ORDER BY PRIORITY ASC, CONFIDENCE DESC
            """).to_pandas()
            st.dataframe(nbas, use_container_width=True)

        # Active moments
        st.subheader("Active Moments")
        moments = session.sql(f"""
            SELECT MOMENT_TYPE, CONFIDENCE, DETECTED_AT, CONTEXT
            FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_MOMENT
            WHERE CUSTOMER_ID = '{customer_id}'
              AND (EXPIRES_AT IS NULL OR EXPIRES_AT > CURRENT_TIMESTAMP())
            ORDER BY DETECTED_AT DESC
        """).to_pandas()
        if not moments.empty:
            st.dataframe(moments, use_container_width=True)
        else:
            st.info("No active moments detected")


def employee_copilot():
    st.title("Employee Copilot")
    st.caption("AI-powered assistant for customer insights and actions")

    # Role selector in sidebar
    with st.sidebar:
        role = st.selectbox("Employee Role", [
            "Retention Manager",
            "Claims Analyst",
            "Service Agent"
        ], key="copilot_role")

    # Chat interface
    if "messages" not in st.session_state:
        st.session_state.messages = []

    for msg in st.session_state.messages:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    if prompt := st.chat_input("Ask about customers, portfolio health, or actions..."):
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        with st.chat_message("assistant"):
            with st.spinner("Thinking..."):
                full_prompt = f"[Role: {role}] {prompt}"
                try:
                    result = session.sql(f"""
                        SELECT SNOWFLAKE.CORTEX.AGENT(
                            'SFK_HACKATHON.SFK_HACK_1.NEXUS360_AGENT',
                            '{full_prompt.replace("'", "''")}'
                        ) AS RESPONSE
                    """).collect()
                    response = result[0]['RESPONSE'] if result else "Unable to get response"
                except Exception as e:
                    response = f"Agent error: {str(e)}"

                st.markdown(response)
                st.session_state.messages.append({"role": "assistant", "content": response})


def nba_dashboard():
    st.title("NBA Dashboard")
    st.caption("Next Best Action queue - review, approve, and track recommendations")

    # Summary metrics
    nba_stats = session.sql("""
        SELECT
            COUNT(*) AS TOTAL,
            SUM(CASE WHEN STATUS = 'PENDING' THEN 1 ELSE 0 END) AS PENDING,
            SUM(CASE WHEN STATUS = 'APPROVED' THEN 1 ELSE 0 END) AS APPROVED,
            SUM(CASE WHEN STATUS = 'REJECTED' THEN 1 ELSE 0 END) AS REJECTED,
            SUM(CASE WHEN SUPPRESSED = TRUE THEN 1 ELSE 0 END) AS SUPPRESSED
        FROM SFK_HACKATHON.SFK_HACK_1.NEXT_BEST_ACTION
    """).collect()

    if nba_stats:
        row = nba_stats[0]
        c1, c2, c3, c4, c5 = st.columns(5)
        c1.metric("Total Actions", row['TOTAL'])
        c2.metric("Pending", row['PENDING'])
        c3.metric("Approved", row['APPROVED'])
        c4.metric("Rejected", row['REJECTED'])
        c5.metric("Suppressed", row['SUPPRESSED'])

    st.divider()

    # Filter by action type
    action_filter = st.selectbox("Filter by Action Type", [
        "All", "RETENTION_OFFER", "CLAIMS_ESCALATION",
        "COMPETITOR_RETENTION_CAMPAIGN", "CROSS_SELL", "PAYMENT_ASSISTANCE"
    ], key="nba_filter")

    where_clause = "" if action_filter == "All" else f"AND N.ACTION_TYPE = '{action_filter}'"

    # Action queue
    actions_df = session.sql(f"""
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
    """).to_pandas()

    if not actions_df.empty:
        st.subheader("Pending Actions")
        st.dataframe(actions_df, use_container_width=True)

        # Approve/reject form
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
                session.sql(f"""
                    CALL SFK_HACKATHON.SFK_HACK_1.APPROVE_NBA_ACTION(
                        '{selected_action}', '{approver}', '{decision}'
                    )
                """).collect()
                st.success(f"Action {selected_action} {decision} by {approver}")
                st.rerun()
            except Exception as e:
                st.error(f"Error: {str(e)}")
    else:
        st.info("No pending actions in queue")

    # Effectiveness chart
    st.subheader("NBA Effectiveness by Type")
    eff_df = session.sql("""
        SELECT ACTION_TYPE,
               COUNT(*) AS TOTAL,
               SUM(CASE WHEN DECISION = 'APPROVED' THEN 1 ELSE 0 END) AS APPROVED,
               SUM(CASE WHEN OUTCOME = 'SUCCESSFUL' THEN 1 ELSE 0 END) AS SUCCESSFUL
        FROM SFK_HACKATHON.SFK_HACK_1.NEXT_BEST_ACTION_LOG
        GROUP BY ACTION_TYPE
    """).to_pandas()
    if not eff_df.empty:
        fig = px.bar(eff_df, x='ACTION_TYPE', y=['TOTAL', 'APPROVED', 'SUCCESSFUL'],
                     barmode='group', title='Actions by Type and Outcome')
        st.plotly_chart(fig, use_container_width=True)


def realtime_simulation():
    st.title("Real-Time Simulation")
    st.caption("Inject a new interaction and observe how health, risk, and NBA update")

    # Customer selection
    customer_id = st.text_input("Customer ID to simulate", value="CUST-000001", key="sim_customer")

    # Show current state
    if customer_id:
        st.subheader("Current State")
        current = session.sql(f"""
            SELECT H.HEALTH_SCORE, H.CHURN_RISK, H.RISK_LEVEL,
                   H.SENTIMENT_SCORE, H.ENGAGEMENT_SCORE
            FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH H
            WHERE H.CUSTOMER_ID = '{customer_id}'
        """).collect()

        if current:
            row = current[0]
            bc1, bc2, bc3, bc4 = st.columns(4)
            bc1.metric("Health", row['HEALTH_SCORE'])
            bc2.metric("Churn Risk", f"{round(row['CHURN_RISK']*100, 1)}%")
            bc3.metric("Risk Level", row['RISK_LEVEL'])
            bc4.metric("Sentiment", row['SENTIMENT_SCORE'])

        st.divider()

        # Simulation form
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
                # Insert interaction
                session.sql(f"""
                    INSERT INTO SFK_HACKATHON.SFK_HACK_1.INTERACTION
                    (INTERACTION_ID, CUSTOMER_ID, CHANNEL, DIRECTION, INTERACTION_DATE, DURATION_SECONDS, TOPIC)
                    VALUES ('INT-SIM-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                            '{customer_id}', '{channel}', 'Inbound', CURRENT_TIMESTAMP(), 300, '{topic}')
                """).collect()

                # Insert transcript
                session.sql(f"""
                    INSERT INTO SFK_HACKATHON.SFK_HACK_1.TRANSCRIPT
                    (TRANSCRIPT_ID, INTERACTION_ID, CUSTOMER_ID, TRANSCRIPT_TEXT)
                    VALUES ('TRN-SIM-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                            'INT-SIM-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                            '{customer_id}', '{transcript_text.replace("'", "''")}')
                """).collect()

                # Insert enrichment with simulated sentiment
                session.sql(f"""
                    INSERT INTO SFK_HACKATHON.SFK_HACK_1.CUSTOMER_AI_ENRICHMENT
                    (ENRICHMENT_ID, CUSTOMER_ID, SOURCE_TABLE, SOURCE_ID,
                     SENTIMENT_SCORE, SENTIMENT_LABEL, CLASSIFICATION)
                    VALUES ('ENR-SIM-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                            '{customer_id}', 'TRANSCRIPT',
                            'TRN-SIM-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                            {sentiment_sim},
                            '{"POSITIVE" if sentiment_sim >= 0.3 else "NEGATIVE" if sentiment_sim <= -0.3 else "NEUTRAL"}',
                            '{"CHURN" if topic == "Cancellation Request" else "CLAIM_FRICTION" if topic == "Claim Status" else "GENERAL_INQUIRY"}')
                """).collect()

                # Re-run health scoring for this customer
                session.sql(f"""
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
                """).collect()

                st.success("Simulation complete! Interaction injected and scores updated.")

                # Show updated state
                st.subheader("Updated State")
                updated = session.sql(f"""
                    SELECT H.HEALTH_SCORE, H.CHURN_RISK, H.RISK_LEVEL,
                           H.SENTIMENT_SCORE, H.ENGAGEMENT_SCORE
                    FROM SFK_HACKATHON.SFK_HACK_1.CUSTOMER_HEALTH H
                    WHERE H.CUSTOMER_ID = '{customer_id}'
                """).collect()

                if updated:
                    urow = updated[0]
                    uc1, uc2, uc3, uc4 = st.columns(4)
                    old_health = row['HEALTH_SCORE'] if current else 0
                    old_churn = row['CHURN_RISK'] if current else 0
                    uc1.metric("Health", urow['HEALTH_SCORE'],
                               delta=f"{urow['HEALTH_SCORE'] - old_health:.1f}")
                    uc2.metric("Churn Risk", f"{round(urow['CHURN_RISK']*100, 1)}%",
                               delta=f"{round((urow['CHURN_RISK'] - old_churn)*100, 1)}%")
                    uc3.metric("Risk Level", urow['RISK_LEVEL'])
                    uc4.metric("Sentiment", urow['SENTIMENT_SCORE'])


# ─── Navigation ───────────────────────────────────────────────────────────────

pages = st.navigation([
    st.Page(portfolio_view, title="Portfolio View", icon="📊"),
    st.Page(customer_360, title="Customer 360", icon="👤"),
    st.Page(employee_copilot, title="Employee Copilot", icon="🤖"),
    st.Page(nba_dashboard, title="NBA Dashboard", icon="🎯"),
    st.Page(realtime_simulation, title="Real-Time Simulation", icon="⚡"),
])

pages.run()
