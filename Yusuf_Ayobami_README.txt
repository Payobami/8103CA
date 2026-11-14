================================================================================
MIT 8103: ADVANCED DATABASE SYSTEMS — PRACTICAL DATABASE PORTFOLIO
================================================================================

Student Name:          Ayobami Yusuf
Matriculation Number:  2025/A/MIT/0729
Student ID:            301799163
Programme:             Master of Information Technology (MIT)
Academic Session:      2026/2027 (First Semester Continuous Assessment)
Course:                MIT 8103 — Advanced Database Systems
Database Technologies: MySQL 8.0 (Relational) & MongoDB 7.0 (NoSQL Document Store)
GitHub Repository:     https://github.com/Payobami/8103CA

--------------------------------------------------------------------------------
1. SELECTED CASE STUDY / ORGANISATION STATEMENT
--------------------------------------------------------------------------------

Organisation Name:
Oval Pay Finances ("Oval Pay")

Nature of Business / System:
Oval Pay Finances is a digital wallet, peer-to-peer (P2P) money transfer, and
merchant payment platform operating in a high-volume financial technology
(Fintech) environment. The platform enables retail customers to open tiered
digital wallets, fund accounts via bank deposits, transfer money instantaneously
between wallets or external bank accounts, and pay registered merchants and
utility billers.

Users of the Database:
1. Retail Customers: Open digital wallets, complete KYC verification, deposit
   funds, save beneficiaries, transfer money, and pay merchants.
2. Merchants / Billers: Receive customer payments and automated settlement
   payouts into their designated settlement accounts.
3. Compliance & Fraud Analysts: Monitor KYC tier limits, audit suspicious
   transactions, and review real-time device telemetry and fraud logs.
4. Finance & Operations Officers: Reconcile wallet ledgers, process failed
   transaction reversals, and audit platform fee revenue.
5. Core Banking API & Background Workers (Laravel Queue/Services): Execute
   atomic wallet debits/credits, enforce concurrency locks, and replicate
   read traffic.

Major Data Stored:
- Relational Data (MySQL 8.0 — ovalpay_db):
  * kyc_tiers        : Regulatory KYC levels (Tier 1, Tier 2, Tier 3) defining
                       maximum account balances and daily transfer limits.
  * customers        : Verified customer profiles, contact information,
                       BVN/identity numbers, and KYC status.
  * wallets          : Multi-currency digital accounts storing available
                       balances, locked balances, account numbers, and
                       optimistic lock versions.
  * merchants        : Registered business profiles, merchant codes,
                       categories, and commission rates.
  * beneficiaries    : Saved recipient bank accounts linked to customers.
  * transactions     : Immutable financial ledger recording every credit,
                       debit, fee, balance_before, and balance_after.
  * wallet_transfers : Atomic peer-to-peer transfer records linking sender and
                       receiver wallets with their corresponding debit and
                       credit ledger entries.

- NoSQL Data (MongoDB 7.0 — ovalpay_nosql):
  * fraud_telemetry_events & gateway_webhook_logs: High-velocity,
    schema-flexible event logs storing device fingerprints, IP geolocation,
    3DS/biometric challenges, and raw third-party payment gateway webhook
    payloads.

Key Operations Supported:
- Opening customer wallets and enforcing regulatory KYC tier balance and
  transfer limits.
- Atomic peer-to-peer (P2P) fund transfers with pessimistic locking
  (SELECT ... FOR UPDATE) and automatic rollback on insufficient funds or
  limit breaches.
- Reversing failed transactions while maintaining an immutable audit trail
  (balance_before / balance_after).
- High-speed analytical querying for customer account statements, merchant
  settlement summaries, and daily transaction volume reports.
- Capturing and querying semi-structured fraud telemetry and gateway webhook
  payloads in MongoDB.
- Horizontal scaling via Primary-Replica read/write splitting and table
  partitioning/sharding for high availability and strict financial consistency.

--------------------------------------------------------------------------------
2. REPOSITORY STRUCTURE & PORTFOLIO NAVIGATION
--------------------------------------------------------------------------------

Repository URL: https://github.com/Payobami/8103CA

8103CA/
├── portfolio-1-database-design/          (ERD, Relational Schema, Constraints & 3NF Normalisation)
├── portfolio-2-query-optimisation/       (Complex SQL, EXPLAIN ANALYZE Plans & Indexing Benchmarks)
├── portfolio-3-transactions-concurrency/ (ACID Transactions, Rollbacks, Locking & Concurrency Control)
├── portfolio-4-nosql/                    (MongoDB Document Model, Scripts & Suitability Analysis)
├── portfolio-5-distributed-cloud/        (Replication, Sharding, CAP Theorem & Cloud/Docker Setup)
├── LMS_Submission_Document_Oval_Pay_Finances.pdf
└── README.md                             (Portfolio Overview & Case Study Definition)

Portfolio Components Summary:
- Portfolio 1 : Database Design and Modelling             [./portfolio-1-database-design/]          — Completed
- Portfolio 2 : Query Processing and Optimisation         [./portfolio-2-query-optimisation/]       — Completed
- Portfolio 3 : Transactions and Concurrency              [./portfolio-3-transactions-concurrency/] — Completed
- Portfolio 4 : NoSQL and Advanced Data Models            [./portfolio-4-nosql/]                    — Completed
- Portfolio 5 : Distributed and Cloud Database Exercise   [./portfolio-5-distributed-cloud/]        — Completed
- LMS Report  : Final Portfolio Summary & Reflection      [./LMS_Submission_Document_Oval_Pay_Finances.pdf] — Completed
================================================================================

