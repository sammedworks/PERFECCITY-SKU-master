# Perfeccity Wall Configurator — Neo4j Graph Database

Production-ready Neo4j graph database for the **Perfeccity Wall Panel Configurator** system.  
Models the complete product catalog, installation rules, trim/LED/furniture compatibility, and a 30+ rule validation engine for an Indian interior decor company.

## Quick Start

### Prerequisites

- **Neo4j 5.x** (Community or Enterprise)
- `cypher-shell` CLI (bundled with Neo4j)

### Load the Graph

```bash
# Option 1: cypher-shell (recommended)
cat cypher/wall-configurator-graph-v5.cypher | cypher-shell -u neo4j -p <password>

# Option 2: Neo4j Browser — paste sections into the query editor

# Option 3: neo4j-admin import (for fresh databases)
neo4j-admin database import full --nodes=... --relationships=...
```

The script is **fully idempotent** — re-running it safely updates existing nodes without creating duplicates.

## Repository Structure

```
├── README.md                              # This file
├── SCHEMA.md                              # Graph schema reference & ER diagram
├── cypher/
│   ├── wall-configurator-graph-v5.cypher  # Complete seed script (V5.0)
│   └── validate-graph.cypher              # Post-load validation queries
└── queries/
    └── utility-queries.cypher             # Common operational queries
```

## Graph Overview

### Node Labels (11 types)

| Label               | Count  | Purpose                                        |
|---------------------|--------|------------------------------------------------|
| `Panel`             | ~30    | Wall panels (PVC, WPC, Charcoal, Sheet)        |
| `Trim`              | ~25    | U, L, H, Metal, and specialty trims            |
| `Consumable`        | 5      | Clips, silicon glue, PVC boards, filler        |
| `LEDProfile`        | 7      | LED light profiles (dedicated & universal)     |
| `LEDStrip`          | 2      | LED strips (120/240 density)                   |
| `LEDKit`            | 2      | Complete LED installation kits                 |
| `Furniture`         | ~20    | TV units, shelves, cabinets, desks             |
| `Subcategory`       | 24     | Product classification with calc rules         |
| `InstallationMethod`| 6      | Physical installation techniques               |
| `Rule`              | 30+    | Validation, installation, LED, & UI rules      |
| `CartScene`         | 1      | Global anchor for cart-scoped rules            |

### Relationship Types (15 types)

| Relationship             | Pattern                          | Purpose                                  |
|--------------------------|----------------------------------|------------------------------------------|
| `BELONGS_TO`             | Product → Subcategory            | Category membership                      |
| `USES_METHOD`            | Subcategory/Panel → InstallMethod| Installation technique                   |
| `HAS_U_TRIM`            | Panel → Trim                     | U-bidding trim assignment                |
| `HAS_L_TRIM`            | Panel → Trim                     | L-bidding trim assignment                |
| `HAS_H_TRIM`            | Panel → Trim                     | H-bidding joiner assignment              |
| `HAS_METAL_TRIM`        | Panel → Trim                     | Optional metal trim                      |
| `HAS_DEDICATED_LED`     | Panel → LEDProfile               | Dedicated LED profile                    |
| `COMPATIBLE_LED`         | Panel → LEDProfile               | Universal LED compatibility              |
| `BUNDLE_WITH_LED`        | Panel → Trim                     | Conditional accessory with LED           |
| `APPLIES_TO`             | Rule → Target                    | Rule scope anchor                        |
| `REQUIRES_CONSUMABLE`    | Rule → Consumable                | Required consumable                      |
| `FORBIDS_CONSUMABLE`     | Rule → Consumable                | Forbidden consumable                     |
| `OPTIONAL_CONSUMABLE`    | Rule → Consumable                | Conditional consumable                   |
| `INCOMPATIBLE_ACCESSORY` | Rule → Product                   | Incompatible product                     |
| `COMPATIBLE_LED_PROFILE` | Rule → LEDProfile                | LED compatibility mapping                |

### Rule Engine (30+ rules)

Rules are organized into 6 types:

| Type                     | Count | Scope             | Severity       |
|--------------------------|-------|--------------------|----------------|
| `INSTALLATION_CONTRACT`  | 10    | Subcategory/Panel  | REQUIRED       |
| `LED_COMPATIBILITY`      | 7     | Subcategory        | INFO           |
| `VALIDATION` (V-01..V-20)| 20   | Mixed              | ERROR/WARNING/INFO |
| `TWO_ZONE`               | 2     | Cart (global)      | INFO           |
| `SKIRTING`               | 1     | Cart (global)      | INFO           |
| `DEFAULT_SELECTION`      | 2     | Cart (global)      | INFO           |
| `ROOM_AFFINITY`          | 1     | Cart (global)      | INFO           |
| `ROOM_FILTER`            | 1     | Cart (global)      | WARNING        |
| `AVAILABILITY`           | 1     | Cart (global)      | INFO           |

## Product Categories

### Wall Panels

| Subcategory   | Panels | Price Range (INR) | Installation       | Key Feature                    |
|---------------|--------|-------------------|--------------------|--------------------------------|
| PVC_PANEL     | 7      | ₹650              | Clip + Adhesive    | Waterproof, 8-10mm thick       |
| PVC_FLUTE     | 4      | ₹1,450            | Batten + Adhesive  | 2900mm height, no U-bidding    |
| WPC_CLASSIC   | 4      | ₹550 (avail only) | Clip + Adhesive    | Termite-proof, moisture-resist |
| WPC_NEW       | 5      | ₹950–₹1,300       | Clip + Adhesive    | 2900mm, modern profiles        |
| WPC_CERAMIC   | 2      | ₹1,100–₹1,250     | Clip + Adhesive    | Dedicated LED profile          |
| CHARCOAL      | 8      | ₹650–₹3,700       | Silicon Glue       | Fire retardant, acoustic       |
| SHEET         | 5      | ₹2,100–₹9,000     | Silicon/Adhesive   | Ultra-high gloss, waterproof   |

### Furniture

| Subcategory | Items | Price Range (INR)     | Installation         |
|-------------|-------|-----------------------|----------------------|
| TV_UNIT     | 7     | ₹8,000–₹27,000       | Delivered + Installed|
| SHELF       | 7     | ₹1,000–₹2,750        | Wall Mounted         |
| CABINET     | 6     | ₹4,500–₹8,800        | Wall Mounted         |
| DESK        | 4     | ₹5,500–₹12,000       | Wall Mounted         |

## Key Business Rules

1. **PVC Flute & Charcoal cannot use clips** (V-01, V-02) — enforced as ERROR
2. **Charcoal has no standard bidding trims** (V-05, V-06) — only metal trims
3. **ON_REQUEST items block automated quotes** (V-07) — requires manual inquiry
4. **LED profiles need strips/kits** (V-08) — incomplete lighting setup warning
5. **Grooved WPC sheet uses special H-trim** (V-04) — auto-swap from standard
6. **Polyfix filler is universal** (V-16) — auto-suggested for every installation
7. **Two-zone walls auto-add Metal T divider** — with LED channel upgrade option
8. **Room affinity ranking** — sorts panels by suitability score per room type

## Availability Statuses

| Status       | UI Action            | Quote Eligible |
|--------------|----------------------|----------------|
| `AVAILABLE`  | Add to Cart          | Yes            |
| `NEW`        | Add to Cart          | Yes            |
| `PREMIUM`    | Add to Cart          | Yes            |
| `ON_REQUEST` | Trigger Lead Form    | No (V-07)      |
| `UNAVAILABLE`| Hidden               | No             |

## Version History

| Version | Date       | Changes                                              |
|---------|------------|------------------------------------------------------|
| V5.0    | 2025-04    | Idempotent MERGE, CartScene anchor, composite index   |
| V4.0    | 2025-03    | Full product catalog, 20 validation rules             |

## License

Proprietary — Perfeccity Interior Solutions.
