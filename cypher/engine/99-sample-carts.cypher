// ============================================================================
// SAMPLE CART DATA — Test Harness for the Rule Engine
// ============================================================================
// Creates 5 carts that exercise different rule paths. Run after loading
// the seed script (wall-configurator-graph-v5.cypher) and the cart schema
// (00-cart-schema.cypher).
//
// After loading these carts, run 03-evaluate-cart.cypher with each cart ID
// to verify the engine output.
//
// Idempotent — safe to re-run.
// ============================================================================


// ─────────────────────────────────────────────────────────────────────────────
// CART 1: Happy Path — PVC Texture panel with correct consumables
// ─────────────────────────────────────────────────────────────────────────────
// Expected: PASS — 0 errors, 0 warnings (Polyfix included)
// BOM should suggest: CONS-CLIP50, CONS-POLYFIX, TR-U-TEXTURE, TR-L-TEXTURE, TR-H-BIDDING

MERGE (c:Cart {id: 'test-cart-001'})
SET c.status = 'DRAFT', c.room_type = 'living_room', c.is_two_zone = false,
    c.panels_reach_floor = false, c.wall_width_mm = 3000, c.wall_height_mm = 2440,
    c.created_at = datetime(), c.updated_at = datetime()

WITH c
MERGE (ci1:CartItem {id: 'tc1-panel'})
SET ci1.sku = 'PVC-TEXTURE', ci1.item_type = 'PANEL', ci1.quantity = 4,
    ci1.unit_price = 650, ci1.source = 'USER_ADDED'
MERGE (c)-[:CONTAINS_ITEM]->(ci1)
WITH c
MATCH (p:Panel {sku:'PVC-TEXTURE'})
MATCH (ci1:CartItem {id:'tc1-panel'})
MERGE (ci1)-[:REFERENCES]->(p)

WITH c
MERGE (ci2:CartItem {id: 'tc1-clips'})
SET ci2.sku = 'CONS-CLIP50', ci2.item_type = 'CONSUMABLE', ci2.quantity = 2,
    ci2.unit_price = 120, ci2.source = 'AUTO_SUGGESTED'
MERGE (c)-[:CONTAINS_ITEM]->(ci2)
WITH c
MATCH (con:Consumable {sku:'CONS-CLIP50'})
MATCH (ci2:CartItem {id:'tc1-clips'})
MERGE (ci2)-[:REFERENCES]->(con)

WITH c
MERGE (ci3:CartItem {id: 'tc1-polyfix'})
SET ci3.sku = 'CONS-POLYFIX', ci3.item_type = 'CONSUMABLE', ci3.quantity = 1,
    ci3.unit_price = 180, ci3.source = 'AUTO_SUGGESTED'
MERGE (c)-[:CONTAINS_ITEM]->(ci3)
WITH c
MATCH (con:Consumable {sku:'CONS-POLYFIX'})
MATCH (ci3:CartItem {id:'tc1-polyfix'})
MERGE (ci3)-[:REFERENCES]->(con);


// ─────────────────────────────────────────────────────────────────────────────
// CART 2: Charcoal + Clips — triggers V-02 (ERROR)
// ─────────────────────────────────────────────────────────────────────────────
// Expected: FAIL — V-02 ERROR (clips forbidden), V-16 WARNING (no Polyfix)
// BOM should suggest: CONS-SILGLU, CONS-POLYFIX

MERGE (c:Cart {id: 'test-cart-002'})
SET c.status = 'DRAFT', c.room_type = 'living_room', c.is_two_zone = false,
    c.panels_reach_floor = false, c.wall_width_mm = 4000, c.wall_height_mm = 2440,
    c.created_at = datetime(), c.updated_at = datetime()

WITH c
MERGE (ci1:CartItem {id: 'tc2-panel'})
SET ci1.sku = 'CH-CL2', ci1.item_type = 'PANEL', ci1.quantity = 6,
    ci1.unit_price = 650, ci1.source = 'USER_ADDED'
MERGE (c)-[:CONTAINS_ITEM]->(ci1)
WITH c
MATCH (p:Panel {sku:'CH-CL2'})
MATCH (ci1:CartItem {id:'tc2-panel'})
MERGE (ci1)-[:REFERENCES]->(p)

WITH c
MERGE (ci2:CartItem {id: 'tc2-clips'})
SET ci2.sku = 'CONS-CLIP50', ci2.item_type = 'CONSUMABLE', ci2.quantity = 3,
    ci2.unit_price = 120, ci2.source = 'USER_ADDED'
MERGE (c)-[:CONTAINS_ITEM]->(ci2)
WITH c
MATCH (con:Consumable {sku:'CONS-CLIP50'})
MATCH (ci2:CartItem {id:'tc2-clips'})
MERGE (ci2)-[:REFERENCES]->(con);


// ─────────────────────────────────────────────────────────────────────────────
// CART 3: WPC New + Fluted LED — triggers V-10 (WARNING)
// ─────────────────────────────────────────────────────────────────────────────
// Expected: FAIL-ish — V-10 WARNING (fluted LED without PVC Flute),
//           V-08 WARNING (LED profile without strip), V-16 WARNING (no Polyfix)

MERGE (c:Cart {id: 'test-cart-003'})
SET c.status = 'DRAFT', c.room_type = 'bedroom', c.is_two_zone = false,
    c.panels_reach_floor = true, c.wall_width_mm = 3500, c.wall_height_mm = 2900,
    c.created_at = datetime(), c.updated_at = datetime()

WITH c
MERGE (ci1:CartItem {id: 'tc3-panel'})
SET ci1.sku = 'WPC-NEW-CLASSIC', ci1.item_type = 'PANEL', ci1.quantity = 5,
    ci1.unit_price = 1300, ci1.source = 'USER_ADDED'
MERGE (c)-[:CONTAINS_ITEM]->(ci1)
WITH c
MATCH (p:Panel {sku:'WPC-NEW-CLASSIC'})
MATCH (ci1:CartItem {id:'tc3-panel'})
MERGE (ci1)-[:REFERENCES]->(p)

WITH c
MERGE (ci2:CartItem {id: 'tc3-led'})
SET ci2.sku = 'LED-PROF-FLUTED', ci2.item_type = 'LED_PROFILE', ci2.quantity = 2,
    ci2.unit_price = 350, ci2.source = 'USER_ADDED'
MERGE (c)-[:CONTAINS_ITEM]->(ci2)
WITH c
MATCH (lp:LEDProfile {sku:'LED-PROF-FLUTED'})
MATCH (ci2:CartItem {id:'tc3-led'})
MERGE (ci2)-[:REFERENCES]->(lp);


// ─────────────────────────────────────────────────────────────────────────────
// CART 4: ON_REQUEST product — triggers V-07 (ERROR, blocks quote)
// ─────────────────────────────────────────────────────────────────────────────
// Expected: FAIL — V-07 ERROR (ON_REQUEST item), V-16 WARNING (no Polyfix)

MERGE (c:Cart {id: 'test-cart-004'})
SET c.status = 'DRAFT', c.room_type = 'living_room', c.is_two_zone = false,
    c.panels_reach_floor = false, c.wall_width_mm = 3000, c.wall_height_mm = 2440,
    c.created_at = datetime(), c.updated_at = datetime()

WITH c
MERGE (ci1:CartItem {id: 'tc4-panel'})
SET ci1.sku = 'WPC-MARBLE', ci1.item_type = 'PANEL', ci1.quantity = 4,
    ci1.unit_price = null, ci1.source = 'USER_ADDED'
MERGE (c)-[:CONTAINS_ITEM]->(ci1)
WITH c
MATCH (p:Panel {sku:'WPC-MARBLE'})
MATCH (ci1:CartItem {id:'tc4-panel'})
MERGE (ci1)-[:REFERENCES]->(p);


// ─────────────────────────────────────────────────────────────────────────────
// CART 5: Two-Zone + Skirting + Charcoal wet room — triggers multiple rules
// ─────────────────────────────────────────────────────────────────────────────
// Expected: PASS (0 errors) but many warnings/info:
//   V-12 WARNING (non-waterproof Charcoal in kitchen)
//   WATERPROOF_ENFORCEMENT WARNING
//   V-16 WARNING (no Polyfix)
//   TWO_ZONE_DIVIDER INFO (Metal T missing)
//   SKIRTING_RULE INFO (panels reach floor, skirting missing)

MERGE (c:Cart {id: 'test-cart-005'})
SET c.status = 'DRAFT', c.room_type = 'kitchen', c.is_two_zone = true,
    c.panels_reach_floor = true, c.wall_width_mm = 5000, c.wall_height_mm = 2900,
    c.created_at = datetime(), c.updated_at = datetime()

WITH c
MERGE (ci1:CartItem {id: 'tc5-panel1'})
SET ci1.sku = 'CH-FLUTED', ci1.item_type = 'PANEL', ci1.quantity = 3,
    ci1.unit_price = 2750, ci1.source = 'USER_ADDED', ci1.zone = 1
MERGE (c)-[:CONTAINS_ITEM]->(ci1)
WITH c
MATCH (p:Panel {sku:'CH-FLUTED'})
MATCH (ci1:CartItem {id:'tc5-panel1'})
MERGE (ci1)-[:REFERENCES]->(p)

WITH c
MERGE (ci2:CartItem {id: 'tc5-panel2'})
SET ci2.sku = 'SHT-UV-MARBLE', ci2.item_type = 'PANEL', ci2.quantity = 2,
    ci2.unit_price = 2100, ci2.source = 'USER_ADDED', ci2.zone = 2
MERGE (c)-[:CONTAINS_ITEM]->(ci2)
WITH c
MATCH (p:Panel {sku:'SHT-UV-MARBLE'})
MATCH (ci2:CartItem {id:'tc5-panel2'})
MERGE (ci2)-[:REFERENCES]->(p)

WITH c
MERGE (ci3:CartItem {id: 'tc5-silglu'})
SET ci3.sku = 'CONS-SILGLU', ci3.item_type = 'CONSUMABLE', ci3.quantity = 3,
    ci3.unit_price = 380, ci3.source = 'AUTO_SUGGESTED'
MERGE (c)-[:CONTAINS_ITEM]->(ci3)
WITH c
MATCH (con:Consumable {sku:'CONS-SILGLU'})
MATCH (ci3:CartItem {id:'tc5-silglu'})
MERGE (ci3)-[:REFERENCES]->(con);


// ─────────────────────────────────────────────────────────────────────────────
// CART 6: PVC Flute + Clips (ERROR) + Furniture width violation
// ─────────────────────────────────────────────────────────────────────────────
// Expected: FAIL — V-01 ERROR (Flute+clips), V-13 ERROR (PF TV unit < 6ft),
//           V-08 WARNING (LED without strip), V-16 WARNING (no Polyfix),
//           V-19 INFO (batten frame advisory)

MERGE (c:Cart {id: 'test-cart-006'})
SET c.status = 'DRAFT', c.room_type = 'tv_wall', c.is_two_zone = false,
    c.panels_reach_floor = true, c.wall_width_mm = 4500, c.wall_height_mm = 2900,
    c.created_at = datetime(), c.updated_at = datetime()

WITH c
MERGE (ci1:CartItem {id: 'tc6-panel'})
SET ci1.sku = 'FLT-WIDEWOOD', ci1.item_type = 'PANEL', ci1.quantity = 8,
    ci1.unit_price = 1450, ci1.source = 'USER_ADDED'
MERGE (c)-[:CONTAINS_ITEM]->(ci1)
WITH c
MATCH (p:Panel {sku:'FLT-WIDEWOOD'})
MATCH (ci1:CartItem {id:'tc6-panel'})
MERGE (ci1)-[:REFERENCES]->(p)

WITH c
MERGE (ci2:CartItem {id: 'tc6-clips'})
SET ci2.sku = 'CONS-CLIP50', ci2.item_type = 'CONSUMABLE', ci2.quantity = 4,
    ci2.unit_price = 120, ci2.source = 'USER_ADDED'
MERGE (c)-[:CONTAINS_ITEM]->(ci2)
WITH c
MATCH (con:Consumable {sku:'CONS-CLIP50'})
MATCH (ci2:CartItem {id:'tc6-clips'})
MERGE (ci2)-[:REFERENCES]->(con)

WITH c
MERGE (ci3:CartItem {id: 'tc6-led'})
SET ci3.sku = 'LED-PROF-FLUTED', ci3.item_type = 'LED_PROFILE', ci3.quantity = 4,
    ci3.unit_price = 350, ci3.source = 'AUTO_SUGGESTED'
MERGE (c)-[:CONTAINS_ITEM]->(ci3)
WITH c
MATCH (lp:LEDProfile {sku:'LED-PROF-FLUTED'})
MATCH (ci3:CartItem {id:'tc6-led'})
MERGE (ci3)-[:REFERENCES]->(lp)

WITH c
MERGE (ci4:CartItem {id: 'tc6-tv'})
SET ci4.sku = 'TV-PF-PUREOPEN', ci4.item_type = 'FURNITURE', ci4.quantity = 1,
    ci4.unit_price = 8000, ci4.source = 'USER_ADDED', ci4.width_ft = 4
MERGE (c)-[:CONTAINS_ITEM]->(ci4)
WITH c
MATCH (f:Furniture {sku:'TV-PF-PUREOPEN'})
MATCH (ci4:CartItem {id:'tc6-tv'})
MERGE (ci4)-[:REFERENCES]->(f);


// ============================================================================
// Expected Validation Summary per Cart
// ============================================================================
//
// Cart              | pass_fail | errors | warnings | info
// ──────────────────┼───────────┼────────┼──────────┼──────
// test-cart-001     | PASS      | 0      | 0        | 0
// test-cart-002     | FAIL      | 1      | 1        | 0
// test-cart-003     | PASS      | 0      | 3        | 0
// test-cart-004     | FAIL      | 1      | 1        | 0
// test-cart-005     | PASS      | 0      | 3        | 2
// test-cart-006     | FAIL      | 2      | 2        | 2
//
// ============================================================================
// END OF SAMPLE CARTS
// ============================================================================
