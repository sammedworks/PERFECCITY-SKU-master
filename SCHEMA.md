# Graph Schema Reference — V5.0

## Entity-Relationship Diagram (Text)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        WALL CONFIGURATOR GRAPH V5.0                        │
└─────────────────────────────────────────────────────────────────────────────┘

                         ┌──────────────┐
                         │  CartScene   │
                         │ GLOBAL_CART  │
                         └──────┬───────┘
                                │ APPLIES_TO {scope:'GLOBAL'}
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
              ┌──────────┐ ┌──────────┐ ┌──────────┐
              │  Rule    │ │  Rule    │ │  Rule    │  ... (30+ rules)
              │ V-07     │ │ V-08     │ │ DEFAULT  │
              │ cart-    │ │ cart-    │ │ SELECTION│
              │ scoped   │ │ scoped   │ │          │
              └──────────┘ └──────────┘ └──────────┘


    ┌─────────────────────────────────────────────────────────┐
    │                    PRODUCT LAYER                         │
    └─────────────────────────────────────────────────────────┘

    ┌───────────┐   BELONGS_TO    ┌──────────────┐   USES_METHOD   ┌────────────────────┐
    │   Panel   │ ───────────────▶│ Subcategory  │ ──────────────▶│ InstallationMethod │
    │ (35 SKUs) │                 │ (24 types)   │                │ (6 methods)        │
    └─────┬─────┘                 └──────┬───────┘                └────────────────────┘
          │                              │
          │ HAS_U_TRIM                   │ APPLIES_TO
          │ HAS_L_TRIM    ┌─────────┐   │         ┌──────────────────────┐
          │ HAS_H_TRIM    │  Trim   │   │         │   Rule               │
          │──────────────▶│ (25)    │   └────────▶│ INSTALLATION_CONTRACT│
          │               └─────────┘             │ LED_COMPATIBILITY    │
          │ HAS_METAL_TRIM                        │ VALIDATION (V-01-20) │
          │──────────────▶ Metal Trims            │ TWO_ZONE / SKIRTING  │
          │                                       └──────────┬───────────┘
          │ HAS_DEDICATED_LED                                │
          │ COMPATIBLE_LED    ┌────────────┐                 │ REQUIRES_CONSUMABLE
          │──────────────────▶│ LEDProfile │                 │ FORBIDS_CONSUMABLE
          │                   │ (7 profiles)│                │ OPTIONAL_CONSUMABLE
          │                   └────────────┘                 ▼
          │ BUNDLE_WITH_LED                          ┌──────────────┐
          │──────────────────▶ TR-MET-CHANNEL        │  Consumable  │
          │                                          │ (5 items)    │
          │                                          └──────────────┘
          │
    ┌─────┴──────┐     ┌────────────┐    ┌────────────┐
    │            │     │  LEDStrip  │    │  LEDKit    │
    │ Furniture  │     │ (2 strips) │    │ (2 kits)   │
    │ (20 items) │     └────────────┘    └────────────┘
    └────────────┘
```

## Node Properties

### Panel

| Property              | Type     | Required | Description                                    |
|-----------------------|----------|----------|------------------------------------------------|
| `sku`                 | String   | Yes (PK) | Unique product identifier                      |
| `name`                | String   | Yes      | Display name                                   |
| `subcategory`         | String   | Yes      | Links to Subcategory.name                      |
| `calculation_type`    | String   | Yes      | SHEET_AREA / LINEAR_WIDTH / TILE_GRID          |
| `price`               | Integer  | No       | Price in INR (null = ON_REQUEST)               |
| `colors`              | Integer  | Yes      | Number of color variants                       |
| `finish`              | String   | Yes      | Surface finish description                     |
| `trim_family`         | String   | No       | Groups panels sharing trim sets                |
| `availability`        | String   | Yes      | AVAILABLE / NEW / PREMIUM / ON_REQUEST / UNAVAILABLE |
| `waterproof`          | Boolean  | No       | Rated for wet environments                     |
| `moisture_resistant`  | Boolean  | No       | Moisture resistance rating                     |
| `termite_proof`       | Boolean  | No       | Termite proofing                               |
| `fire_retardant`      | Boolean  | No       | Fire retardant (Charcoal)                      |
| `sheet_w_mm`          | Integer  | No       | Sheet width in mm (sheet-area types)           |
| `sheet_h_mm`          | Integer  | No       | Sheet height in mm                             |
| `panel_w_mm`          | Integer  | No       | Panel width in mm (linear-width types)         |
| `panel_h_mm`          | Integer  | No       | Panel height in mm                             |
| `tile_w_mm`           | Integer  | No       | Tile width (tile-grid types)                   |
| `tile_h_mm`           | Integer  | No       | Tile height (tile-grid types)                  |
| `thickness_min_mm`    | Integer  | No       | Minimum thickness                              |
| `thickness_max_mm`    | Integer  | No       | Maximum thickness                              |
| `default_selection`   | Boolean  | Yes      | Pre-selected in category                       |
| `room_affinity`       | String   | Yes      | JSON: room_type → score (0.0–1.0)             |
| `led_compat`          | String   | No       | DEDICATED / UNIVERSAL / null                   |
| `dedicated_led_sku`   | String   | No       | SKU of dedicated LED profile                   |
| `ceiling_rated`       | Boolean  | No       | Safe for ceiling installation                  |
| `h_trim_override`     | String   | No       | Overrides default H-trim SKU                   |

### Subcategory

| Property              | Type     | Required | Description                                    |
|-----------------------|----------|----------|------------------------------------------------|
| `name`                | String   | Yes (PK) | Unique category identifier                     |
| `calculation_type`    | String   | Yes      | Quantity calculation method                     |
| `sheet_area_sqft`     | Integer  | No       | Standard sheet area                            |
| `panel_height_mm`     | Integer  | No       | Standard panel height                          |
| `piece_length_mm`     | Integer  | No       | Standard piece length (trims/LED)              |
| `warranty_years`      | Integer  | No       | Warranty period in years                       |
| `default_sku`         | String   | No       | Default panel for the subcategory              |

### Rule

| Property              | Type     | Required | Description                                    |
|-----------------------|----------|----------|------------------------------------------------|
| `id`                  | String   | Yes (PK) | Unique rule identifier (e.g., V-01)            |
| `type`                | String   | Yes      | Rule classification                            |
| `severity`            | String   | Yes      | ERROR / WARNING / INFO / REQUIRED              |
| `name`                | String   | No       | Human-readable rule name                       |
| `description`         | String   | No       | Detailed description                           |
| `trigger_condition`   | String   | No       | Pseudo-code condition expression               |
| `action`              | String   | No       | Action to take when triggered                  |
| `message`             | String   | No       | User-facing message                            |
| `method`              | String   | No       | Installation method (for contracts)            |

### Trim

| Property              | Type     | Required | Description                                    |
|-----------------------|----------|----------|------------------------------------------------|
| `sku`                 | String   | Yes (PK) | Unique trim identifier                         |
| `name`                | String   | Yes      | Display name                                   |
| `subcategory`         | String   | Yes      | TRIM_U / TRIM_L / TRIM_H / TRIM_METAL / TRIM_OTHER |
| `trim_type`           | String   | Yes      | U / L / H / Metal-T / Metal-U / Channel / etc. |
| `price`               | Integer  | No       | Price in INR                                   |
| `colors`              | Integer  | Yes      | Number of color variants                       |
| `piece_length_mm`     | Integer  | No       | Standard piece length                          |
| `material`            | String   | Yes      | PVC / WPC / Aluminium                          |
| `availability`        | String   | Yes      | Availability status                            |
| `compatible_panels`   | List     | No       | Array of compatible panel SKUs                 |

### Consumable

| Property              | Type     | Required | Description                                    |
|-----------------------|----------|----------|------------------------------------------------|
| `sku`                 | String   | Yes (PK) | Unique consumable identifier                   |
| `name`                | String   | Yes      | Display name                                   |
| `subcategory`         | String   | Yes      | CONSUMABLE_CLIPS / _ADHESIVE / _BOARD / _FILLER|
| `price`               | Integer  | Yes      | Price in INR                                   |
| `calc_formula`        | String   | No       | Quantity calculation formula                   |
| `allowed_for`         | List     | No       | Subcategories that use this consumable         |
| `forbidden_for`       | List     | No       | Subcategories that must not use this           |
| `always_include`      | Boolean  | No       | Auto-include in every order                    |

### Furniture

| Property              | Type     | Required | Description                                    |
|-----------------------|----------|----------|------------------------------------------------|
| `sku`                 | String   | Yes (PK) | Unique furniture identifier                    |
| `name`                | String   | Yes      | Display name                                   |
| `subcategory`         | String   | Yes      | TV_UNIT / SHELF / CABINET / DESK               |
| `series`              | String   | No       | Product series (PF, GL)                        |
| `style`               | String   | No       | Design style                                   |
| `widths_ft`           | List     | No       | Available width options                        |
| `prices`              | String   | No       | JSON: width → price mapping                    |
| `price`               | Integer  | No       | Fixed price (non-configurable items)           |
| `finishes`            | Integer  | Yes      | Number of finish options                       |
| `installation`        | String   | Yes      | DELIVERED_INSTALLED / WALL_MOUNTED_INSTALL     |
| `warranty_years`      | Integer  | Yes      | Warranty period                                |
| `min_width_ft`        | Integer  | No       | Minimum configurable width                     |
| `max_width_ft`        | Integer  | No       | Maximum configurable width                     |

## Relationship Properties

### HAS_*_TRIM

| Property              | Type     | Description                                    |
|-----------------------|----------|------------------------------------------------|
| `relationship_type`   | String   | AUTO_SUGGESTED / OPTIONAL                      |
| `note`                | String   | Special handling notes                         |

### APPLIES_TO

| Property              | Type     | Description                                    |
|-----------------------|----------|------------------------------------------------|
| `scope`               | String   | GLOBAL (for CartScene-anchored rules)          |

### REQUIRES_CONSUMABLE / OPTIONAL_CONSUMABLE

| Property              | Type     | Description                                    |
|-----------------------|----------|------------------------------------------------|
| `relationship_type`   | String   | REQUIRED                                       |
| `condition`           | String   | Condition expression for optional consumables  |
| `default`             | Boolean  | Default inclusion state                        |
| `preferred`           | Boolean  | Preferred recommendation                       |

### COMPATIBLE_LED_PROFILE

| Property              | Type     | Description                                    |
|-----------------------|----------|------------------------------------------------|
| `rank`                | Integer  | Priority ranking (1 = primary)                 |

### HAS_DEDICATED_LED / COMPATIBLE_LED

| Property              | Type     | Description                                    |
|-----------------------|----------|------------------------------------------------|
| `relationship_type`   | String   | AUTO_SUGGESTED / OPTIONAL                      |
| `priority`            | Integer  | 1 = dedicated, 2 = universal                   |

## Constraints

| Constraint Name           | Label             | Property | Type   |
|---------------------------|-------------------|----------|--------|
| `panel_sku_unique`        | Panel             | sku      | UNIQUE |
| `trim_sku_unique`         | Trim              | sku      | UNIQUE |
| `consumable_sku_unique`   | Consumable        | sku      | UNIQUE |
| `ledprofile_sku_unique`   | LEDProfile        | sku      | UNIQUE |
| `ledstrip_sku_unique`     | LEDStrip          | sku      | UNIQUE |
| `ledkit_sku_unique`       | LEDKit            | sku      | UNIQUE |
| `furniture_sku_unique`    | Furniture         | sku      | UNIQUE |
| `subcategory_name_unique` | Subcategory       | name     | UNIQUE |
| `installmethod_unique`    | InstallationMethod| name     | UNIQUE |
| `rule_id_unique`          | Rule              | id       | UNIQUE |
| `cartscene_name_unique`   | CartScene         | name     | UNIQUE |

## Indexes

| Index Name                 | Label     | Properties                  | Type      |
|----------------------------|-----------|-----------------------------|-----------|
| `panel_subcategory_idx`    | Panel     | subcategory                 | Single    |
| `panel_availability_idx`   | Panel     | availability                | Single    |
| `panel_trim_family_idx`    | Panel     | trim_family                 | Single    |
| `panel_subcat_avail_idx`   | Panel     | subcategory, availability   | Composite |
| `trim_type_idx`            | Trim      | trim_type                   | Single    |
| `rule_type_idx`            | Rule      | type                        | Single    |
| `rule_severity_idx`        | Rule      | severity                    | Single    |
| `furniture_subcategory_idx`| Furniture | subcategory                 | Single    |
