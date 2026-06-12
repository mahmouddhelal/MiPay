from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    DATABASE_URL: str = "postgresql+asyncpg://mipay:mipay@postgres:5432/mipay"

    JWT_SECRET: str = "change-me-in-production"
    ACCESS_TOKEN_MINUTES: int = 30
    REFRESH_TOKEN_DAYS: int = 30

    WHISPER_MODEL: str = "small"
    WHISPER_COMPUTE_TYPE: str = "int8"

    OLLAMA_URL: str = "http://ollama:11434"
    EXTRACTION_MODEL: str = "qwen2.5:7b-instruct"

    MAX_AUDIO_SECONDS: int = 30
    MAX_AUDIO_BYTES: int = 5_242_880  # 5 MB


settings = Settings()
