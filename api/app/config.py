"""Application configuration — reads from environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    neo4j_uri: str = "bolt://localhost:7687"
    neo4j_user: str = "neo4j"
    neo4j_password: str = "password"
    neo4j_database: str = "neo4j"

    app_title: str = "Perfeccity Wall Configurator API"
    app_version: str = "1.0.0"
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:5173"]

    # API key auth — set via PERFECCITY_API_KEY env var. Empty = auth disabled.
    api_key: str = ""

    model_config = {"env_prefix": "PERFECCITY_"}


settings = Settings()
