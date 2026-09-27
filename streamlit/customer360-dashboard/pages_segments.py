import os
import streamlit as st
import pandas as pd

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))


@st.cache_data(ttl=600)
def load_churn_distribution():
    return conn.query("""
        SELECT
            CASE
                WHEN CHURN_RISK_SCORE < 0.2 THEN '0.0-0.2 (Very Low)'
                WHEN CHURN_RISK_SCORE < 0.4 THEN '0.2-0.4 (Low)'
                WHEN CHURN_RISK_SCORE < 0.6 THEN '0.4-0.6 (Medium)'
                WHEN CHURN_RISK_SCORE < 0.8 THEN '0.6-0.8 (High)'
                ELSE '0.8-1.0 (Critical)'
            END AS RISK_BUCKET,
            COUNT(*) AS CUSTOMER_COUNT
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMERS
        GROUP BY RISK_BUCKET ORDER BY RISK_BUCKET
    """)


@st.cache_data(ttl=600)
def load_segment_comparison():
    return conn.query("""
        SELECT
            c.SEGMENT,
            COUNT(DISTINCT c.CUSTOMER_ID) AS CUSTOMER_COUNT,
            AVG(c.LIFETIME_VALUE) AS AVG_LTV,
            AVG(c.CHURN_RISK_SCORE) AS AVG_CHURN_RISK,
            COUNT(DISTINCT o.ORDER_ID) AS TOTAL_ORDERS,
            COUNT(DISTINCT t.TICKET_ID) AS TOTAL_TICKETS
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMERS c
        LEFT JOIN CUSTOMER360_DB.ANALYTICS.ORDERS o ON c.CUSTOMER_ID = o.CUSTOMER_ID
        LEFT JOIN CUSTOMER360_DB.ANALYTICS.SUPPORT_TICKETS t ON c.CUSTOMER_ID = t.CUSTOMER_ID
        GROUP BY c.SEGMENT
        ORDER BY AVG_LTV DESC
    """)


@st.cache_data(ttl=600)
def load_high_risk_customers():
    return conn.query("""
        SELECT c.CUSTOMER_ID, c.FIRST_NAME || ' ' || c.LAST_NAME AS NAME,
               c.SEGMENT, c.REGION, c.LIFETIME_VALUE, c.CHURN_RISK_SCORE,
               COUNT(DISTINCT o.ORDER_ID) AS ORDER_COUNT,
               COUNT(DISTINCT t.TICKET_ID) AS TICKET_COUNT
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMERS c
        LEFT JOIN CUSTOMER360_DB.ANALYTICS.ORDERS o ON c.CUSTOMER_ID = o.CUSTOMER_ID
        LEFT JOIN CUSTOMER360_DB.ANALYTICS.SUPPORT_TICKETS t ON c.CUSTOMER_ID = t.CUSTOMER_ID
        WHERE c.CHURN_RISK_SCORE > 0.7
        GROUP BY c.CUSTOMER_ID, c.FIRST_NAME, c.LAST_NAME, c.SEGMENT, c.REGION,
                 c.LIFETIME_VALUE, c.CHURN_RISK_SCORE
        ORDER BY c.CHURN_RISK_SCORE DESC
        LIMIT 50
    """)


def render():
    st.header("Segments & Risk Analysis")

    col1, col2 = st.columns(2)

    with col1:
        with st.container(border=True):
            st.subheader("Churn Risk Distribution")
            churn_df = load_churn_distribution()
            st.bar_chart(churn_df, x="RISK_BUCKET", y="CUSTOMER_COUNT")

    with col2:
        with st.container(border=True):
            st.subheader("Segment Comparison")
            seg_df = load_segment_comparison()
            st.dataframe(
                seg_df.style.format({
                    "AVG_LTV": "${:,.2f}",
                    "AVG_CHURN_RISK": "{:.2f}",
                }),
                hide_index=True,
                use_container_width=True,
            )

    with st.container(border=True):
        st.subheader("High-Risk Customers (Churn Score > 0.7)")
        risk_df = load_high_risk_customers()
        if risk_df.empty:
            st.info("No high-risk customers found.")
        else:
            st.metric("At-Risk Customers", len(risk_df), border=True)
            total_ltv = risk_df["LIFETIME_VALUE"].sum()
            st.metric("Revenue at Risk", f"${total_ltv:,.0f}", border=True)
            st.dataframe(
                risk_df.style.format({
                    "LIFETIME_VALUE": "${:,.2f}",
                    "CHURN_RISK_SCORE": "{:.2f}",
                }),
                hide_index=True,
                use_container_width=True,
            )


render()
