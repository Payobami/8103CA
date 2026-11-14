================================================================================
MIT 8103: ADVANCED DATABASE SYSTEMS — PRACTICAL DATABASE PORTFOLIO
================================================================================

Student Name:          Ayobami Yusuf
Surname:               Yusuf
Firstname:             Ayobami
Student ID:            301799163
Matriculation Number:  2025/A/MIT/0729
Programme:             Master of Information Technology (MIT)
Academic Session:      2026/2027 (First Semester Continuous Assessment)
Course:                MIT 8103 — Advanced Database Systems
Database Technologies: MySQL 8.0 (Relational) & MongoDB 7.0 (NoSQL Document Store)
GitHub Repository:     https://github.com/Payobami/8103CA

================================================================================
1. SELECTED CASE STUDY / ORGANISATION STATEMENT
================================================================================

Organisation Name:
Oval Pay Finances ("Oval Pay")

Nature of Business / System:
Oval Pay Finances is a high-volume financial technology (Fintech) digital wallet,
peer-to-peer (P2P) money transfer, and merchant bill-payment platform. The
system enables retail customers to open KYC-tiered digital wallets, fund
accounts via bank deposits, transfer money instantaneously between wallets or
external bank accounts, and pay utility, telecom, and retail merchants.

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

================================================================================
2. SUMMARY OF THE FIVE PORTFOLIO ACTIVITIES
================================================================================

PORTFOLIO 1: DATABASE DESIGN AND MODELLING (7 MARKS)
- Directory: ./portfolio-1-database-design/
- Designed a 7-table relational schema in MySQL 8.0 (InnoDB) normalised to
  Third Normal Form (3NF) in 01_schema_ddl.sql.
- Eliminated repeating groups (1NF), partial dependencies (2NF), and transitive
  dependencies (3NF) by extracting regulatory tier limits into kyc_tiers
  (customer_id -> kyc_tier_id -> daily_transfer_limit) and merchant commission
  attributes into merchants.
- Enforced domain integrity via CHECK (balance >= 0.00) on wallets, ON DELETE
  RESTRICT foreign keys across all financial ledger tables, and a BEFORE INSERT
  trigger (trg_transfers_prevent_self_transfer) preventing self-transfers.

PORTFOLIO 2: QUERY PROCESSING AND OPTIMISATION (7 MARKS)
- Directory: ./portfolio-2-query-optimisation/
- Populated 1,000 customers, 1,000 wallets, and 50,005 ledger transactions via
  stored procedure sp_seed_benchmark_data() in 01_bulk_benchmark_seeder.sql.
- Profiled 4 analytical queries using live MySQL 8.0 EXPLAIN ANALYZE before and
  after creating Composite and Covering B-Tree indexes:
  * Query 1 (Monthly Wallet Statement): Composite index
    idx_tx_wallet_status_created (wallet_id, status, created_at DESC) eliminated
    filesort and reduced latency from 0.155 ms to 0.051 ms (3.04x faster).
  * Query 2 (AML Outbound Audit): Covering index
    idx_tx_status_type_created_covering converted a 50,005-row Full Table Scan
    (18.00 ms scan / 49.40 ms total) into a 2,721-row Covering Index Range Scan
    (1.49 ms scan / 32.40 ms total — 12.1x faster table scan).
  * Query 3 (Merchant Settlement Summary): Covering index
    idx_tx_merchant_settlement_covering reduced latency from 15.10 ms to 4.51 ms
    (3.35x faster).
  * Query 4 (Latest Wallet Transaction): Rewriting a correlated subquery (2,505
    loops) into ROW_NUMBER() OVER (PARTITION BY wallet_id ORDER BY created_at
    DESC) reduced execution time from 104.00 ms to 5.44 ms (19.1x faster).

PORTFOLIO 3: TRANSACTIONS AND CONCURRENCY (7 MARKS)
- Directory: ./portfolio-3-transactions-concurrency/
- Implemented atomic stored procedure sp_execute_p2p_transfer and multi-session
  concurrency control scripts in MySQL 8.0:
  * Demonstrated atomic COMMIT (50,000 NGN transfer from Wallet #1 to Wallet #2),
    automatic ROLLBACK on insufficient funds (Wallet #4 attempting 48,000 NGN
    transfer on a 42,000 NGN balance), and partial rollback via SAVEPOINT.
  * Prevented Double-Spend / Lost Update race conditions across concurrent
    withdrawal sessions using pessimistic row locking (SELECT ... FOR UPDATE),
    verified via performance_schema.data_locks.
  * Prevented circular-wait deadlocks by locking wallets in deterministic
    ascending wallet_id order.

PORTFOLIO 4: NOSQL AND ADVANCED DATA MODELS (7 MARKS)
- Directory: ./portfolio-4-nosql/
- Implemented ovalpay_nosql in MongoDB 7.0 for fraud_telemetry_events and
  gateway_webhook_logs (01_mongodb_setup_and_seed.mongodb.js &
  02_mongodb_queries_and_aggregations.mongodb.js).
- Enforced $jsonSchema validation on core correlation keys while supporting
  polymorphic channel payloads (iOS/Android biometrics, *810# USSD cell-tower
  metadata, Web/Tor proxy flags, and NIBSS/Paystack raw webhook JSON).
- Created Multikey indexes on embedded triggered_rules[] arrays and a 90-day TTL
  expiration index (expireAfterSeconds: 7776000) for automated log purging.

PORTFOLIO 5: DISTRIBUTED AND CLOUD DATABASE EXERCISE (6 MARKS)
- Directory: ./portfolio-5-distributed-cloud/
- Configured a multi-container MySQL 8.0 Primary-Replica GTID cluster + MongoDB
  telemetry node in docker-compose.replication.yml and Laravel read/write
  splitting with 'sticky' => true in laravel_read_write_database_config.php.
- Implemented Horizontal Range Partitioning (PARTITION BY RANGE) on
  transactions_partitioned across monthly partitions (p_2026_07 to p_2026_11)
  and verified Partition Pruning via EXPLAIN.
- Applied CAP Theorem analysis: classified wallet balances/transfers as CP
  (Strict Consistency + Partition Tolerance) to prevent split-brain double
  spending, and telemetry/replica analytics as AP / Eventual Consistency.

================================================================================
3. INDIVIDUAL TECHNICAL REFLECTION
================================================================================

- Design Choices: Adopting a Polyglot Persistence architecture allowed MySQL 8.0
  to enforce strict ACID row locking and 3NF referential integrity for financial
  balances while leveraging MongoDB 7.0 for schema-flexible fraud telemetry and
  gateway webhooks. Retaining balance_before and balance_after on transactions
  guaranteed audit immutability without violating 3NF.
- Challenges Faced & Resolved:
  1. MySQL Error 3823 on Foreign Key Check Constraints: MySQL 8.0 prohibited
     using sender_wallet_id and receiver_wallet_id inside a CHECK constraint
     because they participate in foreign keys. Resolved by creating the BEFORE
     INSERT trigger trg_transfers_prevent_self_transfer using SIGNAL SQLSTATE
     '45000'.
  2. InnoDB Partitioning Key Rules: Partitioning transactions_partitioned by
     created_at required including created_at in every PRIMARY and UNIQUE key
     ((transaction_id, created_at) and (reference, created_at)).
  3. Correlated Subquery Bottleneck: EXPLAIN ANALYZE exposed 2,505 dependent
     loops (104.00 ms); rewriting with ROW_NUMBER() OVER (...) and a composite
     index cut execution time to 5.44 ms (19.1x faster).

================================================================================
4. REFERENCES & AI USE DECLARATION
================================================================================

References:
1. Silberschatz, A., Korth, H. F., & Sudarshan, S. (2019). Database System
   Concepts (7th ed.). McGraw-Hill Education.
2. Kleppmann, M. (2017). Designing Data-Intensive Applications. O'Reilly Media.
3. Oracle Corporation. (2026). MySQL 8.0 Reference Manual: InnoDB Locking,
   Optimization, and Partitioning. https://dev.mysql.com/doc/refman/8.0/en/
4. MongoDB, Inc. (2026). MongoDB v7.0 Manual: Schema Validation, Aggregation
   Pipeline, and TTL Indexes. https://www.mongodb.com/docs/manual/

AI Use Declaration (Section 11 Compliance):
- AI Tool Used: Google Antigravity AI Assistant.
- What the AI Tool Was Used For: Assisting with SQL benchmark seeder
  scaffolding, Mermaid/SVG diagram formatting, and documentation structuring.
- How Output Was Reviewed, Tested, and Verified: All SQL DDL scripts, triggers,
  composite indexes, stored procedures, and partitioning scripts were executed
  and verified against a live local MySQL 8.0 server (ovalpay_db), with real
  EXPLAIN ANALYZE outputs captured and reviewed.

================================================================================
5. SUBMISSION FOLDER CONTENTS (Surname_Firstname_StudentID Convention)
================================================================================

Folder Name: Yusuf_Ayobami_301799163
├── portfolio-1-database-design/          (ERD, Relational Schema, Constraints & 3NF Normalisation)
├── portfolio-2-query-optimisation/       (Complex SQL, EXPLAIN ANALYZE Plans & Speed Benchmark Graph)
├── portfolio-3-transactions-concurrency/ (ACID Transactions, Rollbacks, Locking & Concurrency Control)
├── portfolio-4-nosql/                    (MongoDB Document Model, Scripts & Suitability Analysis)
├── portfolio-5-distributed-cloud/        (Replication, Sharding, CAP Theorem & Cloud/Docker Setup)
├── Yusuf_Ayobami_301799163_README.txt
├── Yusuf_Ayobami_301799163_Portfolio_Report.pdf
├── Yusuf_Ayobami_301799163_ER_Diagram.png
└── Yusuf_Ayobami_301799163_ER_Diagram.pdf
================================================================================

