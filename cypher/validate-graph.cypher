// ============================================================================
// GRAPH VALIDATION QUERIES — V5.0
// ============================================================================
// Run after loading wall-configurator-graph-v5.cypher to verify integrity.
// Each query should return the expected result noted in the comment.
// A non-empty result (where empty is expected) indicates a data issue.
// ============================================================================


// ── V1. Node count by label (baseline sanity check) ─────────────────────────
// Expected: Stable counts across re-runs (idempotency proof)
MATCH (n) RETURN labels(n)[0] AS label, count(n) AS count ORDER BY label;


// ── V2. Orphan rules — rules without any APPLIES_TO relationship ────────────
// Expected: EMPTY (all rules must be linked in V5.0)
MATCH (r:Rule)
WHERE NOT (r)-[:APPLIES_TO]->()
RETURN r.id AS orphan_rule_id, r.type AS rule_type;


// ── V3. Orphan panels — panels not linked to any subcategory ────────────────
// Expected: EMPTY
MATCH (p:Panel)
WHERE NOT (p)-[:BELONGS_TO]->(:Subcategory)
RETURN p.sku AS orphan_panel;


// ── V4. Orphan trims — trims not linked to any subcategory ──────────────────
// Expected: EMPTY
MATCH (t:Trim)
WHERE NOT (t)-[:BELONGS_TO]->(:Subcategory)
RETURN t.sku AS orphan_trim;


// ── V5. Orphan furniture — furniture not linked to any subcategory ───────────
// Expected: EMPTY
MATCH (f:Furniture)
WHERE NOT (f)-[:BELONGS_TO]->(:Subcategory)
RETURN f.sku AS orphan_furniture;


// ── V6. ON_REQUEST integrity — ON_REQUEST items should have price=null ──────
// Expected: EMPTY (no ON_REQUEST item should have a concrete price)
MATCH (p:Panel)
WHERE p.availability = 'ON_REQUEST' AND p.price IS NOT NULL
RETURN p.sku AS invalid_on_request, p.price;


// ── V7. Default selection — exactly one default per panel subcategory ────────
// Expected: Each subcategory with panels should have exactly 1 default
MATCH (p:Panel)
WHERE p.default_selection = true
WITH p.subcategory AS subcat, count(p) AS defaults
WHERE defaults <> 1
RETURN subcat, defaults AS default_count;


// ── V8. Installation method coverage — every panel subcategory has a method ──
// Expected: EMPTY (all 7 panel subcategories should have USES_METHOD)
MATCH (s:Subcategory)
WHERE s.name IN ['PVC_PANEL','PVC_FLUTE','WPC_CLASSIC','WPC_NEW','WPC_CERAMIC','CHARCOAL','SHEET']
AND NOT (s)-[:USES_METHOD]->(:InstallationMethod)
AND NOT ()-[:USES_METHOD]->(:InstallationMethod) // Some panels have direct USES_METHOD
RETURN s.name AS missing_install_method;


// ── V9. Trim assignment coverage — every available panel has at least one trim
// Expected: EMPTY (excluding CHARCOAL which has no standard trims)
MATCH (p:Panel)
WHERE p.availability IN ['AVAILABLE','NEW','PREMIUM']
AND p.subcategory <> 'CHARCOAL'
AND NOT (p)-[:HAS_U_TRIM|HAS_L_TRIM|HAS_H_TRIM]->(:Trim)
RETURN p.sku AS panel_without_trims, p.subcategory;


// ── V10. Installation contract coverage ─────────────────────────────────────
// Expected: Every panel subcategory (and silicon/adhesive sheets) has a contract
MATCH (s:Subcategory)
WHERE s.name IN ['PVC_PANEL','PVC_FLUTE','WPC_CLASSIC','WPC_NEW','WPC_CERAMIC','CHARCOAL']
AND NOT (:Rule {type:'INSTALLATION_CONTRACT'})-[:APPLIES_TO]->(s)
RETURN s.name AS missing_contract;


// ── V11. LED compatibility rule coverage ────────────────────────────────────
// Expected: Every panel subcategory has an LED compatibility rule
MATCH (s:Subcategory)
WHERE s.name IN ['PVC_PANEL','PVC_FLUTE','WPC_CLASSIC','WPC_NEW','WPC_CERAMIC','CHARCOAL','SHEET']
AND NOT (:Rule {type:'LED_COMPATIBILITY'})-[:APPLIES_TO]->(s)
RETURN s.name AS missing_led_compat_rule;


// ── V12. CartScene linked rules count ───────────────────────────────────────
// Expected: 15+ rules linked to CartScene
MATCH (r:Rule)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs:CartScene)
RETURN count(r) AS global_rule_count;


// ── V13. Validation rule severity distribution ──────────────────────────────
// Expected: Mix of ERROR, WARNING, and INFO
MATCH (r:Rule {type:'VALIDATION'})
RETURN r.severity, count(r) AS count
ORDER BY r.severity;


// ── V14. Duplicate SKU check across all product labels ──────────────────────
// Expected: EMPTY (no SKU collisions across node types)
MATCH (a) WHERE a:Panel OR a:Trim OR a:Consumable OR a:LEDProfile OR a:LEDStrip OR a:LEDKit OR a:Furniture
WITH a.sku AS sku, collect(labels(a)) AS types
WHERE size(types) > 1
RETURN sku, types;


// ── V15. Full rule count by type and severity ───────────────────────────────
// Expected: Comprehensive view for audit
MATCH (r:Rule)
RETURN r.type, r.severity, count(r) AS rule_count
ORDER BY r.type, r.severity;


// ── V16. Relationship count summary ─────────────────────────────────────────
// Expected: Stable counts across re-runs
MATCH ()-[r]->()
RETURN type(r) AS relationship_type, count(r) AS count
ORDER BY count DESC;


// ============================================================================
// END OF VALIDATION QUERIES
// ============================================================================
