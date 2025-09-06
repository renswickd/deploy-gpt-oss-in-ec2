from typing import List

from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = Field(default="Local LLM API", validation_alias="APP_NAME")
    debug: bool = Field(default=False, validation_alias="DEBUG")

    # Ollama settings
    ollama_host: str = Field(default="http://localhost:11434", validation_alias="OLLAMA_HOST")
    ollama_model: str = Field(default="", validation_alias="OLLAMA_MODEL")

    # CORS
    cors_origins: List[str] = Field(default_factory=lambda: ["*"] , validation_alias="CORS_ORIGINS")
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
