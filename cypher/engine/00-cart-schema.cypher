// ============================================================================
// CART & CART-ITEM SCHEMA — Executable Rule Engine
// ============================================================================
// Defines the :Cart and :CartItem node structure, constraints, indexes,
// and the relationships that link cart items to the product catalog graph.
//
// A Cart represents a single configurator session / quote request.
// CartItems are individual line-items (panel, trim, consumable, LED, furniture).
//
// Fully idempotent — safe to re-run.
// ============================================================================


// ─────────────────────────────────────────────────────────────────────────────
// Constraints
// ─────────────────────────────────────────────────────────────────────────────

CREATE CONSTRAINT cart_id_unique      IF NOT EXISTS FOR (c:Cart)     REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT cartitem_id_unique  IF NOT EXISTS FOR (ci:CartItem) REQUIRE ci.id IS UNIQUE;


// ─────────────────────────────────────────────────────────────────────────────
// Indexes
// ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX cart_status_idx     IF NOT EXISTS FOR (c:Cart)     ON (c.status);
CREATE INDEX cartitem_sku_idx    IF NOT EXISTS FOR (ci:CartItem) ON (ci.sku);
CREATE INDEX cartitem_type_idx   IF NOT EXISTS FOR (ci:CartItem) ON (ci.item_type);


// ─────────────────────────────────────────────────────────────────────────────
// Cart Node Properties
// ─────────────────────────────────────────────────────────────────────────────
//
// :Cart {
//   id:            String  (PK)  — UUID or session-based identifier
//   status:        String        — DRAFT | VALIDATING | VALID | INVALID | QUOTED
//   room_type:     String        — living_room | bedroom | bathroom | kitchen | ceiling | etc.
//   is_two_zone:   Boolean       — Whether the wall has two different panel zones
//   panels_reach_floor: Boolean  — Whether panels extend to floor level
//   wall_width_mm: Integer       — Wall width in millimeters
//   wall_height_mm:Integer       — Wall height in millimeters
//   created_at:    DateTime      — Cart creation timestamp
//   updated_at:    DateTime      — Last modification timestamp
// }
//
// :CartItem {
//   id:           String  (PK)  — Unique line-item identifier
//   sku:          String        — Product SKU (matches Panel/Trim/Consumable/etc.)
//   item_type:    String        — PANEL | TRIM | CONSUMABLE | LED_PROFILE | LED_STRIP | LED_KIT | FURNITURE
//   quantity:     Integer       — Number of units / pieces / packs
//   unit_price:   Integer       — Price per unit in INR (copied from catalog at add-time)
//   source:       String        — USER_ADDED | AUTO_SUGGESTED | RULE_ADDED
//   added_by_rule:String        — Rule ID that auto-added this item (null if user-added)
//   width_ft:     Integer       — Selected width for configurable furniture (null otherwise)
//   zone:         Integer       — 1 or 2 (for two-zone walls; null for single-zone)
// }
//
// Relationships:
//   (Cart)-[:CONTAINS_ITEM]->(CartItem)
//   (CartItem)-[:REFERENCES]->(Panel|Trim|Consumable|LEDProfile|LEDStrip|LEDKit|Furniture)


// ─────────────────────────────────────────────────────────────────────────────
// Helper: Create a cart with items (example procedure pattern)
// ─────────────────────────────────────────────────────────────────────────────
// The frontend or API layer should:
//   1. MERGE a :Cart node with a unique ID
//   2. For each item, MERGE a :CartItem and link to the Cart
//   3. Link each CartItem to its catalog product via :REFERENCES
//   4. Call the validation engine (01-validate-cart.cypher)
//   5. Call the BOM engine (02-bom-generator.cypher)
//
// Example:
//   MERGE (cart:Cart {id: $cartId})
//   SET cart.room_type = $roomType, cart.is_two_zone = $isTwoZone, ...
//   WITH cart
//   UNWIND $items AS item
//   MERGE (ci:CartItem {id: item.id})
//   SET ci += item
//   MERGE (cart)-[:CONTAINS_ITEM]->(ci)
//   WITH ci, item
//   MATCH (product) WHERE (product:Panel OR product:Trim OR product:Consumable
//     OR product:LEDProfile OR product:LEDStrip OR product:LEDKit OR product:Furniture)
//     AND product.sku = ci.sku
//   MERGE (ci)-[:REFERENCES]->(product)


// ============================================================================
// END OF CART SCHEMA
// ============================================================================
