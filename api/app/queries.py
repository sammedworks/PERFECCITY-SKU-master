"""Cypher query strings used by the service layer."""

# ── Catalog ──────────────────────────────────────────────────────────────────

PANELS_BY_SUBCATEGORY = """
MATCH (p:Panel)
WHERE ($subcategory IS NULL OR p.subcategory = $subcategory)
  AND ($availability IS NULL OR p.availability = $availability)
  AND p.availability <> 'UNAVAILABLE'
RETURN p ORDER BY p.subcategory, p.name
"""

ALL_TRIMS = """
MATCH (t:Trim)
WHERE ($subcategory IS NULL OR t.subcategory = $subcategory)
RETURN t ORDER BY t.subcategory, t.name
"""

ALL_CONSUMABLES = """
MATCH (c:Consumable) RETURN c ORDER BY c.name
"""

ALL_LED_PROFILES = """
MATCH (lp:LEDProfile) RETURN lp ORDER BY lp.name
"""

LED_STRIPS_AND_KITS = """
MATCH (n) WHERE n:LEDStrip OR n:LEDKit RETURN n ORDER BY labels(n)[0], n.name
"""

ALL_FURNITURE = """
MATCH (f:Furniture)
WHERE ($subcategory IS NULL OR f.subcategory = $subcategory)
  AND f.availability <> 'UNAVAILABLE'
RETURN f ORDER BY f.subcategory, f.name
"""

PANEL_ACCESSORIES = """
MATCH (p:Panel {sku: $panelSku})
OPTIONAL MATCH (p)-[ru:HAS_U_TRIM]->(ut:Trim)
OPTIONAL MATCH (p)-[rl:HAS_L_TRIM]->(lt:Trim)
OPTIONAL MATCH (p)-[rh:HAS_H_TRIM]->(ht:Trim)
OPTIONAL MATCH (p)-[rm:HAS_METAL_TRIM]->(mt:Trim)
OPTIONAL MATCH (p)-[rd:HAS_DEDICATED_LED]->(dlp:LEDProfile)
OPTIONAL MATCH (p)-[rc:COMPATIBLE_LED]->(ulp:LEDProfile)
RETURN p,
  collect(DISTINCT {sku:ut.sku, name:ut.name, price:ut.price, type:'U', suggestion:ru.relationship_type}) AS u_trims,
  collect(DISTINCT {sku:lt.sku, name:lt.name, price:lt.price, type:'L', suggestion:rl.relationship_type}) AS l_trims,
  collect(DISTINCT {sku:ht.sku, name:ht.name, price:ht.price, type:'H', suggestion:rh.relationship_type}) AS h_trims,
  collect(DISTINCT {sku:mt.sku, name:mt.name, price:mt.price, type:'METAL', suggestion:rm.relationship_type}) AS metal_trims,
  collect(DISTINCT {sku:dlp.sku, name:dlp.name, price:dlp.price, type:'DEDICATED', priority:rd.priority}) AS dedicated_led,
  collect(DISTINCT {sku:ulp.sku, name:ulp.name, price:ulp.price, type:'UNIVERSAL', priority:rc.priority}) AS universal_led
"""

# ── Cart Management ──────────────────────────────────────────────────────────

CREATE_CART = """
MERGE (c:Cart {id: $cartId})
SET c.status = 'DRAFT',
    c.room_type = $roomType,
    c.is_two_zone = $isTwoZone,
    c.panels_reach_floor = $panelsReachFloor,
    c.wall_width_mm = $wallWidthMm,
    c.wall_height_mm = $wallHeightMm,
    c.created_at = CASE WHEN c.created_at IS NULL THEN datetime() ELSE c.created_at END,
    c.updated_at = datetime()
RETURN c
"""

ADD_CART_ITEM = """
MATCH (c:Cart {id: $cartId})
MERGE (ci:CartItem {id: $itemId})
SET ci.sku = $sku,
    ci.item_type = $itemType,
    ci.quantity = $quantity,
    ci.unit_price = $unitPrice,
    ci.source = $source,
    ci.width_ft = $widthFt,
    ci.zone = $zone
MERGE (c)-[:CONTAINS_ITEM]->(ci)
WITH ci
OPTIONAL MATCH (product)
  WHERE (product:Panel OR product:Trim OR product:Consumable
    OR product:LEDProfile OR product:LEDStrip OR product:LEDKit OR product:Furniture)
  AND product.sku = ci.sku
FOREACH (_ IN CASE WHEN product IS NOT NULL THEN [1] ELSE [] END |
  MERGE (ci)-[:REFERENCES]->(product)
)
WITH ci
OPTIONAL MATCH (product) WHERE (product:Panel OR product:Trim OR product:Consumable
  OR product:LEDProfile OR product:LEDStrip OR product:LEDKit OR product:Furniture)
  AND product.sku = ci.sku
SET ci.unit_price = CASE WHEN ci.unit_price IS NULL AND product IS NOT NULL THEN product.price ELSE ci.unit_price END
RETURN ci
"""

REMOVE_CART_ITEM = """
MATCH (c:Cart {id: $cartId})-[:CONTAINS_ITEM]->(ci:CartItem {id: $itemId})
DETACH DELETE ci
RETURN count(*) AS removed
"""

GET_CART = """
MATCH (c:Cart {id: $cartId})
OPTIONAL MATCH (c)-[:CONTAINS_ITEM]->(ci:CartItem)
RETURN c, collect(ci) AS items
"""

DELETE_CART = """
MATCH (c:Cart {id: $cartId})
OPTIONAL MATCH (c)-[:CONTAINS_ITEM]->(ci:CartItem)
DETACH DELETE ci, c
RETURN count(*) AS deleted
"""

# ── Validation Engine ────────────────────────────────────────────────────────

VALIDATE_CART = """
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

OPTIONAL MATCH (p:Panel) WHERE p.sku IN panel_skus
WITH cart, all_items, all_skus, panel_skus, trim_skus, consumable_skus,
     led_profile_skus, led_strip_skus, led_kit_skus, furniture_skus,
     collect(DISTINCT p.subcategory) AS panel_subcategories

// Evaluate rules via CALL {} subqueries
CALL {
  WITH consumable_skus, panel_subcategories, panel_skus, trim_skus,
       led_profile_skus, led_strip_skus, led_kit_skus, all_skus, all_items,
       cart, furniture_skus

  CALL { WITH consumable_skus, panel_subcategories WITH consumable_skus, panel_subcategories WHERE 'PVC_FLUTE' IN panel_subcategories AND 'CONS-CLIP50' IN consumable_skus RETURN 'V-01' AS rid, 'ERROR' AS sev, 'PVC Flute panels cannot use clips. Remove clips from your order.' AS msg, 'remove_from_cart("CONS-CLIP50")' AS act, 'CONS-CLIP50' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH consumable_skus, panel_subcategories WITH consumable_skus, panel_subcategories WHERE 'CHARCOAL' IN panel_subcategories AND 'CONS-CLIP50' IN consumable_skus RETURN 'V-02' AS rid, 'ERROR' AS sev, 'Charcoal panels use silicon glue only. Remove clips from your order.' AS msg, 'remove_from_cart("CONS-CLIP50")' AS act, 'CONS-CLIP50' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH consumable_skus, panel_skus WITH consumable_skus, panel_skus WHERE 'CONS-CLIP50' IN consumable_skus AND any(s IN panel_skus WHERE s IN ['SHT-UV-MARBLE','SHT-SPC']) RETURN 'V-03' AS rid, 'ERROR' AS sev, 'UV and SPC sheets use silicon glue, not clips. Remove clips from your order.' AS msg, 'remove_from_cart("CONS-CLIP50")' AS act, 'CONS-CLIP50' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH panel_skus, trim_skus WITH panel_skus, trim_skus WHERE 'SHT-WPC-GROOVED-7MM' IN panel_skus AND 'TR-H-BIDDING' IN trim_skus AND NOT 'TR-WPC-H-TRIM' IN trim_skus RETURN 'V-04' AS rid, 'ERROR' AS sev, 'Grooved WPC sheets require TR-WPC-H-TRIM as the joiner, not standard H Bidding. Swapping automatically.' AS msg, 'swap_in_cart("TR-H-BIDDING","TR-WPC-H-TRIM")' AS act, 'TR-H-BIDDING' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH panel_subcategories, trim_skus WITH panel_subcategories, trim_skus WHERE 'CHARCOAL' IN panel_subcategories AND any(t IN trim_skus WHERE t IN ['TR-U-FLORAL','TR-U-TEXTURE','TR-U-STONE','TR-U-TRAD','TR-U-GEOM','TR-U-WOOD','TR-U-SHEET','TR-L-NEUTRAL','TR-L-WOOD','TR-L-SHEET','TR-L-WPC-NEW','TR-L-WPC-CER']) RETURN 'V-05' AS rid, 'WARNING' AS sev, 'Standard bidding trims are not designed for Charcoal. Only metal trims apply. Remove incompatible trims?' AS msg, 'prompt_removal' AS act, 'CHARCOAL+PVC_TRIM' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH panel_subcategories, trim_skus WITH panel_subcategories, trim_skus WHERE 'CHARCOAL' IN panel_subcategories AND 'TR-H-BIDDING' IN trim_skus RETURN 'V-06' AS rid, 'ERROR' AS sev, 'Charcoal panels are butt-jointed with silicon glue. H-Bidding joiner is not applicable.' AS msg, 'remove_from_cart("TR-H-BIDDING")' AS act, 'TR-H-BIDDING' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH all_skus WITH all_skus MATCH (prod) WHERE (prod:Panel OR prod:Trim OR prod:Consumable OR prod:LEDProfile OR prod:LEDStrip OR prod:LEDKit OR prod:Furniture) AND prod.sku IN all_skus AND prod.availability = 'ON_REQUEST' WITH collect(prod.sku) AS bad WHERE size(bad) > 0 RETURN 'V-07' AS rid, 'ERROR' AS sev, 'One or more items are available on custom order only and cannot be in an automated quote.' AS msg, 'block_quote_generation' AS act, bad[0] AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH led_profile_skus, led_strip_skus, led_kit_skus WITH led_profile_skus, led_strip_skus, led_kit_skus WHERE size(led_profile_skus) > 0 AND size(led_strip_skus) = 0 AND size(led_kit_skus) = 0 RETURN 'V-08' AS rid, 'WARNING' AS sev, 'You have an LED profile but no LED strip or kit. Your lighting setup will be incomplete.' AS msg, 'prompt_add_led_strip' AS act, led_profile_skus[0] AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH trim_skus, panel_subcategories WITH trim_skus, panel_subcategories WHERE 'TR-L-WPC-NEW' IN trim_skus AND NOT 'WPC_NEW' IN panel_subcategories RETURN 'V-09' AS rid, 'WARNING' AS sev, 'WPC L Bidding New is designed for WPC New panels. Is this intentional?' AS msg, 'prompt_confirm' AS act, 'TR-L-WPC-NEW' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH led_profile_skus, panel_subcategories WITH led_profile_skus, panel_subcategories WHERE 'LED-PROF-FLUTED' IN led_profile_skus AND NOT 'PVC_FLUTE' IN panel_subcategories RETURN 'V-10' AS rid, 'WARNING' AS sev, 'Fluted LED Profile is designed for PVC Flute panels. Is this correct?' AS msg, 'prompt_confirm' AS act, 'LED-PROF-FLUTED' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH led_profile_skus, panel_subcategories WITH led_profile_skus, panel_subcategories WHERE 'LED-PROF-CER' IN led_profile_skus AND NOT 'WPC_CERAMIC' IN panel_subcategories RETURN 'V-11' AS rid, 'WARNING' AS sev, 'Ceramic LED Profile is designed for WPC Ceramic panels. Is this correct?' AS msg, 'prompt_confirm' AS act, 'LED-PROF-CER' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH cart, panel_skus WITH cart, panel_skus WHERE cart.room_type IN ['bathroom','kitchen'] WITH panel_skus, ['CH-CL2','CH-MINCONC-SM','CH-CLASSIC-NEW','CH-CONCAVE','CH-FLUTED','CH-MINRECT','CH-MINCONC-PREM','SHT-METALLIC','SHT-WPC-5MM','SHT-WPC-GROOVED-7MM'] AS non_rated WITH [s IN panel_skus WHERE s IN non_rated] AS bad WHERE size(bad) > 0 RETURN 'V-12' AS rid, 'WARNING' AS sev, 'This panel is not rated for wet environments. Recommend waterproof alternatives.' AS msg, 'show_warning_badge' AS act, bad[0] AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH all_items UNWIND all_items AS ci WITH ci WHERE ci.item_type = 'FURNITURE' AND ci.sku IN ['TV-PF-PUREOPEN','TV-PF-MODUFIT','TV-PF-LEAFLEDGE'] AND ci.width_ft IS NOT NULL AND ci.width_ft < 6 RETURN 'V-13' AS rid, 'ERROR' AS sev, 'This TV unit is only available from 6 ft. Please select 6-8 ft.' AS msg, 'disable_width_options([4,5])' AS act, ci.sku AS inv LIMIT 1 } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH all_items UNWIND all_items AS ci WITH ci WHERE ci.item_type = 'FURNITURE' AND ci.sku = 'TV-GL' AND ci.width_ft IS NOT NULL AND ci.width_ft >= 8 RETURN 'V-14' AS rid, 'ERROR' AS sev, 'GrooveLine TV Units are available up to 7 ft only.' AS msg, 'disable_width_option(8)' AS act, ci.sku AS inv LIMIT 1 } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH cart, panel_skus WITH cart, panel_skus WHERE cart.room_type = 'ceiling' AND size(panel_skus) > 0 AND NOT 'SHT-WPC-5MM' IN panel_skus RETURN 'V-15' AS rid, 'WARNING' AS sev, 'For ceiling use, WPC Sheet 5mm is the only rated option.' AS msg, 'show_info' AS act, panel_skus[0] AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH all_skus WITH all_skus WHERE size(all_skus) > 0 AND NOT 'CONS-POLYFIX' IN all_skus RETURN 'V-16' AS rid, 'WARNING' AS sev, 'Polyfix joint filler is recommended for every installation. Add 1 tube?' AS msg, 'prompt_add("CONS-POLYFIX", 1)' AS act, 'CONS-POLYFIX' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH all_skus WITH all_skus WHERE 'CAB-OH-1.5FT-INSTALL' IN all_skus RETURN 'V-17' AS rid, 'INFO' AS sev, 'Cabinet installation only — the cabinet unit must be supplied by you.' AS msg, 'show_info' AS act, 'CAB-OH-1.5FT-INSTALL' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH panel_skus WITH panel_skus WHERE any(s IN panel_skus WHERE s IN ['WPC-NEW-CONCAVE','WPC-NEW-CONVEX']) RETURN 'V-18' AS rid, 'INFO' AS sev, '3D curved panels require a professional site measurement.' AS msg, 'show_measurement_advisory' AS act, [s IN panel_skus WHERE s IN ['WPC-NEW-CONCAVE','WPC-NEW-CONVEX']][0] AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH panel_subcategories WITH panel_subcategories WHERE 'PVC_FLUTE' IN panel_subcategories RETURN 'V-19' AS rid, 'INFO' AS sev, 'PVC Flute panels require a batten frame and panel adhesive. Confirm with installation team.' AS msg, 'show_advisory' AS act, 'PVC_FLUTE' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH panel_skus, consumable_skus WITH panel_skus, consumable_skus WHERE 'SHT-SPC' IN panel_skus AND NOT 'CONS-PVC10' IN consumable_skus RETURN 'V-20' AS rid, 'WARNING' AS sev, 'SPC Sheet is heavy. A 10mm PVC backing board is strongly recommended.' AS msg, 'prompt_add("CONS-PVC10")' AS act, 'CONS-PVC10' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH cart, trim_skus WITH cart, trim_skus WHERE cart.is_two_zone = true AND NOT 'TR-MET-T' IN trim_skus RETURN 'TWO_ZONE_DIVIDER' AS rid, 'INFO' AS sev, 'Metal T trim required between zones.' AS msg, 'auto_add("TR-MET-T")' AS act, 'TR-MET-T' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH cart, trim_skus WITH cart, trim_skus WHERE cart.panels_reach_floor = true AND NOT 'TR-SKIRTING' IN trim_skus RETURN 'SKIRTING_RULE' AS rid, 'INFO' AS sev, 'Panels reach floor — add skirting to finish the junction.' AS msg, 'prompt_suggest("TR-SKIRTING")' AS act, 'TR-SKIRTING' AS inv } RETURN rid, sev, msg, act, inv
  UNION ALL
  CALL { WITH cart, panel_skus WITH cart, panel_skus WHERE cart.room_type IN ['bathroom','kitchen'] WITH panel_skus, ['CH-CL2','CH-MINCONC-SM','CH-CLASSIC-NEW','CH-CONCAVE','CH-FLUTED','CH-MINRECT','CH-MINCONC-PREM','SHT-METALLIC','SHT-WPC-5MM','SHT-WPC-GROOVED-7MM'] AS non_rated WITH [s IN panel_skus WHERE s IN non_rated] AS bad WHERE size(bad) > 0 RETURN 'WATERPROOF_ENFORCEMENT' AS rid, 'WARNING' AS sev, 'Panel not rated for wet environments.' AS msg, 'show_warning' AS act, bad[0] AS inv } RETURN rid, sev, msg, act, inv
}

WITH cart, all_skus, panel_skus,
     collect({rule_id: rid, severity: sev, message: msg, action: act, item: inv}) AS raw_violations
WITH cart, all_skus, panel_skus,
     [v IN raw_violations WHERE v.rule_id IS NOT NULL] AS violations

RETURN
  cart.id AS cart_id,
  cart.room_type AS room_type,
  CASE WHEN size([v IN violations WHERE v.severity = 'ERROR']) = 0 THEN 'PASS' ELSE 'FAIL' END AS pass_fail,
  size([v IN violations WHERE v.severity = 'ERROR']) AS error_count,
  size([v IN violations WHERE v.severity = 'WARNING']) AS warning_count,
  size([v IN violations WHERE v.severity = 'INFO']) AS info_count,
  violations
"""

# ── BOM ──────────────────────────────────────────────────────────────────────

BOM_CONSUMABLES = """
MATCH (cart:Cart {id: $cartId})-[:CONTAINS_ITEM]->(ci:CartItem {item_type:'PANEL'})
MATCH (panel:Panel {sku: ci.sku})-[:BELONGS_TO]->(subcat:Subcategory)
OPTIONAL MATCH (panelRule:Rule {type:'INSTALLATION_CONTRACT'})-[:APPLIES_TO]->(panel)
OPTIONAL MATCH (subcatRule:Rule {type:'INSTALLATION_CONTRACT'})-[:APPLIES_TO]->(subcat)
WITH ci, panel, subcat, CASE WHEN panelRule IS NOT NULL THEN panelRule ELSE subcatRule END AS contract
OPTIONAL MATCH (contract)-[req:REQUIRES_CONSUMABLE]->(rc:Consumable)
WITH ci, panel, contract, collect(DISTINCT {sku:rc.sku, name:rc.name, price:rc.price, status:'REQUIRED'}) AS required
OPTIONAL MATCH (contract)-[opt:OPTIONAL_CONSUMABLE]->(oc:Consumable)
WITH ci, panel, contract, required, collect(DISTINCT {sku:oc.sku, name:oc.name, price:oc.price, condition:opt.condition, status:'OPTIONAL'}) AS optional
RETURN ci.sku AS panel_sku, panel.name AS panel_name, contract.method AS install_method,
  [r IN required WHERE r.sku IS NOT NULL] AS required,
  [o IN optional WHERE o.sku IS NOT NULL] AS optional
ORDER BY ci.sku
"""

BOM_TRIMS = """
MATCH (cart:Cart {id: $cartId})-[:CONTAINS_ITEM]->(ci:CartItem {item_type:'PANEL'})
MATCH (panel:Panel {sku: ci.sku})
OPTIONAL MATCH (panel)-[ru:HAS_U_TRIM]->(ut:Trim)
OPTIONAL MATCH (panel)-[rl:HAS_L_TRIM]->(lt:Trim)
OPTIONAL MATCH (panel)-[rh:HAS_H_TRIM]->(ht:Trim)
WITH ci, panel,
  collect(DISTINCT CASE WHEN ut IS NOT NULL THEN {sku:ut.sku, name:ut.name, price:ut.price, type:'U', suggestion:ru.relationship_type} END) AS u,
  collect(DISTINCT CASE WHEN lt IS NOT NULL THEN {sku:lt.sku, name:lt.name, price:lt.price, type:'L', suggestion:rl.relationship_type} END) AS l,
  collect(DISTINCT CASE WHEN ht IS NOT NULL THEN {sku:ht.sku, name:ht.name, price:ht.price, type:'H', suggestion:rh.relationship_type} END) AS h
RETURN ci.sku AS panel_sku, [t IN u + l + h WHERE t IS NOT NULL] AS trims
ORDER BY ci.sku
"""

# ── Defaults / Room Affinity ─────────────────────────────────────────────────

DEFAULT_PANEL_FOR_ROOM = """
MATCH (r:Rule {id:'DEFAULT_SELECTION_BY_ROOM'})
WITH r.defaults AS defaults_json
CALL {
  WITH defaults_json
  // Parse the JSON manually — no APOC needed
  RETURN defaults_json AS raw
}
WITH raw
RETURN raw
"""

ROOM_RANKED_PANELS = """
MATCH (p:Panel)
WHERE p.availability IN ['AVAILABLE','NEW','PREMIUM']
RETURN p.sku AS sku, p.name AS name, p.price AS price, p.subcategory AS subcategory,
       p.availability AS availability, p.room_affinity AS room_affinity, p.default_selection AS default_selection
ORDER BY p.name
"""
