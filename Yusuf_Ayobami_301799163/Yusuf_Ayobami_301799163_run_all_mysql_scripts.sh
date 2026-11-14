#!/usr/bin/env bash
# ============================================================================
# MIT 8103: Advanced Database Systems
# Automated MySQL Execution & Evidence Capture Script — Oval Pay Finances
# Student: Ayobami Yusuf (301799163 | 2025/A/MIT/0729)
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MYSQL_BIN="/usr/local/mysql/bin/mysql"
if ! command -v "$MYSQL_BIN" &>/dev/null; then
    MYSQL_BIN="mysql"
fi

if [ -n "$1" ]; then
    export MYSQL_PWD="$1"
elif [ -z "$MYSQL_PWD" ]; then
    read -r -s -p "Enter your local MySQL root password: " MYSQL_PWD_INPUT
    echo ""
    export MYSQL_PWD="$MYSQL_PWD_INPUT"
fi

P1_DIR="Yusuf_Ayobami_301799163_Portfolio_1_database_design"
P2_DIR="Yusuf_Ayobami_301799163_Portfolio_2_query_optimisation"
P3_DIR="Yusuf_Ayobami_301799163_Portfolio_3_transactions_concurrency"
P5_DIR="Yusuf_Ayobami_301799163_Portfolio_5_distributed_cloud"

echo "[1/5] Running Portfolio 1: Schema DDL & Initial Seed Data..."
"$MYSQL_BIN" -u root -t < "$P1_DIR/01_schema_ddl.sql"
"$MYSQL_BIN" -u root -t ovalpay_db < "$P1_DIR/02_seed_sample_data.sql" > "$P1_DIR/screenshots/p1_mysql_verification_output.txt"
cat "$P1_DIR/screenshots/p1_mysql_verification_output.txt"

echo ""
echo "[2/5] Running Portfolio 2: 50,000-Row Benchmark Seeder..."
"$MYSQL_BIN" -u root -t ovalpay_db < "$P2_DIR/01_bulk_benchmark_seeder.sql" > "$P2_DIR/screenshots/p2_seeder_output.txt"
cat "$P2_DIR/screenshots/p2_seeder_output.txt"

echo ""
echo "[3/5] Running Portfolio 2: EXPLAIN ANALYZE BEFORE & AFTER Indexing..."
"$MYSQL_BIN" -u root -t ovalpay_db < "$P2_DIR/02_analytical_queries_before_indexing.sql" > "$P2_DIR/screenshots/p2_explain_before_indexing.txt"
"$MYSQL_BIN" -u root -t ovalpay_db < "$P2_DIR/03_indexes_and_optimisation.sql" > "$P2_DIR/screenshots/p2_explain_after_indexing.txt"
echo "Saved EXPLAIN ANALYZE outputs to $P2_DIR/screenshots/"

echo ""
echo "[4/5] Running Portfolio 3: ACID P2P Transfers (COMMIT, ROLLBACK & SAVEPOINT)..."
"$MYSQL_BIN" -u root -t ovalpay_db < "$P3_DIR/01_atomic_p2p_transfer_commit_rollback.sql" > "$P3_DIR/screenshots/p3_transactions_output.txt"
cat "$P3_DIR/screenshots/p3_transactions_output.txt"

echo ""
echo "[5/5] Running Portfolio 5: Horizontal Range Partitioning & Partition Pruning..."
"$MYSQL_BIN" -u root -t ovalpay_db < "$P5_DIR/01_partitioning_and_sharding_strategy.sql" > "$P5_DIR/screenshots/p5_partitioning_output.txt"
cat "$P5_DIR/screenshots/p5_partitioning_output.txt"

unset MYSQL_PWD
echo ""
echo "============================================================================"
echo "  ALL SQL SCRIPTS EXECUTED SUCCESSFULLY! Outputs saved in screenshots/"
echo "============================================================================"
