"""Pydantic request/response models for the API."""

from __future__ import annotations

from pydantic import BaseModel, Field

# ── Catalog ──────────────────────────────────────────────────────────────────


class PanelOut(BaseModel):
    sku: str
    name: str
    subcategory: str
    price: int | None = None
    colors: int = 0
    finish: str | None = None
    availability: str = "AVAILABLE"
    waterproof: bool | None = None
    moisture_resistant: bool | None = None
    room_affinity: str | None = None
    default_selection: bool = False


class TrimOut(BaseModel):
    sku: str
    name: str
    subcategory: str
    trim_type: str
    price: int | None = None
    material: str | None = None
    availability: str = "AVAILABLE"


class ConsumableOut(BaseModel):
    sku: str
    name: str
    subcategory: str
    price: int | None = None


class LEDProfileOut(BaseModel):
    sku: str
    name: str
    price: int | None = None
    profile_type: str | None = None


class FurnitureOut(BaseModel):
    sku: str
    name: str
    subcategory: str
    series: str | None = None
    style: str | None = None
    widths_ft: list[int] | None = None
    prices: str | None = None
    price: int | None = None
    finishes: int = 1
    installation: str | None = None
    availability: str = "AVAILABLE"


# ── Cart ─────────────────────────────────────────────────────────────────────


class CartItemIn(BaseModel):
    sku: str
    item_type: str = Field(description="PANEL | TRIM | CONSUMABLE | LED_PROFILE | LED_STRIP | LED_KIT | FURNITURE")
    quantity: int = 1
    source: str = "USER_ADDED"
    width_ft: int | None = None
    zone: int | None = None


class CartCreateIn(BaseModel):
    cart_id: str | None = None
    room_type: str = "any"
    is_two_zone: bool = False
    panels_reach_floor: bool = False
    wall_width_mm: int | None = None
    wall_height_mm: int | None = None
    items: list[CartItemIn] = []


class CartItemOut(BaseModel):
    id: str
    sku: str
    item_type: str
    quantity: int
    unit_price: int | None = None
    source: str = "USER_ADDED"
    width_ft: int | None = None
    zone: int | None = None


class CartOut(BaseModel):
    id: str
    status: str
    room_type: str
    is_two_zone: bool
    panels_reach_floor: bool
    wall_width_mm: int | None = None
    wall_height_mm: int | None = None
    items: list[CartItemOut] = []


# ── Validation ───────────────────────────────────────────────────────────────


class Violation(BaseModel):
    rule_id: str
    severity: str
    message: str
    action: str | None = None
    item: str | None = None


class ValidationResult(BaseModel):
    cart_id: str
    room_type: str | None = None
    pass_fail: str
    error_count: int = 0
    warning_count: int = 0
    info_count: int = 0
    violations: list[Violation] = []


# ── BOM ──────────────────────────────────────────────────────────────────────


class BOMConsumable(BaseModel):
    sku: str
    name: str | None = None
    price: int | None = None
    status: str  # REQUIRED | OPTIONAL | FORBIDDEN


class BOMTrim(BaseModel):
    sku: str
    name: str | None = None
    price: int | None = None
    trim_type: str | None = None
    suggestion: str | None = None


class BOMPanelEntry(BaseModel):
    panel_sku: str
    install_method: str | None = None
    required_consumables: list[BOMConsumable] = []
    optional_consumables: list[BOMConsumable] = []
    suggested_trims: list[BOMTrim] = []


class BOMResult(BaseModel):
    cart_id: str
    panels: list[BOMPanelEntry] = []
    polyfix_suggestion: dict | None = None
    two_zone_suggestion: dict | None = None
    skirting_suggestion: dict | None = None


# ── Evaluate (combined) ─────────────────────────────────────────────────────


class EvaluateResult(BaseModel):
    cart_id: str
    room_type: str | None = None
    pass_fail: str
    error_count: int = 0
    warning_count: int = 0
    info_count: int = 0
    violations: list[Violation] = []
    bom: BOMResult | None = None


# ── Defaults ─────────────────────────────────────────────────────────────────


class DefaultPanelOut(BaseModel):
    room_type: str
    suggested_sku: str | None = None
    panel: PanelOut | None = None
