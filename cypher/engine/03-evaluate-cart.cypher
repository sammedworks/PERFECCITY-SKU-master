// ============================================================================
// EVALUATE CART — Single-Call Endpoint (V1.0)
// ============================================================================
// One query → returns the full cart evaluation:
//   { pass_fail, error_count, warning_count, info_count,
//     violations[], suggested_consumables[], suggested_trims[] }
//
// This is the query your backend calls. It combines validation + BOM into
// a single result payload.
//
// Input parameter: $cartId (String)
//
// Usage:
//   :param cartId => 'my-cart-001'
//   // run this file → get one result row with everything
//
// ============================================================================


// ── Step 1: Collect cart state ───────────────────────────────────────────────

MATCH (cart:Cart {id: $cartId})-[:CONTAINS_ITEM]->(ci:CartItem)
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

// Get panel details
OPTIONAL MATCH (p:Panel) WHERE p.sku IN panel_skus
WITH cart, all_items, all_skus, panel_skus, trim_skus, consumable_skus,
     led_profile_skus, led_strip_skus, led_kit_skus, furniture_skus,
     collect(DISTINCT p.subcategory) AS panel_subcategories,
     collect(DISTINCT p) AS cart_panels


// ── Step 2: Run all validation rules ────────────────────────────────────────
// Each CALL block evaluates one rule and returns 0 or 1 violation row.

// Collect violations into a list using subqueries
CALL {
  WITH consumable_skus, panel_subcategories, panel_skus, trim_skus,
       led_profile_skus, led_strip_skus, led_kit_skus, all_skus, all_items,
       cart, furniture_skus

  // V-01
  CALL {
    WITH consumable_skus, panel_subcategories
    WITH consumable_skus, panel_subcategories
    WHERE 'PVC_FLUTE' IN panel_subcategories AND 'CONS-CLIP50' IN consumable_skus
    RETURN 'V-01' AS rid, 'ERROR' AS sev, 'PVC Flute cannot use clips' AS msg, 'remove_from_cart("CONS-CLIP50")' AS act, 'CONS-CLIP50' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-02
  CALL {
    WITH consumable_skus, panel_subcategories
    WITH consumable_skus, panel_subcategories
    WHERE 'CHARCOAL' IN panel_subcategories AND 'CONS-CLIP50' IN consumable_skus
    RETURN 'V-02' AS rid, 'ERROR' AS sev, 'Charcoal cannot use clips' AS msg, 'remove_from_cart("CONS-CLIP50")' AS act, 'CONS-CLIP50' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-03
  CALL {
    WITH consumable_skus, panel_skus
    WITH consumable_skus, panel_skus
    WHERE 'CONS-CLIP50' IN consumable_skus AND any(s IN panel_skus WHERE s IN ['SHT-UV-MARBLE','SHT-SPC'])
    RETURN 'V-03' AS rid, 'ERROR' AS sev, 'UV/SPC sheets must not use clips' AS msg, 'remove_from_cart("CONS-CLIP50")' AS act, 'CONS-CLIP50' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-04
  CALL {
    WITH panel_skus, trim_skus
    WITH panel_skus, trim_skus
    WHERE 'SHT-WPC-GROOVED-7MM' IN panel_skus AND 'TR-H-BIDDING' IN trim_skus AND NOT 'TR-WPC-H-TRIM' IN trim_skus
    RETURN 'V-04' AS rid, 'ERROR' AS sev, 'Grooved WPC sheet requires specific H-Trim' AS msg, 'swap_in_cart("TR-H-BIDDING","TR-WPC-H-TRIM")' AS act, 'TR-H-BIDDING' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-05
  CALL {
    WITH panel_subcategories, trim_skus
    WITH panel_subcategories, trim_skus
    WHERE 'CHARCOAL' IN panel_subcategories
      AND any(t IN trim_skus WHERE t IN ['TR-U-FLORAL','TR-U-TEXTURE','TR-U-STONE','TR-U-TRAD','TR-U-GEOM','TR-U-WOOD','TR-U-SHEET','TR-L-NEUTRAL','TR-L-WOOD','TR-L-SHEET','TR-L-WPC-NEW','TR-L-WPC-CER'])
    RETURN 'V-05' AS rid, 'WARNING' AS sev, 'Charcoal does not support standard bidding trims' AS msg, 'prompt_removal' AS act, 'CHARCOAL+PVC_TRIM' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-06
  CALL {
    WITH panel_subcategories, trim_skus
    WITH panel_subcategories, trim_skus
    WHERE 'CHARCOAL' IN panel_subcategories AND 'TR-H-BIDDING' IN trim_skus
    RETURN 'V-06' AS rid, 'ERROR' AS sev, 'Charcoal does not use H-Bidding joiner' AS msg, 'remove_from_cart("TR-H-BIDDING")' AS act, 'TR-H-BIDDING' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-07
  CALL {
    WITH all_skus
    WITH all_skus
    MATCH (prod) WHERE (prod:Panel OR prod:Trim OR prod:Consumable OR prod:LEDProfile OR prod:LEDStrip OR prod:LEDKit OR prod:Furniture)
      AND prod.sku IN all_skus AND prod.availability = 'ON_REQUEST'
    WITH collect(prod.sku) AS bad WHERE size(bad) > 0
    RETURN 'V-07' AS rid, 'ERROR' AS sev, 'On-Request product blocks automated quote' AS msg, 'block_quote_generation' AS act, bad[0] AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-08
  CALL {
    WITH led_profile_skus, led_strip_skus, led_kit_skus
    WITH led_profile_skus, led_strip_skus, led_kit_skus
    WHERE size(led_profile_skus) > 0 AND size(led_strip_skus) = 0 AND size(led_kit_skus) = 0
    RETURN 'V-08' AS rid, 'WARNING' AS sev, 'LED profile without LED strip or kit' AS msg, 'prompt_add_led_strip' AS act, led_profile_skus[0] AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-09
  CALL {
    WITH trim_skus, panel_subcategories
    WITH trim_skus, panel_subcategories
    WHERE 'TR-L-WPC-NEW' IN trim_skus AND NOT 'WPC_NEW' IN panel_subcategories
    RETURN 'V-09' AS rid, 'WARNING' AS sev, 'WPC L Bidding New without WPC New panel' AS msg, 'prompt_confirm' AS act, 'TR-L-WPC-NEW' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-10
  CALL {
    WITH led_profile_skus, panel_subcategories
    WITH led_profile_skus, panel_subcategories
    WHERE 'LED-PROF-FLUTED' IN led_profile_skus AND NOT 'PVC_FLUTE' IN panel_subcategories
    RETURN 'V-10' AS rid, 'WARNING' AS sev, 'Fluted LED profile without PVC Flute panel' AS msg, 'prompt_confirm' AS act, 'LED-PROF-FLUTED' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-11
  CALL {
    WITH led_profile_skus, panel_subcategories
    WITH led_profile_skus, panel_subcategories
    WHERE 'LED-PROF-CER' IN led_profile_skus AND NOT 'WPC_CERAMIC' IN panel_subcategories
    RETURN 'V-11' AS rid, 'WARNING' AS sev, 'Ceramic LED profile without WPC Ceramic panel' AS msg, 'prompt_confirm' AS act, 'LED-PROF-CER' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-12
  CALL {
    WITH cart, panel_skus
    WITH cart, panel_skus
    WHERE cart.room_type IN ['bathroom','kitchen']
    WITH panel_skus, ['CH-CL2','CH-MINCONC-SM','CH-CLASSIC-NEW','CH-CONCAVE','CH-FLUTED','CH-MINRECT','CH-MINCONC-PREM','SHT-METALLIC','SHT-WPC-5MM','SHT-WPC-GROOVED-7MM'] AS non_rated
    WITH [s IN panel_skus WHERE s IN non_rated] AS bad WHERE size(bad) > 0
    RETURN 'V-12' AS rid, 'WARNING' AS sev, 'Non-waterproof panel in wet room' AS msg, 'show_warning_badge' AS act, bad[0] AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-13
  CALL {
    WITH all_items
    UNWIND all_items AS ci
    WITH ci WHERE ci.item_type = 'FURNITURE' AND ci.sku IN ['TV-PF-PUREOPEN','TV-PF-MODUFIT','TV-PF-LEAFLEDGE'] AND ci.width_ft IS NOT NULL AND ci.width_ft < 6
    RETURN 'V-13' AS rid, 'ERROR' AS sev, 'PF TV Unit requires minimum 6ft width' AS msg, 'disable_width_options([4,5])' AS act, ci.sku AS inv LIMIT 1
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-14
  CALL {
    WITH all_items
    UNWIND all_items AS ci
    WITH ci WHERE ci.item_type = 'FURNITURE' AND ci.sku = 'TV-GL' AND ci.width_ft IS NOT NULL AND ci.width_ft >= 8
    RETURN 'V-14' AS rid, 'ERROR' AS sev, 'GrooveLine TV Unit max 7ft' AS msg, 'disable_width_option(8)' AS act, ci.sku AS inv LIMIT 1
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-15
  CALL {
    WITH cart, panel_skus
    WITH cart, panel_skus
    WHERE cart.room_type = 'ceiling' AND size(panel_skus) > 0 AND NOT 'SHT-WPC-5MM' IN panel_skus
    RETURN 'V-15' AS rid, 'WARNING' AS sev, 'Ceiling use — non-rated sheet selected' AS msg, 'show_info' AS act, panel_skus[0] AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-16
  CALL {
    WITH all_skus
    WITH all_skus
    WHERE size(all_skus) > 0 AND NOT 'CONS-POLYFIX' IN all_skus
    RETURN 'V-16' AS rid, 'WARNING' AS sev, 'Polyfix missing from cart' AS msg, 'prompt_add("CONS-POLYFIX", 1)' AS act, 'CONS-POLYFIX' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-17
  CALL {
    WITH all_skus
    WITH all_skus
    WHERE 'CAB-OH-1.5FT-INSTALL' IN all_skus
    RETURN 'V-17' AS rid, 'INFO' AS sev, 'Install-only cabinet advisory' AS msg, 'show_info' AS act, 'CAB-OH-1.5FT-INSTALL' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-18
  CALL {
    WITH panel_skus
    WITH panel_skus
    WHERE any(s IN panel_skus WHERE s IN ['WPC-NEW-CONCAVE','WPC-NEW-CONVEX'])
    RETURN 'V-18' AS rid, 'INFO' AS sev, '3D curved panel measurement advisory' AS msg, 'show_measurement_advisory' AS act, [s IN panel_skus WHERE s IN ['WPC-NEW-CONCAVE','WPC-NEW-CONVEX']][0] AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-19
  CALL {
    WITH panel_subcategories
    WITH panel_subcategories
    WHERE 'PVC_FLUTE' IN panel_subcategories
    RETURN 'V-19' AS rid, 'INFO' AS sev, 'PVC Flute batten frame advisory' AS msg, 'show_advisory' AS act, 'PVC_FLUTE' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // V-20
  CALL {
    WITH panel_skus, consumable_skus
    WITH panel_skus, consumable_skus
    WHERE 'SHT-SPC' IN panel_skus AND NOT 'CONS-PVC10' IN consumable_skus
    RETURN 'V-20' AS rid, 'WARNING' AS sev, 'SPC sheet backing board recommendation' AS msg, 'prompt_add("CONS-PVC10")' AS act, 'CONS-PVC10' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // TWO_ZONE_DIVIDER
  CALL {
    WITH cart, trim_skus
    WITH cart, trim_skus
    WHERE cart.is_two_zone = true AND NOT 'TR-MET-T' IN trim_skus
    RETURN 'TWO_ZONE_DIVIDER' AS rid, 'INFO' AS sev, 'Metal T trim required between zones' AS msg, 'auto_add("TR-MET-T")' AS act, 'TR-MET-T' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // SKIRTING
  CALL {
    WITH cart, trim_skus
    WITH cart, trim_skus
    WHERE cart.panels_reach_floor = true AND NOT 'TR-SKIRTING' IN trim_skus
    RETURN 'SKIRTING_RULE' AS rid, 'INFO' AS sev, 'Panels reach floor — add skirting' AS msg, 'prompt_suggest("TR-SKIRTING")' AS act, 'TR-SKIRTING' AS inv
  }
  RETURN rid, sev, msg, act, inv

  UNION ALL

  // WATERPROOF_ENFORCEMENT
  CALL {
    WITH cart, panel_skus
    WITH cart, panel_skus
    WHERE cart.room_type IN ['bathroom','kitchen']
    WITH panel_skus, ['CH-CL2','CH-MINCONC-SM','CH-CLASSIC-NEW','CH-CONCAVE','CH-FLUTED','CH-MINRECT','CH-MINCONC-PREM','SHT-METALLIC','SHT-WPC-5MM','SHT-WPC-GROOVED-7MM'] AS non_rated
    WITH [s IN panel_skus WHERE s IN non_rated] AS bad WHERE size(bad) > 0
    RETURN 'WATERPROOF_ENFORCEMENT' AS rid, 'WARNING' AS sev, 'Panel not rated for wet environments' AS msg, 'show_warning' AS act, bad[0] AS inv
  }
  RETURN rid, sev, msg, act, inv
}

// ── Step 3: Aggregate violations + compute pass/fail ────────────────────────
WITH cart, all_items, all_skus, panel_skus, trim_skus, consumable_skus,
     led_profile_skus, cart_panels, panel_subcategories,
     collect({rule_id: rid, severity: sev, message: msg, action: act, item: inv}) AS violations

WITH cart, all_items, all_skus, panel_skus, trim_skus, consumable_skus,
     led_profile_skus, cart_panels, panel_subcategories,
     [v IN violations WHERE v.rule_id IS NOT NULL] AS violations

WITH cart, all_items, all_skus, panel_skus, cart_panels, panel_subcategories,
     violations,
     size([v IN violations WHERE v.severity = 'ERROR']) AS error_count,
     size([v IN violations WHERE v.severity = 'WARNING']) AS warning_count,
     size([v IN violations WHERE v.severity = 'INFO']) AS info_count


// ── Step 4: Build BOM (suggested consumables per panel) ─────────────────────

CALL {
  WITH cart_panels, cart
  UNWIND cart_panels AS panel
  MATCH (panel)-[:BELONGS_TO]->(subcat:Subcategory)
  OPTIONAL MATCH (pr:Rule {type:'INSTALLATION_CONTRACT'})-[:APPLIES_TO]->(panel)
  OPTIONAL MATCH (sr:Rule {type:'INSTALLATION_CONTRACT'})-[:APPLIES_TO]->(subcat)
  WITH panel, CASE WHEN pr IS NOT NULL THEN pr ELSE sr END AS contract
  OPTIONAL MATCH (contract)-[:REQUIRES_CONSUMABLE]->(rc:Consumable)
  WITH panel, contract, collect(DISTINCT {sku: rc.sku, name: rc.name, price: rc.price, status: 'REQUIRED'}) AS req
  OPTIONAL MATCH (contract)-[opt:OPTIONAL_CONSUMABLE]->(oc:Consumable)
  WITH panel, contract, req, collect(DISTINCT {sku: oc.sku, name: oc.name, price: oc.price, condition: opt.condition, status: 'OPTIONAL'}) AS optl
  RETURN collect({
    panel_sku: panel.sku,
    install_method: contract.method,
    required: [r IN req WHERE r.sku IS NOT NULL],
    optional: [o IN optl WHERE o.sku IS NOT NULL]
  }) AS bom_consumables
}

// ── Step 5: Build suggested trims per panel ─────────────────────────────────

CALL {
  WITH cart_panels
  UNWIND cart_panels AS panel
  OPTIONAL MATCH (panel)-[ru:HAS_U_TRIM]->(ut:Trim)
  OPTIONAL MATCH (panel)-[rl:HAS_L_TRIM]->(lt:Trim)
  OPTIONAL MATCH (panel)-[rh:HAS_H_TRIM]->(ht:Trim)
  WITH panel,
       collect(DISTINCT CASE WHEN ut IS NOT NULL THEN {sku:ut.sku, name:ut.name, price:ut.price, type:'U', suggestion:ru.relationship_type} END) AS u,
       collect(DISTINCT CASE WHEN lt IS NOT NULL THEN {sku:lt.sku, name:lt.name, price:lt.price, type:'L', suggestion:rl.relationship_type} END) AS l,
       collect(DISTINCT CASE WHEN ht IS NOT NULL THEN {sku:ht.sku, name:ht.name, price:ht.price, type:'H', suggestion:rh.relationship_type} END) AS h
  RETURN collect({
    panel_sku: panel.sku,
    trims: [t IN u + l + h WHERE t IS NOT NULL]
  }) AS bom_trims
}


// ── Step 6: Return final result ─────────────────────────────────────────────

RETURN
  cart.id                                       AS cart_id,
  cart.room_type                                AS room_type,
  CASE WHEN error_count = 0 THEN 'PASS' ELSE 'FAIL' END AS pass_fail,
  error_count,
  warning_count,
  info_count,
  violations,
  bom_consumables,
  bom_trims;


// ============================================================================
// END OF EVALUATE CART
// ============================================================================
