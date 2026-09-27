import os
import streamlit as st
import pandas as pd

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))


@st.cache_data(ttl=600)
def load_kpis():
    return conn.query("""
        SELECT
            (SELECT COUNT(*) FROM CUSTOMER360_DB.ANALYTICS.CUSTOMERS) AS total_customers,
            (SELECT SUM(TOTAL_AMOUNT) FROM CUSTOMER360_DB.ANALYTICS.ORDERS) AS total_revenue,
            (SELECT AVG(TOTAL_AMOUNT) FROM CUSTOMER360_DB.ANALYTICS.ORDERS) AS avg_order_value,
            (SELECT AVG(CHURN_RISK_SCORE) FROM CUSTOMER360_DB.ANALYTICS.CUSTOMERS) AS avg_churn_risk,
            (SELECT COUNT(*) FROM CUSTOMER360_DB.ANALYTICS.SUPPORT_TICKETS WHERE STATUS IN ('Open', 'In Progress')) AS open_tickets
    """)


@st.cache_data(ttl=600)
def load_revenue_trend():
    return conn.query("""
        SELECT DATE_TRUNC('month', ORDER_DATE)::DATE AS MONTH,
               SUM(TOTAL_AMOUNT) AS REVENUE
        FROM CUSTOMER360_DB.ANALYTICS.ORDERS
        GROUP BY MONTH ORDER BY MONTH
    """)


@st.cache_data(ttl=600)
def load_segment_distribution():
    return conn.query("""
        SELECT SEGMENT, COUNT(*) AS CUSTOMER_COUNT
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMERS
        GROUP BY SEGMENT ORDER BY CUSTOMER_COUNT DESC
    """)


@st.cache_data(ttl=600)
def load_region_revenue():
    return conn.query("""
        SELECT c.REGION, SUM(o.TOTAL_AMOUNT) AS REVENUE
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMERS c
        JOIN CUSTOMER360_DB.ANALYTICS.ORDERS o ON c.CUSTOMER_ID = o.CUSTOMER_ID
        GROUP BY c.REGION ORDER BY REVENUE DESC
    """)


@st.cache_data(ttl=600)
def load_top_customers():
    return conn.query("""
        SELECT CUSTOMER_ID, FIRST_NAME || ' ' || LAST_NAME AS NAME,
               SEGMENT, REGION, LIFETIME_VALUE, CHURN_RISK_SCORE
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMERS
        ORDER BY LIFETIME_VALUE DESC LIMIT 10
    """)


@st.cache_data(ttl=600)
def load_channel_revenue():
    return conn.query("""
        SELECT CHANNEL, SUM(TOTAL_AMOUNT) AS REVENUE, COUNT(*) AS ORDER_COUNT
        FROM CUSTOMER360_DB.ANALYTICS.ORDERS
        GROUP BY CHANNEL ORDER BY REVENUE DESC
    """)


def render():
    st.header("Overview Dashboard")

    kpis = load_kpis()
    row = kpis.iloc[0]

    with st.container(horizontal=True):
        st.metric("Total Customers", f"{int(row['TOTAL_CUSTOMERS']):,}", border=True)
        st.metric("Total Revenue", f"${row['TOTAL_REVENUE']:,.0f}", border=True)
        st.metric("Avg Order Value", f"${row['AVG_ORDER_VALUE']:,.2f}", border=True)
        st.metric("Avg Churn Risk", f"{row['AVG_CHURN_RISK']:.2f}", border=True)
        st.metric("Open Tickets", f"{int(row['OPEN_TICKETS']):,}", border=True)

    col1, col2 = st.columns(2)

    with col1:
        with st.container(border=True):
            st.subheader("Monthly Revenue Trend")
            revenue_df = load_revenue_trend()
            st.line_chart(revenue_df, x="MONTH", y="REVENUE")

    with col2:
        with st.container(border=True):
            st.subheader("Revenue by Region")
            region_df = load_region_revenue()
            st.bar_chart(region_df, x="REGION", y="REVENUE")

    col3, col4 = st.columns(2)

    with col3:
        with st.container(border=True):
            st.subheader("Customers by Segment")
            seg_df = load_segment_distribution()
            st.bar_chart(seg_df, x="SEGMENT", y="CUSTOMER_COUNT")

    with col4:
        with st.container(border=True):
            st.subheader("Revenue by Channel")
            ch_df = load_channel_revenue()
            st.bar_chart(ch_df, x="CHANNEL", y="REVENUE")

    with st.container(border=True):
        st.subheader("Top 10 Customers by Lifetime Value")
        top_df = load_top_customers()
        st.dataframe(top_df, hide_index=True, use_container_width=True)


render()
