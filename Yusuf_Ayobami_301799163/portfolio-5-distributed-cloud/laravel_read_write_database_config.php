<?php

/**
 * MIT 8103: Advanced Database Systems
 * Portfolio 5: Distributed and Cloud Database Exercise
 * Case Study: Oval Pay Finances
 * Purpose: Demonstrates how the Laravel backend configures Primary-Replica
 *          Read/Write splitting with sticky sessions to prevent stale balance reads.
 */

return [
    'default' => env('DB_CONNECTION', 'mysql'),

    'connections' => [

        // ---------------------------------------------------------------------
        // 1. Primary-Replica MySQL Cluster Connection (Core Financial Ledger)
        // ---------------------------------------------------------------------
        'mysql' => [
            'driver' => 'mysql',

            // Read traffic (Account Statements, Merchant Reports, Compliance Queries)
            // is load-balanced across Read-Only Replica nodes.
            'read' => [
                'host' => [
                    env('DB_REPLICA_1_HOST', '127.0.0.1'),
                    env('DB_REPLICA_2_HOST', '127.0.0.1'),
                ],
                'port' => env('DB_REPLICA_PORT', '3307'),
            ],

            // Write traffic (Wallet Debits/Credits, Transfers, SELECT ... FOR UPDATE)
            // is strictly routed to the Primary node.
            'write' => [
                'host' => [
                    env('DB_PRIMARY_HOST', '127.0.0.1'),
                ],
                'port' => env('DB_PRIMARY_PORT', '3306'),
            ],

            // CRITICAL FOR FINTECH CONSISTENCY:
            // When 'sticky' is true, if a wallet transfer (write) occurs during
            // the current HTTP request cycle, all subsequent reads in that same
            // request read from the Primary node so the user never sees a stale
            // pre-transfer balance due to asynchronous replication lag!
            'sticky' => true,

            'database' => env('DB_DATABASE', 'ovalpay_db'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', 'ovalpay_root_secret'),
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_unicode_ci',
            'prefix' => '',
            'strict' => true,
            'engine' => 'InnoDB',
        ],

        // ---------------------------------------------------------------------
        // 2. MongoDB Connection (Portfolio 4: Fraud Telemetry & Webhook Logs)
        // ---------------------------------------------------------------------
        'mongodb' => [
            'driver' => 'mongodb',
            'host' => env('MONGO_DB_HOST', '127.0.0.1'),
            'port' => env('MONGO_DB_PORT', 27017),
            'database' => env('MONGO_DB_DATABASE', 'ovalpay_nosql'),
        ],
    ],
];

