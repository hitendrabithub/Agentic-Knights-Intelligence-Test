import streamlit as st

st.set_page_config(
    page_title="Customer 360 Dashboard",
    page_icon=":bar_chart:",
    layout="wide",
)

overview_page = st.Page("pages_overview.py", title="Overview", icon=":material/dashboard:", default=True)
customer_page = st.Page("pages_customer_detail.py", title="Customer Detail", icon=":material/person:")
chatbot_page = st.Page("pages_chatbot.py", title="AI Chatbot", icon=":material/smart_toy:")
segments_page = st.Page("pages_segments.py", title="Segments & Risk", icon=":material/analytics:")

pg = st.navigation([overview_page, customer_page, chatbot_page, segments_page])
st.sidebar.title("Customer 360")
pg.run()
