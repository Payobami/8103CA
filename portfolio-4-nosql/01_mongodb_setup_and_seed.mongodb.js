// ============================================================================
// MIT 8103: Advanced Database Systems
// Portfolio 4: NoSQL and Advanced Data Models
// File: 01_mongodb_setup_and_seed.mongodb.js
// Case Study: Oval Pay Finances (Digital Wallet & Payment Platform)
// Target DBMS: MongoDB 7.0+ (mongosh script)
// Purpose: Implements a Document Store for Oval Pay's Real-Time Fraud
//          Telemetry Events and Polymorphic Payment Gateway Webhook Logs.
// ============================================================================

use("ovalpay_nosql");

// Drop existing collections for clean re-runs
db.fraud_telemetry_events.drop();
db.gateway_webhook_logs.drop();

// ============================================================================
// 1. CREATE COLLECTION WITH JSON SCHEMA VALIDATION
// Enforces required core correlation IDs (customer_id, wallet_id, tx_reference)
// while allowing schema-flexible nested telemetry, device_context, and risk_signals.
// ============================================================================
db.createCollection("fraud_telemetry_events", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["event_id", "customer_id", "wallet_id", "tx_reference", "channel", "risk_assessment", "created_at"],
            properties: {
                event_id:     { bsonType: "string", description: "Unique telemetry event UUID" },
                customer_id:  { bsonType: "int",    description: "References MySQL customers.customer_id" },
                wallet_id:    { bsonType: "int",    description: "References MySQL wallets.wallet_id" },
                tx_reference: { bsonType: "string", description: "References MySQL transactions.reference" },
                channel:      { enum: ["mobile_app", "ussd", "web", "pos", "api"] },
                risk_assessment: {
                    bsonType: "object",
                    required: ["risk_score", "decision"],
                    properties: {
                        risk_score: { bsonType: "int", minimum: 0, maximum: 100 },
                        decision:   { enum: ["ALLOW", "CHALLENGE_2FA", "BLOCK_AND_FREEZE"] }
                    }
                },
                created_at: { bsonType: "date" }
            }
        }
    }
});

// ============================================================================
// 2. CREATE INDEXES (Compound, Multikey Array, and TTL Expiration Index)
// ============================================================================

// Fast lookup by customer + descending timestamp
db.fraud_telemetry_events.createIndex(
    { customer_id: 1, created_at: -1 },
    { name: "idx_customer_recent_events" }
);

// Fast lookup by risk decision and score for Fraud Operations Dashboard
db.fraud_telemetry_events.createIndex(
    { "risk_assessment.decision": 1, "risk_assessment.risk_score": -1 },
    { name: "idx_risk_decision_score" }
);

// Multikey index on nested array of triggered fraud rules
db.fraud_telemetry_events.createIndex(
    { "risk_assessment.triggered_rules.rule_code": 1 },
    { name: "idx_multikey_triggered_rules" }
);

// TTL Index on gateway_webhook_logs to automatically purge raw logs after 90 days
db.gateway_webhook_logs.createIndex(
    { received_at: 1 },
    { expireAfterSeconds: 7776000, name: "idx_ttl_90_days" }
);

// ============================================================================
// 3. SEED POLYMORPHIC FRAUD TELEMETRY DOCUMENTS
// Notice how mobile_app, ussd, and pos channels store completely different
// nested attributes without requiring nullable SQL columns or schema migrations!
// ============================================================================
db.fraud_telemetry_events.insertMany([
    {
        event_id: "EVT-20261002-0001",
        customer_id: 1,
        wallet_id: 1,
        tx_reference: "OP-TRF-20261002-0002",
        channel: "mobile_app",
        amount_ngn: 35000.00,
        device_context: {
            os: "iOS 18.1",
            device_model: "iPhone 15 Pro",
            device_fingerprint: "dfp_9981ab72c10e44",
            app_version: "4.12.0",
            biometric_verified: true,
            battery_level: 0.78,
            is_jailbroken: false
        },
        network_geo: {
            ip_address: "102.89.43.112",
            isp: "MTN Nigeria Communications",
            city: "Lagos",
            country_code: "NG",
            coordinates: { lat: 6.5244, lng: 3.3792 }
        },
        risk_assessment: {
            risk_score: 12,
            decision: "ALLOW",
            evaluation_time_ms: 8,
            triggered_rules: [
                { rule_code: "KNOWN_DEVICE_MATCH", weight: -15, description: "Trusted primary iPhone device" },
                { rule_code: "KNOWN_BENEFICIARY",  weight: -10, description: "Prior successful transfer to Chidinma Okafor" }
            ]
        },
        created_at: ISODate("2026-10-02T14:15:00Z")
    },
    {
        event_id: "EVT-20261004-0002",
        customer_id: 4,
        wallet_id: 4,
        tx_reference: "OP-MCH-20261004-0005",
        channel: "ussd",
        amount_ngn: 3000.00,
        // USSD session has telecom tower metadata instead of iOS/Android app telemetry
        ussd_session_context: {
            session_id: "USSD_MTN_88392011",
            shortcode_dialed: "*810*2*3000#",
            msisdn: "+2348031000004",
            cell_tower_id: "LAC-4021-CID-9912",
            sim_swap_detected_last_7d: false,
            pin_retry_count: 0
        },
        risk_assessment: {
            risk_score: 18,
            decision: "ALLOW",
            evaluation_time_ms: 5,
            triggered_rules: [
                { rule_code: "LOW_VALUE_AIRTIME", weight: 5, description: "Routine USSD data purchase under 5,000 NGN" }
            ]
        },
        created_at: ISODate("2026-10-04T11:05:00Z")
    },
    {
        event_id: "EVT-20261005-0003",
        customer_id: 5,
        wallet_id: 5,
        tx_reference: "OP-TRF-20261005-9999",
        channel: "web",
        amount_ngn: 480000.00,
        device_context: {
            os: "Linux x86_64",
            browser: "HeadlessChrome/129.0",
            device_fingerprint: "dfp_unknown_tor_8821",
            vpn_or_proxy_detected: true,
            new_device_login: true
        },
        network_geo: {
            ip_address: "185.220.101.45",
            isp: "Tor Exit Node Network",
            city: "Frankfurt",
            country_code: "DE",
            impossible_travel_detected: true,
            minutes_since_last_lagos_login: 9
        },
        risk_assessment: {
            risk_score: 94,
            decision: "BLOCK_AND_FREEZE",
            evaluation_time_ms: 14,
            triggered_rules: [
                { rule_code: "IMPOSSIBLE_TRAVEL",  weight: 45, description: "Login from Germany 9 mins after Lagos session" },
                { rule_code: "TOR_PROXY_DETECTED", weight: 30, description: "Request originated from anonymizing proxy" },
                { rule_code: "NEW_DEVICE_HIGH_TX", weight: 25, description: "Unrecognized device attempting > 250k NGN transfer" }
            ]
        },
        created_at: ISODate("2026-10-05T02:18:30Z")
    },
    {
        event_id: "EVT-20261006-0004",
        customer_id: 2,
        wallet_id: 2,
        tx_reference: "OP-TRF-20261006-0104",
        channel: "mobile_app",
        amount_ngn: 195000.00,
        device_context: {
            os: "Android 15",
            device_model: "Samsung Galaxy S24",
            device_fingerprint: "dfp_7712ca90b31f11",
            biometric_verified: false,
            is_rooted: false
        },
        network_geo: {
            ip_address: "197.210.54.88",
            isp: "Airtel Networks Limited",
            city: "Abuja",
            country_code: "NG"
        },
        risk_assessment: {
            risk_score: 65,
            decision: "CHALLENGE_2FA",
            evaluation_time_ms: 11,
            triggered_rules: [
                { rule_code: "NEAR_SINGLE_TIER_LIMIT", weight: 35, description: "Transfer is 97.5% of Tier 2 single limit (200k)" },
                { rule_code: "FIRST_TIME_RECIPIENT",   weight: 30, description: "First transfer to newly added external account" }
            ]
        },
        created_at: ISODate("2026-10-06T19:42:10Z")
    }
]);

// ============================================================================
// 4. SEED POLYMORPHIC PAYMENT GATEWAY WEBHOOK LOGS
// Stores raw webhook payloads from NIBSS NIP and Paystack without schema rigidity.
// ============================================================================
db.gateway_webhook_logs.insertMany([
    {
        webhook_id: "WHK-NIBSS-20261001-001",
        provider: "NIBSS_NIP",
        event_type: "NIP_INWARD_CREDIT_NOTIFICATION",
        tx_reference: "OP-DEP-20261001-0001",
        http_headers: {
            "x-nibss-signature": "sha256=8f992a11bc7e0019283a",
            "content-type": "application/json"
        },
        raw_payload: {
            sessionID: "000013261001090000112233445566",
            originatorAccountName: "ADEBAYO OGUNLESI",
            originatorBankCode: "058",
            beneficiaryAccountNumber: "3010000001",
            amount: "1500000.00",
            responseCode: "00"
        },
        processing_status: "PROCESSED",
        received_at: ISODate("2026-10-01T09:00:00Z")
    },
    {
        webhook_id: "WHK-PAYSTACK-20261003-002",
        provider: "PAYSTACK_BILLER_SWITCH",
        event_type: "billpayment.success",
        tx_reference: "OP-MCH-20261003-0004",
        http_headers: {
            "x-paystack-signature": "5c11a892e40192b8811",
            "content-type": "application/json"
        },
        raw_payload: {
            event: "billpayment.success",
            data: {
                id: 99182736,
                domain: "live",
                meter_number: "45001928371",
                token_generated: "4819-2039-1182-9940-1123",
                units_kwh: "68.4",
                disco: "IKEDC_PREPAID",
                amount_kobo: 1497500
            }
        },
        processing_status: "PROCESSED",
        received_at: ISODate("2026-10-03T18:40:02Z")
    }
]);
