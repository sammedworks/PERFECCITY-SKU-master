# Perfeccity Configurator API

FastAPI service wrapping the Neo4j Wall Panel Configurator rule engine.

## Quick Start

### With Docker Compose (recommended)

```bash
# From the repo root
docker compose up -d

# Load the seed data
docker compose exec neo4j cypher-shell -u neo4j -p perfeccity123 < cypher/wall-configurator-graph-v5.cypher
docker compose exec neo4j cypher-shell -u neo4j -p perfeccity123 < cypher/engine/00-cart-schema.cypher

# API is at http://localhost:8000
# Swagger docs at http://localhost:8000/docs
# Neo4j Browser at http://localhost:7474
```

### Local development

```bash
cd api

# Install dependencies
pip install -e ".[dev]"

# Set env vars (or copy .env.example to .env)
export PERFECCITY_NEO4J_URI=bolt://localhost:7687
export PERFECCITY_NEO4J_USER=neo4j
export PERFECCITY_NEO4J_PASSWORD=password

# Run
uvicorn app.main:app --reload --port 8000
```

## API Endpoints

### Catalog

| Method | Path | Description |
|--------|------|-------------|
| GET | `/catalog/panels` | List all panels (filter: `?subcategory=`, `?availability=`) |
| GET | `/catalog/panels/{sku}/accessories` | Get trims + LED for a panel |
| GET | `/catalog/panels/ranked/{room_type}` | Panels ranked by room affinity |
| GET | `/catalog/trims` | List all trims (filter: `?subcategory=`) |
| GET | `/catalog/consumables` | List all consumables |
| GET | `/catalog/led-profiles` | List LED profiles |
| GET | `/catalog/led-accessories` | List LED strips & kits |
| GET | `/catalog/furniture` | List furniture (filter: `?subcategory=`) |

### Cart

| Method | Path | Description |
|--------|------|-------------|
| POST | `/cart` | Create a cart with items |
| GET | `/cart/{cart_id}` | Get cart details |
| POST | `/cart/{cart_id}/items` | Add item to cart |
| DELETE | `/cart/{cart_id}/items/{item_id}` | Remove item from cart |
| DELETE | `/cart/{cart_id}` | Delete entire cart |

### Validation & BOM

| Method | Path | Description |
|--------|------|-------------|
| GET | `/cart/{cart_id}/validate` | Run all rules → pass/fail + violations |
| GET | `/cart/{cart_id}/bom` | Generate BOM (consumables + trims) |
| GET | `/cart/{cart_id}/evaluate` | **Combined** — validation + BOM in one call |

### Defaults

| Method | Path | Description |
|--------|------|-------------|
| GET | `/defaults/{room_type}` | Get default panel for a room type |

## Example: Full workflow

```bash
# 1. Create a cart with a Charcoal panel and clips (should trigger V-02)
curl -X POST http://localhost:8000/cart \
  -H "Content-Type: application/json" \
  -d '{
    "room_type": "living_room",
    "items": [
      {"sku": "CH-CL2", "item_type": "PANEL", "quantity": 6},
      {"sku": "CONS-CLIP50", "item_type": "CONSUMABLE", "quantity": 3}
    ]
  }'

# 2. Evaluate the cart (validation + BOM)
curl http://localhost:8000/cart/{cart_id}/evaluate

# Response:
# {
#   "pass_fail": "FAIL",
#   "error_count": 1,
#   "violations": [
#     {"rule_id": "V-02", "severity": "ERROR",
#      "message": "Charcoal panels use silicon glue only..."}
#   ],
#   "bom": { ... }
# }
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PERFECCITY_NEO4J_URI` | `bolt://localhost:7687` | Neo4j Bolt URI |
| `PERFECCITY_NEO4J_USER` | `neo4j` | Neo4j username |
| `PERFECCITY_NEO4J_PASSWORD` | `password` | Neo4j password |
| `PERFECCITY_NEO4J_DATABASE` | `neo4j` | Neo4j database name |
| `PERFECCITY_CORS_ORIGINS` | `["*"]` | Allowed CORS origins (JSON array) |
