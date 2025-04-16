-- 1. How many users are there?
SELECT count(*) AS  'all users'
FROM users;

-- 2.  How many cookies does each user have on average?
SELECT
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT user_id), 2) AS avg_cookies_per_user
FROM users;

-- 3. What is the unique number of visits by all users per month?
SELECT 
  DATE_FORMAT(start_date, '%Y-%m') AS visit_month,
  COUNT(DISTINCT user_id, DATE(start_date)) AS unique_user_visits
FROM users
GROUP BY visit_month
ORDER BY visit_month;

-- 4. What is the number of events for each event type?
SELECT 
  event_type,
  COUNT(*) AS event_count
FROM events
GROUP BY event_type
ORDER BY event_count DESC;

-- 5. What is the percentage of visits which have a purchase event?
SELECT ei.event_name,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS percentage
FROM events e JOIN 
event_identifier ei USING (event_type)
WHERE ei.event_name='purchase';



SELECT 
  ROUND(
    COUNT(DISTINCT CASE WHEN ei.event_name = 'Purchase' THEN e.visit_id END) 
    / COUNT(DISTINCT e.visit_id) * 100, 
    2
  ) AS pct_visits_with_purchase
FROM events e
JOIN event_identifier ei
  ON e.event_type = ei.event_type;
  
  -- 6. What is the percentage of visits which view the checkout page but do not have a purchase event?
WITH event_mapping AS (
  SELECT 
    e.visit_id,
    ei.event_name
  FROM events e
  JOIN event_identifier ei 
    ON e.event_type = ei.event_type
),
visit_events AS (
  SELECT 
    visit_id,
    MAX(CASE WHEN event_name = 'Checkout' THEN 1 ELSE 0 END) AS has_checkout,
    MAX(CASE WHEN event_name = 'Purchase' THEN 1 ELSE 0 END) AS has_purchase
  FROM event_mapping
  GROUP BY visit_id
)
SELECT 
  ROUND(
    COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT visit_id) FROM events),
    2
  ) AS pct_checkout_no_purchase
FROM visit_events
WHERE has_checkout = 1 AND has_purchase = 0;

-- 7. What are the top 3 pages by number of views?
SELECT 
    ph.page_name,
    COUNT(*) AS view_count
FROM 
    events e
JOIN 
    page_hierarchy ph ON e.page_id = ph.page_id
WHERE 
    e.event_type = 1  -- Page View event
GROUP BY 
    ph.page_name
ORDER BY 
    view_count DESC
LIMIT 3;

-- 8. What is the number of views and cart adds for each product category?
 SELECT 
    ph.product_category,
    SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END) AS view_count,
    SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) AS cart_add_count,
    ROUND(
        100.0 * SUM(CASE WHEN e.event_type = 2 THEN 1 ELSE 0 END) / 
        NULLIF(SUM(CASE WHEN e.event_type = 1 THEN 1 ELSE 0 END), 0),2
    )AS conversion_rate_percentage
FROM 
    events e
JOIN 
    page_hierarchy ph ON e.page_id = ph.page_id
WHERE 
    ph.product_category IS NOT NULL
    AND e.event_type IN (1, 2)  -- Page View (1) and Add to Cart (2)
GROUP BY 
    ph.product_category
ORDER BY 
    view_count DESC;
    
 -- 9. What are the top 3 products by purchases?
 WITH product_purchases AS (
    SELECT 
        ph.page_id,
        ph.page_name AS product_name,
        ph.product_category,
        COUNT(*) AS purchase_count
    FROM 
        events e
    JOIN 
        page_hierarchy ph ON e.page_id = ph.page_id
    JOIN 
        events e2 ON e.visit_id = e2.visit_id
        AND e2.event_type = 3  -- Purchase event
        AND e2.event_time >= e.event_time  -- Purchase happened after add to cart
    WHERE 
        e.event_type = 2  -- Add to cart event
        AND ph.product_id IS NOT NULL  -- Only actual products, not category pages
    GROUP BY 
        ph.page_id, ph.page_name, ph.product_category
)
SELECT 
    product_name,
    product_category,
    purchase_count
FROM 
    product_purchases
ORDER BY 
    purchase_count DESC
LIMIT 3;