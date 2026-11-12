// ============================================================================
// MIT 8103: Advanced Database Systems
// Portfolio 4: NoSQL and Advanced Data Models
// File: 02_mongodb_queries_and_aggregations.mongodb.js
// Case Study: Oval Pay Finances
// Purpose: Demonstrates MongoDB document queries, nested dot-notation filters,
//          array element matching, and multi-stage Aggregation Pipelines.
// ============================================================================

use("ovalpay_nosql");

// ============================================================================
// QUERY 1: Find High-Risk Telemetry Events Requiring Action (Risk Score >= 60)
// Uses idx_risk_decision_score index and projects nested fields cleanly.
// ============================================================================
print("--- QUERY 1: High-Risk Events (Score >= 60) ---");
db.fraud_telemetry_events.find(
    {
        "risk_assessment.risk_score": { $gte: 60 },
        "risk_assessment.decision": { $in: ["CHALLENGE_2FA", "BLOCK_AND_FREEZE"] }
    },
    {
        _id: 0,
        event_id: 1,
        customer_id: 1,
        tx_reference: 1,
        channel: 1,
        amount_ngn: 1,
        "risk_assessment.risk_score": 1,
        "risk_assessment.decision": 1,
        "network_geo.country_code": 1
    }
).sort({ "risk_assessment.risk_score": -1 }).toArray();

// ============================================================================
// QUERY 2: Multikey Array Query — Find Events Triggering 'IMPOSSIBLE_TRAVEL'
// Queries inside the nested risk_assessment.triggered_rules array.
// ============================================================================
print("--- QUERY 2: Events Triggering IMPOSSIBLE_TRAVEL Rule ---");
db.fraud_telemetry_events.find(
    {
        "risk_assessment.triggered_rules.rule_code": "IMPOSSIBLE_TRAVEL"
    },
    {
        _id: 0,
        event_id: 1,
        customer_id: 1,
        wallet_id: 1,
        tx_reference: 1,
        "network_geo.ip_address": 1,
        "network_geo.city": 1,
        "risk_assessment.triggered_rules": 1
    }
).toArray();

// ============================================================================
// QUERY 3: Multi-Stage Aggregation Pipeline — Fraud Risk Summary by Decision
// Groups telemetry events by risk decision, computing total events, average
// risk score, total NGN value exposed, and distinct channels involved.
// ============================================================================
print("--- QUERY 3: Fraud Risk Aggregation by Decision ---");
db.fraud_telemetry_events.aggregate([
    {
        $group: {
            _id: "$risk_assessment.decision",
            total_events: { $sum: 1 },
            avg_risk_score: { $avg: "$risk_assessment.risk_score" },
            max_risk_score: { $max: "$risk_assessment.risk_score" },
            total_amount_exposed_ngn: { $sum: "$amount_ngn" },
            channels_observed: { $addToSet: "$channel" }
        }
    },
    {
        $project: {
            _id: 0,
            decision: "$_id",
            total_events: 1,
            avg_risk_score: { $round: ["$avg_risk_score", 1] },
            max_risk_score: 1,
            total_amount_exposed_ngn: 1,
            channels_observed: 1
        }
    },
    {
        $sort: { max_risk_score: -1 }
    }
]).toArray();

// ============================================================================
// QUERY 4: Unwind Triggered Rules Pipeline — Top Fraud Rules by Frequency
// Uses $unwind on the embedded array to rank individual risk rules.
// ============================================================================
print("--- QUERY 4: Unwind & Rank Triggered Fraud Rules ---");
db.fraud_telemetry_events.aggregate([
    { $unwind: "$risk_assessment.triggered_rules" },
    {
        $group: {
            _id: "$risk_assessment.triggered_rules.rule_code",
            rule_description: { $first: "$risk_assessment.triggered_rules.description" },
            times_triggered: { $sum: 1 },
            avg_rule_weight: { $avg: "$risk_assessment.triggered_rules.weight" },
            affected_customers: { $addToSet: "$customer_id" }
        }
    },
    { $sort: { avg_rule_weight: -1 } }
]).toArray();

