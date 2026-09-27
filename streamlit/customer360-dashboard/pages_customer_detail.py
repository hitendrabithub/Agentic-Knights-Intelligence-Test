import os
import streamlit as st
import pandas as pd

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))


@st.cache_data(ttl=600)
def load_customer_list():
    return conn.query("""
        SELECT CUSTOMER_ID, FIRST_NAME || ' ' || LAST_NAME AS NAME
        FROM CUSTOMER360_DB.ANALYTICS.CUSTOMERS ORDER BY NAME
    """)


@st.cache_data(ttl=600)
def load_customer_profile(customer_id):
    return conn.query(
        """SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE,
                  SEGMENT, REGION, SIGNUP_DATE, LIFETIME_VALUE, CHURN_RISK_SCORE
           FROM CUSTOMER360_DB.ANALYTICS.CUSTOMERS WHERE CUSTOMER_ID = ?""",
        params=[customer_id],
    )


@st.cache_data(ttl=600)
def load_customer_orders(customer_id):
    return conn.query(
        """SELECT ORDER_ID, ORDER_DATE, TOTAL_AMOUNT, STATUS, CHANNEL, PRODUCT_CATEGORY
           FROM CUSTOMER360_DB.ANALYTICS.ORDERS
           WHERE CUSTOMER_ID = ? ORDER BY ORDER_DATE DESC""",
        params=[customer_id],
    )


@st.cache_data(ttl=600)
def load_customer_tickets(customer_id):
    return conn.query(
        """SELECT TICKET_ID, CREATED_DATE, CATEGORY, PRIORITY, STATUS, RESOLUTION_TIME_HRS
           FROM CUSTOMER360_DB.ANALYTICS.SUPPORT_TICKETS
           WHERE CUSTOMER_ID = ? ORDER BY CREATED_DATE DESC""",
        params=[customer_id],
    )


@st.cache_data(ttl=600)
def load_customer_reviews(customer_id):
    return conn.query(
        """SELECT REVIEW_ID, PRODUCT_NAME, RATING, REVIEW_TEXT, REVIEW_DATE
           FROM CUSTOMER360_DB.ANALYTICS.PRODUCT_REVIEWS
           WHERE CUSTOMER_ID = ? ORDER BY REVIEW_DATE DESC""",
        params=[customer_id],
    )


@st.cache_data(ttl=600)
def load_customer_events_summary(customer_id):
    return conn.query(
        """SELECT EVENT_TYPE, COUNT(*) AS EVENT_COUNT,
                  AVG(DURATION_SECONDS) AS AVG_DURATION
           FROM CUSTOMER360_DB.ANALYTICS.WEB_EVENTS
           WHERE CUSTOMER_ID = ? GROUP BY EVENT_TYPE ORDER BY EVENT_COUNT DESC""",
        params=[customer_id],
    )


def render():
    st.header("Customer Deep Dive")

    customers = load_customer_list()
    options = {row["NAME"]: row["CUSTOMER_ID"] for _, row in customers.iterrows()}

    selected_name = st.selectbox("Select a Customer", list(options.keys()))

    if not selected_name:
        st.info("Select a customer to view their details.")
        return

    customer_id = options[selected_name]
    profile = load_customer_profile(customer_id)

    if profile.empty:
        st.warning("Customer not found.")
        return

    p = profile.iloc[0]

    with st.container(border=True):
        st.subheader(f"{p['FIRST_NAME']} {p['LAST_NAME']}")
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Segment", p["SEGMENT"])
        col2.metric("Region", p["REGION"])
        col3.metric("Lifetime Value", f"${p['LIFETIME_VALUE']:,.2f}")
        col4.metric("Churn Risk", f"{p['CHURN_RISK_SCORE']:.2f}")

        col5, col6, col7 = st.columns(3)
        col5.write(f"**Email:** {p['EMAIL']}")
        col6.write(f"**Phone:** {p['PHONE']}")
        col7.write(f"**Signup:** {p['SIGNUP_DATE']}")

    tab1, tab2, tab3, tab4 = st.tabs(["Orders", "Support Tickets", "Reviews", "Web Activity"])

    with tab1:
        orders = load_customer_orders(customer_id)
        if orders.empty:
            st.info("No orders found.")
        else:
            st.metric("Total Orders", len(orders), border=True)
            st.dataframe(orders, hide_index=True, use_container_width=True)

    with tab2:
        tickets = load_customer_tickets(customer_id)
        if tickets.empty:
            st.info("No support tickets found.")
        else:
            st.metric("Total Tickets", len(tickets), border=True)
            st.dataframe(tickets, hide_index=True, use_container_width=True)

    with tab3:
        reviews = load_customer_reviews(customer_id)
        if reviews.empty:
            st.info("No reviews found.")
        else:
            avg_rating = reviews["RATING"].mean()
            st.metric("Avg Rating", f"{avg_rating:.1f} / 5", border=True)
            st.dataframe(reviews, hide_index=True, use_container_width=True)

    with tab4:
        events = load_customer_events_summary(customer_id)
        if events.empty:
            st.info("No web events found.")
        else:
            st.bar_chart(events, x="EVENT_TYPE", y="EVENT_COUNT")
            st.dataframe(events, hide_index=True, use_container_width=True)


render()
