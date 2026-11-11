-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Portfolio 2: Query Processing and Optimisation
-- File: 02_analytical_queries_before_indexing.sql
-- Purpose: Runs 4 core Fintech operational/analytical SQL queries and inspects
--          their execution plans BEFORE composite indexing is applied.
-- ============================================================================

USE ovalpay_db;

-- ============================================================================
-- QUERY 1: Customer Monthly Account Statement (Filter + Date Range + Sort)
-- Business Use Case: Mobile App fetches completed mobile_app transactions for
-- Wallet #1 between Sept 1, 2026 and Nov 1, 2026 sorted newest first.
-- ============================================================================
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

-- ============================================================================
-- QUERY 2: High-Value Outbound Volume vs. KYC Daily Limit Audit (AML Report)
-- Business Use Case: Compliance team identifies active customers whose completed
-- outbound transfers/withdrawals over a 30-day window exceed 500,000 NGN.
-- ============================================================================
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

-- ============================================================================
-- QUERY 3: Merchant Settlement & Platform Commission Revenue Summary
-- Business Use Case: Finance team computes gross merchant payment volume,
-- platform commission revenue, and net merchant payout per merchant.
-- ============================================================================
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
-- QUERY 4A (UNOPTIMISED): Correlated Subquery for Latest Transaction per Wallet
-- Problem: Executes a dependent subquery for every wallet row.
-- ============================================================================
EXPLAIN ANALYZE
SELECT
    w.wallet_id,
    w.wallet_number,
    t.reference,
    t.transaction_type,
    t.amount,
    t.created_at
FROM wallets w
INNER JOIN transactions t ON w.wallet_id = t.wallet_id
WHERE w.wallet_id <= 50
  AND t.created_at = (
      SELECT MAX(t2.created_at)
      FROM transactions t2
      WHERE t2.wallet_id = w.wallet_id
        AND t2.status = 'completed'
  );
