from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    ai_env: str = "local"
    ai_service_name: str = "myaaptha-agent"
    ai_api_prefix: str = "/api/v1"
    ai_log_level: str = "INFO"


settings = Settings()
