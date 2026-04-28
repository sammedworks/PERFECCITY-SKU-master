// ============================================================================
// UTILITY QUERIES — Wall Configurator Graph V5.0
// ============================================================================
// Common operational queries for the frontend configurator, admin dashboard,
// and debugging. Copy-paste into Neo4j Browser or cypher-shell.
// ============================================================================


// ─────────────────────────────────────────────────────────────────────────────
// Q1. All rules for a panel's subcategory
// ─────────────────────────────────────────────────────────────────────────────
// Usage: Change the SKU to query any panel's applicable rules.

MATCH (p:Panel {sku:'FLT-WIDEWOOD'})-[:BELONGS_TO]->(s:Subcategory)
MATCH (r:Rule)-[:APPLIES_TO]->(s)
RETURN r.id, r.type, r.severity, r.message ORDER BY r.severity;


// ─────────────────────────────────────────────────────────────────────────────
// Q2. All global (cart-scoped) validation rules
// ─────────────────────────────────────────────────────────────────────────────

MATCH (r:Rule)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs:CartScene)
RETURN r.id, r.severity, r.name, r.trigger_condition ORDER BY r.severity, r.id;


// ─────────────────────────────────────────────────────────────────────────────
// Q3. Complete accessory BOM for a panel
// ─────────────────────────────────────────────────────────────────────────────
// Returns all trims, consumables, and LED profiles linked to a panel.

MATCH (p:Panel {sku:'WPC-NEW-CLASSIC'})
OPTIONAL MATCH (p)-[ru:HAS_U_TRIM]->(u:Trim)
OPTIONAL MATCH (p)-[rl:HAS_L_TRIM]->(l:Trim)
OPTIONAL MATCH (p)-[rh:HAS_H_TRIM]->(h:Trim)
OPTIONAL MATCH (p)-[:BELONGS_TO]->(s:Subcategory)<-[:APPLIES_TO]-(ic:Rule {type:'INSTALLATION_CONTRACT'})-[rc:REQUIRES_CONSUMABLE]->(c:Consumable)
OPTIONAL MATCH (p)-[rled:HAS_DEDICATED_LED|COMPATIBLE_LED]->(lp:LEDProfile)
RETURN
  p.sku AS panel,
  collect(DISTINCT {sku:u.sku, rel:ru.relationship_type}) AS u_trims,
  collect(DISTINCT {sku:l.sku, rel:rl.relationship_type}) AS l_trims,
  collect(DISTINCT {sku:h.sku, rel:rh.relationship_type}) AS h_trims,
  collect(DISTINCT {sku:c.sku, rel:rc.relationship_type}) AS consumables,
  collect(DISTINCT {sku:lp.sku, rel:type(rled)}) AS led_profiles;


// ─────────────────────────────────────────────────────────────────────────────
// Q4. All incompatible accessories for a subcategory
// ─────────────────────────────────────────────────────────────────────────────

MATCH (r:Rule)-[:APPLIES_TO]->(s:Subcategory {name:'CHARCOAL'})
MATCH (r)-[:INCOMPATIBLE_ACCESSORY]->(a)
RETURN a.sku, labels(a) AS type, r.id;


// ─────────────────────────────────────────────────────────────────────────────
// Q5. All ERROR-level validation rules (ordered)
// ─────────────────────────────────────────────────────────────────────────────

MATCH (r:Rule {type:'VALIDATION', severity:'ERROR'})
RETURN r.id, r.name, r.trigger_condition, r.action ORDER BY r.id;


// ─────────────────────────────────────────────────────────────────────────────
// Q6. Room-ranked panel catalog
// ─────────────────────────────────────────────────────────────────────────────
// Replace 'living_room' with the target room type.
// Requires APOC plugin for apoc.convert.fromJsonMap.

MATCH (p:Panel) WHERE p.availability IN ['AVAILABLE','NEW','PREMIUM']
WITH p, apoc.convert.fromJsonMap(p.room_affinity) AS scores
RETURN p.sku, p.name, p.price, p.availability,
       coalesce(scores['living_room'], scores['any'], 0.0) AS affinity_score
ORDER BY affinity_score DESC;


// ─────────────────────────────────────────────────────────────────────────────
// Q7. All rules that mention a specific trim SKU
// ─────────────────────────────────────────────────────────────────────────────

MATCH (r:Rule)-[rel]->(t:Trim {sku:'TR-L-WPC-NEW'})
RETURN r.id, r.type, type(rel) AS rel_to_trim;


// ─────────────────────────────────────────────────────────────────────────────
// Q8. Catalog filter — panels by subcategory and availability
// ─────────────────────────────────────────────────────────────────────────────
// Uses the composite index panel_subcat_avail_idx for fast lookups.

MATCH (p:Panel)
WHERE p.subcategory = 'PVC_PANEL' AND p.availability = 'AVAILABLE'
RETURN p.sku, p.name, p.price, p.colors, p.finish
ORDER BY p.name;


// ─────────────────────────────────────────────────────────────────────────────
// Q9. Installation consumables for a subcategory
// ─────────────────────────────────────────────────────────────────────────────

MATCH (s:Subcategory {name:'PVC_PANEL'})<-[:APPLIES_TO]-(r:Rule {type:'INSTALLATION_CONTRACT'})
OPTIONAL MATCH (r)-[req:REQUIRES_CONSUMABLE]->(c:Consumable)
OPTIONAL MATCH (r)-[:FORBIDS_CONSUMABLE]->(fc:Consumable)
OPTIONAL MATCH (r)-[opt:OPTIONAL_CONSUMABLE]->(oc:Consumable)
RETURN
  r.method AS install_method,
  collect(DISTINCT {sku:c.sku, type:'REQUIRED'}) AS required,
  collect(DISTINCT {sku:fc.sku, type:'FORBIDDEN'}) AS forbidden,
  collect(DISTINCT {sku:oc.sku, type:'OPTIONAL', condition:opt.condition}) AS optional;


// ─────────────────────────────────────────────────────────────────────────────
// Q10. LED profile options for a panel
// ─────────────────────────────────────────────────────────────────────────────

MATCH (p:Panel {sku:'FLT-WIDEWOOD'})
OPTIONAL MATCH (p)-[d:HAS_DEDICATED_LED]->(ded:LEDProfile)
OPTIONAL MATCH (p)-[c:COMPATIBLE_LED]->(uni:LEDProfile)
RETURN
  p.sku AS panel,
  collect(DISTINCT {sku:ded.sku, name:ded.name, type:'DEDICATED', priority:d.priority}) AS dedicated,
  collect(DISTINCT {sku:uni.sku, name:uni.name, type:'UNIVERSAL', priority:c.priority}) AS universal;


// ─────────────────────────────────────────────────────────────────────────────
// Q11. Furniture catalog with pricing
// ─────────────────────────────────────────────────────────────────────────────

MATCH (f:Furniture)
WHERE f.subcategory = 'TV_UNIT' AND f.availability = 'AVAILABLE'
RETURN f.sku, f.name, f.series, f.style, f.widths_ft, f.prices, f.finishes
ORDER BY f.name;


// ─────────────────────────────────────────────────────────────────────────────
// Q12. Two-zone rules
// ─────────────────────────────────────────────────────────────────────────────

MATCH (r:Rule {type:'TWO_ZONE'})-[:REQUIRES_ACCESSORY|SUGGESTS_ACCESSORY]->(t:Trim)
RETURN r.id, r.trigger_condition, r.action, t.sku AS trim_sku, t.name AS trim_name;


// ─────────────────────────────────────────────────────────────────────────────
// Q13. Default panel for a room type
// ─────────────────────────────────────────────────────────────────────────────
// Requires APOC plugin for JSON parsing.

MATCH (r:Rule {id:'DEFAULT_SELECTION_BY_ROOM'})
WITH apoc.convert.fromJsonMap(r.defaults) AS defaults
RETURN defaults['living_room'] AS living_room_default,
       defaults['bedroom'] AS bedroom_default,
       defaults['bathroom'] AS bathroom_default,
       defaults['tv_wall'] AS tv_wall_default,
       defaults['ceiling'] AS ceiling_default;


// ─────────────────────────────────────────────────────────────────────────────
// Q14. Full graph statistics
// ─────────────────────────────────────────────────────────────────────────────

CALL {
  MATCH (n) RETURN 'Nodes' AS metric, count(n) AS value
  UNION ALL
  MATCH ()-[r]->() RETURN 'Relationships' AS metric, count(r) AS value
  UNION ALL
  MATCH (r:Rule) RETURN 'Rules' AS metric, count(r) AS value
  UNION ALL
  MATCH (p:Panel) RETURN 'Panels' AS metric, count(p) AS value
  UNION ALL
  MATCH (f:Furniture) RETURN 'Furniture' AS metric, count(f) AS value
}
RETURN metric, value ORDER BY metric;


// ============================================================================
// END OF UTILITY QUERIES
// ============================================================================
