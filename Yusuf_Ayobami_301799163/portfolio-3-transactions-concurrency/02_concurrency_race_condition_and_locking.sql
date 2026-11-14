-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Portfolio 3: Transactions and Concurrency
-- File: 02_concurrency_race_condition_and_locking.sql
-- Case Study: Oval Pay Finances
-- Purpose: Demonstrates concurrency anomalies (Lost Update / Double Withdrawal)
--          and their resolution using Pessimistic Locking (SELECT ... FOR UPDATE),
--          Optimistic Locking (lock_version), and Transaction Isolation Levels.
-- ============================================================================

USE ovalpay_db;

-- ============================================================================
-- PART A: PESSIMISTIC CONCURRENCY CONTROL (SELECT ... FOR UPDATE)
-- Scenario: Two concurrent withdrawal requests (Mobile App & POS Terminal)
-- attempt to withdraw 40,000 NGN simultaneously from Wallet #4 (Balance: 52,000 NGN).
-- Run Session A in Terminal 1 and Session B in Terminal 2.
-- ============================================================================

/* ----------------------------------------------------------------------------
   [SESSION A - Terminal 1: Mobile App Withdrawal of 40,000 NGN]
   ---------------------------------------------------------------------------- */
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;

-- Acquires an exclusive row-level X-lock on wallet_id = 4 in InnoDB
SELECT wallet_id, wallet_number, balance, lock_version
  FROM wallets
 WHERE wallet_id = 4
   FOR UPDATE;
-- Output: balance = 52000.00

-- Debit 40,000.00 NGN
UPDATE wallets
   SET balance      = balance - 40000.00,
       lock_version = lock_version + 1
 WHERE wallet_id = 4;

INSERT INTO transactions (
    reference, wallet_id, transaction_type, amount, fee,
    balance_before, balance_after, status, channel, narration
) VALUES (
    'OP-CONC-SESSA-01', 4, 'withdrawal', 40000.00, 0.00,
    52000.00, 12000.00, 'completed', 'mobile_app', 'Session A Concurrent Withdrawal'
);

-- Hold lock for 5 seconds while Session B attempts to read FOR UPDATE
DO SLEEP(5);

COMMIT;
-- Output: Wallet #4 balance is now 12,000.00 NGN. Lock is released!


/* ----------------------------------------------------------------------------
   [SESSION B - Terminal 2: Concurrent POS Withdrawal of 40,000 NGN]
   (Executed while Session A is inside DO SLEEP(5))
   ---------------------------------------------------------------------------- */
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;

-- This statement BLOCKS and waits for Session A to COMMIT or ROLLBACK
SELECT wallet_id, wallet_number, balance, lock_version
  FROM wallets
 WHERE wallet_id = 4
   FOR UPDATE;

-- As soon as Session A commits, Session B unblocks and receives the UPDATED row:
-- Output: balance = 12000.00 (NOT the stale 52000.00!)
-- Because 12,000.00 < 40,000.00, Session B safely aborts:
ROLLBACK;


-- ============================================================================
-- PART B: OPTIMISTIC CONCURRENCY CONTROL (Compare-and-Swap via lock_version)
-- Scenario: Used in high-throughput API endpoints where holding database locks
-- across external HTTP calls is undesirable.
-- ============================================================================

-- Suppose both workers read Wallet #3 with balance = 875000.00 and lock_version = 1:
-- Worker 1 executes:
UPDATE wallets
   SET balance      = balance - 25000.00,
       lock_version = lock_version + 1
 WHERE wallet_id    = 3
   AND lock_version = 1
   AND balance     >= 25000.00;

SELECT ROW_COUNT() AS worker_1_updated_rows; -- Returns 1 (Success, lock_version is now 2)

-- Worker 2 (holding stale lock_version = 1) executes milliseconds later:
UPDATE wallets
   SET balance      = balance - 25000.00,
       lock_version = lock_version + 1
 WHERE wallet_id    = 3
   AND lock_version = 1
   AND balance     >= 25000.00;

SELECT ROW_COUNT() AS worker_2_updated_rows; -- Returns 0 (Stale version detected; Lost Update prevented!)


-- ============================================================================
-- PART C: TRANSACTION ISOLATION LEVELS COMPARISON (MVCC Snapshot vs Current Read)
-- ============================================================================

-- Inspect current global and session isolation levels in MySQL 8.0
SELECT
    @@GLOBAL.transaction_isolation  AS global_isolation_level,
    @@SESSION.transaction_isolation AS session_isolation_level;

-- Inspect active InnoDB row locks and lock waits (useful during concurrency testing)
SELECT
    engine_lock_id,
    engine_transaction_id,
    thread_id,
    object_schema,
    object_name,
    lock_type,
    lock_mode,
    lock_status,
    lock_data
FROM performance_schema.data_locks;

