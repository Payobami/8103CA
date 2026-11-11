-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Portfolio 3: Transactions and Concurrency
-- File: 01_atomic_p2p_transfer_commit_rollback.sql
-- Case Study: Oval Pay Finances (Digital Wallet & Payment Platform)
-- Purpose: Demonstrates ACID transactions, explicit COMMIT, automatic ROLLBACK
--          on insufficient funds or KYC breach, and SAVEPOINT usage.
-- ============================================================================

USE ovalpay_db;

DROP PROCEDURE IF EXISTS sp_execute_p2p_transfer;

DELIMITER $$

CREATE PROCEDURE sp_execute_p2p_transfer(
    IN  p_sender_wallet_id   BIGINT UNSIGNED,
    IN  p_receiver_wallet_id BIGINT UNSIGNED,
    IN  p_amount             DECIMAL(15, 2),
    IN  p_fee                DECIMAL(15, 2),
    IN  p_transfer_ref       VARCHAR(64),
    OUT p_result_status      VARCHAR(30),
    OUT p_result_message     VARCHAR(255)
)
BEGIN
    DECLARE v_sender_balance     DECIMAL(15, 2);
    DECLARE v_sender_status      VARCHAR(20);
    DECLARE v_single_limit       DECIMAL(15, 2);
    DECLARE v_receiver_balance   DECIMAL(15, 2);
    DECLARE v_receiver_status    VARCHAR(20);
    DECLARE v_total_debit        DECIMAL(15, 2);
    DECLARE v_debit_tx_id        BIGINT UNSIGNED;
    DECLARE v_credit_tx_id       BIGINT UNSIGNED;

    -- Exit handler: Rollback the entire transaction if any SQL exception occurs
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_status  = 'ROLLED_BACK';
        SET p_result_message = 'Transaction rolled back due to a database constraint or runtime error.';
    END;

    SET v_total_debit = p_amount + p_fee;

    -- Start atomic ACID transaction
    START TRANSACTION;

    -- DEADLOCK PREVENTION: Lock both wallets in ascending wallet_id order
    IF p_sender_wallet_id < p_receiver_wallet_id THEN
        SELECT w.balance, w.wallet_status, k.single_transfer_limit
          INTO v_sender_balance, v_sender_status, v_single_limit
          FROM wallets w
          INNER JOIN customers c ON w.customer_id = c.customer_id
          INNER JOIN kyc_tiers k ON c.kyc_tier_id = k.kyc_tier_id
         WHERE w.wallet_id = p_sender_wallet_id
           FOR UPDATE;

        SELECT w.balance, w.wallet_status
          INTO v_receiver_balance, v_receiver_status
          FROM wallets w
         WHERE w.wallet_id = p_receiver_wallet_id
           FOR UPDATE;
    ELSE
        SELECT w.balance, w.wallet_status
          INTO v_receiver_balance, v_receiver_status
          FROM wallets w
         WHERE w.wallet_id = p_receiver_wallet_id
           FOR UPDATE;

        SELECT w.balance, w.wallet_status, k.single_transfer_limit
          INTO v_sender_balance, v_sender_status, v_single_limit
          FROM wallets w
          INNER JOIN customers c ON w.customer_id = c.customer_id
          INNER JOIN kyc_tiers k ON c.kyc_tier_id = k.kyc_tier_id
         WHERE w.wallet_id = p_sender_wallet_id
           FOR UPDATE;
    END IF;

    -- Validation 1: Check active wallet status
    IF v_sender_status <> 'active' OR v_receiver_status <> 'active' THEN
        ROLLBACK;
        SET p_result_status  = 'FAILED_ROLLED_BACK';
        SET p_result_message = 'Transfer aborted: Sender or receiver wallet is frozen/closed.';

    -- Validation 2: Check KYC Single Transfer Limit
    ELSEIF p_amount > v_single_limit THEN
        ROLLBACK;
        SET p_result_status  = 'FAILED_ROLLED_BACK';
        SET p_result_message = CONCAT('Transfer aborted: Amount exceeds KYC single limit of ', v_single_limit);

    -- Validation 3: Check Sufficient Balance
    ELSEIF v_sender_balance < v_total_debit THEN
        ROLLBACK;
        SET p_result_status  = 'FAILED_ROLLED_BACK';
        SET p_result_message = CONCAT('Transfer aborted: Insufficient balance (Available: ', v_sender_balance, ', Required: ', v_total_debit, ')');

    ELSE
        -- Step 1: Debit Sender Wallet
        UPDATE wallets
           SET balance      = balance - v_total_debit,
               lock_version = lock_version + 1
         WHERE wallet_id = p_sender_wallet_id;

        -- Step 2: Record Sender Debit Ledger Entry
        INSERT INTO transactions (
            reference, wallet_id, transaction_type, amount, fee,
            balance_before, balance_after, status, channel, narration
        ) VALUES (
            CONCAT(p_transfer_ref, '-DR'),
            p_sender_wallet_id,
            'transfer_out',
            p_amount,
            p_fee,
            v_sender_balance,
            v_sender_balance - v_total_debit,
            'completed',
            'mobile_app',
            CONCAT('P2P Debit to Wallet #', p_receiver_wallet_id)
        );
        SET v_debit_tx_id = LAST_INSERT_ID();

        -- Step 3: Credit Receiver Wallet
        UPDATE wallets
           SET balance      = balance + p_amount,
               lock_version = lock_version + 1
         WHERE wallet_id = p_receiver_wallet_id;

        -- Step 4: Record Receiver Credit Ledger Entry
        INSERT INTO transactions (
            reference, wallet_id, transaction_type, amount, fee,
            balance_before, balance_after, status, channel, narration
        ) VALUES (
            CONCAT(p_transfer_ref, '-CR'),
            p_receiver_wallet_id,
            'transfer_in',
            p_amount,
            0.00,
            v_receiver_balance,
            v_receiver_balance + p_amount,
            'completed',
            'mobile_app',
            CONCAT('P2P Credit from Wallet #', p_sender_wallet_id)
        );
        SET v_credit_tx_id = LAST_INSERT_ID();

        -- Step 5: Record Master Wallet Transfer Row
        INSERT INTO wallet_transfers (
            transfer_reference, sender_wallet_id, receiver_wallet_id,
            debit_transaction_id, credit_transaction_id, amount, fee,
            transfer_status, completed_at
        ) VALUES (
            p_transfer_ref, p_sender_wallet_id, p_receiver_wallet_id,
            v_debit_tx_id, v_credit_tx_id, p_amount, p_fee,
            'completed', CURRENT_TIMESTAMP
        );

        -- Commit atomic transaction
        COMMIT;
        SET p_result_status  = 'COMMITTED';
        SET p_result_message = CONCAT('Transfer ', p_transfer_ref, ' committed successfully.');
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- TEST CASE 1: SUCCESSFUL ATOMIC P2P TRANSFER (COMMIT)
-- Transfer 50,000.00 NGN (+ 25.00 fee) from Wallet #1 to Wallet #2
-- ============================================================================
SELECT wallet_id, wallet_number, balance, lock_version
  FROM wallets WHERE wallet_id IN (1, 2);

CALL sp_execute_p2p_transfer(1, 2, 50000.00, 25.00, 'OP-TXN-DEMO-COMMIT-01', @status1, @msg1);
SELECT @status1 AS transaction_outcome, @msg1 AS details;

SELECT wallet_id, wallet_number, balance, lock_version
  FROM wallets WHERE wallet_id IN (1, 2);

-- ============================================================================
-- TEST CASE 2: FAILED TRANSFER DUE TO INSUFFICIENT FUNDS (AUTOMATIC ROLLBACK)
-- Attempt to transfer 48,000.00 NGN from Wallet #4 (Balance is only 42,000.00)
-- ============================================================================
SELECT wallet_id, wallet_number, balance, lock_version
  FROM wallets WHERE wallet_id IN (4, 2);

CALL sp_execute_p2p_transfer(4, 2, 48000.00, 25.00, 'OP-TXN-DEMO-ROLLBACK-02', @status2, @msg2);
SELECT @status2 AS transaction_outcome, @msg2 AS details;

-- Verify Wallet #4 and Wallet #2 balances are completely unchanged
SELECT wallet_id, wallet_number, balance, lock_version
  FROM wallets WHERE wallet_id IN (4, 2);

-- ============================================================================
-- TEST CASE 3: EXPLICIT SAVEPOINT & PARTIAL ROLLBACK DEMONSTRATION
-- Scenario: Batch fee deduction where a secondary optional charge fails and
-- rolls back to a SAVEPOINT while preserving the primary wallet deposit.
-- ============================================================================
START TRANSACTION;

-- Primary operation: Deposit 10,000 NGN into Wallet #4
UPDATE wallets SET balance = balance + 10000.00 WHERE wallet_id = 4;
INSERT INTO transactions (
    reference, wallet_id, transaction_type, amount, fee,
    balance_before, balance_after, status, channel, narration
) VALUES (
    'OP-SVP-DEP-001', 4, 'deposit', 10000.00, 0.00,
    42000.00, 52000.00, 'completed', 'web', 'Savepoint Demo Deposit'
);

SAVEPOINT sp_after_deposit;

-- Secondary operation: Attempt promotional debit that we decide to abort
UPDATE wallets SET balance = balance - 2000.00 WHERE wallet_id = 4;

-- Roll back ONLY the secondary operation, preserving the 10,000 NGN deposit
ROLLBACK TO SAVEPOINT sp_after_deposit;

COMMIT;

-- Verify Wallet #4 now has 52,000.00 NGN (deposit kept, 2,000 debit rolled back)
SELECT wallet_id, wallet_number, balance FROM wallets WHERE wallet_id = 4;
