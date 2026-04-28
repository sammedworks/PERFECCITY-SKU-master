// ============================================================================
// BOM GENERATOR — V1.0
// ============================================================================
// Reads installation contracts, trim assignments, LED compatibility, and
// conditional rules from the graph to generate a complete Bill of Materials
// for a given cart.
//
// Input parameter: $cartId (String) — the Cart node's id property.
//
// Returns three result sets (run each section separately or use UNION):
//   1. Suggested consumables (required + optional from installation contracts)
//   2. Suggested trims (auto-suggested from panel → trim relationships)
//   3. Suggested LED profiles (dedicated + universal from panel → LED relationships)
//
// Usage:
//   :param cartId => 'my-cart-001'
//   // then run each section
//
// ============================================================================


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 1: CONSUMABLES FROM INSTALLATION CONTRACTS
// ─────────────────────────────────────────────────────────────────────────────
// For each panel in the cart, find the installation contract rule
// (subcategory-level or panel-level) and collect required/forbidden/optional
// consumables.

MATCH (cart:Cart {id: $cartId})-[:CONTAINS_ITEM]->(ci:CartItem {item_type:'PANEL'})
MATCH (panel:Panel {sku: ci.sku})-[:BELONGS_TO]->(subcat:Subcategory)

// Find installation contract — prefer panel-level, fall back to subcategory-level
OPTIONAL MATCH (panelRule:Rule {type:'INSTALLATION_CONTRACT'})-[:APPLIES_TO]->(panel)
OPTIONAL MATCH (subcatRule:Rule {type:'INSTALLATION_CONTRACT'})-[:APPLIES_TO]->(subcat)
WITH cart, ci, panel, subcat,
     CASE WHEN panelRule IS NOT NULL THEN panelRule ELSE subcatRule END AS contract

// Collect required consumables
OPTIONAL MATCH (contract)-[req:REQUIRES_CONSUMABLE]->(rc:Consumable)
WITH cart, ci, panel, subcat, contract,
     collect(DISTINCT {
       sku: rc.sku,
       name: rc.name,
       price: rc.price,
       relationship: req.relationship_type,
       status: 'REQUIRED'
     }) AS required_consumables

// Collect forbidden consumables
OPTIONAL MATCH (contract)-[:FORBIDS_CONSUMABLE]->(fc:Consumable)
WITH cart, ci, panel, subcat, contract, required_consumables,
     collect(DISTINCT {
       sku: fc.sku,
       name: fc.name,
       status: 'FORBIDDEN'
     }) AS forbidden_consumables

// Collect optional consumables
OPTIONAL MATCH (contract)-[opt:OPTIONAL_CONSUMABLE]->(oc:Consumable)
WITH cart, ci, panel, subcat, contract, required_consumables, forbidden_consumables,
     collect(DISTINCT {
       sku: oc.sku,
       name: oc.name,
       price: oc.price,
       condition: opt.condition,
       preferred: coalesce(opt.preferred, false),
       status: 'OPTIONAL'
     }) AS optional_consumables

RETURN
  ci.sku                 AS cart_panel_sku,
  ci.quantity            AS panel_qty,
  panel.name             AS panel_name,
  subcat.name            AS subcategory,
  contract.method        AS install_method,
  contract.advisory      AS advisory,
  required_consumables   AS required,
  forbidden_consumables  AS forbidden,
  optional_consumables   AS optional
ORDER BY ci.sku;


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 2: AUTO-SUGGESTED TRIMS
// ─────────────────────────────────────────────────────────────────────────────
// For each panel in the cart, find matching U, L, H, and Metal trims.

MATCH (cart:Cart {id: $cartId})-[:CONTAINS_ITEM]->(ci:CartItem {item_type:'PANEL'})
MATCH (panel:Panel {sku: ci.sku})

// Check for H-trim override (e.g., SHT-WPC-GROOVED-7MM uses TR-WPC-H-TRIM)
OPTIONAL MATCH (panel)-[ru:HAS_U_TRIM]->(ut:Trim)
OPTIONAL MATCH (panel)-[rl:HAS_L_TRIM]->(lt:Trim)
OPTIONAL MATCH (panel)-[rh:HAS_H_TRIM]->(ht:Trim)
OPTIONAL MATCH (panel)-[rm:HAS_METAL_TRIM]->(mt:Trim)

WITH ci, panel,
     collect(DISTINCT {
       sku: ut.sku, name: ut.name, price: ut.price,
       trim_type: 'U', suggestion: ru.relationship_type
     }) AS u_trims,
     collect(DISTINCT {
       sku: lt.sku, name: lt.name, price: lt.price,
       trim_type: 'L', suggestion: rl.relationship_type
     }) AS l_trims,
     collect(DISTINCT {
       sku: ht.sku, name: ht.name, price: ht.price,
       trim_type: 'H', suggestion: rh.relationship_type, note: rh.note
     }) AS h_trims,
     collect(DISTINCT {
       sku: mt.sku, name: mt.name, price: mt.price,
       trim_type: 'METAL', suggestion: rm.relationship_type
     }) AS metal_trims

RETURN
  ci.sku         AS cart_panel_sku,
  ci.quantity    AS panel_qty,
  panel.name     AS panel_name,
  // Filter out null-sku entries from OPTIONAL MATCH
  [t IN u_trims WHERE t.sku IS NOT NULL]     AS u_trims,
  [t IN l_trims WHERE t.sku IS NOT NULL]     AS l_trims,
  [t IN h_trims WHERE t.sku IS NOT NULL]     AS h_trims,
  [t IN metal_trims WHERE t.sku IS NOT NULL] AS metal_trims
ORDER BY ci.sku;


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 3: LED PROFILE SUGGESTIONS
// ─────────────────────────────────────────────────────────────────────────────
// For each panel in the cart, find dedicated and compatible LED profiles.

MATCH (cart:Cart {id: $cartId})-[:CONTAINS_ITEM]->(ci:CartItem {item_type:'PANEL'})
MATCH (panel:Panel {sku: ci.sku})

// Dedicated LED (highest priority)
OPTIONAL MATCH (panel)-[rd:HAS_DEDICATED_LED]->(dlp:LEDProfile)

// Universal LED compatibility
OPTIONAL MATCH (panel)-[rc:COMPATIBLE_LED]->(ulp:LEDProfile)

// Conditional bundle: Sheet + LED → aluminium channel
OPTIONAL MATCH (panel)-[rb:BUNDLE_WITH_LED]->(bt:Trim)

WITH ci, panel,
     collect(DISTINCT {
       sku: dlp.sku, name: dlp.name, price: dlp.price,
       type: 'DEDICATED', priority: rd.priority
     }) AS dedicated_led,
     collect(DISTINCT {
       sku: ulp.sku, name: ulp.name, price: ulp.price,
       type: 'UNIVERSAL', priority: rc.priority
     }) AS universal_led,
     collect(DISTINCT {
       sku: bt.sku, name: bt.name, price: bt.price,
       type: 'BUNDLE_ACCESSORY', condition: rb.condition
     }) AS led_bundle_trims

RETURN
  ci.sku         AS cart_panel_sku,
  panel.name     AS panel_name,
  panel.led_compat AS led_compat_type,
  // Filter out null entries
  [l IN dedicated_led WHERE l.sku IS NOT NULL]   AS dedicated,
  [l IN universal_led WHERE l.sku IS NOT NULL]   AS universal,
  [l IN led_bundle_trims WHERE l.sku IS NOT NULL] AS bundle_accessories
ORDER BY ci.sku;


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 4: POLYFIX UNIVERSAL INCLUSION
// ─────────────────────────────────────────────────────────────────────────────
// Polyfix joint filler (CONS-POLYFIX) is required for every installation.
// Check if it's already in the cart; if not, recommend adding it.

MATCH (cart:Cart {id: $cartId})-[:CONTAINS_ITEM]->(ci:CartItem)
WITH cart, collect(ci.sku) AS all_skus
WITH cart, all_skus,
     CASE WHEN 'CONS-POLYFIX' IN all_skus THEN true ELSE false END AS has_polyfix
MATCH (poly:Consumable {sku:'CONS-POLYFIX'})
RETURN
  has_polyfix AS polyfix_in_cart,
  CASE WHEN NOT has_polyfix
    THEN {sku: poly.sku, name: poly.name, price: poly.price, quantity: 1, reason: 'Universal joint filler — required for every installation'}
    ELSE null
  END AS polyfix_suggestion;


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 5: TWO-ZONE ACCESSORIES
// ─────────────────────────────────────────────────────────────────────────────
// When the cart is marked as two-zone, auto-suggest zone divider trims.

MATCH (cart:Cart {id: $cartId})
WHERE cart.is_two_zone = true
WITH cart
MATCH (cart)-[:CONTAINS_ITEM]->(ci:CartItem)
WITH cart, collect(ci.sku) AS all_skus,
     [x IN collect(ci) WHERE x.item_type = 'LED_PROFILE' | x.sku] AS led_profile_skus
MATCH (met_t:Trim {sku:'TR-MET-T'})
OPTIONAL MATCH (channel:Trim {sku:'TR-MET-CHANNEL'})
RETURN
  'TWO_ZONE' AS section,
  CASE WHEN NOT 'TR-MET-T' IN all_skus
    THEN {sku: met_t.sku, name: met_t.name, price: met_t.price, reason: 'Zone divider required for two-zone wall'}
    ELSE null
  END AS zone_divider_suggestion,
  CASE WHEN size(led_profile_skus) > 0 AND NOT 'TR-MET-CHANNEL' IN all_skus
    THEN {sku: channel.sku, name: channel.name, price: channel.price, reason: 'Aluminium channel preferred as LED-compatible zone divider'}
    ELSE null
  END AS led_channel_upgrade;


// ─────────────────────────────────────────────────────────────────────────────
// SECTION 6: SKIRTING SUGGESTION
// ─────────────────────────────────────────────────────────────────────────────
// When panels reach the floor, suggest skirting to finish the junction.

MATCH (cart:Cart {id: $cartId})
WHERE cart.panels_reach_floor = true
WITH cart
MATCH (cart)-[:CONTAINS_ITEM]->(ci:CartItem)
WITH cart, collect(ci.sku) AS all_skus
WHERE NOT 'TR-SKIRTING' IN all_skus
MATCH (sk:Trim {sku:'TR-SKIRTING'})
RETURN
  'SKIRTING' AS section,
  {sku: sk.sku, name: sk.name, price: sk.price, reason: 'Panels reach floor — skirting recommended'} AS skirting_suggestion;


// ============================================================================
// END OF BOM GENERATOR
// ============================================================================
