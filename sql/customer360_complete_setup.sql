-- ============================================================================
-- CUSTOMER 360 PROJECT - COMPLETE SETUP SCRIPT
-- ============================================================================
-- This file contains ALL Snowflake objects for the Customer 360 project.
-- Run sections in order. Replace <PLACEHOLDER> values where noted.
--
-- PREREQUISITES (manual steps before running):
-- 1. Run this script with ACCOUNTADMIN role (or a role with CREATE DATABASE,
--    CREATE WAREHOUSE, CREATE INTEGRATION, CREATE COMPUTE POOL privileges)
-- 2. Replace all <PLACEHOLDER> values in Section 6 (GitHub Integration)
--    with your actual GitHub credentials before running that section
-- 3. After running this SQL, create the Streamlit app manually:
--    - In Snowsight: Projects > Workspaces > create folder "customer360-dashboard"
--    - Copy the Streamlit app files (streamlit_app.py, pages_*.py, etc.)
--    - Configure App Settings: compute pool + query warehouse
--    - Click Run to start the app
-- ============================================================================


-- ============================================================================
-- 1. ROLE, WAREHOUSE, DATABASE & SCHEMA
-- ============================================================================

USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE COMPUTE_WH;

CREATE OR REPLACE DATABASE CUSTOMER360_DB;

CREATE OR REPLACE SCHEMA CUSTOMER360_DB.ANALYTICS;


-- ============================================================================
-- 2. TABLES
-- ============================================================================

-- 2.1 Customers
CREATE OR REPLACE TABLE CUSTOMER360_DB.ANALYTICS.CUSTOMERS (
    CUSTOMER_ID NUMBER(38,0),
    FIRST_NAME VARCHAR(50),
    LAST_NAME VARCHAR(50),
    EMAIL VARCHAR(100),
    PHONE VARCHAR(20),
    SEGMENT VARCHAR(50),
    REGION VARCHAR(50),
    SIGNUP_DATE DATE,
    LIFETIME_VALUE NUMBER(12,2),
    CHURN_RISK_SCORE NUMBER(3,2)
);

-- 2.2 Customer Segments
CREATE OR REPLACE TABLE CUSTOMER360_DB.ANALYTICS.CUSTOMER_SEGMENTS (
    SEGMENT_ID NUMBER(38,0),
    SEGMENT_NAME VARCHAR(50),
    DESCRIPTION VARCHAR(200),
    CRITERIA VARCHAR(200)
);

-- 2.3 Orders
CREATE OR REPLACE TABLE CUSTOMER360_DB.ANALYTICS.ORDERS (
    ORDER_ID NUMBER(38,0),
    CUSTOMER_ID NUMBER(38,0),
    ORDER_DATE DATE,
    TOTAL_AMOUNT NUMBER(10,2),
    STATUS VARCHAR(20),
    CHANNEL VARCHAR(20),
    PRODUCT_CATEGORY VARCHAR(50)
);

-- 2.4 Product Reviews
CREATE OR REPLACE TABLE CUSTOMER360_DB.ANALYTICS.PRODUCT_REVIEWS (
    REVIEW_ID NUMBER(38,0),
    CUSTOMER_ID NUMBER(38,0),
    PRODUCT_ID NUMBER(38,0),
    PRODUCT_NAME VARCHAR(100),
    RATING NUMBER(38,0),
    REVIEW_TEXT VARCHAR(300),
    REVIEW_DATE DATE
);

-- 2.5 Support Tickets
CREATE OR REPLACE TABLE CUSTOMER360_DB.ANALYTICS.SUPPORT_TICKETS (
    TICKET_ID NUMBER(38,0),
    CUSTOMER_ID NUMBER(38,0),
    CREATED_DATE DATE,
    CATEGORY VARCHAR(50),
    PRIORITY VARCHAR(20),
    STATUS VARCHAR(20),
    RESOLUTION_TIME_HRS NUMBER(8,2),
    DESCRIPTION VARCHAR(200)
);

-- 2.6 Web Events
CREATE OR REPLACE TABLE CUSTOMER360_DB.ANALYTICS.WEB_EVENTS (
    EVENT_ID NUMBER(38,0),
    CUSTOMER_ID NUMBER(38,0),
    EVENT_DATE TIMESTAMP_NTZ(9),
    EVENT_TYPE VARCHAR(50),
    PAGE VARCHAR(100),
    SESSION_ID VARCHAR(50),
    DEVICE VARCHAR(20),
    DURATION_SECONDS NUMBER(38,0)
);


-- ============================================================================
-- 2B. SAMPLE DATA
-- ============================================================================
-- Uses Snowflake's GENERATOR + ARRAY functions for compact, reproducible data.

-- 2B.1 Customer Segments (5 rows)
INSERT INTO CUSTOMER360_DB.ANALYTICS.CUSTOMER_SEGMENTS VALUES
    (1, 'Enterprise', 'Large enterprise accounts with 1000+ employees', 'ARR > $500K and employees > 1000'),
    (2, 'Mid-Market', 'Mid-size businesses with 100-999 employees', 'ARR $50K-$500K and employees 100-999'),
    (3, 'SMB', 'Small and medium businesses with 10-99 employees', 'ARR $5K-$50K and employees 10-99'),
    (4, 'Startup', 'Early-stage companies under 10 employees', 'ARR < $5K and employees < 10'),
    (5, 'Individual', 'Individual professionals and freelancers', 'Single-user accounts');

-- 2B.2 Customers (1000 rows)
INSERT INTO CUSTOMER360_DB.ANALYTICS.CUSTOMERS
WITH first_names AS (
    SELECT ARRAY_CONSTRUCT(
        'James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda',
        'David','Elizabeth','William','Barbara','Richard','Susan','Joseph','Jessica',
        'Thomas','Sarah','Christopher','Karen','Charles','Lisa','Daniel','Nancy',
        'Matthew','Betty','Mark','Margaret','Donald','Sandra','Steven','Ashley',
        'Paul','Emily','Andrew','Donna','Joshua','Michelle','Kenneth','Dorothy',
        'George','Carol','Brian','Amanda','Edward','Melissa','Ronald','Deborah',
        'Timothy','Laura'
    ) AS names
),
last_names AS (
    SELECT ARRAY_CONSTRUCT(
        'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis',
        'Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson',
        'Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson',
        'White','Harris','Sanchez','Clark','Lewis','Robinson','Walker','Young',
        'Allen','King','Wright','Scott','Torres','Hill','Flores','Green',
        'Adams','Nelson','Baker','Hall','Rivera','Campbell','Mitchell','Carter',
        'Roberts','Phillips'
    ) AS names
),
segments AS (
    SELECT ARRAY_CONSTRUCT('Enterprise','Mid-Market','SMB','Startup','Individual') AS vals
),
regions AS (
    SELECT ARRAY_CONSTRUCT('North America','Europe','APAC','LATAM') AS vals
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS CUSTOMER_ID,
    first_names.names[UNIFORM(0, 49, RANDOM())]::VARCHAR AS FIRST_NAME,
    last_names.names[UNIFORM(0, 49, RANDOM())]::VARCHAR AS LAST_NAME,
    LOWER(first_names.names[UNIFORM(0, 49, RANDOM())]::VARCHAR) || '.' ||
        LOWER(last_names.names[UNIFORM(0, 49, RANDOM())]::VARCHAR) ||
        UNIFORM(1, 999, RANDOM())::VARCHAR || '@example.com' AS EMAIL,
    '+1-' || UNIFORM(200, 999, RANDOM())::VARCHAR || '-' ||
        UNIFORM(100, 999, RANDOM())::VARCHAR || '-' ||
        UNIFORM(1000, 9999, RANDOM())::VARCHAR AS PHONE,
    segments.vals[UNIFORM(0, 4, RANDOM())]::VARCHAR AS SEGMENT,
    regions.vals[UNIFORM(0, 3, RANDOM())]::VARCHAR AS REGION,
    DATEADD('day', -UNIFORM(30, 1500, RANDOM()), CURRENT_DATE()) AS SIGNUP_DATE,
    ROUND(UNIFORM(500, 500000, RANDOM()) + UNIFORM(0, 100, RANDOM()) / 100.0, 2) AS LIFETIME_VALUE,
    ROUND(UNIFORM(0, 100, RANDOM()) / 100.0, 2) AS CHURN_RISK_SCORE
FROM TABLE(GENERATOR(ROWCOUNT => 1000)),
     first_names, last_names, segments, regions;

-- 2B.3 Orders (10000 rows)
INSERT INTO CUSTOMER360_DB.ANALYTICS.ORDERS
WITH statuses AS (
    SELECT ARRAY_CONSTRUCT('Completed','Processing','Pending','Cancelled','Refunded') AS vals
),
channels AS (
    SELECT ARRAY_CONSTRUCT('Web','Mobile','In-Store','Partner') AS vals
),
categories AS (
    SELECT ARRAY_CONSTRUCT('Software Licenses','Cloud Services','Professional Services',
        'Consulting','Training','Support Plans','Hardware','Subscriptions') AS vals
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS ORDER_ID,
    UNIFORM(1, 1000, RANDOM()) AS CUSTOMER_ID,
    DATEADD('day', -UNIFORM(0, 730, RANDOM()), CURRENT_DATE()) AS ORDER_DATE,
    ROUND(UNIFORM(50, 10000, RANDOM()) + UNIFORM(0, 100, RANDOM()) / 100.0, 2) AS TOTAL_AMOUNT,
    statuses.vals[UNIFORM(0, 4, RANDOM())]::VARCHAR AS STATUS,
    channels.vals[UNIFORM(0, 3, RANDOM())]::VARCHAR AS CHANNEL,
    categories.vals[UNIFORM(0, 7, RANDOM())]::VARCHAR AS PRODUCT_CATEGORY
FROM TABLE(GENERATOR(ROWCOUNT => 10000)),
     statuses, channels, categories;

-- 2B.4 Support Tickets (3000 rows)
INSERT INTO CUSTOMER360_DB.ANALYTICS.SUPPORT_TICKETS
WITH ticket_categories AS (
    SELECT ARRAY_CONSTRUCT('Technical Issue','Billing','Account Access',
        'Feature Request','Integration','General Inquiry') AS vals
),
priorities AS (
    SELECT ARRAY_CONSTRUCT('Low','Medium','High','Critical') AS vals
),
statuses AS (
    SELECT ARRAY_CONSTRUCT('Open','In Progress','Resolved') AS vals
),
descriptions AS (
    SELECT ARRAY_CONSTRUCT(
        'Unable to access dashboard','Billing discrepancy reported',
        'Password reset required','Feature enhancement suggestion',
        'API integration failing','General question about product',
        'Performance issue detected','Data export not working',
        'Login timeout error','Invoice clarification needed'
    ) AS vals
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS TICKET_ID,
    UNIFORM(1, 1000, RANDOM()) AS CUSTOMER_ID,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS CREATED_DATE,
    ticket_categories.vals[UNIFORM(0, 5, RANDOM())]::VARCHAR AS CATEGORY,
    priorities.vals[UNIFORM(0, 3, RANDOM())]::VARCHAR AS PRIORITY,
    statuses.vals[UNIFORM(0, 2, RANDOM())]::VARCHAR AS STATUS,
    ROUND(UNIFORM(1, 200, RANDOM()) + UNIFORM(0, 100, RANDOM()) / 100.0, 2) AS RESOLUTION_TIME_HRS,
    descriptions.vals[UNIFORM(0, 9, RANDOM())]::VARCHAR AS DESCRIPTION
FROM TABLE(GENERATOR(ROWCOUNT => 3000)),
     ticket_categories, priorities, statuses, descriptions;

-- 2B.5 Product Reviews (5000 rows)
INSERT INTO CUSTOMER360_DB.ANALYTICS.PRODUCT_REVIEWS
WITH products AS (
    SELECT ARRAY_CONSTRUCT(
        'Analytics Suite','DataSync Pro','CloudManager Elite','DataWarehouse Express',
        'SecureVault','API Gateway Plus','ML Pipeline','ETL Connector',
        'Report Builder','Monitoring Dashboard','Query Optimizer','Stream Processor',
        'Data Catalog','Workflow Automator','Identity Manager','Governance Suite',
        'Integration Hub','Compliance Tracker','DevOps Toolkit','Backup Solution'
    ) AS names
),
reviews AS (
    SELECT ARRAY_CONSTRUCT(
        'Great product, very intuitive','Needs improvement in performance',
        'Excellent customer support','Good value for money',
        'Could use more features','Reliable and stable platform',
        'Easy to set up and configure','Documentation could be better',
        'Outstanding analytics capabilities','Perfect for our team needs'
    ) AS texts
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS REVIEW_ID,
    UNIFORM(1, 1000, RANDOM()) AS CUSTOMER_ID,
    UNIFORM(1, 20, RANDOM()) AS PRODUCT_ID,
    products.names[UNIFORM(0, 19, RANDOM())]::VARCHAR AS PRODUCT_NAME,
    UNIFORM(1, 5, RANDOM()) AS RATING,
    reviews.texts[UNIFORM(0, 9, RANDOM())]::VARCHAR AS REVIEW_TEXT,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS REVIEW_DATE
FROM TABLE(GENERATOR(ROWCOUNT => 5000)),
     products, reviews;

-- 2B.6 Web Events (50000 rows)
INSERT INTO CUSTOMER360_DB.ANALYTICS.WEB_EVENTS
WITH event_types AS (
    SELECT ARRAY_CONSTRUCT('Page View','Click','Form Submit','Search',
        'Download','Video Play','Sign Up','Add to Cart') AS vals
),
pages AS (
    SELECT ARRAY_CONSTRUCT('/home','/products','/pricing','/docs','/blog',
        '/dashboard','/settings','/support','/contact','/checkout') AS vals
),
devices AS (
    SELECT ARRAY_CONSTRUCT('Desktop','Mobile','Tablet') AS vals
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS EVENT_ID,
    UNIFORM(1, 1000, RANDOM()) AS CUSTOMER_ID,
    DATEADD('second', -UNIFORM(0, 31536000, RANDOM()), CURRENT_TIMESTAMP()) AS EVENT_DATE,
    event_types.vals[UNIFORM(0, 7, RANDOM())]::VARCHAR AS EVENT_TYPE,
    pages.vals[UNIFORM(0, 9, RANDOM())]::VARCHAR AS PAGE,
    'sess-' || UUID_STRING() AS SESSION_ID,
    devices.vals[UNIFORM(0, 2, RANDOM())]::VARCHAR AS DEVICE,
    UNIFORM(1, 600, RANDOM()) AS DURATION_SECONDS
FROM TABLE(GENERATOR(ROWCOUNT => 50000)),
     event_types, pages, devices;


-- ============================================================================
-- 3. SEMANTIC VIEW
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    TABLES (
        CUSTOMER360_DB.ANALYTICS.CUSTOMERS PRIMARY KEY (CUSTOMER_ID),
        CUSTOMER360_DB.ANALYTICS.ORDERS,
        CUSTOMER360_DB.ANALYTICS.SUPPORT_TICKETS,
        CUSTOMER360_DB.ANALYTICS.PRODUCT_REVIEWS,
        CUSTOMER360_DB.ANALYTICS.WEB_EVENTS,
        CUSTOMER360_DB.ANALYTICS.CUSTOMER_SEGMENTS
    )
    RELATIONSHIPS (
        ORDERS_TO_CUSTOMERS AS ORDERS(CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID)
    )
    FACTS (
        CUSTOMERS.LIFETIME_VALUE AS LIFETIME_VALUE,
        CUSTOMERS.CHURN_RISK_SCORE AS CHURN_RISK_SCORE,
        ORDERS.TOTAL_AMOUNT AS TOTAL_AMOUNT,
        SUPPORT_TICKETS.RESOLUTION_TIME_HRS AS RESOLUTION_TIME_HRS
    )
    DIMENSIONS (
        CUSTOMERS.CUSTOMER_ID AS CUSTOMER_ID,
        CUSTOMERS.FIRST_NAME AS FIRST_NAME,
        CUSTOMERS.LAST_NAME AS LAST_NAME,
        CUSTOMERS.EMAIL AS EMAIL,
        CUSTOMERS.PHONE AS PHONE,
        CUSTOMERS.SEGMENT AS SEGMENT,
        CUSTOMERS.REGION AS REGION,
        CUSTOMERS.SIGNUP_DATE AS SIGNUP_DATE,
        ORDERS.ORDER_ID AS ORDER_ID,
        ORDERS.CUSTOMER_ID AS CUSTOMER_ID,
        ORDERS.STATUS AS STATUS,
        ORDERS.CHANNEL AS CHANNEL,
        ORDERS.PRODUCT_CATEGORY AS PRODUCT_CATEGORY,
        ORDERS.ORDER_DATE AS ORDER_DATE,
        SUPPORT_TICKETS.TICKET_ID AS TICKET_ID,
        SUPPORT_TICKETS.CUSTOMER_ID AS CUSTOMER_ID,
        SUPPORT_TICKETS.CATEGORY AS CATEGORY,
        SUPPORT_TICKETS.PRIORITY AS PRIORITY,
        SUPPORT_TICKETS.STATUS AS STATUS,
        SUPPORT_TICKETS.DESCRIPTION AS DESCRIPTION,
        SUPPORT_TICKETS.CREATED_DATE AS CREATED_DATE,
        PRODUCT_REVIEWS.REVIEW_ID AS REVIEW_ID,
        PRODUCT_REVIEWS.CUSTOMER_ID AS CUSTOMER_ID,
        PRODUCT_REVIEWS.PRODUCT_ID AS PRODUCT_ID,
        PRODUCT_REVIEWS.PRODUCT_NAME AS PRODUCT_NAME,
        PRODUCT_REVIEWS.RATING AS RATING,
        PRODUCT_REVIEWS.REVIEW_TEXT AS REVIEW_TEXT,
        PRODUCT_REVIEWS.REVIEW_DATE AS REVIEW_DATE,
        WEB_EVENTS.EVENT_ID AS EVENT_ID,
        WEB_EVENTS.CUSTOMER_ID AS CUSTOMER_ID,
        WEB_EVENTS.EVENT_TYPE AS EVENT_TYPE,
        WEB_EVENTS.PAGE AS PAGE,
        WEB_EVENTS.SESSION_ID AS SESSION_ID,
        WEB_EVENTS.DEVICE AS DEVICE,
        WEB_EVENTS.DURATION_SECONDS AS DURATION_SECONDS,
        WEB_EVENTS.EVENT_DATE AS EVENT_DATE,
        CUSTOMER_SEGMENTS.SEGMENT_ID AS SEGMENT_ID,
        CUSTOMER_SEGMENTS.SEGMENT_NAME AS SEGMENT_NAME,
        CUSTOMER_SEGMENTS.DESCRIPTION AS DESCRIPTION,
        CUSTOMER_SEGMENTS.CRITERIA AS CRITERIA
    )
    COMMENT = 'Customer 360 analytics model covering customer profiles, orders, support tickets, product reviews, web engagement events, and customer segments. Enables analysis of customer lifetime value, churn risk, revenue trends, support quality, and product satisfaction.'
    AI_VERIFIED_QUERIES (
        "avg_ltv_churn_by_segment" AS (
            QUESTION 'What is the average lifetime value and churn risk by customer segment?'
            SQL 'SELECT c.SEGMENT, COUNT(*) AS customer_count, AVG(c.LIFETIME_VALUE) AS avg_ltv, AVG(c.CHURN_RISK_SCORE) AS avg_churn_risk FROM customers AS c GROUP BY c.SEGMENT ORDER BY avg_ltv DESC'
        ),
        "top_10_customers_by_ltv" AS (
            QUESTION 'Who are the top 10 customers by lifetime value?'
            SQL 'SELECT c.CUSTOMER_ID, c.FIRST_NAME, c.LAST_NAME, c.SEGMENT, c.LIFETIME_VALUE, c.CHURN_RISK_SCORE FROM customers AS c ORDER BY c.LIFETIME_VALUE DESC LIMIT 10'
        ),
        "monthly_revenue_trend" AS (
            QUESTION 'What is the monthly revenue trend?'
            SQL 'SELECT DATE_TRUNC(''MONTH'', o.ORDER_DATE) AS month, SUM(o.TOTAL_AMOUNT) AS total_revenue, COUNT(o.ORDER_ID) AS order_count FROM orders AS o GROUP BY month ORDER BY month'
        ),
        "tickets_by_priority_status" AS (
            QUESTION 'How many support tickets are there by priority and status?'
            SQL 'SELECT t.PRIORITY, t.STATUS, COUNT(*) AS ticket_count FROM support_tickets AS t GROUP BY t.PRIORITY, t.STATUS ORDER BY t.PRIORITY, t.STATUS'
        ),
        "high_churn_risk_customers" AS (
            QUESTION 'Which customers have high churn risk?'
            SQL 'SELECT c.CUSTOMER_ID, c.FIRST_NAME, c.LAST_NAME, c.SEGMENT, c.CHURN_RISK_SCORE, c.LIFETIME_VALUE FROM customers AS c WHERE c.CHURN_RISK_SCORE > 0.7 ORDER BY c.CHURN_RISK_SCORE DESC'
        ),
        "revenue_by_channel" AS (
            QUESTION 'What is the revenue by sales channel?'
            SQL 'SELECT o.CHANNEL, COUNT(o.ORDER_ID) AS order_count, SUM(o.TOTAL_AMOUNT) AS total_revenue FROM orders AS o GROUP BY o.CHANNEL ORDER BY total_revenue DESC'
        ),
        "best_reviewed_products" AS (
            QUESTION 'Which products have the best reviews?'
            SQL 'SELECT pr.PRODUCT_NAME, AVG(pr.RATING) AS avg_rating, COUNT(pr.REVIEW_ID) AS review_count FROM product_reviews AS pr GROUP BY pr.PRODUCT_NAME ORDER BY avg_rating DESC'
        ),
        "revenue_by_region" AS (
            QUESTION 'What is the revenue breakdown by region?'
            SQL 'SELECT c.REGION, COUNT(DISTINCT c.CUSTOMER_ID) AS customer_count, SUM(o.TOTAL_AMOUNT) AS total_revenue FROM customers AS c JOIN orders AS o ON c.CUSTOMER_ID = o.CUSTOMER_ID GROUP BY c.REGION ORDER BY total_revenue DESC'
        )
    );

-- 3B. Column descriptions with alternate names / business terminology
-- These help the Cortex Agent map different team terminologies to the correct columns.

-- Customers table columns
ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY FACT LIFETIME_VALUE SET DESCRIPTION =
    'Total lifetime value of the customer in USD. Also known as LTV, CLV (Customer Lifetime Value), Customer Value, or Total Customer Revenue.';

ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY FACT CHURN_RISK_SCORE SET DESCRIPTION =
    'Probability score (0 to 1) indicating the likelihood a customer will churn. Also known as Attrition Risk, Churn Probability, Risk Score, or Retention Risk. A score above 0.7 is considered high risk.';

ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY DIMENSION SEGMENT SET DESCRIPTION =
    'Customer segment classification. Also known as Customer Tier, Account Type, or Customer Category. Values: Enterprise, Mid-Market, SMB, Startup, Individual.';

ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY DIMENSION REGION SET DESCRIPTION =
    'Geographic region of the customer. Also known as Territory, Geography, Market, or Area. Values: North America, Europe, APAC, LATAM.';

ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY DIMENSION SIGNUP_DATE SET DESCRIPTION =
    'Date the customer first signed up. Also known as Registration Date, Onboarding Date, Enrollment Date, or Account Created Date.';

-- Orders table columns
ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY FACT TOTAL_AMOUNT SET DESCRIPTION =
    'Total monetary value of the order in USD. Also known as Order Value, Revenue, Sales Amount, Order Total, or Transaction Amount.';

ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY DIMENSION CHANNEL SET DESCRIPTION =
    'Sales channel through which the order was placed. Also known as Source, Sales Channel, Order Source, or Acquisition Channel. Values: Web, Mobile, In-Store, Partner.';

ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY DIMENSION PRODUCT_CATEGORY SET DESCRIPTION =
    'Category of the product ordered. Also known as Product Type, Product Line, Service Category, or Offering Type.';

ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY DIMENSION ORDER_DATE SET DESCRIPTION =
    'Date the order was placed. Also known as Purchase Date, Transaction Date, Sale Date, or Order Placed Date.';

-- Support Tickets table columns
ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY FACT RESOLUTION_TIME_HRS SET DESCRIPTION =
    'Time in hours to resolve the support ticket. Also known as Resolution Time, Time to Resolve, TTR, Handle Time, or Turnaround Time.';

ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY DIMENSION CATEGORY SET DESCRIPTION =
    'Category of the support ticket. Also known as Issue Type, Ticket Type, Case Category, or Problem Category. Values: Technical Issue, Billing, Account Access, Feature Request, Integration, General Inquiry.';

ALTER SEMANTIC VIEW CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW
    MODIFY DIMENSION PRIORITY SET DESCRIPTION =
    'Priority level of the support ticket. Also known as Severity, Urgency, or Importance Level. Values: Low, Medium, High, Critical.';


-- ============================================================================
-- 4. CORTEX AGENT
-- ============================================================================

CREATE OR REPLACE AGENT CUSTOMER360_DB.ANALYTICS.CUSTOMER360_AGENT
  FROM SPECIFICATION $$
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: customer360_analyst
      description: "Query customer 360 data including customer profiles, orders, support tickets, product reviews, web engagement events, and customer segments. Answers questions about customer lifetime value, churn risk, revenue trends, support quality, and product satisfaction."

tool_resources:
  customer360_analyst:
    execution_environment:
      type: warehouse
      warehouse: COMPUTE_WH
    semantic_view: CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW

instructions:
  response: |
    You are a Customer 360 analytics assistant.
    Be concise and data-driven. Format currency as dollars (e.g., $1,234.56).
    Use tables when presenting multiple rows of results.
    Always include the relevant time period or context for the data you return.
  orchestration: "Use customer360_analyst for all questions about customers, orders, revenue, churn risk, support tickets, product reviews, and web activity."
  sample_questions:
    - question: "Who are the top 10 customers by lifetime value?"
    - question: "What is the monthly revenue trend?"
    - question: "Which customers have high churn risk?"
    - question: "What is revenue by sales channel?"
    - question: "How many support tickets are open by priority?"
$$;


-- ============================================================================
-- 5. GITHUB INTEGRATION
-- ============================================================================

-- 5.1 Secret (stores GitHub PAT credentials)
-- IMPORTANT: Replace <YOUR_GITHUB_USERNAME> and <YOUR_GITHUB_PAT> with real values.
-- Never commit actual credentials to version control.
CREATE OR REPLACE SECRET CUSTOMER360_DB.ANALYTICS.GIT_SNOW_SECRET
    TYPE = PASSWORD
    USERNAME = '<YOUR_GITHUB_USERNAME>'
    PASSWORD = '<YOUR_GITHUB_PAT>';

-- 5.2 API Integration (account-level object)
CREATE OR REPLACE API INTEGRATION MY_GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/<YOUR_GITHUB_ORG_OR_USER>/')
    ALLOWED_AUTHENTICATION_SECRETS = (CUSTOMER360_DB.ANALYTICS.GIT_SNOW_SECRET)
    ENABLED = TRUE;

-- 5.3 Git Repository
CREATE OR REPLACE GIT REPOSITORY CUSTOMER360_DB.ANALYTICS.GIT_SNOW_REPO_TEST
    API_INTEGRATION = MY_GIT_API_INTEGRATION
    GIT_CREDENTIALS = CUSTOMER360_DB.ANALYTICS.GIT_SNOW_SECRET
    ORIGIN = 'https://github.com/<YOUR_GITHUB_ORG_OR_USER>/<YOUR_REPO_NAME>.git';

-- Fetch latest from remote
ALTER GIT REPOSITORY CUSTOMER360_DB.ANALYTICS.GIT_SNOW_REPO_TEST FETCH;


-- ============================================================================
-- 6. COMPUTE POOL (for Streamlit apps)
-- ============================================================================
-- Creates the compute pool if it doesn't exist (safe for all account types).

CREATE COMPUTE POOL IF NOT EXISTS SYSTEM_COMPUTE_POOL_CPU
    MIN_NODES = 1
    MAX_NODES = 2
    INSTANCE_FAMILY = CPU_X64_S;


-- ============================================================================
-- 7. SUMMARY OF ALL OBJECTS
-- ============================================================================
-- | Object Type        | Name                                                  |
-- |--------------------|-------------------------------------------------------|
-- | Warehouse          | COMPUTE_WH                                            |
-- | Database           | CUSTOMER360_DB                                        |
-- | Schema             | CUSTOMER360_DB.ANALYTICS                              |
-- | Table              | CUSTOMER360_DB.ANALYTICS.CUSTOMERS                    |
-- | Table              | CUSTOMER360_DB.ANALYTICS.CUSTOMER_SEGMENTS            |
-- | Table              | CUSTOMER360_DB.ANALYTICS.ORDERS                       |
-- | Table              | CUSTOMER360_DB.ANALYTICS.PRODUCT_REVIEWS              |
-- | Table              | CUSTOMER360_DB.ANALYTICS.SUPPORT_TICKETS              |
-- | Table              | CUSTOMER360_DB.ANALYTICS.WEB_EVENTS                   |
-- | Semantic View      | CUSTOMER360_DB.ANALYTICS.CUSTOMER360_VIEW             |
-- | Cortex Agent       | CUSTOMER360_DB.ANALYTICS.CUSTOMER360_AGENT            |
-- | Secret             | CUSTOMER360_DB.ANALYTICS.GIT_SNOW_SECRET              |
-- | API Integration    | MY_GIT_API_INTEGRATION (account-level)                |
-- | Git Repository     | CUSTOMER360_DB.ANALYTICS.GIT_SNOW_REPO_TEST           |
-- | Compute Pool       | SYSTEM_COMPUTE_POOL_CPU (account-level, pre-created)  |
-- | Streamlit App      | customer360-dashboard/ (Workspace files)              |
-- ============================================================================
