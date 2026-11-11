-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Portfolio 5: Distributed and Cloud Database Exercise
-- File: 01_partitioning_and_sharding_strategy.sql
-- Case Study: Oval Pay Finances
-- Purpose: Demonstrates Horizontal Range Partitioning on the high-growth
--          transactions ledger (Partition Pruning) and GTID Replication setup.
-- ============================================================================

USE ovalpay_db;

-- ============================================================================
-- PART 1: HORIZONTAL RANGE PARTITIONING FOR HIGH-VOLUME LEDGER ARCHIVAL
-- In MySQL 8.0, partitioning a massive transactions table by year/quarter
-- allows the optimizer to prune historical partitions during recent queries.
-- ============================================================================

DROP TABLE IF EXISTS transactions_partitioned;

CREATE TABLE transactions_partitioned (
    transaction_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    reference        VARCHAR(64)     NOT NULL,
    wallet_id        BIGINT UNSIGNED NOT NULL,
    merchant_id      BIGINT UNSIGNED NULL,
    transaction_type ENUM('deposit', 'withdrawal', 'transfer_in', 'transfer_out', 'merchant_payment', 'reversal') NOT NULL,
    amount           DECIMAL(15, 2)  NOT NULL,
    fee              DECIMAL(15, 2)  NOT NULL DEFAULT 0.00,
    balance_before   DECIMAL(15, 2)  NOT NULL,
    balance_after    DECIMAL(15, 2)  NOT NULL,
    status           ENUM('pending', 'completed', 'failed', 'reversed') NOT NULL DEFAULT 'pending',
    channel          ENUM('mobile_app', 'ussd', 'web', 'pos', 'api') NOT NULL DEFAULT 'mobile_app',
    narration        VARCHAR(255)    NULL,
    created_at       DATETIME        NOT NULL,

    -- Note: In MySQL InnoDB partitioning, the partitioning key (created_at)
    -- must be included in every PRIMARY and UNIQUE key.
    PRIMARY KEY (transaction_id, created_at),
    UNIQUE KEY uq_tx_part_ref_date (reference, created_at),
    KEY idx_tx_part_wallet_date (wallet_id, status, created_at DESC)
) ENGINE=InnoDB
PARTITION BY RANGE ( YEAR(created_at) * 100 + MONTH(created_at) ) (
    PARTITION p_2026_07 VALUES LESS THAN (202608),
    PARTITION p_2026_08 VALUES LESS THAN (202609),
    PARTITION p_2026_09 VALUES LESS THAN (202610),
    PARTITION p_2026_10 VALUES LESS THAN (202611),
    PARTITION p_2026_11 VALUES LESS THAN (202612),
    PARTITION p_future  VALUES LESS THAN MAXVALUE
);

-- Copy existing ledger rows from transactions into transactions_partitioned
INSERT INTO transactions_partitioned (
    transaction_id, reference, wallet_id, merchant_id, transaction_type,
    amount, fee, balance_before, balance_after, status, channel, narration, created_at
)
SELECT
    transaction_id, reference, wallet_id, merchant_id, transaction_type,
    amount, fee, balance_before, balance_after, status, channel, narration, created_at
FROM transactions;

ANALYZE TABLE transactions_partitioned;

-- Verify row distribution across horizontal partitions
SELECT
    PARTITION_NAME,
    PARTITION_DESCRIPTION AS less_than_yyyymm,
    TABLE_ROWS            AS estimated_rows
FROM information_schema.PARTITIONS
WHERE TABLE_SCHEMA = 'ovalpay_db'
  AND TABLE_NAME   = 'transactions_partitioned';

-- Verify Partition Pruning: Notice "partitions: p_2026_10" in EXPLAIN output!
EXPLAIN
SELECT transaction_id, reference, amount, created_at
  FROM transactions_partitioned
 WHERE wallet_id = 1
   AND status = 'completed'
   AND created_at BETWEEN '2026-10-01 00:00:00' AND '2026-10-31 23:59:59';


-- ============================================================================
-- PART 2: GTID PRIMARY-REPLICA CONFIGURATION COMMANDS (REFERENCE SCRIPT)
-- ============================================================================

/*
-- [Executed on mysql-primary (Server ID = 1)]:
CREATE USER 'repl_user'@'%' IDENTIFIED WITH mysql_native_password BY 'ovalpay_repl_pass';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;
SHOW BINARY LOG STATUS;

-- [Executed on mysql-replica-1 (Server ID = 2)]:
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'mysql-primary',
    SOURCE_PORT = 3306,
    SOURCE_USER = 'repl_user',
    SOURCE_PASSWORD = 'ovalpay_repl_pass',
    SOURCE_AUTO_POSITION = 1;

START REPLICA;
SHOW REPLICA STATUS\G
*/
