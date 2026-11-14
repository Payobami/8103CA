-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Portfolio 2: Query Processing and Optimisation
-- File: 01_bulk_benchmark_seeder.sql
-- Purpose: Populates ovalpay_db with 1,000 customers/wallets and 50,000
--          realistic ledger transactions using MySQL 8.0 Stored Procedures so
--          EXPLAIN ANALYZE demonstrates realistic Full Table Scans vs Index Scans.
-- ============================================================================

USE ovalpay_db;

DROP PROCEDURE IF EXISTS sp_seed_benchmark_data;

DELIMITER $$

CREATE PROCEDURE sp_seed_benchmark_data()
BEGIN
    DECLARE v_i INT DEFAULT 6;
    DECLARE v_tx INT DEFAULT 6;
    DECLARE v_wallet_id BIGINT;
    DECLARE v_merchant_id BIGINT;
    DECLARE v_tx_type VARCHAR(20);
    DECLARE v_status VARCHAR(20);
    DECLARE v_channel VARCHAR(20);
    DECLARE v_amount DECIMAL(15,2);
    DECLARE v_fee DECIMAL(15,2);
    DECLARE v_created_at TIMESTAMP;

    -- Disable autocommit inside bulk loop for fast insertion
    SET autocommit = 0;

    -- 1. Seed 1,000 Customers & Wallets (IDs 6 to 1000)
    WHILE v_i <= 1000 DO
        INSERT IGNORE INTO customers (
            customer_id, kyc_tier_id, first_name, last_name, email, phone_number, bvn_number, date_of_birth, account_status
        ) VALUES (
            v_i,
            1 + (v_i % 3),
            CONCAT('CustomerFirst', v_i),
            CONCAT('CustomerLast', v_i),
            CONCAT('user', v_i, '@ovalpay.ng'),
            CONCAT('+234803', LPAD(v_i, 7, '0')),
            LPAD(22100000000 + v_i, 11, '0'),
            DATE_SUB('1998-01-01', INTERVAL (v_i % 5000) DAY),
            IF(v_i % 25 = 0, 'suspended', 'active')
        );

        INSERT IGNORE INTO wallets (
            wallet_id, customer_id, wallet_number, currency, balance, locked_balance, wallet_status, lock_version
        ) VALUES (
            v_i,
            v_i,
            LPAD(3010000000 + v_i, 10, '0'),
            'NGN',
            ROUND(10000 + (RAND(v_i) * 950000), 2),
            0.00,
            'active',
            1
        );

        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;

    -- 2. Seed 50,000 Transactions (IDs 6 to 50005) spread across 180 days
    WHILE v_tx <= 50005 DO
        SET v_wallet_id = 1 + (v_tx % 1000);
        SET v_tx_type = ELT(1 + (v_tx % 5), 'deposit', 'transfer_out', 'transfer_in', 'merchant_payment', 'withdrawal');
        SET v_merchant_id = IF(v_tx_type = 'merchant_payment', 1 + (v_tx % 3), NULL);
        SET v_status = ELT(1 + (v_tx % 10), 'completed', 'completed', 'completed', 'completed', 'completed', 'completed', 'completed', 'pending', 'failed', 'reversed');
        SET v_channel = ELT(1 + (v_tx % 5), 'mobile_app', 'mobile_app', 'ussd', 'web', 'pos');
        SET v_amount = ROUND(500 + ((v_tx * 137) % 250000), 2);
        SET v_fee = IF(v_tx_type IN ('transfer_out', 'withdrawal'), 25.00, 0.00);
        SET v_created_at = TIMESTAMPADD(MINUTE, -(v_tx * 5), '2026-11-01 12:00:00');

        INSERT INTO transactions (
            reference, wallet_id, merchant_id, transaction_type, amount, fee,
            balance_before, balance_after, status, channel, narration, created_at
        ) VALUES (
            CONCAT('OP-BENCH-', LPAD(v_tx, 8, '0')),
            v_wallet_id,
            v_merchant_id,
            v_tx_type,
            v_amount,
            v_fee,
            500000.00,
            500000.00 + IF(v_tx_type IN ('deposit', 'transfer_in'), v_amount, -(v_amount + v_fee)),
            v_status,
            v_channel,
            CONCAT('Benchmark ', v_tx_type, ' via ', v_channel),
            v_created_at
        );

        IF (v_tx % 5000 = 0) THEN
            COMMIT;
        END IF;

        SET v_tx = v_tx + 1;
    END WHILE;

    COMMIT;
    SET autocommit = 1;

    -- Refresh table statistics for the MySQL Cost-Based Optimizer
    ANALYZE TABLE customers, wallets, merchants, transactions, wallet_transfers;
END$$

DELIMITER ;

-- Execute the benchmark seeder
CALL sp_seed_benchmark_data();

-- Verify total row counts
SELECT
    (SELECT COUNT(*) FROM customers)    AS total_customers,
    (SELECT COUNT(*) FROM wallets)      AS total_wallets,
    (SELECT COUNT(*) FROM transactions) AS total_transactions;
