-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Portfolio 1: Database Design and Modelling
-- Case Study: Oval Pay Finances (Digital Wallet & Payment System)
-- Target DBMS: MySQL 8.0+ (InnoDB Engine)
-- ============================================================================

DROP DATABASE IF EXISTS ovalpay_db;
CREATE DATABASE ovalpay_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE ovalpay_db;

-- ============================================================================
-- 1. TABLE: kyc_tiers
-- Purpose: Stores regulatory Know-Your-Customer (KYC) levels and limits.
-- 3NF Justification: Eliminates transitive dependency where customer_id ->
-- kyc_tier_id -> (single_transfer_limit, daily_transfer_limit, max_wallet_balance).
-- ============================================================================
CREATE TABLE kyc_tiers (
    kyc_tier_id           TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    tier_code             VARCHAR(10)      NOT NULL,
    tier_name             VARCHAR(50)      NOT NULL,
    single_transfer_limit DECIMAL(15, 2)   NOT NULL,
    daily_transfer_limit  DECIMAL(15, 2)   NOT NULL,
    max_wallet_balance    DECIMAL(15, 2)   NOT NULL,
    requires_bvn          BOOLEAN          NOT NULL DEFAULT TRUE,
    requires_address_ver  BOOLEAN          NOT NULL DEFAULT FALSE,
    created_at            TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_kyc_tiers PRIMARY KEY (kyc_tier_id),
    CONSTRAINT uq_kyc_tiers_code UNIQUE (tier_code),
    CONSTRAINT uq_kyc_tiers_name UNIQUE (tier_name),
    CONSTRAINT chk_kyc_limits_positive CHECK (
        single_transfer_limit > 0.00
        AND daily_transfer_limit >= single_transfer_limit
        AND max_wallet_balance >= daily_transfer_limit
    )
) ENGINE=InnoDB;

-- ============================================================================
-- 2. TABLE: customers
-- Purpose: Stores verified retail user profiles on the Oval Pay Finances platform.
-- ============================================================================
CREATE TABLE customers (
    customer_id    BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    kyc_tier_id    TINYINT UNSIGNED NOT NULL DEFAULT 1,
    first_name     VARCHAR(80)      NOT NULL,
    last_name      VARCHAR(80)      NOT NULL,
    email          VARCHAR(150)     NOT NULL,
    phone_number   VARCHAR(20)      NOT NULL,
    bvn_number     CHAR(11)         NULL,
    date_of_birth  DATE             NOT NULL,
    account_status ENUM('active', 'suspended', 'closed') NOT NULL DEFAULT 'active',
    created_at     TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_customers PRIMARY KEY (customer_id),
    CONSTRAINT uq_customers_email UNIQUE (email),
    CONSTRAINT uq_customers_phone UNIQUE (phone_number),
    CONSTRAINT uq_customers_bvn UNIQUE (bvn_number),
    CONSTRAINT fk_customers_kyc_tier
        FOREIGN KEY (kyc_tier_id) REFERENCES kyc_tiers (kyc_tier_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================================
-- 3. TABLE: wallets
-- Purpose: Stores customer digital wallet accounts and real-time balances.
-- Integrity: Enforces non-negative balance via CHECK constraint and supports
-- both pessimistic (FOR UPDATE) and optimistic (lock_version) concurrency control.
-- ============================================================================
CREATE TABLE wallets (
    wallet_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id    BIGINT UNSIGNED NOT NULL,
    wallet_number  CHAR(10)        NOT NULL,
    currency       CHAR(3)         NOT NULL DEFAULT 'NGN',
    balance        DECIMAL(15, 2)  NOT NULL DEFAULT 0.00,
    locked_balance DECIMAL(15, 2)  NOT NULL DEFAULT 0.00,
    wallet_status  ENUM('active', 'frozen', 'closed') NOT NULL DEFAULT 'active',
    lock_version   INT UNSIGNED    NOT NULL DEFAULT 1,
    created_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_wallets PRIMARY KEY (wallet_id),
    CONSTRAINT uq_wallets_number UNIQUE (wallet_number),
    CONSTRAINT uq_wallets_customer_currency UNIQUE (customer_id, currency),
    CONSTRAINT fk_wallets_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_wallets_non_negative_balance CHECK (
        balance >= 0.00 AND locked_balance >= 0.00
    )
) ENGINE=InnoDB;

-- ============================================================================
-- 4. TABLE: merchants
-- Purpose: Stores registered billers and merchants accepting Oval Pay payments.
-- 3NF Justification: Separates merchant details and commission rates from
-- individual transaction records.
-- ============================================================================
CREATE TABLE merchants (
    merchant_id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    merchant_code             VARCHAR(20)     NOT NULL,
    business_name             VARCHAR(150)    NOT NULL,
    category                  ENUM('utilities', 'telecoms', 'retail', 'transport', 'hospitality', 'education') NOT NULL,
    settlement_bank_code      CHAR(6)         NOT NULL,
    settlement_account_number CHAR(10)        NOT NULL,
    commission_rate           DECIMAL(5, 4)   NOT NULL DEFAULT 0.0150,
    status                    ENUM('active', 'inactive', 'suspended') NOT NULL DEFAULT 'active',
    created_at                TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_merchants PRIMARY KEY (merchant_id),
    CONSTRAINT uq_merchants_code UNIQUE (merchant_code),
    CONSTRAINT chk_merchants_commission CHECK (
        commission_rate >= 0.0000 AND commission_rate <= 0.2500
    )
) ENGINE=InnoDB;

-- ============================================================================
-- 5. TABLE: beneficiaries
-- Purpose: Stores saved external bank recipients for quick customer transfers.
-- ============================================================================
CREATE TABLE beneficiaries (
    beneficiary_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id    BIGINT UNSIGNED NOT NULL,
    bank_code      CHAR(6)         NOT NULL,
    bank_name      VARCHAR(100)    NOT NULL,
    account_number CHAR(10)        NOT NULL,
    account_name   VARCHAR(150)    NOT NULL,
    is_favourite   BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_beneficiaries PRIMARY KEY (beneficiary_id),
    CONSTRAINT uq_beneficiaries_customer_acct UNIQUE (customer_id, bank_code, account_number),
    CONSTRAINT fk_beneficiaries_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================================
-- 6. TABLE: transactions
-- Purpose: Immutable financial ledger recording every credit and debit entry.
-- Stores point-in-time balance_before and balance_after for full auditability.
-- ============================================================================
CREATE TABLE transactions (
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
    created_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_transactions PRIMARY KEY (transaction_id),
    CONSTRAINT uq_transactions_reference UNIQUE (reference),
    CONSTRAINT fk_transactions_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_transactions_merchant
        FOREIGN KEY (merchant_id) REFERENCES merchants (merchant_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_transactions_amounts CHECK (
        amount > 0.00
        AND fee >= 0.00
        AND balance_before >= 0.00
        AND balance_after >= 0.00
    )
) ENGINE=InnoDB;

-- ============================================================================
-- 7. TABLE: wallet_transfers
-- Purpose: Links peer-to-peer (P2P) wallet transfers between a sender wallet
-- and receiver wallet, pairing the corresponding debit and credit ledger rows.
-- ============================================================================
CREATE TABLE wallet_transfers (
    transfer_id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    transfer_reference    VARCHAR(64)     NOT NULL,
    sender_wallet_id      BIGINT UNSIGNED NOT NULL,
    receiver_wallet_id    BIGINT UNSIGNED NOT NULL,
    debit_transaction_id  BIGINT UNSIGNED NULL,
    credit_transaction_id BIGINT UNSIGNED NULL,
    amount                DECIMAL(15, 2)  NOT NULL,
    fee                   DECIMAL(15, 2)  NOT NULL DEFAULT 0.00,
    transfer_status       ENUM('initiated', 'completed', 'failed', 'reversed') NOT NULL DEFAULT 'initiated',
    failure_reason        VARCHAR(255)    NULL,
    created_at            TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at          TIMESTAMP       NULL,

    CONSTRAINT pk_wallet_transfers PRIMARY KEY (transfer_id),
    CONSTRAINT uq_wallet_transfers_ref UNIQUE (transfer_reference),
    CONSTRAINT uq_wallet_transfers_debit_tx UNIQUE (debit_transaction_id),
    CONSTRAINT uq_wallet_transfers_credit_tx UNIQUE (credit_transaction_id),
    CONSTRAINT fk_transfers_sender_wallet
        FOREIGN KEY (sender_wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_transfers_receiver_wallet
        FOREIGN KEY (receiver_wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_transfers_debit_tx
        FOREIGN KEY (debit_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_transfers_credit_tx
        FOREIGN KEY (credit_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_transfers_positive_amount CHECK (
        amount > 0.00 AND fee >= 0.00
    )
) ENGINE=InnoDB;

-- ============================================================================
-- 8. TRIGGER: trg_transfers_prevent_self_transfer
-- Purpose: Enforces sender_wallet_id <> receiver_wallet_id on wallet_transfers
-- (MySQL 8.0 Error 3823 prohibits CHECK constraints on Foreign Key columns, so
--  a BEFORE INSERT trigger is the canonical MySQL way to enforce this rule).
-- ============================================================================
DELIMITER $$

CREATE TRIGGER trg_transfers_prevent_self_transfer
BEFORE INSERT ON wallet_transfers
FOR EACH ROW
BEGIN
    IF NEW.sender_wallet_id = NEW.receiver_wallet_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Self-transfer error: sender_wallet_id and receiver_wallet_id cannot be identical.';
    END IF;
END$$

DELIMITER ;

