"""VPN2GO Backend — конфигурация через .env"""
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Stealthnet
    stealthnet_base_url: str = "https://your-stealthnet.com/api/v1"
    stealthnet_api_key: str = ""

    # Remnawave
    remnawave_base_url: str = "https://your-remnawave.com/api"
    remnawave_api_key: str = ""
    remnawave_sub_base_url: str = "https://connect.example.com"

    # JWT
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 1440  # 24 часа

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = True

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
