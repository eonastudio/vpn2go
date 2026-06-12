"""VPN2GO Backend — модели данных (Pydantic)"""
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


# === Auth ===
class LoginRequest(BaseModel):
    email: str
    password: str


class RegisterRequest(BaseModel):
    email: str
    password: str
    username: Optional[str] = None


class TokenResponse(BaseModel):
    app_token: str
    stealthnet_jwt: str
    user_id: str
    email: str
    expires_in: int


# === Profile ===
class ProfileResponse(BaseModel):
    id: str
    email: str
    username: Optional[str] = None
    balance: Optional[float] = None
    subscription_status: Optional[str] = None


# === Subscription ===
class SubscriptionResponse(BaseModel):
    short_uuid: str
    status: str
    expire_at: Optional[str] = None
    traffic_used: Optional[int] = None
    traffic_limit: Optional[int] = None


# === Server ===
class ServerInfo(BaseModel):
    uuid: str
    name: str
    country: Optional[str] = None
    address: str
    port: int
    is_online: bool
    load_percent: Optional[float] = None
    users_count: Optional[int] = None


# === VPN Config ===
class VpnConfigResponse(BaseModel):
    config_type: str  # singbox, v2ray-json, etc.
    config_data: str  # raw config JSON/base64
    short_uuid: str
