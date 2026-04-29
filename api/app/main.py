"""Perfeccity Wall Configurator API — FastAPI application."""

from __future__ import annotations

import json
import logging
import secrets
import uuid
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Query, Request, Security
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import APIKeyHeader
from starlette.middleware.base import BaseHTTPMiddleware

from app.config import settings
from app.db import close_driver, get_session, init_driver
from app.models import (
    BOMConsumable,
    BOMPanelEntry,
    BOMResult,
    BOMTrim,
    CartCreateIn,
    CartItemIn,
    CartItemOut,
    CartOut,
    ConsumableOut,
    DefaultPanelOut,
    EvaluateResult,
    FurnitureOut,
    LEDProfileOut,
    PanelOut,
    TrimOut,
    ValidationResult,
    Violation,
)
from app.queries import (
    ADD_CART_ITEM,
    ADD_CART_ITEMS_BATCH,
    ALL_CONSUMABLES,
    ALL_FURNITURE,
    ALL_LED_PROFILES,
    ALL_TRIMS,
    BOM_CONSUMABLES,
    BOM_TRIMS,
    CART_META,
    CREATE_CART,
    DEFAULT_PANEL_FOR_ROOM,
    DELETE_CART,
    GET_CART,
    LED_STRIPS_AND_KITS,
    PANEL_ACCESSORIES,
    PANELS_BY_SUBCATEGORY,
    REMOVE_CART_ITEM,
    RESOLVE_PRODUCT,
    ROOM_RANKED_PANELS,
    VALIDATION_GROUPS,
)

logger = logging.getLogger("perfeccity")

DEFAULT_PAGE_SIZE = 100
MAX_PAGE_SIZE = 500

# ── App lifecycle ────────────────────────────────────────────────────────────


@asynccontextmanager
async def lifespan(_app: FastAPI):
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    )
    await init_driver()
    logger.info("Neo4j driver initialised")
    yield
    await close_driver()


app = FastAPI(
    title=settings.app_title,
    version=settings.app_version,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex
        request.state.request_id = request_id
        logger.info(
            "request_start",
            extra={"request_id": request_id, "method": request.method, "path": request.url.path},
        )
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        logger.info(
            "request_end",
            extra={"request_id": request_id, "status": response.status_code},
        )
        return response


app.add_middleware(RequestIDMiddleware)


# ── API Key Auth ─────────────────────────────────────────────────────────────

_api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def require_api_key(
    api_key: str | None = Security(_api_key_header),
) -> str | None:
    """Validate API key if configured. Skips auth when PERFECCITY_API_KEY is empty."""
    if not settings.api_key:
        return None
    if not secrets.compare_digest(api_key or "", settings.api_key):
        raise HTTPException(403, "Invalid or missing API key")
    return api_key


# ── Helpers ──────────────────────────────────────────────────────────────────


def _safe_int(val) -> int | None:
    if val is None:
        return None
    try:
        return int(val)
    except (ValueError, TypeError):
        return None


# ── Health ───────────────────────────────────────────────────────────────────


@app.get("/health")
async def health():
    return {"status": "ok", "version": settings.app_version}


# ═════════════════════════════════════════════════════════════════════════════
# CATALOG ENDPOINTS
# ═════════════════════════════════════════════════════════════════════════════


@app.get("/catalog/panels", response_model=list[PanelOut])
async def list_panels(
    subcategory: str | None = Query(None, description="Filter by subcategory"),
    availability: str | None = Query(None, description="Filter by availability"),
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE, description="Max records to return"),
):
    async with get_session() as session:
        result = await session.run(
            PANELS_BY_SUBCATEGORY,
            subcategory=subcategory,
            availability=availability,
            skip=skip,
            limit=limit,
        )
        records = await result.data()
    return [PanelOut(**dict(r["p"])) for r in records]


@app.get("/catalog/panels/{panel_sku}/accessories")
async def panel_accessories(panel_sku: str):
    async with get_session() as session:
        result = await session.run(PANEL_ACCESSORIES, panelSku=panel_sku)
        record = await result.single()
    if record is None:
        raise HTTPException(404, f"Panel {panel_sku} not found")
    return {
        "panel": dict(record["p"]),
        "u_trims": [t for t in record["u_trims"] if t.get("sku")],
        "l_trims": [t for t in record["l_trims"] if t.get("sku")],
        "h_trims": [t for t in record["h_trims"] if t.get("sku")],
        "metal_trims": [t for t in record["metal_trims"] if t.get("sku")],
        "dedicated_led": [led for led in record["dedicated_led"] if led.get("sku")],
        "universal_led": [led for led in record["universal_led"] if led.get("sku")],
    }


@app.get("/catalog/trims", response_model=list[TrimOut])
async def list_trims(
    subcategory: str | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
):
    async with get_session() as session:
        result = await session.run(ALL_TRIMS, subcategory=subcategory, skip=skip, limit=limit)
        records = await result.data()
    return [TrimOut(**dict(r["t"])) for r in records]


@app.get("/catalog/consumables", response_model=list[ConsumableOut])
async def list_consumables(
    skip: int = Query(0, ge=0),
    limit: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
):
    async with get_session() as session:
        result = await session.run(ALL_CONSUMABLES, skip=skip, limit=limit)
        records = await result.data()
    return [ConsumableOut(**dict(r["c"])) for r in records]


@app.get("/catalog/led-profiles", response_model=list[LEDProfileOut])
async def list_led_profiles(
    skip: int = Query(0, ge=0),
    limit: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
):
    async with get_session() as session:
        result = await session.run(ALL_LED_PROFILES, skip=skip, limit=limit)
        records = await result.data()
    return [LEDProfileOut(**dict(r["lp"])) for r in records]


@app.get("/catalog/led-accessories")
async def list_led_accessories(
    skip: int = Query(0, ge=0),
    limit: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
):
    async with get_session() as session:
        result = await session.run(LED_STRIPS_AND_KITS, skip=skip, limit=limit)
        records = await result.data()
    return [dict(r["n"]) for r in records]


@app.get("/catalog/furniture", response_model=list[FurnitureOut])
async def list_furniture(
    subcategory: str | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
):
    async with get_session() as session:
        result = await session.run(ALL_FURNITURE, subcategory=subcategory, skip=skip, limit=limit)
        records = await result.data()
    return [FurnitureOut(**dict(r["f"])) for r in records]


# ═════════════════════════════════════════════════════════════════════════════
# CART ENDPOINTS
# ═════════════════════════════════════════════════════════════════════════════


@app.post("/cart", response_model=CartOut, dependencies=[Depends(require_api_key)])
async def create_cart(body: CartCreateIn):
    cart_id = body.cart_id or str(uuid.uuid4())

    async with get_session() as session:
        # Validate all SKUs exist in catalog before touching cart
        for item in body.items:
            result = await session.run(RESOLVE_PRODUCT, sku=item.sku)
            if await result.single() is None:
                raise HTTPException(
                    404,
                    f"Product '{item.sku}' not found in catalog",
                )

        # Create cart node
        await session.run(
            CREATE_CART,
            cartId=cart_id,
            roomType=body.room_type,
            isTwoZone=body.is_two_zone,
            panelsReachFloor=body.panels_reach_floor,
            wallWidthMm=body.wall_width_mm,
            wallHeightMm=body.wall_height_mm,
        )

        # Add all items atomically via UNWIND
        if body.items:
            batch = [
                {
                    "id": f"{cart_id}_{item.sku}_{uuid.uuid4().hex[:8]}",
                    "sku": item.sku,
                    "item_type": item.item_type,
                    "quantity": item.quantity,
                    "unit_price": None,
                    "source": item.source,
                    "width_ft": item.width_ft,
                    "zone": item.zone,
                }
                for item in body.items
            ]
            await session.run(ADD_CART_ITEMS_BATCH, cartId=cart_id, items=batch)

        # Return full cart
        result = await session.run(GET_CART, cartId=cart_id)
        record = await result.single()

    if record is None:
        raise HTTPException(500, "Failed to create cart")

    cart_node = dict(record["c"])
    items = [CartItemOut(**dict(ci)) for ci in record["items"]]
    return CartOut(
        id=cart_node["id"],
        status=cart_node.get("status", "DRAFT"),
        room_type=cart_node.get("room_type", "any"),
        is_two_zone=cart_node.get("is_two_zone", False),
        panels_reach_floor=cart_node.get("panels_reach_floor", False),
        wall_width_mm=_safe_int(cart_node.get("wall_width_mm")),
        wall_height_mm=_safe_int(cart_node.get("wall_height_mm")),
        items=items,
    )


@app.get("/cart/{cart_id}", response_model=CartOut)
async def get_cart(cart_id: str):
    async with get_session() as session:
        result = await session.run(GET_CART, cartId=cart_id)
        record = await result.single()
    if record is None or record["c"] is None:
        raise HTTPException(404, f"Cart {cart_id} not found")
    cart_node = dict(record["c"])
    items = [CartItemOut(**dict(ci)) for ci in record["items"]]
    return CartOut(
        id=cart_node["id"],
        status=cart_node.get("status", "DRAFT"),
        room_type=cart_node.get("room_type", "any"),
        is_two_zone=cart_node.get("is_two_zone", False),
        panels_reach_floor=cart_node.get("panels_reach_floor", False),
        wall_width_mm=_safe_int(cart_node.get("wall_width_mm")),
        wall_height_mm=_safe_int(cart_node.get("wall_height_mm")),
        items=items,
    )


@app.post("/cart/{cart_id}/items", response_model=CartItemOut, dependencies=[Depends(require_api_key)])
async def add_item(cart_id: str, body: CartItemIn):
    async with get_session() as session:
        # Validate SKU exists
        prod_result = await session.run(RESOLVE_PRODUCT, sku=body.sku)
        if await prod_result.single() is None:
            raise HTTPException(404, f"Product '{body.sku}' not found in catalog")

        item_id = f"{cart_id}_{body.sku}_{uuid.uuid4().hex[:8]}"
        result = await session.run(
            ADD_CART_ITEM,
            cartId=cart_id,
            itemId=item_id,
            sku=body.sku,
            itemType=body.item_type,
            quantity=body.quantity,
            unitPrice=None,
            source=body.source,
            widthFt=body.width_ft,
            zone=body.zone,
        )
        record = await result.single()
    if record is None:
        raise HTTPException(404, f"Cart {cart_id} not found")
    return CartItemOut(**dict(record["ci"]))


@app.delete("/cart/{cart_id}/items/{item_id}", dependencies=[Depends(require_api_key)])
async def remove_item(cart_id: str, item_id: str):
    async with get_session() as session:
        result = await session.run(REMOVE_CART_ITEM, cartId=cart_id, itemId=item_id)
        record = await result.single()
    if record is None or record["removed"] == 0:
        raise HTTPException(404, "Item not found")
    return {"removed": True}


@app.delete("/cart/{cart_id}", dependencies=[Depends(require_api_key)])
async def delete_cart(cart_id: str):
    async with get_session() as session:
        result = await session.run(DELETE_CART, cartId=cart_id)
        record = await result.single()
    if record is None or record["deleted"] == 0:
        raise HTTPException(404, f"Cart {cart_id} not found")
    return {"deleted": True}


# ═════════════════════════════════════════════════════════════════════════════
# VALIDATION ENDPOINT
# ═════════════════════════════════════════════════════════════════════════════


@app.get("/cart/{cart_id}/validate", response_model=ValidationResult)
async def validate_cart(cart_id: str):
    """Run all validation rule groups in one read transaction, merge results."""

    async def _run_validation(tx):
        # 1. Fetch cart metadata (cart_id, room_type)
        meta_result = await tx.run(CART_META, cartId=cart_id)
        meta_record = await meta_result.single()
        if meta_record is None:
            return None

        meta = {
            "cart_id": meta_record["cart_id"],
            "room_type": meta_record["room_type"],
        }

        # 2. Run each validation group and collect violations
        all_violations: list[dict] = []
        for _group_name, query in VALIDATION_GROUPS:
            result = await tx.run(query, cartId=cart_id)
            record = await result.single()
            if record is not None:
                all_violations.extend(record["violations"])

        return {"meta": meta, "violations": all_violations}

    async with get_session() as session:
        data = await session.execute_read(_run_validation)

    if data is None:
        raise HTTPException(404, f"Cart {cart_id} not found")

    violations = [
        Violation(
            rule_id=v["rule_id"],
            severity=v["severity"],
            message=v["message"],
            action=v.get("action"),
            item=v.get("item"),
        )
        for v in data["violations"]
        if v.get("rule_id") is not None
    ]

    error_count = sum(1 for v in violations if v.severity == "ERROR")
    warning_count = sum(1 for v in violations if v.severity == "WARNING")
    info_count = sum(1 for v in violations if v.severity == "INFO")

    return ValidationResult(
        cart_id=data["meta"]["cart_id"],
        room_type=data["meta"]["room_type"],
        pass_fail="FAIL" if error_count > 0 else "PASS",
        error_count=error_count,
        warning_count=warning_count,
        info_count=info_count,
        violations=violations,
    )


# ═════════════════════════════════════════════════════════════════════════════
# BOM ENDPOINT
# ═════════════════════════════════════════════════════════════════════════════


@app.get("/cart/{cart_id}/bom", response_model=BOMResult)
async def get_bom(cart_id: str):
    panels: list[BOMPanelEntry] = []

    async with get_session() as session:
        # Consumables per panel
        result = await session.run(BOM_CONSUMABLES, cartId=cart_id)
        records = await result.data()
        for r in records:
            panels.append(
                BOMPanelEntry(
                    panel_sku=r["panel_sku"],
                    install_method=r.get("install_method"),
                    required_consumables=[BOMConsumable(**c) for c in r.get("required", []) if c.get("sku")],
                    optional_consumables=[BOMConsumable(**c) for c in r.get("optional", []) if c.get("sku")],
                )
            )

        # Trims per panel
        result = await session.run(BOM_TRIMS, cartId=cart_id)
        records = await result.data()
        trim_map: dict[str, list[BOMTrim]] = {}
        for r in records:
            trim_map[r["panel_sku"]] = [
                BOMTrim(
                    sku=t["sku"],
                    name=t.get("name"),
                    price=_safe_int(t.get("price")),
                    trim_type=t.get("type"),
                    suggestion=t.get("suggestion"),
                )
                for t in r.get("trims", [])
                if t.get("sku")
            ]

        for panel_entry in panels:
            panel_entry.suggested_trims = trim_map.get(panel_entry.panel_sku, [])

    return BOMResult(cart_id=cart_id, panels=panels)


# ═════════════════════════════════════════════════════════════════════════════
# EVALUATE (COMBINED VALIDATION + BOM)
# ═════════════════════════════════════════════════════════════════════════════


@app.get("/cart/{cart_id}/evaluate", response_model=EvaluateResult)
async def evaluate_cart(cart_id: str):
    """Run validation + BOM in a single read transaction for snapshot consistency."""

    async def _run_evaluate(tx):
        # ── Validation ──
        meta_result = await tx.run(CART_META, cartId=cart_id)
        meta_record = await meta_result.single()
        if meta_record is None:
            return None

        meta = {
            "cart_id": meta_record["cart_id"],
            "room_type": meta_record["room_type"],
        }

        all_violations: list[dict] = []
        for _group_name, query in VALIDATION_GROUPS:
            result = await tx.run(query, cartId=cart_id)
            record = await result.single()
            if record is not None:
                all_violations.extend(record["violations"])

        # ── BOM ──
        bom_result = await tx.run(BOM_CONSUMABLES, cartId=cart_id)
        bom_records = await bom_result.data()

        trim_result = await tx.run(BOM_TRIMS, cartId=cart_id)
        trim_records = await trim_result.data()

        return {
            "meta": meta,
            "violations": all_violations,
            "bom_records": bom_records,
            "trim_records": trim_records,
        }

    async with get_session() as session:
        data = await session.execute_read(_run_evaluate)

    if data is None:
        raise HTTPException(404, f"Cart {cart_id} not found")

    # Build violations
    violations = [
        Violation(
            rule_id=v["rule_id"],
            severity=v["severity"],
            message=v["message"],
            action=v.get("action"),
            item=v.get("item"),
        )
        for v in data["violations"]
        if v.get("rule_id") is not None
    ]
    error_count = sum(1 for v in violations if v.severity == "ERROR")
    warning_count = sum(1 for v in violations if v.severity == "WARNING")
    info_count = sum(1 for v in violations if v.severity == "INFO")

    # Build BOM
    panels: list[BOMPanelEntry] = []
    for r in data["bom_records"]:
        panels.append(
            BOMPanelEntry(
                panel_sku=r["panel_sku"],
                install_method=r.get("install_method"),
                required_consumables=[BOMConsumable(**c) for c in r.get("required", []) if c.get("sku")],
                optional_consumables=[BOMConsumable(**c) for c in r.get("optional", []) if c.get("sku")],
            )
        )
    trim_map: dict[str, list[BOMTrim]] = {}
    for r in data["trim_records"]:
        trim_map[r["panel_sku"]] = [
            BOMTrim(
                sku=t["sku"],
                name=t.get("name"),
                price=_safe_int(t.get("price")),
                trim_type=t.get("type"),
                suggestion=t.get("suggestion"),
            )
            for t in r.get("trims", [])
            if t.get("sku")
        ]
    for panel_entry in panels:
        panel_entry.suggested_trims = trim_map.get(panel_entry.panel_sku, [])

    bom = BOMResult(cart_id=cart_id, panels=panels)

    return EvaluateResult(
        cart_id=data["meta"]["cart_id"],
        room_type=data["meta"]["room_type"],
        pass_fail="FAIL" if error_count > 0 else "PASS",
        error_count=error_count,
        warning_count=warning_count,
        info_count=info_count,
        violations=violations,
        bom=bom,
    )


# ═════════════════════════════════════════════════════════════════════════════
# DEFAULTS & ROOM AFFINITY
# ═════════════════════════════════════════════════════════════════════════════


@app.get("/defaults/{room_type}", response_model=DefaultPanelOut)
async def default_panel(room_type: str):
    async with get_session() as session:
        result = await session.run(DEFAULT_PANEL_FOR_ROOM)
        record = await result.single()

    if record is None:
        raise HTTPException(404, "Default selection rules not loaded")

    defaults_json = record["raw"]
    try:
        defaults = json.loads(defaults_json)
    except (json.JSONDecodeError, TypeError):
        defaults = {}

    suggested_sku = defaults.get(room_type, defaults.get("any"))
    panel = None

    if suggested_sku:
        async with get_session() as session:
            result = await session.run(
                "MATCH (p:Panel {sku: $sku}) RETURN p",
                sku=suggested_sku,
            )
            rec = await result.single()
            if rec:
                panel = PanelOut(**dict(rec["p"]))

    return DefaultPanelOut(room_type=room_type, suggested_sku=suggested_sku, panel=panel)


@app.get("/catalog/panels/ranked/{room_type}")
async def ranked_panels(room_type: str):
    async with get_session() as session:
        result = await session.run(ROOM_RANKED_PANELS)
        records = await result.data()

    ranked = []
    for r in records:
        affinity_raw = r.get("room_affinity", "{}")
        try:
            affinity = json.loads(affinity_raw) if affinity_raw else {}
        except (json.JSONDecodeError, TypeError):
            affinity = {}
        score = affinity.get(room_type, affinity.get("any", 0.0))
        ranked.append(
            {
                "sku": r["sku"],
                "name": r["name"],
                "price": r.get("price"),
                "subcategory": r["subcategory"],
                "availability": r["availability"],
                "affinity_score": score,
                "default_selection": r.get("default_selection", False),
            }
        )

    ranked.sort(key=lambda x: x["affinity_score"], reverse=True)
    return ranked
