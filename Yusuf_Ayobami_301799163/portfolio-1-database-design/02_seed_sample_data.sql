-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Portfolio 1: Sample Seed Data & Schema Verification Script
-- Case Study: Oval Pay Finances
-- ============================================================================

USE ovalpay_db;

-- 1. Seed KYC Tiers
INSERT INTO kyc_tiers (kyc_tier_id, tier_code, tier_name, single_transfer_limit, daily_transfer_limit, max_wallet_balance, requires_bvn, requires_address_ver)
VALUES
    (1, 'TIER_1', 'Basic KYC (Phone & NIN)',       50000.00,   300000.00,    300000.00, FALSE, FALSE),
    (2, 'TIER_2', 'Standard KYC (BVN Verified)',  200000.00,  1000000.00,   5000000.00, TRUE,  FALSE),
    (3, 'TIER_3', 'Enhanced KYC (Full Document)', 5000000.00, 25000000.00, 999999999.99, TRUE,  TRUE);

-- 2. Seed Customers
INSERT INTO customers (customer_id, kyc_tier_id, first_name, last_name, email, phone_number, bvn_number, date_of_birth, account_status)
VALUES
    (1, 3, 'Adebayo',  'Ogunlesi', 'adebayo.ogunlesi@ovalpay.ng', '+2348031000001', '22100000001', '1990-04-15', 'active'),
    (2, 2, 'Chidinma', 'Okafor',   'chidinma.okafor@ovalpay.ng',  '+2348031000002', '22100000002', '1995-08-22', 'active'),
    (3, 2, 'Ibrahim',  'Danladi',  'ibrahim.danladi@ovalpay.ng',  '+2348031000003', '22100000003', '1988-11-30', 'active'),
    (4, 1, 'Zainab',   'Bello',    'zainab.bello@ovalpay.ng',     '+2348031000004', NULL,          '2000-02-10', 'active'),
    (5, 2, 'Tunde',    'Bakare',   'tunde.bakare@ovalpay.ng',     '+2348031000005', '22100000005', '1992-07-04', 'suspended');

-- 3. Seed Wallets
INSERT INTO wallets (wallet_id, customer_id, wallet_number, currency, balance, locked_balance, wallet_status, lock_version)
VALUES
    (1, 1, '3010000001', 'NGN', 1450000.00, 0.00,    'active', 3),
    (2, 2, '3010000002', 'NGN',  320500.00, 5000.00, 'active', 2),
    (3, 3, '3010000003', 'NGN',  875000.00, 0.00,    'active', 1),
    (4, 4, '3010000004', 'NGN',   42000.00, 0.00,    'active', 1),
    (5, 5, '3010000005', 'NGN',   15000.00, 15000.00,'frozen', 1);

-- 4. Seed Merchants
INSERT INTO merchants (merchant_id, merchant_code, business_name, category, settlement_bank_code, settlement_account_number, commission_rate, status)
VALUES
    (1, 'MCH_IKEDC',   'Ikeja Electric Disco',        'utilities', '058', '0112233445', 0.0100, 'active'),
    (2, 'MCH_MTN_NG',  'MTN Nigeria VTU & Data',      'telecoms',  '011', '2023344556', 0.0200, 'active'),
    (3, 'MCH_SHOPRITE','Shoprite Retail Superstores', 'retail',    '044', '0667788990', 0.0150, 'active');

-- 5. Seed Beneficiaries
INSERT INTO beneficiaries (beneficiary_id, customer_id, bank_code, bank_name, account_number, account_name, is_favourite)
VALUES
    (1, 1, '058', 'Guaranty Trust Bank', '0123456789', 'CHIDINMA OKAFOR', TRUE),
    (2, 1, '044', 'Access Bank',         '0765432109', 'ADEBAYO OGUNLESI SAVINGS', TRUE),
    (3, 2, '033', 'United Bank for Africa', '2099887766', 'IBRAHIM DANLADI', FALSE);

-- 6. Seed Transactions
INSERT INTO transactions (transaction_id, reference, wallet_id, merchant_id, transaction_type, amount, fee, balance_before, balance_after, status, channel, narration, created_at)
VALUES
    (1, 'OP-DEP-20261001-0001', 1, NULL, 'deposit',          1500000.00,  0.00,       0.00, 1500000.00, 'completed', 'web',        'Initial NIP bank deposit',          '2026-10-01 09:00:00'),
    (2, 'OP-TRF-20261002-0002', 1, NULL, 'transfer_out',       35000.00, 25.00, 1500000.00, 1464975.00, 'completed', 'mobile_app', 'P2P Transfer to Chidinma Okafor',   '2026-10-02 14:15:00'),
    (3, 'OP-TRF-20261002-0003', 2, NULL, 'transfer_in',        35000.00,  0.00,  285500.00,  320500.00, 'completed', 'mobile_app', 'P2P Transfer from Adebayo Ogunlesi','2026-10-02 14:15:00'),
    (4, 'OP-MCH-20261003-0004', 1, 1,    'merchant_payment',   14975.00,  0.00, 1464975.00, 1450000.00, 'completed', 'mobile_app', 'Prepaid Meter Token - IKEDC',       '2026-10-03 18:40:00'),
    (5, 'OP-MCH-20261004-0005', 4, 2,    'merchant_payment',    3000.00,  0.00,   45000.00,   42000.00, 'completed', 'ussd',       'MTN 5GB Monthly Data Plan',         '2026-10-04 11:05:00');

-- 7. Seed Wallet Transfers (Linking Transaction #2 and #3)
INSERT INTO wallet_transfers (transfer_id, transfer_reference, sender_wallet_id, receiver_wallet_id, debit_transaction_id, credit_transaction_id, amount, fee, transfer_status, completed_at)
VALUES
    (1, 'OP-P2P-20261002-9001', 1, 2, 2, 3, 35000.00, 25.00, 'completed', '2026-10-02 14:15:01');

-- ============================================================================
-- VERIFICATION QUERY: Customer Wallets & KYC Tier Limits
-- ============================================================================
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    k.tier_name,
    k.daily_transfer_limit,
    w.wallet_number,
    w.currency,
    w.balance,
    w.wallet_status
FROM customers c
INNER JOIN kyc_tiers k ON c.kyc_tier_id = k.kyc_tier_id
INNER JOIN wallets w   ON c.customer_id = w.customer_id
ORDER BY c.customer_id;

