"""Neo4j seed loader — loads Cypher scripts into the database.

Correctly handles comment lines interleaved with Cypher statements.
Previous ad-hoc seeders dropped statements that followed comment blocks,
silently skipping ~80 of 227 statements including constraints, products,
relationships, and validation rules.

Usage:
    python scripts/seed.py [--wipe]

    --wipe   Delete all nodes/relationships before seeding (for clean reload).

Environment:
    NEO4J_URI       bolt://localhost:7687  (default)
    NEO4J_USER      neo4j                  (default)
    NEO4J_PASSWORD  perfeccity123          (default)
"""

from __future__ import annotations

import os
import re
import sys

from neo4j import GraphDatabase

NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "perfeccity123")

SEED_FILES = [
    "cypher/wall-configurator-graph-v5.cypher",
    "cypher/engine/00-cart-schema.cypher",
]


def parse_cypher(path: str) -> list[str]:
    """Parse a .cypher file into individual executable statements.

    Strategy:
      1. Split on semicolons followed by optional whitespace + newline.
      2. Strip single-line comments (``// ...``) from each chunk.
      3. Drop empty/meta chunks (`:param`, etc.).
    """
    with open(path) as f:
        content = f.read()

    # Split on statement terminator ; followed by newline
    raw_chunks = re.split(r";\s*\n", content)

    statements: list[str] = []
    for chunk in raw_chunks:
        # Remove single-line comments (preserving strings is not needed
        # because our Cypher seed files never have // inside strings).
        cleaned = re.sub(r"//.*$", "", chunk, flags=re.MULTILINE)
        cleaned = cleaned.strip().rstrip(";")
        if not cleaned or cleaned.startswith(":"):
            continue
        statements.append(cleaned)

    return statements


def seed(wipe: bool = False) -> None:
    driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
    driver.verify_connectivity()
    print(f"Connected to {NEO4J_URI}")

    if wipe:
        with driver.session() as session:
            session.run("MATCH (n) DETACH DELETE n")
        print("Wiped all data")

    total_ok, total_fail = 0, 0
    for path in SEED_FILES:
        stmts = parse_cypher(path)
        ok, fail = 0, 0
        with driver.session() as session:
            for stmt in stmts:
                try:
                    session.run(stmt)
                    ok += 1
                except Exception as exc:
                    fail += 1
                    # Show first 120 chars of the failing statement for debugging
                    preview = stmt.replace("\n", " ")[:120]
                    print(f"  FAIL: {preview}…")
                    print(f"        {exc!s:.120}")
        print(f"{path}: {ok} ok, {fail} fail")
        total_ok += ok
        total_fail += fail

    driver.close()
    print(f"\nTotal: {total_ok} ok, {total_fail} fail")
    if total_fail:
        sys.exit(1)


if __name__ == "__main__":
    wipe = "--wipe" in sys.argv
    seed(wipe=wipe)
