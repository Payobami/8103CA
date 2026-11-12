#!/usr/bin/env bash
# ============================================================================
# MIT 8103: Advanced Database Systems
# Automated MySQL Execution & Evidence Capture Script — Oval Pay Finances
# ============================================================================

set -e

MYSQL_BIN="/usr/local/mysql/bin/mysql"
if ! command -v "$MYSQL_BIN" &>/dev/null; then
    MYSQL_BIN="mysql"
fi

echo "============================================================================"
echo "  Oval Pay Finances (ovalpay_db) — Portfolio SQL Runner & Evidence Generator"
echo "============================================================================"
read -r -s -p "Enter your local MySQL root password (press Enter if empty): " MYSQL_PWD_INPUT
echo ""

export MYSQL_PWD="$MYSQL_PWD_INPUT"

echo "[1/5] Running Portfolio 1: Schema DDL & Initial Seed Data..."
"$MYSQL_BIN" -u root -t < "portfolio-1-database-design/01_schema_ddl.sql"
"$MYSQL_BIN" -u root -t ovalpay_db < "portfolio-1-database-design/02_seed_sample_data.sql" > "portfolio-1-database-design/screenshots/p1_mysql_verification_output.txt"
cat "portfolio-1-database-design/screenshots/p1_mysql_verification_output.txt"

echo ""
echo "[2/5] Running Portfolio 2: 50,000-Row Benchmark Seeder (takes ~2-4 seconds)..."
"$MYSQL_BIN" -u root -t ovalpay_db < "portfolio-2-query-optimisation/01_bulk_benchmark_seeder.sql" > "portfolio-2-query-optimisation/screenshots/p2_seeder_output.txt"
cat "portfolio-2-query-optimisation/screenshots/p2_seeder_output.txt"

echo ""
echo "[3/5] Running Portfolio 2: EXPLAIN ANALYZE BEFORE & AFTER Indexing..."
"$MYSQL_BIN" -u root -t ovalpay_db < "portfolio-2-query-optimisation/02_analytical_queries_before_indexing.sql" > "portfolio-2-query-optimisation/screenshots/p2_explain_before_indexing.txt"
"$MYSQL_BIN" -u root -t ovalpay_db < "portfolio-2-query-optimisation/03_indexes_and_optimisation.sql" > "portfolio-2-query-optimisation/screenshots/p2_explain_after_indexing.txt"
echo "Saved EXPLAIN ANALYZE outputs to portfolio-2-query-optimisation/screenshots/"

echo ""
echo "[4/5] Running Portfolio 3: ACID P2P Transfers (COMMIT, ROLLBACK & SAVEPOINT)..."
"$MYSQL_BIN" -u root -t ovalpay_db < "portfolio-3-transactions-concurrency/01_atomic_p2p_transfer_commit_rollback.sql" > "portfolio-3-transactions-concurrency/screenshots/p3_transactions_output.txt"
cat "portfolio-3-transactions-concurrency/screenshots/p3_transactions_output.txt"

echo ""
echo "[5/5] Running Portfolio 5: Horizontal Range Partitioning & Partition Pruning..."
"$MYSQL_BIN" -u root -t ovalpay_db < "portfolio-5-distributed-cloud/01_partitioning_and_sharding_strategy.sql" > "portfolio-5-distributed-cloud/screenshots/p5_partitioning_output.txt"
cat "portfolio-5-distributed-cloud/screenshots/p5_partitioning_output.txt"

unset MYSQL_PWD
echo ""
echo "============================================================================"
echo "  ALL SQL SCRIPTS EXECUTED SUCCESSFULLY! Outputs saved in screenshots/"
echo "============================================================================"
