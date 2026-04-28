// ============================================================================
// WALL CONFIGURATOR GRAPH — V5.0 (IDEMPOTENT & FULLY LINKED)
// ============================================================================
//
// Production-ready Neo4j Cypher seed script for the Perfeccity Wall Panel
// Configurator.  Models the complete product catalog, installation methods,
// trim/accessory relationships, LED compatibility, furniture catalog, and a
// 20+ rule validation/suggestion engine.
//
// Change log vs V4.0:
//   [FIX-1] All CREATE (r:Rule {...}) -> MERGE (r:Rule {id:...}) SET r.prop = ...
//           Script is now safely re-runnable; re-execution updates properties,
//           never fails on duplicate id constraint.
//   [FIX-2] :CartScene meta-node introduced as the global APPLIES_TO anchor
//           for cart-scope validation rules that have no single panel/subcategory
//           target (V-05, V-07, V-08, V-09, V-10, V-11, V-12, V-13, V-14,
//           V-15, V-16, V-17, V-18, V-19, V-20 — 15 rules now fully linked).
//   [FIX-3] Skirting, two-zone, default-selection, availability, room-affinity
//           rule nodes also converted to MERGE + SET.
//   [FIX-4] Composite index added for (Panel.subcategory, Panel.availability)
//           to support the most common catalog-filter query.
//   [NOTE]  All product nodes (sections 3-20) and relationship blocks
//           (sections 21-24) are unchanged from V4.0 — they were already
//           correct. They are reproduced here for a self-contained script.
//
// Neo4j compatibility: 5.x (Community or Enterprise).
// Estimated node count: ~120 product nodes, 24 subcategories, 6 install
//   methods, 30+ rules, 1 CartScene meta-node.
// Estimated relationship count: ~500+
//
// Usage:
//   neo4j-admin database import ... OR
//   cat wall-configurator-graph-v5.cypher | cypher-shell -u neo4j -p <password>
//
// ============================================================================


// ─────────────────────────────────────────────────────────────────────────────
// 0. UNIQUENESS CONSTRAINTS & EXISTENCE GUARDS
// ─────────────────────────────────────────────────────────────────────────────
// These constraints ensure data integrity and prevent duplicate SKUs.
// IF NOT EXISTS makes the statements idempotent on re-run.

CREATE CONSTRAINT panel_sku_unique        IF NOT EXISTS FOR (n:Panel)              REQUIRE n.sku IS UNIQUE;
CREATE CONSTRAINT trim_sku_unique         IF NOT EXISTS FOR (n:Trim)               REQUIRE n.sku IS UNIQUE;
CREATE CONSTRAINT consumable_sku_unique   IF NOT EXISTS FOR (n:Consumable)         REQUIRE n.sku IS UNIQUE;
CREATE CONSTRAINT ledprofile_sku_unique   IF NOT EXISTS FOR (n:LEDProfile)         REQUIRE n.sku IS UNIQUE;
CREATE CONSTRAINT ledstrip_sku_unique     IF NOT EXISTS FOR (n:LEDStrip)           REQUIRE n.sku IS UNIQUE;
CREATE CONSTRAINT ledkit_sku_unique       IF NOT EXISTS FOR (n:LEDKit)             REQUIRE n.sku IS UNIQUE;
CREATE CONSTRAINT furniture_sku_unique    IF NOT EXISTS FOR (n:Furniture)          REQUIRE n.sku IS UNIQUE;
CREATE CONSTRAINT subcategory_name_unique IF NOT EXISTS FOR (n:Subcategory)        REQUIRE n.name IS UNIQUE;
CREATE CONSTRAINT installmethod_unique    IF NOT EXISTS FOR (n:InstallationMethod) REQUIRE n.name IS UNIQUE;
CREATE CONSTRAINT rule_id_unique          IF NOT EXISTS FOR (n:Rule)               REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT cartscene_name_unique   IF NOT EXISTS FOR (n:CartScene)          REQUIRE n.name IS UNIQUE;


// ─────────────────────────────────────────────────────────────────────────────
// 1. META-NODE — CartScene (global anchor for cart-scoped validation rules)
// ─────────────────────────────────────────────────────────────────────────────
// Rules that evaluate the full cart state (not a single panel or subcategory)
// are linked here with APPLIES_TO {scope:'GLOBAL'}.
// Query pattern:
//   MATCH (r:Rule)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs:CartScene) RETURN r

MERGE (:CartScene {
  name:        'GLOBAL_CART',
  description: 'Anchor node for cart-scoped validation rules that do not target a specific panel or subcategory.',
  version:     '5.0'
});


// ─────────────────────────────────────────────────────────────────────────────
// 2. INSTALLATION METHOD NODES
// ─────────────────────────────────────────────────────────────────────────────
// Each method describes the physical installation technique and the
// consumables it requires.

MERGE (:InstallationMethod {name:'CLIP_ADHESIVE',        requires_clips:true,  requires_silicon:false, requires_batten:false, requires_generic_adhesive:false});
MERGE (:InstallationMethod {name:'BATTEN_ADHESIVE',      requires_clips:false, requires_silicon:false, requires_batten:true,  requires_generic_adhesive:true});
MERGE (:InstallationMethod {name:'SILICON_GLUE',         requires_clips:false, requires_silicon:true,  requires_batten:false, requires_generic_adhesive:false});
MERGE (:InstallationMethod {name:'ADHESIVE_ONLY',        requires_clips:false, requires_silicon:false, requires_batten:false, requires_generic_adhesive:true});
MERGE (:InstallationMethod {name:'DELIVERED_INSTALLED',  requires_clips:false, requires_silicon:false, requires_batten:false, requires_generic_adhesive:false});
MERGE (:InstallationMethod {name:'WALL_MOUNTED_INSTALL', requires_clips:false, requires_silicon:false, requires_batten:false, requires_generic_adhesive:false});


// ─────────────────────────────────────────────────────────────────────────────
// 3. SUBCATEGORY NODES
// ─────────────────────────────────────────────────────────────────────────────
// Each subcategory defines calculation type, dimensions, warranty, and
// default SKU for the category.

// --- Wall Panels ---
MERGE (:Subcategory {name:'PVC_PANEL',           calculation_type:'SHEET_AREA',     sheet_area_sqft:32,  panel_height_mm:2440, warranty_years:5,  default_sku:'PVC-TEXTURE'});
MERGE (:Subcategory {name:'PVC_FLUTE',           calculation_type:'LINEAR_WIDTH',   panel_height_mm:2900, warranty_years:5,    default_sku:'FLT-WIDEWOOD',    note:'No U-Bidding. No clips. Batten frame required.'});
MERGE (:Subcategory {name:'WPC_CLASSIC',         calculation_type:'SHEET_AREA',     sheet_area_sqft:32,  panel_height_mm:2440, warranty_years:5,  default_sku:'WPC-NEUTRAL'});
MERGE (:Subcategory {name:'WPC_NEW',             calculation_type:'LINEAR_WIDTH',   panel_height_mm:2900, warranty_years:5,    default_sku:'WPC-NEW-CLASSIC', trim_length_mm:2900});
MERGE (:Subcategory {name:'WPC_CERAMIC',         calculation_type:'LINEAR_WIDTH',   panel_height_mm:2900, warranty_years:5,    default_sku:'WPC-CER-NEUT'});
MERGE (:Subcategory {name:'CHARCOAL',            calculation_type:'VARIES_PER_SKU', warranty_years:5,    default_sku:'CH-CL2',          note:'Full panels=SHEET_AREA; tiles=TILE_GRID'});
MERGE (:Subcategory {name:'SHEET',               calculation_type:'SHEET_AREA',     sheet_area_sqft:32,  panel_height_mm:2440, warranty_years:5,  default_sku:'SHT-UV-MARBLE'});

// --- Trims ---
MERGE (:Subcategory {name:'TRIM_U',              calculation_type:'RUNNING_LENGTH', piece_length_mm:2440, warranty:'material_defect_only'});
MERGE (:Subcategory {name:'TRIM_L',              calculation_type:'RUNNING_LENGTH', piece_length_mm_default:2440, warranty:'material_defect_only', note:'TR-L-WPC-NEW exception: 2900mm'});
MERGE (:Subcategory {name:'TRIM_H',              calculation_type:'RUNNING_LENGTH', piece_length_mm:2440, warranty:'material_defect_only'});
MERGE (:Subcategory {name:'TRIM_METAL',          calculation_type:'RUNNING_LENGTH', piece_length_mm:2440, warranty:'material_defect_only'});
MERGE (:Subcategory {name:'TRIM_OTHER',          calculation_type:'RUNNING_LENGTH', warranty:'material_defect_only'});

// --- Consumables ---
MERGE (:Subcategory {name:'CONSUMABLE_CLIPS',    calculation_type:'PACK_COUNT',     pack_size:50});
MERGE (:Subcategory {name:'CONSUMABLE_ADHESIVE', calculation_type:'PER_TUBE'});
MERGE (:Subcategory {name:'CONSUMABLE_BOARD',    calculation_type:'SHEET_AREA',     sheet_area_sqft:32});
MERGE (:Subcategory {name:'CONSUMABLE_FILLER',   calculation_type:'PER_TUBE'});

// --- LED ---
MERGE (:Subcategory {name:'LED_PROFILE',         calculation_type:'RUNNING_LENGTH', piece_length_mm:2440});
MERGE (:Subcategory {name:'LED_STRIP',           calculation_type:'ROLL_LENGTH',    roll_length_mm:5000});
MERGE (:Subcategory {name:'LED_KIT',             calculation_type:'FULL_PANEL_FIXED'});

// --- Furniture ---
MERGE (:Subcategory {name:'TV_UNIT',             calculation_type:'FULL_PANEL_FIXED', installation:'DELIVERED_INSTALLED',  warranty_years:1});
MERGE (:Subcategory {name:'SHELF',               calculation_type:'FULL_PANEL_FIXED', installation:'WALL_MOUNTED_INSTALL', warranty_years:1});
MERGE (:Subcategory {name:'CABINET',             calculation_type:'FULL_PANEL_FIXED', installation:'WALL_MOUNTED_INSTALL', warranty_years:1});
MERGE (:Subcategory {name:'DESK',                calculation_type:'FULL_PANEL_FIXED', installation:'WALL_MOUNTED_INSTALL', warranty_years:1});


// ─────────────────────────────────────────────────────────────────────────────
// 4-20. PRODUCT NODES
// ─────────────────────────────────────────────────────────────────────────────
// All product nodes use MERGE on SKU + SET for idempotent upsert.
// Properties include pricing (INR), dimensions, finish, room affinity
// scores (JSON), availability status, and material characteristics.

// ── 4. PVC_PANEL ────────────────────────────────────────────────────────────
MERGE (p:Panel {sku:'PVC-PLAINWOOD'})   SET p += {name:'PVC Plain Wood',        subcategory:'PVC_PANEL', calculation_type:'SHEET_AREA', price:650,  colors:3, finish:'Matt wood-grain',    trim_family:'PVC_WOOD',    availability:'AVAILABLE', waterproof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:8,  thickness_max_mm:10, default_selection:false, room_affinity:'{"bedroom":0.9,"living_room":0.8,"any":0.6}'};
MERGE (p:Panel {sku:'PVC-GROOVEDWOOD'}) SET p += {name:'PVC Grooved Wood',      subcategory:'PVC_PANEL', calculation_type:'SHEET_AREA', price:650,  colors:2, finish:'Matt grooved wood', trim_family:'PVC_WOOD',    availability:'AVAILABLE', waterproof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:8,  thickness_max_mm:10, default_selection:false, room_affinity:'{"living_room":0.9,"behind_sofa":1.0,"behind_bed":1.0,"any":0.6}'};
MERGE (p:Panel {sku:'PVC-FLORAL'})      SET p += {name:'PVC Floral',            subcategory:'PVC_PANEL', calculation_type:'SHEET_AREA', price:650,  colors:2, finish:'Embossed floral',   trim_family:'PVC_FLORAL',  availability:'AVAILABLE', waterproof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:8,  thickness_max_mm:10, default_selection:false, room_affinity:'{"bedroom":0.9,"kids_room":1.0,"any":0.4}'};
MERGE (p:Panel {sku:'PVC-TRAD'})        SET p += {name:'PVC Traditional',       subcategory:'PVC_PANEL', calculation_type:'SHEET_AREA', price:650,  colors:2, finish:'Matt relief',       trim_family:'PVC_TRAD',    availability:'AVAILABLE', waterproof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:8,  thickness_max_mm:10, default_selection:false, room_affinity:'{"pooja_room":1.0,"study":0.8,"living_room":0.7,"any":0.4}'};
MERGE (p:Panel {sku:'PVC-GEOM'})        SET p += {name:'PVC Geometric',         subcategory:'PVC_PANEL', calculation_type:'SHEET_AREA', price:650,  colors:2, finish:'Matt geometric',    trim_family:'PVC_GEOM',    availability:'AVAILABLE', waterproof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:8,  thickness_max_mm:10, default_selection:false, room_affinity:'{"home_office":1.0,"study":0.9,"accent_wall":0.9,"any":0.5}'};
MERGE (p:Panel {sku:'PVC-TEXTURE'})     SET p += {name:'PVC Texture',           subcategory:'PVC_PANEL', calculation_type:'SHEET_AREA', price:650,  colors:3, finish:'Matt textured',     trim_family:'PVC_TEXTURE', availability:'AVAILABLE', waterproof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:8,  thickness_max_mm:10, default_selection:true,  room_affinity:'{"any":1.0,"living_room":0.8,"bedroom":0.8}'};
MERGE (p:Panel {sku:'PVC-STONE'})       SET p += {name:'PVC Stone',             subcategory:'PVC_PANEL', calculation_type:'SHEET_AREA', price:650,  colors:2, finish:'Stone-grain emboss',trim_family:'PVC_STONE',   availability:'AVAILABLE', waterproof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:8,  thickness_max_mm:10, default_selection:false, room_affinity:'{"living_room":0.9,"entryway":1.0,"lobby":0.9,"any":0.5}'};

// ── 5. PVC_FLUTE ────────────────────────────────────────────────────────────
MERGE (p:Panel {sku:'FLT-WIDEWOOD'})  SET p += {name:'PVC Fluted Wide Wood',        subcategory:'PVC_FLUTE', calculation_type:'LINEAR_WIDTH', panel_w_mm:175, panel_h_mm:2900, price:1450, colors:2, finish:'Wide channel flute', trim_family:'PVC_SOLID', availability:'AVAILABLE', led_compat:'DEDICATED', dedicated_led_sku:'LED-PROF-FLUTED', default_selection:true,  room_affinity:'{"tv_wall":1.0,"behind_sofa":0.9,"bedroom_headboard":0.9,"any":0.5}'};
MERGE (p:Panel {sku:'FLT-SOLID'})     SET p += {name:'PVC Flute Solid',             subcategory:'PVC_FLUTE', calculation_type:'LINEAR_WIDTH', panel_w_mm:150, panel_h_mm:2900, price:1450, colors:2, finish:'Narrow flute',       trim_family:'PVC_SOLID', availability:'AVAILABLE', led_compat:'UNIVERSAL',  dedicated_led_sku:null, default_selection:false, room_affinity:'{"minimalist_wall":1.0,"commercial":0.9,"any":0.5}'};
MERGE (p:Panel {sku:'FLT-WOOD'})      SET p += {name:'PVC Flute Wood',              subcategory:'PVC_FLUTE', calculation_type:'LINEAR_WIDTH', panel_w_mm:175, panel_h_mm:2900, price:1450, colors:2, finish:'Standard flute',      trim_family:'PVC_SOLID', availability:'AVAILABLE', led_compat:'UNIVERSAL',  dedicated_led_sku:null, default_selection:false, room_affinity:'{"living_room":0.9,"bedroom":0.8,"any":0.6}'};
MERGE (p:Panel {sku:'FLT-WIDETRAD'})  SET p += {name:'PVC Fluted Wide Traditional', subcategory:'PVC_FLUTE', calculation_type:'LINEAR_WIDTH', panel_w_mm:175, panel_h_mm:2900, price:1450, colors:1, finish:'Wide flute+heritage',  trim_family:'PVC_SOLID', availability:'AVAILABLE', led_compat:'UNIVERSAL',  dedicated_led_sku:null, default_selection:false, room_affinity:'{"pooja_room":1.0,"traditional_home":1.0,"any":0.3}'};

// ── 6. WPC_CLASSIC ──────────────────────────────────────────────────────────
MERGE (p:Panel {sku:'WPC-MARBLE'})   SET p += {name:'WPC Marble',      subcategory:'WPC_CLASSIC', calculation_type:'SHEET_AREA', price:null, colors:0, finish:'Marble gloss',  trim_family:null,         availability:'ON_REQUEST', waterproof:true, moisture_resistant:true, termite_proof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:12, thickness_max_mm:18, default_selection:false, room_affinity:'{"living_room":0.8,"bathroom_adjacent":0.7}'};
MERGE (p:Panel {sku:'WPC-METALLIC'}) SET p += {name:'WPC Metallic',    subcategory:'WPC_CLASSIC', calculation_type:'SHEET_AREA', price:null, colors:0, finish:'Brushed metal', trim_family:null,         availability:'ON_REQUEST', waterproof:true, moisture_resistant:true, termite_proof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:12, thickness_max_mm:18, default_selection:false, room_affinity:'{"industrial":1.0,"modern":0.9}'};
MERGE (p:Panel {sku:'WPC-TRAD'})     SET p += {name:'WPC Traditional', subcategory:'WPC_CLASSIC', calculation_type:'SHEET_AREA', price:null, colors:0, finish:'Matt relief',   trim_family:null,         availability:'ON_REQUEST', waterproof:true, moisture_resistant:true, termite_proof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:12, thickness_max_mm:18, default_selection:false, room_affinity:'{"pooja_room":1.0,"traditional_home":0.9}'};
MERGE (p:Panel {sku:'WPC-NEUTRAL'})  SET p += {name:'WPC Neutral',     subcategory:'WPC_CLASSIC', calculation_type:'SHEET_AREA', price:550,  colors:1, finish:'Matt neutral',  trim_family:'WPC_NEUTRAL', availability:'AVAILABLE',  waterproof:true, moisture_resistant:true, termite_proof:true, sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:12, thickness_max_mm:18, default_selection:true,  room_affinity:'{"any":1.0,"living_room":0.8}'};

// ── 7. WPC_NEW ──────────────────────────────────────────────────────────────
MERGE (p:Panel {sku:'WPC-NEW-SMSQ'})    SET p += {name:'WPC Small Square',       subcategory:'WPC_NEW', calculation_type:'LINEAR_WIDTH', panel_w_mm:163, panel_h_mm:2900, price:950,  colors:4, finish:'Wood-grain matt',  trim_family:'WPC_NEW', availability:'NEW',     moisture_resistant:true, termite_proof:true, default_selection:false, room_affinity:'{"bedroom":0.9,"living_room":0.8,"any":0.6}'};
MERGE (p:Panel {sku:'WPC-NEW-SMSQW'})   SET p += {name:'WPC Small Square Wider', subcategory:'WPC_NEW', calculation_type:'LINEAR_WIDTH', panel_w_mm:193, panel_h_mm:2900, price:1150, colors:2, finish:'Wood-grain matt',  trim_family:'WPC_NEW', availability:'NEW',     moisture_resistant:true, termite_proof:true, default_selection:false, room_affinity:'{"living_room":0.9,"large_feature_wall":1.0,"any":0.6}'};
MERGE (p:Panel {sku:'WPC-NEW-CLASSIC'}) SET p += {name:'WPC Classic (Profiled)',  subcategory:'WPC_NEW', calculation_type:'LINEAR_WIDTH', panel_w_mm:195, panel_h_mm:2900, price:1300, colors:8, finish:'Wood-grain matt',  trim_family:'WPC_NEW', availability:'NEW',     moisture_resistant:true, termite_proof:true, default_selection:true,  room_affinity:'{"any":1.0,"living_room":0.9}'};
MERGE (p:Panel {sku:'WPC-NEW-CONCAVE'}) SET p += {name:'WPC Concave',             subcategory:'WPC_NEW', calculation_type:'LINEAR_WIDTH', panel_w_mm:null, panel_h_mm:2900, price:1300, colors:4, finish:'3D sculpted wood', trim_family:'WPC_NEW', availability:'NEW',     moisture_resistant:true, termite_proof:true, default_selection:false, measurement_advisory:'3D curved profile — professional measurement required.', room_affinity:'{"premium_living_room":1.0,"statement_wall":1.0,"any":0.5}'};
MERGE (p:Panel {sku:'WPC-NEW-CONVEX'})  SET p += {name:'WPC Convex',              subcategory:'WPC_NEW', calculation_type:'LINEAR_WIDTH', panel_w_mm:null, panel_h_mm:2900, price:1300, colors:5, finish:'3D sculpted wood', trim_family:'WPC_NEW', availability:'NEW',     moisture_resistant:true, termite_proof:true, default_selection:false, measurement_advisory:'3D curved profile — professional measurement required.', room_affinity:'{"bedroom":0.9,"feature_wall":0.9,"lobby":0.9,"any":0.5}'};

// ── 8. WPC_CERAMIC ──────────────────────────────────────────────────────────
MERGE (p:Panel {sku:'WPC-CER-WOOD'}) SET p += {name:'WPC Ceramic Wood',    subcategory:'WPC_CERAMIC', calculation_type:'LINEAR_WIDTH', panel_h_mm:2900, price:1250, colors:2, finish:'Ceramic-wood',    trim_family:'WPC_CER', availability:'AVAILABLE', led_compat:'DEDICATED', dedicated_led_sku:'LED-PROF-CER', moisture_resistant:true, default_selection:false, room_affinity:'{"living_room":0.9,"bedroom":0.8,"feature_wall":0.9,"any":0.6}'};
MERGE (p:Panel {sku:'WPC-CER-NEUT'}) SET p += {name:'WPC Ceramic Neutral', subcategory:'WPC_CERAMIC', calculation_type:'LINEAR_WIDTH', panel_h_mm:2900, price:1100, colors:6, finish:'Ceramic-neutral', trim_family:'WPC_CER', availability:'AVAILABLE', led_compat:'DEDICATED', dedicated_led_sku:'LED-PROF-CER', moisture_resistant:true, default_selection:true,  room_affinity:'{"living_room":1.0,"kitchen":0.9,"study":0.8,"any":0.9}'};

// ── 9. CHARCOAL ─────────────────────────────────────────────────────────────
MERGE (p:Panel {sku:'CH-CL1'})          SET p += {name:'Charcoal Classic 1',           subcategory:'CHARCOAL', calculation_type:'SHEET_AREA', sheet_w_mm:1220, sheet_h_mm:2440, sheet_area_sqft:32, price:null, colors:0, finish:'Flat',             availability:'ON_REQUEST', fire_retardant:true, anti_bacterial:true, eco_friendly:true, acoustic_benefit:true, default_selection:false, room_affinity:'{"any":0.5}'};
MERGE (p:Panel {sku:'CH-CL2'})          SET p += {name:'Charcoal Classic 2',           subcategory:'CHARCOAL', calculation_type:'SHEET_AREA', sheet_w_mm:1220, sheet_h_mm:2440, sheet_area_sqft:32, price:800,  colors:2, finish:'Textured',         availability:'AVAILABLE',  fire_retardant:true, anti_bacterial:true, eco_friendly:true, acoustic_benefit:true, default_selection:true,  room_affinity:'{"living_room":0.8,"study":0.8,"bedroom":0.7,"any":0.6}'};
MERGE (p:Panel {sku:'CH-MINCONC-SM'})   SET p += {name:'Ch Mini Concave Small',        subcategory:'CHARCOAL', calculation_type:'TILE_GRID',  tile_w_mm:300, tile_h_mm:300, tile_area_mm2:90000,   price:650,  colors:4, finish:'Mini concave 3D',  availability:'AVAILABLE',  fire_retardant:true, anti_bacterial:true, eco_friendly:true, acoustic_benefit:true, default_selection:false, room_affinity:'{"feature_wall":0.9,"living_room":0.8,"office":0.8,"any":0.5}'};
MERGE (p:Panel {sku:'CH-CLASSIC-NEW'})  SET p += {name:'Charcoal Classic New',         subcategory:'CHARCOAL', calculation_type:'SHEET_AREA', sheet_w_mm:1220, sheet_h_mm:2440, sheet_area_sqft:32, price:1200, colors:4, finish:'Flat/rich texture', availability:'NEW',        fire_retardant:true, anti_bacterial:true, eco_friendly:true, acoustic_benefit:true, default_selection:false, room_affinity:'{"any":0.8,"office":0.9,"commercial":0.9}'};
MERGE (p:Panel {sku:'CH-CONCAVE'})      SET p += {name:'Charcoal Concave',             subcategory:'CHARCOAL', calculation_type:'SHEET_AREA', sheet_w_mm:1220, sheet_h_mm:2440, sheet_area_sqft:32, price:1500, colors:4, finish:'Concave 3D',       availability:'NEW',        fire_retardant:true, anti_bacterial:true, eco_friendly:true, acoustic_benefit:true, default_selection:false, room_affinity:'{"living_room":1.0,"premium_bedroom":1.0,"any":0.5}'};
MERGE (p:Panel {sku:'CH-FLUTED'})       SET p += {name:'Charcoal Fluted',              subcategory:'CHARCOAL', calculation_type:'SHEET_AREA', sheet_w_mm:1220, sheet_h_mm:2440, sheet_area_sqft:32, price:2500, colors:4, finish:'Vertical flute 3D', availability:'NEW',        fire_retardant:true, anti_bacterial:true, eco_friendly:true, acoustic_benefit:true, default_selection:false, room_affinity:'{"high_end_living":1.0,"lobby":1.0,"any":0.3}'};
MERGE (p:Panel {sku:'CH-MINRECT'})      SET p += {name:'Charcoal Mini Rectangle',      subcategory:'CHARCOAL', calculation_type:'TILE_GRID',  tile_w_mm:300, tile_h_mm:600, tile_area_mm2:180000,  price:2800, colors:4, finish:'Rectangle 3D',     availability:'NEW',        fire_retardant:true, anti_bacterial:true, eco_friendly:true, acoustic_benefit:true, default_selection:false, room_affinity:'{"feature_wall":0.9,"hotel":1.0,"office":0.8,"any":0.4}'};
MERGE (p:Panel {sku:'CH-MINCONC-PREM'}) SET p += {name:'Charcoal Mini Concave Premium',subcategory:'CHARCOAL', calculation_type:'TILE_GRID',  tile_w_mm:300, tile_h_mm:300, tile_area_mm2:90000,   price:3700, colors:1, finish:'Mini concave 3D',  availability:'PREMIUM',    fire_retardant:true, anti_bacterial:true, eco_friendly:true, acoustic_benefit:true, default_selection:false, room_affinity:'{"luxury_bedroom":1.0,"high_end_space":1.0,"any":0.2}'};

// ── 10. SHEET ───────────────────────────────────────────────────────────────
MERGE (p:Panel {sku:'SHT-UV-MARBLE'})       SET p += {name:'UV Sheet Marble',       subcategory:'SHEET', calculation_type:'SHEET_AREA', installation_method:'SILICON_GLUE',  sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:3, thickness_max_mm:5, price:3500, colors:2, finish:'Ultra-high gloss',  trim_family:'SHEET', availability:'AVAILABLE', waterproof:true,            default_selection:true,  h_trim_override:null,            ceiling_rated:false, room_affinity:'{"living_room":0.9,"kitchen_backsplash":1.0,"bathroom":1.0,"any":0.5}'};
MERGE (p:Panel {sku:'SHT-SPC'})             SET p += {name:'SPC Sheet',             subcategory:'SHEET', calculation_type:'SHEET_AREA', installation_method:'SILICON_GLUE',  sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:5, thickness_max_mm:8, price:9000, colors:8, finish:'Matt/Gloss',        trim_family:'SHEET', availability:'PREMIUM',   waterproof:true, zero_water_absorption:true, default_selection:false, h_trim_override:null,            ceiling_rated:false, room_affinity:'{"premium_living_room":1.0,"bathroom":1.0,"commercial":1.0,"any":0.4}'};
MERGE (p:Panel {sku:'SHT-METALLIC'})        SET p += {name:'Metallic Sheet',        subcategory:'SHEET', calculation_type:'SHEET_AREA', installation_method:'ADHESIVE_ONLY', sheet_w_mm:1220, sheet_h_mm:2440, thickness_min_mm:3, thickness_max_mm:5, price:2100, colors:2, finish:'Brushed metallic',  trim_family:'SHEET', availability:'NEW',       waterproof:true,            default_selection:false, h_trim_override:null,            ceiling_rated:false, room_affinity:'{"modern_living_room":0.9,"feature_wall":0.8,"office":0.8,"any":0.5}'};
MERGE (p:Panel {sku:'SHT-WPC-5MM'})         SET p += {name:'WPC Sheet 5mm',         subcategory:'SHEET', calculation_type:'SHEET_AREA', installation_method:'ADHESIVE_ONLY', sheet_w_mm:1220, sheet_h_mm:2440, thickness_mm:5,                     price:2700, colors:3, finish:'Matt wood/neutral',  trim_family:'SHEET', availability:'NEW',       moisture_resistant:true,    default_selection:false, h_trim_override:null,            ceiling_rated:true,  room_affinity:'{"living_room":0.7,"bedroom":0.7,"ceiling":1.0,"any":0.5}'};
MERGE (p:Panel {sku:'SHT-WPC-GROOVED-7MM'}) SET p += {name:'WPC Sheet Grooved 7mm', subcategory:'SHEET', calculation_type:'SHEET_AREA', installation_method:'ADHESIVE_ONLY', sheet_w_mm:1220, sheet_h_mm:2440, thickness_mm:7,                     price:3000, colors:6, finish:'Grooved texture',   trim_family:'SHEET', availability:'NEW',       moisture_resistant:true,    default_selection:false, h_trim_override:'TR-WPC-H-TRIM', ceiling_rated:false, room_affinity:'{"living_room":0.8,"office":0.8,"feature_wall":0.8,"any":0.6}'};

// ── 11. TRIMS — U-Bidding ───────────────────────────────────────────────────
MERGE (t:Trim {sku:'TR-U-FLORAL'})  SET t += {name:'U Bidding Floral',       subcategory:'TRIM_U', trim_type:'U', price:90,  colors:2, piece_length_mm:2440, material:'PVC', availability:'AVAILABLE', compatible_panels:['PVC-FLORAL']};
MERGE (t:Trim {sku:'TR-U-TEXTURE'}) SET t += {name:'U Bidding Texture',      subcategory:'TRIM_U', trim_type:'U', price:90,  colors:3, piece_length_mm:2440, material:'PVC', availability:'AVAILABLE', compatible_panels:['PVC-TEXTURE']};
MERGE (t:Trim {sku:'TR-U-STONE'})   SET t += {name:'U Bidding Stone',        subcategory:'TRIM_U', trim_type:'U', price:90,  colors:2, piece_length_mm:2440, material:'PVC', availability:'AVAILABLE', compatible_panels:['PVC-STONE']};
MERGE (t:Trim {sku:'TR-U-TRAD'})    SET t += {name:'U Bidding Traditional',  subcategory:'TRIM_U', trim_type:'U', price:90,  colors:2, piece_length_mm:2440, material:'PVC', availability:'AVAILABLE', compatible_panels:['PVC-TRAD']};
MERGE (t:Trim {sku:'TR-U-GEOM'})    SET t += {name:'U Bidding Geometric',    subcategory:'TRIM_U', trim_type:'U', price:90,  colors:2, piece_length_mm:2440, material:'PVC', availability:'AVAILABLE', compatible_panels:['PVC-GEOM']};
MERGE (t:Trim {sku:'TR-U-WOOD'})    SET t += {name:'U Bidding Wood',         subcategory:'TRIM_U', trim_type:'U', price:90,  colors:3, piece_length_mm:2440, material:'PVC', availability:'AVAILABLE', compatible_panels:['PVC-PLAINWOOD','PVC-GROOVEDWOOD']};
MERGE (t:Trim {sku:'TR-U-SHEET'})   SET t += {name:'Sheet U Bidding',        subcategory:'TRIM_U', trim_type:'U', price:220, colors:3, piece_length_mm:2440, material:'PVC', availability:'AVAILABLE', compatible_panels:['SHT-UV-MARBLE','SHT-SPC','SHT-METALLIC','SHT-WPC-5MM','SHT-WPC-GROOVED-7MM']};

// ── 12. TRIMS — L-Bidding ───────────────────────────────────────────────────
MERGE (t:Trim {sku:'TR-L-NEUTRAL'})  SET t += {name:'L Bidding Neutral',           subcategory:'TRIM_L', trim_type:'L', price:90,   colors:1,  piece_length_mm:2440, material:'PVC', availability:'AVAILABLE',   compatible_panels:['WPC-NEUTRAL']};
MERGE (t:Trim {sku:'TR-L-GEOM'})     SET t += {name:'L Bidding Geometric',         subcategory:'TRIM_L', trim_type:'L', price:90,   colors:2,  piece_length_mm:2440, material:'PVC', availability:'AVAILABLE',   compatible_panels:['PVC-GEOM']};
MERGE (t:Trim {sku:'TR-L-TEXTURE'})  SET t += {name:'L Bidding Texture',           subcategory:'TRIM_L', trim_type:'L', price:90,   colors:3,  piece_length_mm:2440, material:'PVC', availability:'AVAILABLE',   compatible_panels:['PVC-TEXTURE']};
MERGE (t:Trim {sku:'TR-L-FLORAL'})   SET t += {name:'L Bidding Floral',            subcategory:'TRIM_L', trim_type:'L', price:90,   colors:2,  piece_length_mm:2440, material:'PVC', availability:'AVAILABLE',   compatible_panels:['PVC-FLORAL']};
MERGE (t:Trim {sku:'TR-L-TRAD'})     SET t += {name:'L Bidding Traditional',       subcategory:'TRIM_L', trim_type:'L', price:90,   colors:3,  piece_length_mm:2440, material:'PVC', availability:'AVAILABLE',   compatible_panels:['PVC-TRAD']};
MERGE (t:Trim {sku:'TR-L-WOOD'})     SET t += {name:'L Bidding Wood',              subcategory:'TRIM_L', trim_type:'L', price:90,   colors:7,  piece_length_mm:2440, material:'PVC', availability:'AVAILABLE',   compatible_panels:['PVC-PLAINWOOD','PVC-GROOVEDWOOD']};
MERGE (t:Trim {sku:'TR-L-STONE'})    SET t += {name:'L Bidding Stone',             subcategory:'TRIM_L', trim_type:'L', price:90,   colors:2,  piece_length_mm:2440, material:'PVC', availability:'AVAILABLE',   compatible_panels:['PVC-STONE']};
MERGE (t:Trim {sku:'TR-L-SOLID'})    SET t += {name:'L Bidding Solid',             subcategory:'TRIM_L', trim_type:'L', price:90,   colors:2,  piece_length_mm:2440, material:'PVC', availability:'AVAILABLE',   compatible_panels:['FLT-SOLID','FLT-WOOD','FLT-WIDEWOOD','FLT-WIDETRAD'], relationship:'optional'};
MERGE (t:Trim {sku:'TR-L-MARBLE'})   SET t += {name:'L Bidding Marble',            subcategory:'TRIM_L', trim_type:'L', price:null, colors:0,  piece_length_mm:2440, material:'PVC', availability:'UNAVAILABLE', compatible_panels:['WPC-MARBLE']};
MERGE (t:Trim {sku:'TR-L-METALLIC'}) SET t += {name:'L Bidding Metallic',          subcategory:'TRIM_L', trim_type:'L', price:null, colors:0,  piece_length_mm:2440, material:'PVC', availability:'UNAVAILABLE', compatible_panels:['WPC-METALLIC']};
MERGE (t:Trim {sku:'TR-L-SHEET'})    SET t += {name:'Sheet L Bidding',             subcategory:'TRIM_L', trim_type:'L', price:240,  colors:3,  piece_length_mm:2440, material:'PVC', availability:'AVAILABLE',   compatible_panels:['SHT-UV-MARBLE','SHT-SPC','SHT-METALLIC','SHT-WPC-5MM','SHT-WPC-GROOVED-7MM']};
MERGE (t:Trim {sku:'TR-L-WPC-CER'})  SET t += {name:'WPC Ceramic L Bidding',       subcategory:'TRIM_L', trim_type:'L', price:150,  colors:2,  piece_length_mm:2440, material:'WPC', availability:'AVAILABLE',   compatible_panels:['WPC-CER-WOOD','WPC-CER-NEUT']};
MERGE (t:Trim {sku:'TR-L-WPC-NEW'})  SET t += {name:'WPC L Bidding New',           subcategory:'TRIM_L', trim_type:'L', price:230,  colors:22, piece_length_mm:2900, material:'WPC', availability:'NEW',         compatible_panels:['WPC-NEW-SMSQ','WPC-NEW-SMSQW','WPC-NEW-CLASSIC','WPC-NEW-CONCAVE','WPC-NEW-CONVEX'], note:'9.5 ft — use 2900mm in quantity calc'};

// ── 13. TRIMS — H-Bidding ───────────────────────────────────────────────────
MERGE (t:Trim {sku:'TR-H-BIDDING'})  SET t += {name:'H Bidding (Standard)', subcategory:'TRIM_H', trim_type:'H', price:220, colors:3, piece_length_mm:2440, material:'PVC', availability:'AVAILABLE', note:'Universal — excludes CHARCOAL and SHT-WPC-GROOVED-7MM'};
MERGE (t:Trim {sku:'TR-WPC-H-TRIM'}) SET t += {name:'WPC Sheet H Trim',     subcategory:'TRIM_H', trim_type:'H', price:430, colors:1, piece_length_mm:2440, material:'WPC', availability:'AVAILABLE', exclusive_sku:'SHT-WPC-GROOVED-7MM'};

// ── 14. TRIMS — Metal ───────────────────────────────────────────────────────
MERGE (t:Trim {sku:'TR-MET-T'})       SET t += {name:'Metal Trim T',       subcategory:'TRIM_METAL', trim_type:'Metal-T', price:600,  colors:3, piece_length_mm:2440, material:'Aluminium', availability:'AVAILABLE', use_case:'Zone divider between two panel areas', bundle_with_led:false};
MERGE (t:Trim {sku:'TR-MET-U'})       SET t += {name:'Metal Trim U',       subcategory:'TRIM_METAL', trim_type:'Metal-U', price:600,  colors:4, piece_length_mm:2440, material:'Aluminium', availability:'AVAILABLE', use_case:'Premium open-edge cap'};
MERGE (t:Trim {sku:'TR-MET-CHANNEL'}) SET t += {name:'Aluminium Channel',  subcategory:'TRIM_METAL', trim_type:'Channel', price:500,  colors:2, piece_length_mm:2440, material:'Aluminium', availability:'AVAILABLE', use_case:'Houses LED strips; sheet edge mount', bundle_with_led:true};
MERGE (t:Trim {sku:'TR-MET-P'})       SET t += {name:'Metal Trim P',       subcategory:'TRIM_METAL', trim_type:'Metal-P', price:1200, colors:2, piece_length_mm:2440, material:'Aluminium', availability:'AVAILABLE', use_case:'Luxury premium edge closure'};
MERGE (t:Trim {sku:'TR-MET-L'})       SET t += {name:'Metal Trim L',       subcategory:'TRIM_METAL', trim_type:'Metal-L', price:600,  colors:3, piece_length_mm:2440, material:'Aluminium', availability:'AVAILABLE', use_case:'Premium corner finish'};

// ── 15. TRIMS — Other ───────────────────────────────────────────────────────
MERGE (t:Trim {sku:'TR-EDGEBAND-23'}) SET t += {name:'Edge Band 23mm', subcategory:'TRIM_OTHER', trim_type:'EdgeBand', price:500, colors:18, material:'PVC/Acrylic', unit:'roll',          availability:'AVAILABLE', applies_to:['TV_UNIT','SHELF','CABINET']};
MERGE (t:Trim {sku:'TR-SKIRTING'})    SET t += {name:'Skirting',        subcategory:'TRIM_OTHER', trim_type:'Skirting', price:800, colors:1,  material:'WPC/PVC',     piece_length_mm:2440, availability:'AVAILABLE', trigger:'panels_reach_floor'};

// ── 16. CONSUMABLES ─────────────────────────────────────────────────────────
MERGE (c:Consumable {sku:'CONS-CLIP50'})  SET c += {name:'Metal Clips (Pack of 50)', subcategory:'CONSUMABLE_CLIPS',   price:350,  pack_size:50, clips_per_panel_estimate:3, calc_formula:'ceil(panels*3/50)',    allowed_for:['PVC_PANEL','WPC_CLASSIC','WPC_NEW','WPC_CERAMIC'], forbidden_for:['PVC_FLUTE','CHARCOAL','SHEET']};
MERGE (c:Consumable {sku:'CONS-SILGLU'})  SET c += {name:'Silicon Glue',             subcategory:'CONSUMABLE_ADHESIVE',price:350,  coverage_charcoal_per_tube:8, coverage_sheet_per_tube:5, calc_formula_charcoal:'ceil(panels/8)', calc_formula_sheet:'ceil(sheets/5)', allowed_for:['CHARCOAL','SHT-UV-MARBLE','SHT-SPC']};
MERGE (c:Consumable {sku:'CONS-PVC5'})    SET c += {name:'PVC Board 5mm',            subcategory:'CONSUMABLE_BOARD',   price:1000, thickness_mm:5,  sheet_w_mm:1220, sheet_h_mm:2440, use_case:'Lightweight backing; uneven walls',       condition:'user_confirms_uneven_wall'};
MERGE (c:Consumable {sku:'CONS-PVC10'})   SET c += {name:'PVC Board 10mm',           subcategory:'CONSUMABLE_BOARD',   price:1500, thickness_mm:10, sheet_w_mm:1220, sheet_h_mm:2440, use_case:'Heavy backing; WPC Ceramic and SPC Sheet', condition:'user_confirms_uneven_wall'};
MERGE (c:Consumable {sku:'CONS-POLYFIX'}) SET c += {name:'Polyfix Joint Filler',     subcategory:'CONSUMABLE_FILLER',  price:150,  coverage_panels_per_tube:20, calc_formula:'max(1,ceil(panels/20))', always_include:true};

// ── 17. LED ─────────────────────────────────────────────────────────────────
MERGE (l:LEDProfile {sku:'LED-PROF-CER'})     SET l += {name:'Light Profile Ceramic',       price:450,  piece_length_mm:2440, colors:1, compat_type:'DEDICATED', dedicated_for:'WPC_CERAMIC', availability:'AVAILABLE'};
MERGE (l:LEDProfile {sku:'LED-PROF-FLUTED'})  SET l += {name:'Light Profile Fluted',        price:450,  piece_length_mm:2440, colors:1, compat_type:'DEDICATED', dedicated_for:'PVC_FLUTE',   availability:'AVAILABLE'};
MERGE (l:LEDProfile {sku:'LED-PROF-CLASSIC'}) SET l += {name:'Light Profile Classic',       price:450,  piece_length_mm:2440, colors:1, compat_type:'UNIVERSAL', universal:true,              availability:'AVAILABLE'};
MERGE (l:LEDProfile {sku:'LED-PROF-LCORNER'}) SET l += {name:'Light Profile L Corner',      price:450,  piece_length_mm:2440, colors:1, compat_type:'UNIVERSAL', use_case:'Internal corner',  availability:'AVAILABLE'};
MERGE (l:LEDProfile {sku:'LED-PROF-SMSQ'})    SET l += {name:'Light Profile Small Square',  price:800,  piece_length_mm:2440, colors:1, compat_type:'UNIVERSAL', use_case:'Recessed/surface', availability:'AVAILABLE'};
MERGE (l:LEDProfile {sku:'LED-WALLWASH'})      SET l += {name:'Wall Washer Profile',         price:1750, piece_length_mm:2440, colors:2, compat_type:'UNIVERSAL', use_case:'Wall-wash effect', availability:'AVAILABLE'};
MERGE (l:LEDProfile {sku:'LED-CASING'})        SET l += {name:'PVC LED Casing',              price:null, piece_length_mm:null, colors:0, compat_type:'NONE',                               availability:'UNAVAILABLE'};
MERGE (l:LEDStrip   {sku:'LED-STRIP-120'})     SET l += {name:'120 LED Strip',  price:500,  roll_length_mm:5000, density_per_m:120, availability:'AVAILABLE'};
MERGE (l:LEDStrip   {sku:'LED-STRIP-240'})     SET l += {name:'240 LED Strip',  price:800,  roll_length_mm:5000, density_per_m:240, availability:'AVAILABLE'};
MERGE (l:LEDKit     {sku:'LED-KIT-120'})        SET l += {name:'120 LED Installation Kit', price:2300, includes:['strip_120','driver','connectors'], recommended_for:'new_installs',         availability:'AVAILABLE'};
MERGE (l:LEDKit     {sku:'LED-KIT-240'})        SET l += {name:'240 LED Installation Kit', price:2850, includes:['strip_240','driver','connectors'], recommended_for:'new_installs_premium', availability:'AVAILABLE'};

// ── 18. FURNITURE — TV UNITS ────────────────────────────────────────────────
MERGE (f:Furniture {sku:'TV-PF-WALLNEST'})  SET f += {name:'PF Wall Nest Drawer',       subcategory:'TV_UNIT', series:'PF', style:'nested_drawers',  widths_ft:[4,5,6,7,8], prices:'{"4":13750,"5":15950,"6":18700,"7":22000,"8":23000}', finishes:6, installation:'DELIVERED_INSTALLED', warranty_years:1, availability:'AVAILABLE', popularity:'highest'};
MERGE (f:Furniture {sku:'TV-PF-AIRVIEW'})   SET f += {name:'PF Air View Unit',          subcategory:'TV_UNIT', series:'PF', style:'floating_open',    widths_ft:[4,5,6,7,8], prices:'{"4":13000,"5":15000,"6":17500,"7":20000,"8":23000}', finishes:6, installation:'DELIVERED_INSTALLED', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'TV-PF-OAKNEST'})   SET f += {name:'PF Oak Nest Unit',          subcategory:'TV_UNIT', series:'PF', style:'oak_nested_box',   widths_ft:[4,5,6,7,8], prices:'{"4":14300,"5":16500,"6":19800,"7":23100,"8":25000}', finishes:6, installation:'DELIVERED_INSTALLED', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'TV-PF-PUREOPEN'})  SET f += {name:'PF Pure Open Shelf',        subcategory:'TV_UNIT', series:'PF', style:'minimalist_open',  widths_ft:[6,7,8],     prices:'{"6":13200,"7":16500,"8":18000}',                   finishes:6, installation:'DELIVERED_INSTALLED', warranty_years:1, availability:'AVAILABLE', min_width_ft:6};
MERGE (f:Furniture {sku:'TV-PF-MODUFIT'})   SET f += {name:'PF Modu Fit Shelf',         subcategory:'TV_UNIT', series:'PF', style:'modular',          widths_ft:[6,7,8],     prices:'{"6":18000,"7":20000,"8":22000}',                   finishes:6, installation:'DELIVERED_INSTALLED', warranty_years:1, availability:'AVAILABLE', min_width_ft:6};
MERGE (f:Furniture {sku:'TV-PF-LEAFLEDGE'}) SET f += {name:'PF Leaf Ledge Shelf',       subcategory:'TV_UNIT', series:'PF', style:'premium_ledge',    widths_ft:[6,7,8],     prices:'{"6":24000,"7":25000,"8":27000}',                   finishes:6, installation:'DELIVERED_INSTALLED', warranty_years:1, availability:'AVAILABLE', min_width_ft:6};
MERGE (f:Furniture {sku:'TV-GL'})           SET f += {name:'GrooveLine TV Unit',         subcategory:'TV_UNIT', series:'GL', style:'grooved_minimal',  widths_ft:[4,5,6,7],   prices:'{"4":8000,"5":9500,"6":11000,"7":13000}',            finishes:4, installation:'DELIVERED_INSTALLED', warranty_years:1, availability:'AVAILABLE', max_width_ft:7};

// ── 19. FURNITURE — SHELVES ─────────────────────────────────────────────────
MERGE (f:Furniture {sku:'SHL-FRILL-2FT'})   SET f += {name:'Frill Shelf 2ft',    subcategory:'SHELF', style:'frill',       width_ft:2, load_kg_max:10, price:2750, finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'SHL-CUBIK-1FT'})   SET f += {name:'Cubik Shelf 1ft',    subcategory:'SHELF', style:'cubik',       width_ft:1, load_kg_max:8,  price:2200, finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'SHL-FLOAT-1FT'})   SET f += {name:'Floating Shelf 1ft', subcategory:'SHELF', style:'floating',    width_ft:1, load_kg_max:8,  price:1000, finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'SHL-FLOAT-2FT'})   SET f += {name:'Floating Shelf 2ft', subcategory:'SHELF', style:'floating',    width_ft:2, load_kg_max:12, price:1300, finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'SHL-FLOAT-3FT'})   SET f += {name:'Floating Shelf 3ft', subcategory:'SHELF', style:'floating',    width_ft:3, load_kg_max:15, price:1600, finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'SHL-FLOAT-4FT'})   SET f += {name:'Floating Shelf 4ft', subcategory:'SHELF', style:'floating',    width_ft:4, load_kg_max:18, price:2200, finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'SHL-BALANCE-4FT'}) SET f += {name:'BalanceBox 4ft',     subcategory:'SHELF', style:'balance_box', width_ft:4, load_kg_max:18, price:2500, finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};

// ── 20. FURNITURE — CABINETS ────────────────────────────────────────────────
MERGE (f:Furniture {sku:'CAB-OH-2FT-SINGLE'})    SET f += {name:'Overhead Cabinet 2ft (Single Door)', subcategory:'CABINET', type:'overhead',             width_ft:2,   doors:1, price:5300,  finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'CAB-OH-3FT-DOUBLE'})    SET f += {name:'Overhead Cabinet 3ft (Double Door)', subcategory:'CABINET', type:'overhead',             width_ft:3,   doors:2, price:7500,  finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'CAB-OH-1.5FT-INSTALL'}) SET f += {name:'Overhead Cabinet Install Only',      subcategory:'CABINET', type:'overhead_install_only',width_ft:1.5, doors:1, price:4500,  finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE', install_only:true};
MERGE (f:Furniture {sku:'CAB-HOV-2FT'})          SET f += {name:'Hover Cabinet 2ft',                  subcategory:'CABINET', type:'hover',                width_ft:2,          price:5700,  finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'CAB-HOV-3FT'})          SET f += {name:'Hover Cabinet 3ft',                  subcategory:'CABINET', type:'hover',                width_ft:3,          price:7150,  finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'CAB-HOV-4FT'})          SET f += {name:'Hover Cabinet 4ft',                  subcategory:'CABINET', type:'hover',                width_ft:4,          price:8800,  finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};

// ── 21. FURNITURE — DESKS ───────────────────────────────────────────────────
MERGE (f:Furniture {sku:'DSK-WORK-2FT'})   SET f += {name:'Work Desk 2ft',   subcategory:'DESK', width_ft:2, drawers:false, price:5500,  finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'DSK-WORK-3FT'})   SET f += {name:'Work Desk 3ft',   subcategory:'DESK', width_ft:3, drawers:false, price:6950,  finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'DSK-WORK-4FT'})   SET f += {name:'Work Desk 4ft',   subcategory:'DESK', width_ft:4, drawers:false, price:7500,  finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};
MERGE (f:Furniture {sku:'DSK-DRAWER-4FT'}) SET f += {name:'Drawer Desk 4ft', subcategory:'DESK', width_ft:4, drawers:true,  price:12000, finishes:4, installation:'WALL_MOUNTED_INSTALL', warranty_years:1, availability:'AVAILABLE'};


// ─────────────────────────────────────────────────────────────────────────────
// 22. RELATIONSHIP BLOCKS — BELONGS_TO
// ─────────────────────────────────────────────────────────────────────────────
// Links every product node to its Subcategory for graph traversal.

MATCH (p:Panel), (s:Subcategory) WHERE p.subcategory = s.name MERGE (p)-[:BELONGS_TO]->(s);
MATCH (t:Trim),  (s:Subcategory) WHERE t.subcategory = s.name MERGE (t)-[:BELONGS_TO]->(s);
MATCH (c:Consumable), (s:Subcategory) WHERE c.subcategory = s.name MERGE (c)-[:BELONGS_TO]->(s);
MATCH (l:LEDProfile), (s:Subcategory {name:'LED_PROFILE'}) MERGE (l)-[:BELONGS_TO]->(s);
MATCH (l:LEDStrip),   (s:Subcategory {name:'LED_STRIP'})   MERGE (l)-[:BELONGS_TO]->(s);
MATCH (l:LEDKit),     (s:Subcategory {name:'LED_KIT'})     MERGE (l)-[:BELONGS_TO]->(s);
MATCH (f:Furniture),  (s:Subcategory) WHERE f.subcategory = s.name MERGE (f)-[:BELONGS_TO]->(s);


// ─────────────────────────────────────────────────────────────────────────────
// 23. RELATIONSHIP BLOCKS — USES_METHOD
// ─────────────────────────────────────────────────────────────────────────────
// Maps subcategories and specific panels to their installation method.

MATCH (s:Subcategory {name:'PVC_PANEL'}),  (m:InstallationMethod {name:'CLIP_ADHESIVE'})   MERGE (s)-[:USES_METHOD]->(m);
MATCH (s:Subcategory {name:'PVC_FLUTE'}),  (m:InstallationMethod {name:'BATTEN_ADHESIVE'}) MERGE (s)-[:USES_METHOD]->(m);
MATCH (s:Subcategory {name:'WPC_CLASSIC'}),(m:InstallationMethod {name:'CLIP_ADHESIVE'})   MERGE (s)-[:USES_METHOD]->(m);
MATCH (s:Subcategory {name:'WPC_NEW'}),    (m:InstallationMethod {name:'CLIP_ADHESIVE'})   MERGE (s)-[:USES_METHOD]->(m);
MATCH (s:Subcategory {name:'WPC_CERAMIC'}),(m:InstallationMethod {name:'CLIP_ADHESIVE'})   MERGE (s)-[:USES_METHOD]->(m);
MATCH (s:Subcategory {name:'CHARCOAL'}),   (m:InstallationMethod {name:'SILICON_GLUE'})    MERGE (s)-[:USES_METHOD]->(m);
MATCH (p:Panel) WHERE p.sku IN ['SHT-UV-MARBLE','SHT-SPC']
MATCH (m:InstallationMethod {name:'SILICON_GLUE'})   MERGE (p)-[:USES_METHOD]->(m);
MATCH (p:Panel) WHERE p.sku IN ['SHT-METALLIC','SHT-WPC-5MM','SHT-WPC-GROOVED-7MM']
MATCH (m:InstallationMethod {name:'ADHESIVE_ONLY'})  MERGE (p)-[:USES_METHOD]->(m);


// ─────────────────────────────────────────────────────────────────────────────
// 24. RELATIONSHIP BLOCKS — HAS_*_TRIM (Panel → Trim mappings)
// ─────────────────────────────────────────────────────────────────────────────
// Each panel is linked to its compatible U, L, and H trims.
// relationship_type: AUTO_SUGGESTED = auto-added to cart, OPTIONAL = user choice.

// PVC_PANEL trim assignments (U + L + H for each design family)
MATCH (p:Panel) WHERE p.sku IN ['PVC-PLAINWOOD','PVC-GROOVEDWOOD']
MATCH (u:Trim {sku:'TR-U-WOOD'}),(l:Trim {sku:'TR-L-WOOD'}),(h:Trim {sku:'TR-H-BIDDING'})
MERGE (p)-[:HAS_U_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(u)
MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l)
MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);

MATCH (p:Panel {sku:'PVC-FLORAL'}),(u:Trim {sku:'TR-U-FLORAL'}),(l:Trim {sku:'TR-L-FLORAL'}),(h:Trim {sku:'TR-H-BIDDING'})   MERGE (p)-[:HAS_U_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(u) MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l) MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);
MATCH (p:Panel {sku:'PVC-TRAD'}),  (u:Trim {sku:'TR-U-TRAD'}),  (l:Trim {sku:'TR-L-TRAD'}),  (h:Trim {sku:'TR-H-BIDDING'})   MERGE (p)-[:HAS_U_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(u) MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l) MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);
MATCH (p:Panel {sku:'PVC-GEOM'}),  (u:Trim {sku:'TR-U-GEOM'}),  (l:Trim {sku:'TR-L-GEOM'}),  (h:Trim {sku:'TR-H-BIDDING'})   MERGE (p)-[:HAS_U_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(u) MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l) MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);
MATCH (p:Panel {sku:'PVC-TEXTURE'}),(u:Trim {sku:'TR-U-TEXTURE'}),(l:Trim {sku:'TR-L-TEXTURE'}),(h:Trim {sku:'TR-H-BIDDING'}) MERGE (p)-[:HAS_U_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(u) MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l) MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);
MATCH (p:Panel {sku:'PVC-STONE'}),  (u:Trim {sku:'TR-U-STONE'}), (l:Trim {sku:'TR-L-STONE'}), (h:Trim {sku:'TR-H-BIDDING'})   MERGE (p)-[:HAS_U_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(u) MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l) MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);

// PVC_FLUTE: No U-Bidding, optional L, standard H
MATCH (p:Panel) WHERE p.subcategory = 'PVC_FLUTE'
MATCH (l:Trim {sku:'TR-L-SOLID'}),(h:Trim {sku:'TR-H-BIDDING'})
MERGE (p)-[:HAS_L_TRIM {relationship_type:'OPTIONAL'}]->(l)
MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);

// WPC_CLASSIC (WPC-NEUTRAL only)
MATCH (p:Panel {sku:'WPC-NEUTRAL'}),(l:Trim {sku:'TR-L-NEUTRAL'}),(h:Trim {sku:'TR-H-BIDDING'}) MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l) MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);

// WPC_NEW: shared L + H
MATCH (p:Panel) WHERE p.subcategory = 'WPC_NEW'
MATCH (l:Trim {sku:'TR-L-WPC-NEW'}),(h:Trim {sku:'TR-H-BIDDING'})
MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l)
MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);

// WPC_CERAMIC: shared L + H
MATCH (p:Panel) WHERE p.subcategory = 'WPC_CERAMIC'
MATCH (l:Trim {sku:'TR-L-WPC-CER'}),(h:Trim {sku:'TR-H-BIDDING'})
MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l)
MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);

// SHEET (excluding SHT-WPC-GROOVED-7MM): standard U + L + H
MATCH (p:Panel) WHERE p.subcategory = 'SHEET' AND p.sku <> 'SHT-WPC-GROOVED-7MM'
MATCH (u:Trim {sku:'TR-U-SHEET'}),(l:Trim {sku:'TR-L-SHEET'}),(h:Trim {sku:'TR-H-BIDDING'})
MERGE (p)-[:HAS_U_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(u)
MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l)
MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(h);

// SHT-WPC-GROOVED-7MM: uses special WPC H-Trim instead of standard H Bidding
MATCH (p:Panel {sku:'SHT-WPC-GROOVED-7MM'}),(u:Trim {sku:'TR-U-SHEET'}),(l:Trim {sku:'TR-L-SHEET'}),(h:Trim {sku:'TR-WPC-H-TRIM'})
MERGE (p)-[:HAS_U_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(u)
MERGE (p)-[:HAS_L_TRIM {relationship_type:'AUTO_SUGGESTED'}]->(l)
MERGE (p)-[:HAS_H_TRIM {relationship_type:'AUTO_SUGGESTED', note:'Special H-trim for grooved WPC sheets only'}]->(h);

// Metal trims are OPTIONAL for WPC and CHARCOAL families
MATCH (p:Panel) WHERE p.subcategory IN ['WPC_CLASSIC','WPC_NEW','WPC_CERAMIC','CHARCOAL']
MATCH (mt:Trim) WHERE mt.subcategory = 'TRIM_METAL'
MERGE (p)-[:HAS_METAL_TRIM {relationship_type:'OPTIONAL'}]->(mt);


// ─────────────────────────────────────────────────────────────────────────────
// 25. RELATIONSHIP BLOCKS — LED (Dedicated & Compatible)
// ─────────────────────────────────────────────────────────────────────────────

// Dedicated LED profiles (highest priority — auto-suggested)
MATCH (p:Panel) WHERE p.subcategory = 'PVC_FLUTE'  MATCH (lp:LEDProfile {sku:'LED-PROF-FLUTED'}) MERGE (p)-[:HAS_DEDICATED_LED {relationship_type:'AUTO_SUGGESTED', priority:1}]->(lp);
MATCH (p:Panel) WHERE p.subcategory = 'WPC_CERAMIC' MATCH (lp:LEDProfile {sku:'LED-PROF-CER'})    MERGE (p)-[:HAS_DEDICATED_LED {relationship_type:'AUTO_SUGGESTED', priority:1}]->(lp);

// Universal LED compatibility (lower priority — optional)
MATCH (p:Panel),(lp:LEDProfile {sku:'LED-PROF-CLASSIC'})  WHERE p.availability <> 'UNAVAILABLE' MERGE (p)-[:COMPATIBLE_LED {relationship_type:'OPTIONAL', priority:2}]->(lp);
MATCH (p:Panel),(lp:LEDProfile {sku:'LED-WALLWASH'})       WHERE p.availability <> 'UNAVAILABLE' MERGE (p)-[:COMPATIBLE_LED {relationship_type:'OPTIONAL'}]->(lp);
MATCH (p:Panel),(lp:LEDProfile {sku:'LED-PROF-LCORNER'})   WHERE p.subcategory <> 'CHARCOAL' AND p.availability <> 'UNAVAILABLE' MERGE (p)-[:COMPATIBLE_LED {relationship_type:'OPTIONAL'}]->(lp);
MATCH (p:Panel),(lp:LEDProfile {sku:'LED-PROF-SMSQ'})      WHERE p.subcategory <> 'CHARCOAL' AND p.availability <> 'UNAVAILABLE' MERGE (p)-[:COMPATIBLE_LED {relationship_type:'OPTIONAL'}]->(lp);

// SHEET + LED → auto-bundle aluminium channel
MATCH (p:Panel) WHERE p.subcategory = 'SHEET'
MATCH (t:Trim {sku:'TR-MET-CHANNEL'})
MERGE (p)-[:BUNDLE_WITH_LED {condition:'led_profile_selected', relationship_type:'CONDITIONAL'}]->(t);


// ─────────────────────────────────────────────────────────────────────────────
// 26. RULE ENGINE — LAYER 2: Installation Contract Rules
// ─────────────────────────────────────────────────────────────────────────────
// Each subcategory/panel has an installation contract that specifies which
// consumables are REQUIRED, FORBIDDEN, or OPTIONAL (conditional).
// All rules use MERGE + SET for idempotency [FIX-1].

// --- PVC_PANEL: clips required; silicon forbidden ---
MATCH (s:Subcategory {name:'PVC_PANEL'})
MERGE (r:Rule {id:'INSTALL_CONTRACT_PVC_PANEL'})
SET r.type = 'INSTALLATION_CONTRACT', r.method = 'CLIP_ADHESIVE',
    r.description = 'PVC Panels: clips required; silicon forbidden.', r.severity = 'REQUIRED'
MERGE (r)-[:APPLIES_TO]->(s)
WITH r
MATCH (clip:Consumable {sku:'CONS-CLIP50'}),(sil:Consumable {sku:'CONS-SILGLU'}),
      (poly:Consumable {sku:'CONS-POLYFIX'}),(b5:Consumable {sku:'CONS-PVC5'}),(b10:Consumable {sku:'CONS-PVC10'})
MERGE (r)-[:REQUIRES_CONSUMABLE {relationship_type:'REQUIRED'}]->(clip)
MERGE (r)-[:REQUIRES_CONSUMABLE {relationship_type:'REQUIRED'}]->(poly)
MERGE (r)-[:FORBIDS_CONSUMABLE]->(sil)
MERGE (r)-[:OPTIONAL_CONSUMABLE {condition:'user_confirms_uneven_wall', default:false}]->(b5)
MERGE (r)-[:OPTIONAL_CONSUMABLE {condition:'user_confirms_uneven_wall AND panel_weight_heavy', default:false}]->(b10);

// --- PVC_FLUTE: batten frame + adhesive; clips and silicon forbidden ---
MATCH (s:Subcategory {name:'PVC_FLUTE'})
MERGE (r:Rule {id:'INSTALL_CONTRACT_PVC_FLUTE'})
SET r.type = 'INSTALLATION_CONTRACT', r.method = 'BATTEN_ADHESIVE', r.severity = 'REQUIRED',
    r.description = 'Flute: batten frame + adhesive. Clips and silicon forbidden.',
    r.advisory = 'Batten frame and panel adhesive not in SKU list — confirm with installation team.'
MERGE (r)-[:APPLIES_TO]->(s)
WITH r
MATCH (clip:Consumable {sku:'CONS-CLIP50'}),(sil:Consumable {sku:'CONS-SILGLU'}),
      (poly:Consumable {sku:'CONS-POLYFIX'}),(b10:Consumable {sku:'CONS-PVC10'})
MERGE (r)-[:FORBIDS_CONSUMABLE]->(clip)
MERGE (r)-[:FORBIDS_CONSUMABLE]->(sil)
MERGE (r)-[:REQUIRES_CONSUMABLE {relationship_type:'REQUIRED'}]->(poly)
MERGE (r)-[:OPTIONAL_CONSUMABLE {condition:'user_confirms_uneven_wall', default:false}]->(b10);

// --- WPC_CLASSIC, WPC_NEW, WPC_CERAMIC: clips required; silicon forbidden ---
UNWIND ['WPC_CLASSIC','WPC_NEW','WPC_CERAMIC'] AS sc_name
MATCH (s:Subcategory {name:sc_name})
MERGE (r:Rule {id:'INSTALL_CONTRACT_' + sc_name})
SET r.type = 'INSTALLATION_CONTRACT', r.method = 'CLIP_ADHESIVE', r.severity = 'REQUIRED',
    r.description = sc_name + ': clips required; silicon forbidden.'
MERGE (r)-[:APPLIES_TO]->(s)
WITH r
MATCH (clip:Consumable {sku:'CONS-CLIP50'}),(sil:Consumable {sku:'CONS-SILGLU'}),
      (poly:Consumable {sku:'CONS-POLYFIX'}),(b5:Consumable {sku:'CONS-PVC5'}),(b10:Consumable {sku:'CONS-PVC10'})
MERGE (r)-[:REQUIRES_CONSUMABLE {relationship_type:'REQUIRED'}]->(clip)
MERGE (r)-[:REQUIRES_CONSUMABLE {relationship_type:'REQUIRED'}]->(poly)
MERGE (r)-[:FORBIDS_CONSUMABLE]->(sil)
MERGE (r)-[:OPTIONAL_CONSUMABLE {condition:'user_confirms_uneven_wall', default:false}]->(b5)
MERGE (r)-[:OPTIONAL_CONSUMABLE {condition:'user_confirms_uneven_wall', default:false}]->(b10);

// --- CHARCOAL: silicon glue only; clips strictly forbidden ---
MATCH (s:Subcategory {name:'CHARCOAL'})
MERGE (r:Rule {id:'INSTALL_CONTRACT_CHARCOAL'})
SET r.type = 'INSTALLATION_CONTRACT', r.method = 'SILICON_GLUE', r.severity = 'REQUIRED',
    r.description = 'Charcoal: silicon glue only. Clips strictly forbidden.'
MERGE (r)-[:APPLIES_TO]->(s)
WITH r
MATCH (clip:Consumable {sku:'CONS-CLIP50'}),(sil:Consumable {sku:'CONS-SILGLU'}),
      (poly:Consumable {sku:'CONS-POLYFIX'}),(b5:Consumable {sku:'CONS-PVC5'}),(b10:Consumable {sku:'CONS-PVC10'})
MERGE (r)-[:REQUIRES_CONSUMABLE {relationship_type:'REQUIRED'}]->(sil)
MERGE (r)-[:REQUIRES_CONSUMABLE {relationship_type:'REQUIRED'}]->(poly)
MERGE (r)-[:FORBIDS_CONSUMABLE]->(clip)
MERGE (r)-[:OPTIONAL_CONSUMABLE {condition:'user_confirms_uneven_wall', default:false}]->(b5)
MERGE (r)-[:OPTIONAL_CONSUMABLE {condition:'user_confirms_uneven_wall', default:false}]->(b10);

// --- SHEET (Silicon Glue panels): SHT-UV-MARBLE, SHT-SPC ---
UNWIND ['SHT-UV-MARBLE','SHT-SPC'] AS psku
MATCH (p:Panel {sku:psku})
MERGE (r:Rule {id:'INSTALL_CONTRACT_' + psku})
SET r.type = 'INSTALLATION_CONTRACT', r.method = 'SILICON_GLUE', r.severity = 'REQUIRED',
    r.description = psku + ': silicon glue. Clips forbidden. PVC10 recommended.'
MERGE (r)-[:APPLIES_TO]->(p)
WITH r
MATCH (clip:Consumable {sku:'CONS-CLIP50'}),(sil:Consumable {sku:'CONS-SILGLU'}),
      (poly:Consumable {sku:'CONS-POLYFIX'}),(b10:Consumable {sku:'CONS-PVC10'})
MERGE (r)-[:REQUIRES_CONSUMABLE {relationship_type:'REQUIRED'}]->(sil)
MERGE (r)-[:REQUIRES_CONSUMABLE {relationship_type:'REQUIRED'}]->(poly)
MERGE (r)-[:FORBIDS_CONSUMABLE]->(clip)
MERGE (r)-[:OPTIONAL_CONSUMABLE {condition:'user_confirms_uneven_wall', preferred:true}]->(b10);

// --- SHEET (Adhesive Only panels): SHT-METALLIC, SHT-WPC-5MM, SHT-WPC-GROOVED-7MM ---
UNWIND ['SHT-METALLIC','SHT-WPC-5MM','SHT-WPC-GROOVED-7MM'] AS psku
MATCH (p:Panel {sku:psku})
MERGE (r:Rule {id:'INSTALL_CONTRACT_' + psku})
SET r.type = 'INSTALLATION_CONTRACT', r.method = 'ADHESIVE_ONLY', r.severity = 'REQUIRED',
    r.description = psku + ': generic adhesive. Clips and silicon forbidden.',
    r.advisory = 'Panel adhesive not in current SKU list — confirm with installation team.'
MERGE (r)-[:APPLIES_TO]->(p)
WITH r
MATCH (clip:Consumable {sku:'CONS-CLIP50'}),(sil:Consumable {sku:'CONS-SILGLU'}),
      (poly:Consumable {sku:'CONS-POLYFIX'}),(b10:Consumable {sku:'CONS-PVC10'})
MERGE (r)-[:REQUIRES_CONSUMABLE {relationship_type:'REQUIRED'}]->(poly)
MERGE (r)-[:FORBIDS_CONSUMABLE]->(clip)
MERGE (r)-[:FORBIDS_CONSUMABLE]->(sil)
MERGE (r)-[:OPTIONAL_CONSUMABLE {condition:'user_confirms_uneven_wall', default:false}]->(b10);


// ─────────────────────────────────────────────────────────────────────────────
// 27. RULE ENGINE — LAYER 2: LED Compatibility Rules
// ─────────────────────────────────────────────────────────────────────────────

// PVC_PANEL: universal LED (Classic, L-Corner, SmSq, WallWash)
MATCH (s:Subcategory {name:'PVC_PANEL'})
MERGE (r:Rule {id:'LED_COMPAT_PVC_PANEL'})
SET r.type = 'LED_COMPATIBILITY', r.compat_type = 'UNIVERSAL', r.primary_suggestion = 'LED-PROF-CLASSIC'
MERGE (r)-[:APPLIES_TO]->(s)
WITH r MATCH (lp:LEDProfile) WHERE lp.sku IN ['LED-PROF-CLASSIC','LED-PROF-LCORNER','LED-PROF-SMSQ','LED-WALLWASH']
MERGE (r)-[:COMPATIBLE_LED_PROFILE {rank: CASE lp.sku WHEN 'LED-PROF-CLASSIC' THEN 1 ELSE 2 END}]->(lp);

// PVC_FLUTE: dedicated fluted profile + universal fallbacks
MATCH (s:Subcategory {name:'PVC_FLUTE'})
MERGE (r:Rule {id:'LED_COMPAT_PVC_FLUTE'})
SET r.type = 'LED_COMPATIBILITY', r.compat_type = 'DEDICATED', r.dedicated_profile = 'LED-PROF-FLUTED', r.primary_suggestion = 'LED-PROF-FLUTED'
MERGE (r)-[:APPLIES_TO]->(s)
WITH r MATCH (lp:LEDProfile) WHERE lp.sku IN ['LED-PROF-FLUTED','LED-PROF-CLASSIC','LED-PROF-SMSQ','LED-WALLWASH']
MERGE (r)-[:COMPATIBLE_LED_PROFILE {rank: CASE lp.sku WHEN 'LED-PROF-FLUTED' THEN 1 ELSE 2 END}]->(lp);

// WPC_CERAMIC: dedicated ceramic profile + universal fallbacks
MATCH (s:Subcategory {name:'WPC_CERAMIC'})
MERGE (r:Rule {id:'LED_COMPAT_WPC_CERAMIC'})
SET r.type = 'LED_COMPATIBILITY', r.compat_type = 'DEDICATED', r.dedicated_profile = 'LED-PROF-CER', r.primary_suggestion = 'LED-PROF-CER'
MERGE (r)-[:APPLIES_TO]->(s)
WITH r MATCH (lp:LEDProfile) WHERE lp.sku IN ['LED-PROF-CER','LED-PROF-CLASSIC','LED-PROF-SMSQ','LED-WALLWASH']
MERGE (r)-[:COMPATIBLE_LED_PROFILE {rank: CASE lp.sku WHEN 'LED-PROF-CER' THEN 1 ELSE 2 END}]->(lp);

// CHARCOAL: limited to Classic + WallWash (no L-Corner, no SmSq)
MATCH (s:Subcategory {name:'CHARCOAL'})
MERGE (r:Rule {id:'LED_COMPAT_CHARCOAL'})
SET r.type = 'LED_COMPATIBILITY', r.compat_type = 'UNIVERSAL', r.primary_suggestion = 'LED-PROF-CLASSIC',
    r.note = 'Classic most suitable for charcoal. LCORNER and SMSQ not recommended.'
MERGE (r)-[:APPLIES_TO]->(s)
WITH r MATCH (lp:LEDProfile) WHERE lp.sku IN ['LED-PROF-CLASSIC','LED-WALLWASH']
MERGE (r)-[:COMPATIBLE_LED_PROFILE]->(lp);

// WPC_CLASSIC, WPC_NEW, SHEET: full universal LED support
UNWIND ['WPC_CLASSIC','WPC_NEW','SHEET'] AS sc_name
MATCH (s:Subcategory {name:sc_name})
MERGE (r:Rule {id:'LED_COMPAT_' + sc_name})
SET r.type = 'LED_COMPATIBILITY', r.compat_type = 'UNIVERSAL', r.primary_suggestion = 'LED-PROF-CLASSIC'
MERGE (r)-[:APPLIES_TO]->(s)
WITH r MATCH (lp:LEDProfile) WHERE lp.sku IN ['LED-PROF-CLASSIC','LED-PROF-LCORNER','LED-PROF-SMSQ','LED-WALLWASH']
MERGE (r)-[:COMPATIBLE_LED_PROFILE {rank: CASE lp.sku WHEN 'LED-PROF-CLASSIC' THEN 1 ELSE 2 END}]->(lp);


// ─────────────────────────────────────────────────────────────────────────────
// 28. RULE ENGINE — LAYER 2: Validation Rules (V-01 through V-20)
// ─────────────────────────────────────────────────────────────────────────────
// Panel/subcategory-scoped rules -> APPLIES_TO panel or subcategory node.
// Cart-scoped rules -> APPLIES_TO CartScene {name:'GLOBAL_CART'}.
// All rules use MERGE + SET for idempotency [FIX-1 + FIX-2].

// V-01: PVC_FLUTE + CONS-CLIP50 — clips forbidden (subcategory-scoped)
MATCH (s:Subcategory {name:'PVC_FLUTE'}),(c:Consumable {sku:'CONS-CLIP50'})
MERGE (r:Rule {id:'V-01'})
SET r.type = 'VALIDATION', r.severity = 'ERROR', r.name = 'Flute panels must not use clips',
    r.trigger_condition = 'subcategory = "PVC_FLUTE" AND cart_contains("CONS-CLIP50")',
    r.action = 'remove_from_cart("CONS-CLIP50")',
    r.message = 'PVC Flute panels require a batten frame, not metal clips. Remove clips from your order.'
MERGE (r)-[:APPLIES_TO]->(s)
MERGE (r)-[:INCOMPATIBLE_ACCESSORY]->(c);

// V-02: CHARCOAL + CONS-CLIP50 — clips forbidden (subcategory-scoped)
MATCH (s:Subcategory {name:'CHARCOAL'}),(c:Consumable {sku:'CONS-CLIP50'})
MERGE (r:Rule {id:'V-02'})
SET r.type = 'VALIDATION', r.severity = 'ERROR', r.name = 'Charcoal panels must not use clips',
    r.trigger_condition = 'subcategory = "CHARCOAL" AND cart_contains("CONS-CLIP50")',
    r.action = 'remove_from_cart("CONS-CLIP50")',
    r.message = 'Charcoal panels use silicon glue only. Remove clips from your order.'
MERGE (r)-[:APPLIES_TO]->(s)
MERGE (r)-[:INCOMPATIBLE_ACCESSORY]->(c);

// V-03: UV/SPC sheets + clips forbidden (panel-scoped)
MATCH (c:Consumable {sku:'CONS-CLIP50'})
MATCH (p1:Panel {sku:'SHT-UV-MARBLE'}),(p2:Panel {sku:'SHT-SPC'})
MERGE (r:Rule {id:'V-03'})
SET r.type = 'VALIDATION', r.severity = 'ERROR', r.name = 'UV/SPC sheets must not use clips',
    r.trigger_condition = 'panel_sku IN ["SHT-UV-MARBLE","SHT-SPC"] AND cart_contains("CONS-CLIP50")',
    r.action = 'remove_from_cart("CONS-CLIP50")',
    r.message = 'UV and SPC sheets use silicon glue, not clips. Remove clips from your order.'
MERGE (r)-[:APPLIES_TO]->(p1)
MERGE (r)-[:APPLIES_TO]->(p2)
MERGE (r)-[:INCOMPATIBLE_ACCESSORY]->(c);

// V-04: SHT-WPC-GROOVED-7MM H-trim swap (panel-scoped)
MATCH (p:Panel {sku:'SHT-WPC-GROOVED-7MM'}),(bad:Trim {sku:'TR-H-BIDDING'}),(good:Trim {sku:'TR-WPC-H-TRIM'})
MERGE (r:Rule {id:'V-04'})
SET r.type = 'VALIDATION', r.severity = 'ERROR', r.name = 'Grooved WPC sheet requires specific H-Trim',
    r.trigger_condition = 'panel_sku = "SHT-WPC-GROOVED-7MM" AND cart_contains("TR-H-BIDDING") AND NOT cart_contains("TR-WPC-H-TRIM")',
    r.action = 'swap_in_cart("TR-H-BIDDING","TR-WPC-H-TRIM")',
    r.message = 'Grooved WPC sheets require TR-WPC-H-TRIM (₹430) as the joiner, not standard H Bidding. Swapping automatically.'
MERGE (r)-[:APPLIES_TO]->(p)
MERGE (r)-[:INCOMPATIBLE_ACCESSORY]->(bad)
MERGE (r)-[:REQUIRES_ACCESSORY {relationship_type:'AUTO_SUGGESTED'}]->(good);

// V-05: CHARCOAL + PVC bidding trims — incompatible (subcategory + CartScene)
MATCH (s:Subcategory {name:'CHARCOAL'}),(cs:CartScene {name:'GLOBAL_CART'})
MERGE (r:Rule {id:'V-05'})
SET r.type = 'VALIDATION', r.severity = 'WARNING', r.name = 'Charcoal does not support standard bidding trims',
    r.trigger_condition = 'subcategory = "CHARCOAL" AND cart_contains_any(["TR-U-FLORAL","TR-U-TEXTURE","TR-U-STONE","TR-U-TRAD","TR-U-GEOM","TR-U-WOOD","TR-U-SHEET","TR-L-NEUTRAL","TR-L-WOOD","TR-L-SHEET","TR-L-WPC-NEW","TR-L-WPC-CER"])',
    r.action = 'prompt_removal',
    r.message = 'Standard bidding trims are not designed for Charcoal. Only metal trims (TR-MET-*) apply. Remove incompatible trims?'
MERGE (r)-[:APPLIES_TO]->(s)
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs);

// V-06: CHARCOAL + H-Bidding — incompatible (subcategory-scoped)
MATCH (s:Subcategory {name:'CHARCOAL'}),(t:Trim {sku:'TR-H-BIDDING'})
MERGE (r:Rule {id:'V-06'})
SET r.type = 'VALIDATION', r.severity = 'ERROR', r.name = 'Charcoal does not use H-Bidding joiner',
    r.trigger_condition = 'subcategory = "CHARCOAL" AND cart_contains("TR-H-BIDDING")',
    r.action = 'remove_from_cart("TR-H-BIDDING")',
    r.message = 'Charcoal panels are butt-jointed with silicon glue. H-Bidding joiner is not applicable.'
MERGE (r)-[:APPLIES_TO]->(s)
MERGE (r)-[:INCOMPATIBLE_ACCESSORY]->(t);

// V-07: ON_REQUEST product in cart — block quote (cart-scoped)
MATCH (cs:CartScene {name:'GLOBAL_CART'})
MERGE (r:Rule {id:'V-07'})
SET r.type = 'VALIDATION', r.severity = 'ERROR', r.name = 'On-Request product in cart',
    r.trigger_condition = 'ANY cart_sku WHERE get_availability(cart_sku) = "ON_REQUEST"',
    r.action = 'block_quote_generation',
    r.message = 'One or more items are available on custom order only and cannot be in an automated quote. Remove them or submit an On-Request inquiry separately.'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs);

// V-08: LED profile without strip/kit — incomplete setup (cart-scoped)
MATCH (cs:CartScene {name:'GLOBAL_CART'}),(s1:Subcategory {name:'LED_PROFILE'}),(s2:Subcategory {name:'LED_STRIP'}),(s3:Subcategory {name:'LED_KIT'})
MERGE (r:Rule {id:'V-08'})
SET r.type = 'VALIDATION', r.severity = 'WARNING', r.name = 'LED profile without LED strip or kit',
    r.trigger_condition = 'cart_contains_any(LED_PROFILES) AND NOT cart_contains_any(LED_STRIPS_AND_KITS)',
    r.action = 'prompt_add_led_strip',
    r.message = 'You have an LED profile but no LED strip or kit. Your lighting setup will be incomplete. Add a strip or kit?'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs)
MERGE (r)-[:TRIGGERED_BY]->(s1)
MERGE (r)-[:REQUIRES_ONE_OF]->(s2)
MERGE (r)-[:REQUIRES_ONE_OF]->(s3);

// V-09: TR-L-WPC-NEW without WPC_NEW panel — mismatch warning (cart-scoped)
MATCH (cs:CartScene {name:'GLOBAL_CART'}),(t:Trim {sku:'TR-L-WPC-NEW'}),(s:Subcategory {name:'WPC_NEW'})
MERGE (r:Rule {id:'V-09'})
SET r.type = 'VALIDATION', r.severity = 'WARNING', r.name = 'WPC L Bidding New used without WPC New panel',
    r.trigger_condition = 'cart_contains("TR-L-WPC-NEW") AND subcategory <> "WPC_NEW"',
    r.action = 'prompt_confirm',
    r.message = 'WPC L Bidding New (TR-L-WPC-NEW) is designed for WPC New panels. Is this intentional?'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs)
MERGE (r)-[:TRIGGERED_BY]->(t)
MERGE (r)-[:EXPECTS_SUBCATEGORY]->(s);

// V-10: LED-PROF-FLUTED without PVC_FLUTE — mismatch warning (cart-scoped)
MATCH (cs:CartScene {name:'GLOBAL_CART'}),(lp:LEDProfile {sku:'LED-PROF-FLUTED'}),(s:Subcategory {name:'PVC_FLUTE'})
MERGE (r:Rule {id:'V-10'})
SET r.type = 'VALIDATION', r.severity = 'WARNING', r.name = 'Fluted LED profile without PVC Flute panel',
    r.trigger_condition = 'cart_contains("LED-PROF-FLUTED") AND subcategory <> "PVC_FLUTE"',
    r.action = 'prompt_confirm',
    r.message = 'Fluted LED Profile is designed for PVC Flute panels. Is this correct?'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs)
MERGE (r)-[:TRIGGERED_BY]->(lp)
MERGE (r)-[:EXPECTS_SUBCATEGORY]->(s);

// V-11: LED-PROF-CER without WPC_CERAMIC — mismatch warning (cart-scoped)
MATCH (cs:CartScene {name:'GLOBAL_CART'}),(lp:LEDProfile {sku:'LED-PROF-CER'}),(s:Subcategory {name:'WPC_CERAMIC'})
MERGE (r:Rule {id:'V-11'})
SET r.type = 'VALIDATION', r.severity = 'WARNING', r.name = 'Ceramic LED profile without WPC Ceramic panel',
    r.trigger_condition = 'cart_contains("LED-PROF-CER") AND subcategory <> "WPC_CERAMIC"',
    r.action = 'prompt_confirm',
    r.message = 'Ceramic LED Profile is designed for WPC Ceramic panels. Is this correct?'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs)
MERGE (r)-[:TRIGGERED_BY]->(lp)
MERGE (r)-[:EXPECTS_SUBCATEGORY]->(s);

// V-12: Non-waterproof panel in wet room (cart-scoped + CHARCOAL anchor)
MATCH (cs:CartScene {name:'GLOBAL_CART'}),(s:Subcategory {name:'CHARCOAL'})
MERGE (r:Rule {id:'V-12'})
SET r.type = 'VALIDATION', r.severity = 'WARNING', r.name = 'Non-waterproof panel in wet room',
    r.trigger_condition = 'room_type IN ["bathroom","kitchen"] AND panel_sku IN non_rated_skus',
    r.non_rated_skus = ['CH-CL2','CH-MINCONC-SM','CH-CLASSIC-NEW','CH-CONCAVE','CH-FLUTED','CH-MINRECT','CH-MINCONC-PREM','SHT-METALLIC','SHT-WPC-5MM','SHT-WPC-GROOVED-7MM'],
    r.action = 'show_warning_badge',
    r.message = 'This panel is not rated for wet environments. Recommend SHT-UV-MARBLE, SHT-SPC, or WPC Ceramic for bathroom/kitchen.'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs)
MERGE (r)-[:APPLIES_TO]->(s);

// V-13: PF TV Unit 6ft minimum width (furniture-scoped)
MATCH (f1:Furniture {sku:'TV-PF-PUREOPEN'}),(f2:Furniture {sku:'TV-PF-MODUFIT'}),(f3:Furniture {sku:'TV-PF-LEAFLEDGE'})
MERGE (r:Rule {id:'V-13'})
SET r.type = 'VALIDATION', r.severity = 'ERROR', r.name = 'PF TV Unit 6ft minimum width',
    r.trigger_condition = 'tv_unit_sku IN ["TV-PF-PUREOPEN","TV-PF-MODUFIT","TV-PF-LEAFLEDGE"] AND selected_width_ft < 6',
    r.action = 'disable_width_options([4,5])',
    r.message = 'This TV unit is only available from 6 ft. Please select 6 ft, 7 ft, or 8 ft.'
MERGE (r)-[:APPLIES_TO]->(f1)
MERGE (r)-[:APPLIES_TO]->(f2)
MERGE (r)-[:APPLIES_TO]->(f3);

// V-14: GrooveLine TV Unit max 7ft (furniture-scoped)
MATCH (f:Furniture {sku:'TV-GL'})
MERGE (r:Rule {id:'V-14'})
SET r.type = 'VALIDATION', r.severity = 'ERROR', r.name = 'GrooveLine TV Unit max 7ft',
    r.trigger_condition = 'tv_unit_sku = "TV-GL" AND selected_width_ft = 8',
    r.action = 'disable_width_option(8)',
    r.message = 'GrooveLine TV Units are available up to 7 ft only. Please select 4-7 ft.'
MERGE (r)-[:APPLIES_TO]->(f);

// V-15: Ceiling use — non-rated sheet warning (cart-scoped)
MATCH (cs:CartScene {name:'GLOBAL_CART'}),(p:Panel {sku:'SHT-WPC-5MM'})
MERGE (r:Rule {id:'V-15'})
SET r.type = 'VALIDATION', r.severity = 'WARNING', r.name = 'Ceiling use — non-rated sheet selected',
    r.trigger_condition = 'room_type = "ceiling" AND panel_sku <> "SHT-WPC-5MM"',
    r.action = 'show_info',
    r.message = 'For ceiling use, WPC Sheet 5mm (SHT-WPC-5MM) is the only sheet rated — lightweight and moisture-resistant.'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs)
MERGE (r)-[:SUGGESTS_ACCESSORY {reason:'ceiling_rated_alternative'}]->(p);

// V-16: Polyfix always required — missing from cart (cart-scoped)
MATCH (cs:CartScene {name:'GLOBAL_CART'}),(c:Consumable {sku:'CONS-POLYFIX'})
MERGE (r:Rule {id:'V-16'})
SET r.type = 'VALIDATION', r.severity = 'WARNING', r.name = 'Polyfix missing from cart',
    r.trigger_condition = 'cart_is_non_empty AND NOT cart_contains("CONS-POLYFIX")',
    r.action = 'prompt_add("CONS-POLYFIX", 1)',
    r.message = 'Polyfix joint filler is recommended for every installation. Add 1 tube?'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs)
MERGE (r)-[:SUGGESTS_ACCESSORY {relationship_type:'AUTO_SUGGESTED'}]->(c);

// V-17: Install-only cabinet advisory (furniture-scoped)
MATCH (f:Furniture {sku:'CAB-OH-1.5FT-INSTALL'})
MERGE (r:Rule {id:'V-17'})
SET r.type = 'VALIDATION', r.severity = 'INFO', r.name = 'Install-only cabinet advisory',
    r.trigger_condition = 'cart_contains("CAB-OH-1.5FT-INSTALL")',
    r.action = 'show_info',
    r.message = 'Cabinet installation only — the cabinet unit must be supplied by you. Our team will install it.'
MERGE (r)-[:APPLIES_TO]->(f);

// V-18: 3D curved panel measurement advisory (panel-scoped)
MATCH (p1:Panel {sku:'WPC-NEW-CONCAVE'}),(p2:Panel {sku:'WPC-NEW-CONVEX'})
MERGE (r:Rule {id:'V-18'})
SET r.type = 'VALIDATION', r.severity = 'INFO', r.name = '3D curved panel measurement advisory',
    r.trigger_condition = 'panel_sku IN ["WPC-NEW-CONCAVE","WPC-NEW-CONVEX"]',
    r.action = 'show_measurement_advisory',
    r.message = '3D curved panels require a professional site measurement. Quantities shown are estimates only.'
MERGE (r)-[:APPLIES_TO]->(p1)
MERGE (r)-[:APPLIES_TO]->(p2);

// V-19: PVC Flute batten frame advisory (subcategory-scoped)
MATCH (s:Subcategory {name:'PVC_FLUTE'})
MERGE (r:Rule {id:'V-19'})
SET r.type = 'VALIDATION', r.severity = 'INFO', r.name = 'PVC Flute batten frame advisory',
    r.trigger_condition = 'subcategory = "PVC_FLUTE"',
    r.action = 'show_advisory',
    r.message = 'PVC Flute panels require a batten frame and panel adhesive (not in current SKU list). Confirm with the installation team.'
MERGE (r)-[:APPLIES_TO]->(s);

// V-20: SPC sheet backing board recommendation (panel-scoped)
MATCH (p:Panel {sku:'SHT-SPC'}),(c:Consumable {sku:'CONS-PVC10'})
MERGE (r:Rule {id:'V-20'})
SET r.type = 'VALIDATION', r.severity = 'WARNING', r.name = 'SPC sheet backing board recommendation',
    r.trigger_condition = 'panel_sku = "SHT-SPC" AND NOT cart_contains("CONS-PVC10")',
    r.action = 'prompt_add("CONS-PVC10")',
    r.message = 'SPC Sheet is heavy. A 10mm PVC backing board (CONS-PVC10) is strongly recommended. Add it?'
MERGE (r)-[:APPLIES_TO]->(p)
MERGE (r)-[:SUGGESTS_ACCESSORY {relationship_type:'AUTO_SUGGESTED'}]->(c);


// ─────────────────────────────────────────────────────────────────────────────
// 29. RULE ENGINE — Two-Zone & Skirting Rules
// ─────────────────────────────────────────────────────────────────────────────

// Two-zone divider: Metal T trim required between zones
MATCH (t:Trim {sku:'TR-MET-T'}),(cs:CartScene {name:'GLOBAL_CART'})
MERGE (r:Rule {id:'TWO_ZONE_DIVIDER'})
SET r.type = 'TWO_ZONE', r.severity = 'INFO',
    r.trigger_condition = 'is_two_zone = true',
    r.action = 'auto_add("TR-MET-T")',
    r.description = 'Metal trim required between different panel zones. TR-MET-T is the default zone divider.'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs)
MERGE (r)-[:REQUIRES_ACCESSORY {relationship_type:'AUTO_SUGGESTED'}]->(t);

// Two-zone LED divider: prefer aluminium channel when LED is present
MATCH (t:Trim {sku:'TR-MET-CHANNEL'}),(cs:CartScene {name:'GLOBAL_CART'})
MERGE (r:Rule {id:'TWO_ZONE_LED_DIVIDER'})
SET r.type = 'TWO_ZONE', r.severity = 'INFO',
    r.trigger_condition = 'is_two_zone = true AND led_profile_selected = true',
    r.action = 'suggest("TR-MET-CHANNEL")',
    r.description = 'When LED is present in a two-zone wall, TR-MET-CHANNEL is preferred — it can house the LED strip at the zone boundary.'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs)
MERGE (r)-[:SUGGESTS_ACCESSORY {relationship_type:'AUTO_SUGGESTED'}]->(t);

// Skirting: suggest when panels reach the floor
MATCH (sk:Trim {sku:'TR-SKIRTING'}),(cs:CartScene {name:'GLOBAL_CART'})
MERGE (r:Rule {id:'SKIRTING_RULE'})
SET r.type = 'SKIRTING', r.severity = 'INFO',
    r.trigger_condition = 'panels_reach_floor = true',
    r.action = 'prompt_suggest("TR-SKIRTING")',
    r.description = 'Panels run to the floor — add skirting to finish the floor-to-wall junction.'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs)
MERGE (r)-[:SUGGESTS_ACCESSORY {relationship_type:'CONDITIONAL', condition:'panels_reach_floor'}]->(sk);


// ─────────────────────────────────────────────────────────────────────────────
// 30. RULE ENGINE — Default Selection & Room Affinity Rules
// ─────────────────────────────────────────────────────────────────────────────

// Global default when no room type is set
MATCH (cs:CartScene {name:'GLOBAL_CART'})
MERGE (r:Rule {id:'DEFAULT_SELECTION_GLOBAL'})
SET r.type = 'DEFAULT_SELECTION', r.severity = 'INFO',
    r.description = 'Global entry default when no room type is set.',
    r.default_subcategory = 'PVC_PANEL', r.default_sku = 'PVC-TEXTURE',
    r.reason = 'Most versatile PVC panel; widest room affinity'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs);

// Room-specific default panel pre-selection
MATCH (cs:CartScene {name:'GLOBAL_CART'})
MERGE (r:Rule {id:'DEFAULT_SELECTION_BY_ROOM'})
SET r.type = 'DEFAULT_SELECTION', r.severity = 'INFO',
    r.description = 'Room-specific default panel pre-selection.',
    r.defaults = '{"living_room":"WPC-NEW-CLASSIC","bedroom":"PVC-FLORAL","kids_room":"PVC-FLORAL","bathroom":"SHT-UV-MARBLE","kitchen":"SHT-UV-MARBLE","study":"PVC-GEOM","pooja_room":"PVC-TRAD","home_office":"PVC-GEOM","entryway":"PVC-STONE","lobby":"CH-FLUTED","commercial":"FLT-SOLID","tv_wall":"FLT-WIDEWOOD","ceiling":"SHT-WPC-5MM","any":"PVC-TEXTURE"}'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs);

// Room affinity ranking algorithm
MATCH (cs:CartScene {name:'GLOBAL_CART'})
MERGE (r:Rule {id:'ROOM_AFFINITY_RANKING'})
SET r.type = 'ROOM_AFFINITY', r.severity = 'INFO',
    r.description = 'Sort panels by room_affinity[room_type] DESC. Badge top 3 as Recommended. Exclude ON_REQUEST.',
    r.ranking_formula = 'room_affinity_score * availability_weight DESC',
    r.availability_weights = '{"AVAILABLE":1.0,"NEW":0.95,"PREMIUM":0.9,"ON_REQUEST":0.0}'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs);

// Waterproof enforcement for wet rooms
MATCH (cs:CartScene {name:'GLOBAL_CART'})
MERGE (r:Rule {id:'WATERPROOF_ENFORCEMENT'})
SET r.type = 'ROOM_FILTER', r.severity = 'WARNING',
    r.description = 'Warn when non-waterproof panel selected for bathroom or kitchen.',
    r.trigger_condition = 'room_type IN ["bathroom","kitchen"] AND panel_sku IN non_rated_skus',
    r.non_rated_skus = ['CH-CL2','CH-MINCONC-SM','CH-CLASSIC-NEW','CH-CONCAVE','CH-FLUTED','CH-MINRECT','CH-MINCONC-PREM','SHT-METALLIC','SHT-WPC-5MM','SHT-WPC-GROOVED-7MM'],
    r.action = 'show_warning("Panel not rated for wet environments")'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs);

// Availability action map — governs UI behavior per availability status
MATCH (cs:CartScene {name:'GLOBAL_CART'})
MERGE (r:Rule {id:'AVAILABILITY_ACTION_MAP'})
SET r.type = 'AVAILABILITY', r.severity = 'INFO',
    r.description = 'Governs UI action per availability status.',
    r.actions = '{"AVAILABLE":"add_to_cart","NEW":"add_to_cart","PREMIUM":"add_to_cart","ON_REQUEST":"trigger_lead_form","UNAVAILABLE":"hide_entirely"}',
    r.precedence_note = 'V-07 (ERROR) overrides UI action for ON_REQUEST items — block_quote_generation takes priority over trigger_lead_form when ON_REQUEST item enters the cart.'
MERGE (r)-[:APPLIES_TO {scope:'GLOBAL'}]->(cs);


// ─────────────────────────────────────────────────────────────────────────────
// 31. INDEXES (Performance Optimization)
// ─────────────────────────────────────────────────────────────────────────────
// Single-property and composite indexes for the most common query patterns.

CREATE INDEX panel_subcategory_idx     IF NOT EXISTS FOR (p:Panel)     ON (p.subcategory);
CREATE INDEX panel_availability_idx    IF NOT EXISTS FOR (p:Panel)     ON (p.availability);
CREATE INDEX panel_trim_family_idx     IF NOT EXISTS FOR (p:Panel)     ON (p.trim_family);
CREATE INDEX trim_type_idx             IF NOT EXISTS FOR (t:Trim)      ON (t.trim_type);
CREATE INDEX rule_type_idx             IF NOT EXISTS FOR (r:Rule)      ON (r.type);
CREATE INDEX rule_severity_idx         IF NOT EXISTS FOR (r:Rule)      ON (r.severity);
CREATE INDEX furniture_subcategory_idx IF NOT EXISTS FOR (f:Furniture) ON (f.subcategory);

// Composite index: most common catalog-filter query (subcategory + availability)
CREATE INDEX panel_subcat_avail_idx    IF NOT EXISTS FOR (p:Panel)     ON (p.subcategory, p.availability);


// ============================================================================
// END OF SEED SCRIPT — V5.0
// ============================================================================
