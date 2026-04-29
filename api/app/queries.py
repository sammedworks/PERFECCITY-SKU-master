"""Cypher query strings used by the service layer."""

# ── Catalog ──────────────────────────────────────────────────────────────────

PANELS_BY_SUBCATEGORY = """
MATCH (p:Panel)
WHERE ($subcategory IS NULL OR p.subcategory = $subcategory)
  AND ($availability IS NULL OR p.availability = $availability)
  AND p.availability <> 'UNAVAILABLE'
RETURN p ORDER BY p.subcategory, p.name
SKIP $skip LIMIT $limit
"""

ALL_TRIMS = """
MATCH (t:Trim)
WHERE ($subcategory IS NULL OR t.subcategory = $subcategory)
RETURN t ORDER BY t.subcategory, t.name
SKIP $skip LIMIT $limit
"""

ALL_CONSUMABLES = """
MATCH (c:Consumable) RETURN c ORDER BY c.name
SKIP $skip LIMIT $limit
"""

ALL_LED_PROFILES = """
MATCH (lp:LEDProfile) RETURN lp ORDER BY lp.name
SKIP $skip LIMIT $limit
"""

LED_STRIPS_AND_KITS = """
MATCH (n) WHERE n:LEDStrip OR n:LEDKit RETURN n ORDER BY labels(n)[0], n.name
SKIP $skip LIMIT $limit
"""

ALL_FURNITURE = """
MATCH (f:Furniture)
WHERE ($subcategory IS NULL OR f.subcategory = $subcategory)
  AND f.availability <> 'UNAVAILABLE'
RETURN f ORDER BY f.subcategory, f.name
SKIP $skip LIMIT $limit
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

RESOLVE_PRODUCT = """
MATCH (product)
WHERE (product:Panel OR product:Trim OR product:Consumable
  OR product:LEDProfile OR product:LEDStrip OR product:LEDKit OR product:Furniture)
  AND product.sku = $sku
RETURN product.sku AS sku, product.price AS price
"""

ADD_CART_ITEM = """
MATCH (c:Cart {id: $cartId})
MATCH (product)
  WHERE (product:Panel OR product:Trim OR product:Consumable
    OR product:LEDProfile OR product:LEDStrip OR product:LEDKit OR product:Furniture)
  AND product.sku = $sku
MERGE (ci:CartItem {id: $itemId})
SET ci.sku = $sku,
    ci.item_type = $itemType,
    ci.quantity = $quantity,
    ci.unit_price = COALESCE($unitPrice, product.price),
    ci.source = $source,
    ci.width_ft = $widthFt,
    ci.zone = $zone
MERGE (c)-[:CONTAINS_ITEM]->(ci)
MERGE (ci)-[:REFERENCES]->(product)
RETURN ci
"""

ADD_CART_ITEMS_BATCH = """
MATCH (c:Cart {id: $cartId})
UNWIND $items AS item
MATCH (product)
  WHERE (product:Panel OR product:Trim OR product:Consumable
    OR product:LEDProfile OR product:LEDStrip OR product:LEDKit OR product:Furniture)
  AND product.sku = item.sku
MERGE (ci:CartItem {id: item.id})
SET ci.sku = item.sku,
    ci.item_type = item.item_type,
    ci.quantity = item.quantity,
    ci.unit_price = COALESCE(item.unit_price, product.price),
    ci.source = item.source,
    ci.width_ft = item.width_ft,
    ci.zone = item.zone
MERGE (c)-[:CONTAINS_ITEM]->(ci)
MERGE (ci)-[:REFERENCES]->(product)
RETURN collect(ci) AS items
"""

REMOVE_CART_ITEM = """
MATCH (c:Cart {id: $cartId})-[:CONTAINS_ITEM]->(ci:CartItem {id: $itemId})
DETACH DELETE ci
RETURN count(*) AS removed
"""

GET_CART = """
MATCH (c:Cart {id: $cartId})
OPTIONAL MATCH (c)-[:CONTAINS_ITEM]->(ci:CartItem)
RETURN c, [x IN collect(ci) WHERE x IS NOT NULL] AS items
"""

DELETE_CART = """
MATCH (c:Cart {id: $cartId})
OPTIONAL MATCH (c)-[:CONTAINS_ITEM]->(ci:CartItem)
DETACH DELETE ci, c
RETURN count(*) AS deleted
"""

# ── Validation Engine ────────────────────────────────────────────────────────
# Modular design: each rule group is a separate Cypher query that reads
# directly from the cart graph and returns a list of violation maps.
# Python orchestrates all groups within one Neo4j session and merges results.
#
# Groups:
#   VALIDATE_CLIPS          V-01, V-02, V-03  (clip incompatibility)
#   VALIDATE_TRIMS          V-04, V-05, V-06  (trim incompatibility)
#   VALIDATE_AVAILABILITY   V-07              (ON_REQUEST block)
#   VALIDATE_LED            V-08, V-10, V-11  (LED mismatch)
#   VALIDATE_COMPATIBILITY  V-09, V-12, V-15  (panel/room compat)
#   VALIDATE_FURNITURE      V-13, V-14        (furniture dimensions)
#   VALIDATE_CONSUMABLES    V-16, V-20        (missing consumables)
#   VALIDATE_ADVISORY       V-17, V-18, V-19  (info advisories)
#   VALIDATE_LAYOUT         two-zone, skirting, waterproof enforcement

# ── Shared preamble macro ────────────────────────────────────────────────────
# Each group query repeats this preamble to extract typed SKU lists from the
# cart. This keeps each query self-contained and independently runnable in
# Neo4j Browser or cypher-shell.

_CART_PREAMBLE = """
MATCH (cart:Cart {id: $cartId})
OPTIONAL MATCH (cart)-[:CONTAINS_ITEM]->(ci:CartItem)
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
"""

# ── Cart metadata (used by Python to build the response envelope) ────────────

CART_META = (
    _CART_PREAMBLE
    + """
RETURN cart.id AS cart_id, cart.room_type AS room_type
"""
)


# ── VALIDATE_CLIPS (V-01, V-02, V-03) ───────────────────────────────────────

VALIDATE_CLIPS = (
    _CART_PREAMBLE
    + """
WITH cart, panel_skus, consumable_skus, panel_subcategories,
     CASE WHEN 'PVC_FLUTE' IN panel_subcategories AND 'CONS-CLIP50' IN consumable_skus
       THEN [{rule_id:'V-01', severity:'ERROR',
              message:'PVC Flute panels cannot use clips. Remove clips from your order.',
              action:'remove_from_cart("CONS-CLIP50")', item:'CONS-CLIP50'}]
       ELSE [] END
   + CASE WHEN 'CHARCOAL' IN panel_subcategories AND 'CONS-CLIP50' IN consumable_skus
       THEN [{rule_id:'V-02', severity:'ERROR',
              message:'Charcoal panels use silicon glue only. Remove clips from your order.',
              action:'remove_from_cart("CONS-CLIP50")', item:'CONS-CLIP50'}]
       ELSE [] END
   + CASE WHEN 'CONS-CLIP50' IN consumable_skus
              AND any(s IN panel_skus WHERE s IN ['SHT-UV-MARBLE','SHT-SPC'])
       THEN [{rule_id:'V-03', severity:'ERROR',
              message:'UV and SPC sheets use silicon glue, not clips.',
              action:'remove_from_cart("CONS-CLIP50")', item:'CONS-CLIP50'}]
       ELSE [] END
     AS violations
RETURN violations
"""
)


# ── VALIDATE_TRIMS (V-04, V-05, V-06) ───────────────────────────────────────

VALIDATE_TRIMS = (
    _CART_PREAMBLE
    + """
WITH cart, panel_skus, trim_skus, panel_subcategories,
     CASE WHEN 'SHT-WPC-GROOVED-7MM' IN panel_skus
              AND 'TR-H-BIDDING' IN trim_skus
              AND NOT 'TR-WPC-H-TRIM' IN trim_skus
       THEN [{rule_id:'V-04', severity:'ERROR',
              message:'Grooved WPC sheets require TR-WPC-H-TRIM, not standard H Bidding.',
              action:'swap_in_cart("TR-H-BIDDING","TR-WPC-H-TRIM")', item:'TR-H-BIDDING'}]
       ELSE [] END
   + CASE WHEN 'CHARCOAL' IN panel_subcategories
              AND any(t IN trim_skus WHERE t IN [
                'TR-U-FLORAL','TR-U-TEXTURE','TR-U-STONE','TR-U-TRAD',
                'TR-U-GEOM','TR-U-WOOD','TR-U-SHEET',
                'TR-L-NEUTRAL','TR-L-WOOD','TR-L-SHEET',
                'TR-L-WPC-NEW','TR-L-WPC-CER'])
       THEN [{rule_id:'V-05', severity:'WARNING',
              message:'Standard bidding trims are not designed for Charcoal. Only metal trims apply.',
              action:'prompt_removal', item:'CHARCOAL+PVC_TRIM'}]
       ELSE [] END
   + CASE WHEN 'CHARCOAL' IN panel_subcategories AND 'TR-H-BIDDING' IN trim_skus
       THEN [{rule_id:'V-06', severity:'ERROR',
              message:'Charcoal panels are butt-jointed with silicon glue. H-Bidding not applicable.',
              action:'remove_from_cart("TR-H-BIDDING")', item:'TR-H-BIDDING'}]
       ELSE [] END
     AS violations
RETURN violations
"""
)


# ── VALIDATE_AVAILABILITY (V-07) ─────────────────────────────────────────────

VALIDATE_AVAILABILITY = (
    _CART_PREAMBLE
    + """
OPTIONAL MATCH (prod) WHERE (prod:Panel OR prod:Trim OR prod:Consumable
  OR prod:LEDProfile OR prod:LEDStrip OR prod:LEDKit OR prod:Furniture)
  AND prod.sku IN all_skus AND prod.availability = 'ON_REQUEST'
WITH collect(prod.sku) AS bad
WITH CASE WHEN size(bad) > 0
       THEN [{rule_id:'V-07', severity:'ERROR',
              message:'On-Request item blocks automated quote.',
              action:'block_quote_generation', item:bad[0]}]
       ELSE [] END AS violations
RETURN violations
"""
)


# ── VALIDATE_LED (V-08, V-10, V-11) ─────────────────────────────────────────

VALIDATE_LED = (
    _CART_PREAMBLE
    + """
WITH cart, led_profile_skus, led_strip_skus, led_kit_skus, panel_subcategories,
     CASE WHEN size(led_profile_skus) > 0
              AND size(led_strip_skus) = 0 AND size(led_kit_skus) = 0
       THEN [{rule_id:'V-08', severity:'WARNING',
              message:'LED profile without LED strip or kit. Lighting setup incomplete.',
              action:'prompt_add_led_strip', item:led_profile_skus[0]}]
       ELSE [] END
   + CASE WHEN 'LED-PROF-FLUTED' IN led_profile_skus
              AND NOT 'PVC_FLUTE' IN panel_subcategories
       THEN [{rule_id:'V-10', severity:'WARNING',
              message:'Fluted LED Profile is designed for PVC Flute panels.',
              action:'prompt_confirm', item:'LED-PROF-FLUTED'}]
       ELSE [] END
   + CASE WHEN 'LED-PROF-CER' IN led_profile_skus
              AND NOT 'WPC_CERAMIC' IN panel_subcategories
       THEN [{rule_id:'V-11', severity:'WARNING',
              message:'Ceramic LED Profile is designed for WPC Ceramic panels.',
              action:'prompt_confirm', item:'LED-PROF-CER'}]
       ELSE [] END
     AS violations
RETURN violations
"""
)


# ── VALIDATE_COMPATIBILITY (V-09, V-12, V-15) ───────────────────────────────

_NON_WATERPROOF = [
    "CH-CL2",
    "CH-MINCONC-SM",
    "CH-CLASSIC-NEW",
    "CH-CONCAVE",
    "CH-FLUTED",
    "CH-MINRECT",
    "CH-MINCONC-PREM",
    "SHT-METALLIC",
    "SHT-WPC-5MM",
    "SHT-WPC-GROOVED-7MM",
]
_NW = ",".join(f"'{s}'" for s in _NON_WATERPROOF)

VALIDATE_COMPATIBILITY = (
    _CART_PREAMBLE
    + f"""
WITH cart, panel_skus, trim_skus, panel_subcategories,
     CASE WHEN 'TR-L-WPC-NEW' IN trim_skus AND NOT 'WPC_NEW' IN panel_subcategories
       THEN [{{rule_id:'V-09', severity:'WARNING',
              message:'WPC L Bidding New is designed for WPC New panels. Is this intentional?',
              action:'prompt_confirm', item:'TR-L-WPC-NEW'}}]
       ELSE [] END
   + CASE WHEN cart.room_type IN ['bathroom','kitchen']
              AND any(s IN panel_skus WHERE s IN [{_NW}])
       THEN [{{rule_id:'V-12', severity:'WARNING',
              message:'Panel not rated for wet environments. Recommend waterproof alternatives.',
              action:'show_warning_badge',
              item:[s IN panel_skus WHERE s IN [{_NW}]][0]}}]
       ELSE [] END
   + CASE WHEN cart.room_type = 'ceiling' AND size(panel_skus) > 0
              AND NOT 'SHT-WPC-5MM' IN panel_skus
       THEN [{{rule_id:'V-15', severity:'WARNING',
              message:'For ceiling use, WPC Sheet 5mm is the only rated option.',
              action:'show_info', item:panel_skus[0]}}]
       ELSE [] END
     AS violations
RETURN violations
"""
)


# ── VALIDATE_FURNITURE (V-13, V-14) ──────────────────────────────────────────

VALIDATE_FURNITURE = (
    _CART_PREAMBLE
    + """
WITH cart, all_items,
     [ci IN all_items WHERE ci.item_type = 'FURNITURE'
       AND ci.sku IN ['TV-PF-PUREOPEN','TV-PF-MODUFIT','TV-PF-LEAFLEDGE']
       AND ci.width_ft IS NOT NULL AND ci.width_ft < 6] AS pf_bad,
     [ci IN all_items WHERE ci.item_type = 'FURNITURE'
       AND ci.sku = 'TV-GL'
       AND ci.width_ft IS NOT NULL AND ci.width_ft >= 8] AS gl_bad
WITH
     CASE WHEN size(pf_bad) > 0
       THEN [{rule_id:'V-13', severity:'ERROR',
              message:'This TV unit requires minimum 6ft width.',
              action:'disable_width_options([4,5])', item:pf_bad[0].sku}]
       ELSE [] END
   + CASE WHEN size(gl_bad) > 0
       THEN [{rule_id:'V-14', severity:'ERROR',
              message:'GrooveLine TV Units max 7ft.',
              action:'disable_width_option(8)', item:gl_bad[0].sku}]
       ELSE [] END
     AS violations
RETURN violations
"""
)


# ── VALIDATE_CONSUMABLES (V-16, V-20) ────────────────────────────────────────

VALIDATE_CONSUMABLES = (
    _CART_PREAMBLE
    + """
WITH cart, all_skus, panel_skus, consumable_skus,
     CASE WHEN size(all_skus) > 0 AND NOT 'CONS-POLYFIX' IN all_skus
       THEN [{rule_id:'V-16', severity:'WARNING',
              message:'Polyfix joint filler is recommended for every installation. Add 1 tube?',
              action:'prompt_add("CONS-POLYFIX", 1)', item:'CONS-POLYFIX'}]
       ELSE [] END
   + CASE WHEN 'SHT-SPC' IN panel_skus AND NOT 'CONS-PVC10' IN consumable_skus
       THEN [{rule_id:'V-20', severity:'WARNING',
              message:'SPC Sheet is heavy. A 10mm PVC backing board is recommended.',
              action:'prompt_add("CONS-PVC10")', item:'CONS-PVC10'}]
       ELSE [] END
     AS violations
RETURN violations
"""
)


# ── VALIDATE_ADVISORY (V-17, V-18, V-19) ─────────────────────────────────────

VALIDATE_ADVISORY = (
    _CART_PREAMBLE
    + """
WITH cart, all_skus, panel_skus, panel_subcategories,
     CASE WHEN 'CAB-OH-1.5FT-INSTALL' IN all_skus
       THEN [{rule_id:'V-17', severity:'INFO',
              message:'Cabinet installation only — the cabinet must be supplied by you.',
              action:'show_info', item:'CAB-OH-1.5FT-INSTALL'}]
       ELSE [] END
   + CASE WHEN any(s IN panel_skus WHERE s IN ['WPC-NEW-CONCAVE','WPC-NEW-CONVEX'])
       THEN [{rule_id:'V-18', severity:'INFO',
              message:'3D curved panels require a professional site measurement.',
              action:'show_measurement_advisory',
              item:[s IN panel_skus WHERE s IN ['WPC-NEW-CONCAVE','WPC-NEW-CONVEX']][0]}]
       ELSE [] END
   + CASE WHEN 'PVC_FLUTE' IN panel_subcategories
       THEN [{rule_id:'V-19', severity:'INFO',
              message:'PVC Flute panels require a batten frame and panel adhesive.',
              action:'show_advisory', item:'PVC_FLUTE'}]
       ELSE [] END
     AS violations
RETURN violations
"""
)


# ── VALIDATE_LAYOUT (two-zone, skirting, waterproof enforcement) ─────────────

VALIDATE_LAYOUT = (
    _CART_PREAMBLE
    + f"""
WITH cart, panel_skus, trim_skus,
     CASE WHEN cart.is_two_zone = true AND NOT 'TR-MET-T' IN trim_skus
       THEN [{{rule_id:'TWO_ZONE_DIVIDER', severity:'INFO',
              message:'Metal T trim required between zones.',
              action:'auto_add("TR-MET-T")', item:'TR-MET-T'}}]
       ELSE [] END
   + CASE WHEN cart.panels_reach_floor = true AND NOT 'TR-SKIRTING' IN trim_skus
       THEN [{{rule_id:'SKIRTING_RULE', severity:'INFO',
              message:'Panels reach floor — add skirting.',
              action:'prompt_suggest("TR-SKIRTING")', item:'TR-SKIRTING'}}]
       ELSE [] END
   + CASE WHEN cart.room_type IN ['bathroom','kitchen']
              AND any(s IN panel_skus WHERE s IN [{_NW}])
       THEN [{{rule_id:'WATERPROOF_ENFORCEMENT', severity:'WARNING',
              message:'Panel not rated for wet environments.',
              action:'show_warning',
              item:[s IN panel_skus WHERE s IN [{_NW}]][0]}}]
       ELSE [] END
     AS violations
RETURN violations
"""
)


# Ordered list of all validation group queries for the orchestrator
VALIDATION_GROUPS: list[tuple[str, str]] = [
    ("clips", VALIDATE_CLIPS),
    ("trims", VALIDATE_TRIMS),
    ("availability", VALIDATE_AVAILABILITY),
    ("led", VALIDATE_LED),
    ("compatibility", VALIDATE_COMPATIBILITY),
    ("furniture", VALIDATE_FURNITURE),
    ("consumables", VALIDATE_CONSUMABLES),
    ("advisory", VALIDATE_ADVISORY),
    ("layout", VALIDATE_LAYOUT),
]

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
OPTIONAL MATCH (panel)-[rm:HAS_METAL_TRIM]->(mt:Trim)
WITH ci, panel,
  collect(DISTINCT CASE WHEN ut IS NOT NULL THEN {sku:ut.sku, name:ut.name, price:ut.price, type:'U', suggestion:ru.relationship_type} END) AS u,
  collect(DISTINCT CASE WHEN lt IS NOT NULL THEN {sku:lt.sku, name:lt.name, price:lt.price, type:'L', suggestion:rl.relationship_type} END) AS l,
  collect(DISTINCT CASE WHEN ht IS NOT NULL THEN {sku:ht.sku, name:ht.name, price:ht.price, type:'H', suggestion:rh.relationship_type} END) AS h,
  collect(DISTINCT CASE WHEN mt IS NOT NULL THEN {sku:mt.sku, name:mt.name, price:mt.price, type:'METAL', suggestion:rm.relationship_type} END) AS m
RETURN ci.sku AS panel_sku, [t IN u + l + h + m WHERE t IS NOT NULL] AS trims
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
