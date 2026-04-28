"""Application configuration — reads from environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    neo4j_uri: str = "bolt://localhost:7687"
    neo4j_user: str = "neo4j"
    neo4j_password: str = "password"
    neo4j_database: str = "neo4j"

    app_title: str = "Perfeccity Wall Configurator API"
    app_version: str = "1.0.0"
    cors_origins: list[str] = ["*"]

    model_config = {"env_prefix": "PERFECCITY_"}


settings = Settings()
