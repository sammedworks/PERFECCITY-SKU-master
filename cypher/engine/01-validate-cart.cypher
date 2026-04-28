// ============================================================================
// CART VALIDATION ENGINE — V1.0
// ============================================================================
// Single parameterized query that evaluates ALL validation rules (V-01 to V-20
// plus two-zone, skirting, waterproof, and availability rules) against a cart.
//
// Input parameter: $cartId (String) — the Cart node's id property.
//
// Returns a list of violations, each with:
//   rule_id, severity, name, message, action, items_involved
//
// Severity levels:
//   ERROR   → blocks quote generation
//   WARNING → user must acknowledge before proceeding
//   INFO    → advisory only (shown in UI, does not block)
//
// Usage:
//   :param cartId => 'my-cart-001'
//   // then run this file
//
// ============================================================================


// ─────────────────────────────────────────────────────────────────────────────
// Collect cart state into a single row for rule evaluation
// ─────────────────────────────────────────────────────────────────────────────

MATCH (cart:Cart {id: $cartId})-[:CONTAINS_ITEM]->(ci:CartItem)

// Collect all SKUs and item types in the cart
WITH cart,
     collect(ci) AS all_items,
     collect(ci.sku) AS all_skus,
     [x IN collect(ci) WHERE x.item_type = 'PANEL' | x.sku] AS panel_skus,
     [x IN collect(ci) WHERE x.item_type = 'TRIM' | x.sku] AS trim_skus,
     [x IN collect(ci) WHERE x.item_type = 'CONSUMABLE' | x.sku] AS consumable_skus,
     [x IN collect(ci) WHERE x.item_type = 'LED_PROFILE' | x.sku] AS led_profile_skus,
     [x IN collect(ci) WHERE x.item_type = 'LED_STRIP' | x.sku] AS led_strip_skus,
     [x IN collect(ci) WHERE x.item_type = 'LED_KIT' | x.sku] AS led_kit_skus,
     [x IN collect(ci) WHERE x.item_type = 'FURNITURE' | x.sku] AS furniture_skus

// Get panel subcategories present in cart
OPTIONAL MATCH (p:Panel) WHERE p.sku IN panel_skus
WITH cart, all_items, all_skus, panel_skus, trim_skus, consumable_skus,
     led_profile_skus, led_strip_skus, led_kit_skus, furniture_skus,
     collect(DISTINCT p.subcategory) AS panel_subcategories,
     collect(DISTINCT p) AS cart_panels

// ─────────────────────────────────────────────────────────────────────────────
// Evaluate each rule and collect violations
// ─────────────────────────────────────────────────────────────────────────────

// V-01: PVC Flute + clips forbidden
CALL {
  WITH consumable_skus, panel_subcategories
  WITH consumable_skus, panel_subcategories
  WHERE 'PVC_FLUTE' IN panel_subcategories AND 'CONS-CLIP50' IN consumable_skus
  MATCH (r:Rule {id:'V-01'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'CONS-CLIP50' AS items_involved
}

UNION ALL

// V-02: Charcoal + clips forbidden
CALL {
  WITH consumable_skus, panel_subcategories
  WITH consumable_skus, panel_subcategories
  WHERE 'CHARCOAL' IN panel_subcategories AND 'CONS-CLIP50' IN consumable_skus
  MATCH (r:Rule {id:'V-02'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'CONS-CLIP50' AS items_involved
}

UNION ALL

// V-03: UV/SPC sheets + clips forbidden
CALL {
  WITH consumable_skus, panel_skus
  WITH consumable_skus, panel_skus
  WHERE 'CONS-CLIP50' IN consumable_skus
        AND (any(s IN panel_skus WHERE s IN ['SHT-UV-MARBLE','SHT-SPC']))
  MATCH (r:Rule {id:'V-03'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'CONS-CLIP50' AS items_involved
}

UNION ALL

// V-04: SHT-WPC-GROOVED-7MM H-trim swap
CALL {
  WITH panel_skus, trim_skus
  WITH panel_skus, trim_skus
  WHERE 'SHT-WPC-GROOVED-7MM' IN panel_skus
        AND 'TR-H-BIDDING' IN trim_skus
        AND NOT 'TR-WPC-H-TRIM' IN trim_skus
  MATCH (r:Rule {id:'V-04'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'TR-H-BIDDING→TR-WPC-H-TRIM' AS items_involved
}

UNION ALL

// V-05: Charcoal + PVC bidding trims incompatible
CALL {
  WITH panel_subcategories, trim_skus
  WITH panel_subcategories, trim_skus
  WHERE 'CHARCOAL' IN panel_subcategories
        AND any(t IN trim_skus WHERE t IN [
          'TR-U-FLORAL','TR-U-TEXTURE','TR-U-STONE','TR-U-TRAD','TR-U-GEOM','TR-U-WOOD','TR-U-SHEET',
          'TR-L-NEUTRAL','TR-L-WOOD','TR-L-SHEET','TR-L-WPC-NEW','TR-L-WPC-CER'
        ])
  MATCH (r:Rule {id:'V-05'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action,
         [t IN trim_skus WHERE t IN ['TR-U-FLORAL','TR-U-TEXTURE','TR-U-STONE','TR-U-TRAD','TR-U-GEOM','TR-U-WOOD','TR-U-SHEET','TR-L-NEUTRAL','TR-L-WOOD','TR-L-SHEET','TR-L-WPC-NEW','TR-L-WPC-CER']][0] AS items_involved
}

UNION ALL

// V-06: Charcoal + H-Bidding incompatible
CALL {
  WITH panel_subcategories, trim_skus
  WITH panel_subcategories, trim_skus
  WHERE 'CHARCOAL' IN panel_subcategories AND 'TR-H-BIDDING' IN trim_skus
  MATCH (r:Rule {id:'V-06'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'TR-H-BIDDING' AS items_involved
}

UNION ALL

// V-07: ON_REQUEST product in cart — block quote
CALL {
  WITH all_skus
  WITH all_skus
  MATCH (product) WHERE (product:Panel OR product:Trim OR product:Consumable
    OR product:LEDProfile OR product:LEDStrip OR product:LEDKit OR product:Furniture)
    AND product.sku IN all_skus
    AND product.availability = 'ON_REQUEST'
  WITH collect(product.sku) AS on_request_skus
  WHERE size(on_request_skus) > 0
  MATCH (r:Rule {id:'V-07'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action,
         on_request_skus[0] AS items_involved
}

UNION ALL

// V-08: LED profile without strip/kit
CALL {
  WITH led_profile_skus, led_strip_skus, led_kit_skus
  WITH led_profile_skus, led_strip_skus, led_kit_skus
  WHERE size(led_profile_skus) > 0
        AND size(led_strip_skus) = 0
        AND size(led_kit_skus) = 0
  MATCH (r:Rule {id:'V-08'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action,
         led_profile_skus[0] AS items_involved
}

UNION ALL

// V-09: TR-L-WPC-NEW without WPC_NEW panel
CALL {
  WITH trim_skus, panel_subcategories
  WITH trim_skus, panel_subcategories
  WHERE 'TR-L-WPC-NEW' IN trim_skus AND NOT 'WPC_NEW' IN panel_subcategories
  MATCH (r:Rule {id:'V-09'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'TR-L-WPC-NEW' AS items_involved
}

UNION ALL

// V-10: LED-PROF-FLUTED without PVC_FLUTE panel
CALL {
  WITH led_profile_skus, panel_subcategories
  WITH led_profile_skus, panel_subcategories
  WHERE 'LED-PROF-FLUTED' IN led_profile_skus AND NOT 'PVC_FLUTE' IN panel_subcategories
  MATCH (r:Rule {id:'V-10'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'LED-PROF-FLUTED' AS items_involved
}

UNION ALL

// V-11: LED-PROF-CER without WPC_CERAMIC panel
CALL {
  WITH led_profile_skus, panel_subcategories
  WITH led_profile_skus, panel_subcategories
  WHERE 'LED-PROF-CER' IN led_profile_skus AND NOT 'WPC_CERAMIC' IN panel_subcategories
  MATCH (r:Rule {id:'V-11'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'LED-PROF-CER' AS items_involved
}

UNION ALL

// V-12: Non-waterproof panel in wet room
CALL {
  WITH cart, panel_skus
  WITH cart, panel_skus
  WHERE cart.room_type IN ['bathroom','kitchen']
  WITH panel_skus
  MATCH (r:Rule {id:'V-12'})
  WITH r, panel_skus, r.non_rated_skus AS non_rated
  WITH r, [s IN panel_skus WHERE s IN non_rated] AS bad_skus
  WHERE size(bad_skus) > 0
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, bad_skus[0] AS items_involved
}

UNION ALL

// V-13: PF TV Unit 6ft minimum width
CALL {
  WITH all_items
  UNWIND all_items AS ci
  WITH ci WHERE ci.item_type = 'FURNITURE'
    AND ci.sku IN ['TV-PF-PUREOPEN','TV-PF-MODUFIT','TV-PF-LEAFLEDGE']
    AND ci.width_ft IS NOT NULL AND ci.width_ft < 6
  MATCH (r:Rule {id:'V-13'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, ci.sku AS items_involved
  LIMIT 1
}

UNION ALL

// V-14: GrooveLine TV Unit max 7ft
CALL {
  WITH all_items
  UNWIND all_items AS ci
  WITH ci WHERE ci.item_type = 'FURNITURE'
    AND ci.sku = 'TV-GL'
    AND ci.width_ft IS NOT NULL AND ci.width_ft >= 8
  MATCH (r:Rule {id:'V-14'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, ci.sku AS items_involved
  LIMIT 1
}

UNION ALL

// V-15: Ceiling use — non-rated sheet
CALL {
  WITH cart, panel_skus
  WITH cart, panel_skus
  WHERE cart.room_type = 'ceiling'
        AND size(panel_skus) > 0
        AND NOT 'SHT-WPC-5MM' IN panel_skus
  MATCH (r:Rule {id:'V-15'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, panel_skus[0] AS items_involved
}

UNION ALL

// V-16: Polyfix always required
CALL {
  WITH all_skus
  WITH all_skus
  WHERE size(all_skus) > 0 AND NOT 'CONS-POLYFIX' IN all_skus
  MATCH (r:Rule {id:'V-16'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'CONS-POLYFIX' AS items_involved
}

UNION ALL

// V-17: Install-only cabinet advisory
CALL {
  WITH all_skus
  WITH all_skus
  WHERE 'CAB-OH-1.5FT-INSTALL' IN all_skus
  MATCH (r:Rule {id:'V-17'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'CAB-OH-1.5FT-INSTALL' AS items_involved
}

UNION ALL

// V-18: 3D curved panel measurement advisory
CALL {
  WITH panel_skus
  WITH panel_skus
  WHERE any(s IN panel_skus WHERE s IN ['WPC-NEW-CONCAVE','WPC-NEW-CONVEX'])
  MATCH (r:Rule {id:'V-18'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action,
         [s IN panel_skus WHERE s IN ['WPC-NEW-CONCAVE','WPC-NEW-CONVEX']][0] AS items_involved
}

UNION ALL

// V-19: PVC Flute batten frame advisory
CALL {
  WITH panel_subcategories
  WITH panel_subcategories
  WHERE 'PVC_FLUTE' IN panel_subcategories
  MATCH (r:Rule {id:'V-19'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'PVC_FLUTE' AS items_involved
}

UNION ALL

// V-20: SPC sheet backing board recommendation
CALL {
  WITH panel_skus, consumable_skus
  WITH panel_skus, consumable_skus
  WHERE 'SHT-SPC' IN panel_skus AND NOT 'CONS-PVC10' IN consumable_skus
  MATCH (r:Rule {id:'V-20'})
  RETURN r.id AS rule_id, r.severity AS severity, r.name AS name,
         r.message AS message, r.action AS action, 'CONS-PVC10' AS items_involved
}

UNION ALL

// TWO_ZONE_DIVIDER: Metal T trim required between zones
CALL {
  WITH cart, trim_skus
  WITH cart, trim_skus
  WHERE cart.is_two_zone = true AND NOT 'TR-MET-T' IN trim_skus
  MATCH (r:Rule {id:'TWO_ZONE_DIVIDER'})
  RETURN r.id AS rule_id, r.severity AS severity, r.id AS name,
         r.description AS message, r.action AS action, 'TR-MET-T' AS items_involved
}

UNION ALL

// TWO_ZONE_LED_DIVIDER: Prefer aluminium channel when LED present
CALL {
  WITH cart, led_profile_skus, trim_skus
  WITH cart, led_profile_skus, trim_skus
  WHERE cart.is_two_zone = true
        AND size(led_profile_skus) > 0
        AND NOT 'TR-MET-CHANNEL' IN trim_skus
  MATCH (r:Rule {id:'TWO_ZONE_LED_DIVIDER'})
  RETURN r.id AS rule_id, r.severity AS severity, r.id AS name,
         r.description AS message, r.action AS action, 'TR-MET-CHANNEL' AS items_involved
}

UNION ALL

// SKIRTING_RULE: Suggest skirting when panels reach floor
CALL {
  WITH cart, trim_skus
  WITH cart, trim_skus
  WHERE cart.panels_reach_floor = true AND NOT 'TR-SKIRTING' IN trim_skus
  MATCH (r:Rule {id:'SKIRTING_RULE'})
  RETURN r.id AS rule_id, r.severity AS severity, r.id AS name,
         r.description AS message, r.action AS action, 'TR-SKIRTING' AS items_involved
}

UNION ALL

// WATERPROOF_ENFORCEMENT: Warn on non-waterproof panel in wet room
CALL {
  WITH cart, panel_skus
  WITH cart, panel_skus
  WHERE cart.room_type IN ['bathroom','kitchen']
  MATCH (r:Rule {id:'WATERPROOF_ENFORCEMENT'})
  WITH r, panel_skus, r.non_rated_skus AS non_rated
  WITH r, [s IN panel_skus WHERE s IN non_rated] AS bad_skus
  WHERE size(bad_skus) > 0
  RETURN r.id AS rule_id, r.severity AS severity, r.id AS name,
         r.description AS message, r.action AS action, bad_skus[0] AS items_involved
};


// ============================================================================
// END OF VALIDATION ENGINE
// ============================================================================
