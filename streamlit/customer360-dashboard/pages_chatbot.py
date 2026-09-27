import os
import json
import streamlit as st

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

AGENT_FQN = "CUSTOMER360_DB.ANALYTICS.CUSTOMER360_AGENT"

SUGGESTIONS = {
    "Top customers by revenue": "Who are the top 10 customers by lifetime value?",
    "Monthly revenue trend": "What is the monthly revenue trend?",
    "High churn risk customers": "Which customers have high churn risk?",
    "Revenue by channel": "What is revenue by sales channel?",
    "Best reviewed products": "Which products have the best reviews?",
    "Open tickets by priority": "How many support tickets are open by priority?",
}


def call_agent(question, conversation_history):
    session = conn.session()
    messages_json = json.dumps(conversation_history)
    result = session.sql(
        """SELECT SNOWFLAKE.CORTEX.INVOKE_AGENT(
            :agent_name,
            :question,
            PARSE_JSON(:history)
        ) AS RESPONSE""",
        params={
            "agent_name": AGENT_FQN,
            "question": question,
            "history": messages_json,
        },
    ).collect()
    if result:
        return result[0]["RESPONSE"]
    return "No response from agent."


def render():
    st.header("AI Chatbot")
    st.caption("Ask questions about your customer data using natural language")

    if "chat_messages" not in st.session_state:
        st.session_state.chat_messages = []

    if not st.session_state.chat_messages:
        selected = st.pills(
            "Try asking:",
            list(SUGGESTIONS.keys()),
            label_visibility="collapsed",
        )
        if selected:
            st.session_state.chat_messages.append(
                {"role": "user", "content": SUGGESTIONS[selected]}
            )
            st.rerun()

    for msg in st.session_state.chat_messages:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    if prompt := st.chat_input("Ask anything about your customers..."):
        st.session_state.chat_messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        with st.chat_message("assistant"):
            with st.spinner("Thinking..."):
                history = [
                    {"role": m["role"], "content": m["content"]}
                    for m in st.session_state.chat_messages[:-1]
                ]
                response = call_agent(prompt, history)
                st.markdown(response)

        st.session_state.chat_messages.append(
            {"role": "assistant", "content": response}
        )


render()
