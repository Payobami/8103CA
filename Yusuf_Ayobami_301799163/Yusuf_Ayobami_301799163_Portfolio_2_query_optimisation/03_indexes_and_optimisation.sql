-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Portfolio 2: Query Processing and Optimisation
-- File: 03_indexes_and_optimisation.sql
-- Purpose: Creates targeted composite B-Tree & covering indexes and rewrites
--          correlated subqueries using MySQL 8.0 Window Functions.
-- ============================================================================

USE ovalpay_db;

-- ============================================================================
-- STEP 1: CREATE COMPOSITE & COVERING B-TREE INDEXES
-- ============================================================================

-- 1. Optimises Query 1 & Query 4:
-- Follows the Equality -> Range/Sort rule: (wallet_id, status, created_at DESC).
-- Eliminates filesort and scans only matching wallet+status rows in date order.
CREATE INDEX idx_tx_wallet_status_created
    ON transactions (wallet_id, status, created_at DESC);

-- 2. Optimises Query 2 (Covering Index for Outbound AML Aggregation):
-- Includes (status, transaction_type, created_at) for filtering and covers
-- (wallet_id, amount, fee) so InnoDB reads strictly from the index leaf pages!
CREATE INDEX idx_tx_status_type_created_covering
    ON transactions (status, transaction_type, created_at, wallet_id, amount, fee);

-- 3. Optimises Query 3 (Covering Index for Merchant Settlement Summary):
-- Filters by (merchant_id, status, transaction_type, created_at) and covers (amount).
CREATE INDEX idx_tx_merchant_settlement_covering
    ON transactions (merchant_id, status, transaction_type, created_at, amount);

-- Refresh optimizer index cardinality statistics
ANALYZE TABLE transactions;

-- Inspect all indexes on transactions
SHOW INDEX FROM transactions;

-- ============================================================================
-- STEP 2: RE-RUN EXPLAIN ANALYZE AFTER INDEXING & QUERY REWRITING
-- ============================================================================

-- Re-test Query 1 (Now uses Index Range Scan on idx_tx_wallet_status_created with NO filesort)
EXPLAIN ANALYZE
SELECT
    t.transaction_id,
    t.reference,
    t.transaction_type,
    t.amount,
    t.fee,
    t.balance_before,
    t.balance_after,
    t.channel,
    t.created_at
FROM transactions t
WHERE t.wallet_id = 1
  AND t.status = 'completed'
  AND t.created_at BETWEEN '2026-09-01 00:00:00' AND '2026-11-01 23:59:59'
ORDER BY t.created_at DESC
LIMIT 20;

-- Re-test Query 2 (Now uses Covering Index Scan on idx_tx_status_type_created_covering)
EXPLAIN ANALYZE
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    k.tier_name,
    k.daily_transfer_limit,
    w.wallet_number,
    COUNT(t.transaction_id)                AS outbound_tx_count,
    SUM(t.amount)                          AS total_outbound_amount,
    SUM(t.fee)                             AS total_fees_paid
FROM transactions t
INNER JOIN wallets w   ON t.wallet_id = w.wallet_id
INNER JOIN customers c ON w.customer_id = c.customer_id
INNER JOIN kyc_tiers k ON c.kyc_tier_id = k.kyc_tier_id
WHERE t.transaction_type IN ('transfer_out', 'withdrawal')
  AND t.status = 'completed'
  AND t.created_at >= '2026-10-01 00:00:00'
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name,
    k.tier_name,
    k.daily_transfer_limit,
    w.wallet_number
HAVING SUM(t.amount) > 500000.00
ORDER BY total_outbound_amount DESC
LIMIT 15;

-- Re-test Query 3 (Now uses Covering Index Range Scan on idx_tx_merchant_settlement_covering)
EXPLAIN ANALYZE
SELECT
    m.merchant_code,
    m.business_name,
    m.category,
    m.commission_rate,
    COUNT(t.transaction_id)                           AS settled_tx_count,
    SUM(t.amount)                                     AS gross_transaction_value,
    ROUND(SUM(t.amount * m.commission_rate), 2)       AS platform_commission_revenue,
    ROUND(SUM(t.amount * (1 - m.commission_rate)), 2) AS net_merchant_payout
FROM merchants m
INNER JOIN transactions t ON m.merchant_id = t.merchant_id
WHERE t.transaction_type = 'merchant_payment'
  AND t.status = 'completed'
  AND t.created_at BETWEEN '2026-09-01 00:00:00' AND '2026-11-01 23:59:59'
GROUP BY
    m.merchant_id,
    m.merchant_code,
    m.business_name,
    m.category,
    m.commission_rate
ORDER BY gross_transaction_value DESC;

-- ============================================================================
-- QUERY 4B (OPTIMISED REWRITE): Window Function ROW_NUMBER() + Composite Index
-- Replaces the correlated subquery with a single-pass partitioned window scan.
-- ============================================================================
EXPLAIN ANALYZE
WITH ranked_transactions AS (
    SELECT
        w.wallet_id,
        w.wallet_number,
        t.reference,
        t.transaction_type,
        t.amount,
        t.created_at,
        ROW_NUMBER() OVER (
            PARTITION BY t.wallet_id
            ORDER BY t.created_at DESC
        ) AS rn
    FROM wallets w
    INNER JOIN transactions t ON w.wallet_id = t.wallet_id
    WHERE w.wallet_id <= 50
      AND t.status = 'completed'
)
SELECT
    wallet_id,
    wallet_number,
    reference,
    transaction_type,
    amount,
    created_at
FROM ranked_transactions
WHERE rn = 1;
