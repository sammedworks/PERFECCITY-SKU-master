# Executable Rule Engine

Cypher-driven validation and BOM generation engine for the Wall Configurator.

## Architecture

```
┌──────────────┐     ┌──────────────────────────┐     ┌──────────────────────┐
│  Frontend /  │     │  03-evaluate-cart.cypher  │     │   Neo4j Graph DB     │
│  API Layer   │────▶│  (single parameterized   │────▶│   (product catalog   │
│              │     │   Cypher query)           │     │    + Rule nodes)     │
│              │◀────│                           │◀────│                      │
└──────────────┘     └──────────────────────────┘     └──────────────────────┘
  Sends $cartId       Returns:                         Reads :Rule nodes,
                        • pass_fail (PASS/FAIL)        installation contracts,
                        • violations[]                 trim/LED relationships
                        • bom_consumables[]
                        • bom_trims[]
```

## Files

| File                        | Purpose                                                |
|-----------------------------|--------------------------------------------------------|
| `00-cart-schema.cypher`     | Cart + CartItem constraints, indexes, and schema docs  |
| `01-validate-cart.cypher`   | Standalone validation engine (violations only)         |
| `02-bom-generator.cypher`   | Standalone BOM generator (6 sections)                  |
| `03-evaluate-cart.cypher`   | **Combined single-call endpoint** (validation + BOM)   |
| `99-sample-carts.cypher`    | 6 test carts exercising different rule paths           |

## Quick Start

```bash
# 1. Load the product catalog (if not already loaded)
cat ../wall-configurator-graph-v5.cypher | cypher-shell -u neo4j -p <password>

# 2. Create the cart schema
cat 00-cart-schema.cypher | cypher-shell -u neo4j -p <password>

# 3. Load sample carts
cat 99-sample-carts.cypher | cypher-shell -u neo4j -p <password>

# 4. Evaluate a cart (in Neo4j Browser or cypher-shell)
:param cartId => 'test-cart-001'
# Then paste the contents of 03-evaluate-cart.cypher
```

## Cart Node Schema

### :Cart

| Property            | Type     | Description                                     |
|---------------------|----------|-------------------------------------------------|
| `id`                | String   | Unique cart identifier (PK)                     |
| `status`            | String   | DRAFT / VALIDATING / VALID / INVALID / QUOTED   |
| `room_type`         | String   | Room type (living_room, bedroom, bathroom, etc.) |
| `is_two_zone`       | Boolean  | Two-zone wall configuration                     |
| `panels_reach_floor`| Boolean  | Panels extend to floor level                    |
| `wall_width_mm`     | Integer  | Wall width in millimeters                       |
| `wall_height_mm`    | Integer  | Wall height in millimeters                      |
| `created_at`        | DateTime | Creation timestamp                              |
| `updated_at`        | DateTime | Last modification timestamp                     |

### :CartItem

| Property            | Type     | Description                                     |
|---------------------|----------|-------------------------------------------------|
| `id`                | String   | Unique line-item identifier (PK)                |
| `sku`               | String   | Product SKU                                     |
| `item_type`         | String   | PANEL / TRIM / CONSUMABLE / LED_PROFILE / etc.  |
| `quantity`          | Integer  | Number of units                                 |
| `unit_price`        | Integer  | Price per unit in INR                            |
| `source`            | String   | USER_ADDED / AUTO_SUGGESTED / RULE_ADDED        |
| `added_by_rule`     | String   | Rule ID that auto-added this item               |
| `width_ft`          | Integer  | Configurable furniture width                    |
| `zone`              | Integer  | 1 or 2 (two-zone walls)                         |

### Relationships

```
(Cart)-[:CONTAINS_ITEM]->(CartItem)-[:REFERENCES]->(Panel|Trim|Consumable|...)
```

## API Usage Pattern

### From your backend (Node.js / Python / Java):

```javascript
// Node.js with neo4j-driver
const result = await session.run(
  EVALUATE_CART_QUERY,   // contents of 03-evaluate-cart.cypher
  { cartId: 'user-session-xyz' }
);

const record = result.records[0];
const passFail     = record.get('pass_fail');      // 'PASS' or 'FAIL'
const errors       = record.get('error_count');     // number
const warnings     = record.get('warning_count');   // number
const violations   = record.get('violations');      // [{rule_id, severity, message, action, item}]
const consumables  = record.get('bom_consumables'); // [{panel_sku, install_method, required[], optional[]}]
const trims        = record.get('bom_trims');       // [{panel_sku, trims[{sku, name, price, type, suggestion}]}]

if (passFail === 'FAIL') {
  // Show error violations to user, block quote generation
} else {
  // Proceed to quote generation, apply BOM suggestions
}
```

### From Python (neo4j driver):

```python
with driver.session() as session:
    result = session.run(EVALUATE_CART_QUERY, cartId="user-session-xyz")
    record = result.single()

    pass_fail    = record["pass_fail"]
    violations   = record["violations"]
    consumables  = record["bom_consumables"]
    trims        = record["bom_trims"]
```

## Sample Cart Expected Results

| Cart ID         | pass_fail | Errors | Warnings | Info | Key Violations                              |
|-----------------|-----------|--------|----------|------|---------------------------------------------|
| test-cart-001   | PASS      | 0      | 0        | 0    | None — happy path                           |
| test-cart-002   | FAIL      | 1      | 1        | 0    | V-02 (Charcoal+clips), V-16 (no Polyfix)   |
| test-cart-003   | PASS      | 0      | 3        | 0    | V-10, V-08, V-16                            |
| test-cart-004   | FAIL      | 1      | 1        | 0    | V-07 (ON_REQUEST), V-16                     |
| test-cart-005   | PASS      | 0      | 3        | 2    | V-12, WATERPROOF, V-16, TWO_ZONE, SKIRTING  |
| test-cart-006   | FAIL      | 2      | 2        | 2    | V-01, V-13, V-08, V-16, V-19, SKIRTING      |

## How Rules Are Evaluated

The engine does **not** interpret `trigger_condition` strings dynamically. Instead, each `:Rule` node's logic is compiled into a Cypher `CALL {}` subquery that:

1. Reads the cart state (collected SKUs, subcategories, item properties)
2. Evaluates the rule's condition using native Cypher predicates
3. Returns a violation row only if the condition fires

This means:
- **No APOC required** — pure Cypher, works on Community Edition
- **No string eval** — all conditions are compile-time checked
- **Adding a new rule** requires adding a new `CALL {}` block to the engine
- Rule metadata (message, action, severity) is read from the `:Rule` node at evaluation time
