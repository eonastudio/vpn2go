"""VPN2GO Backend — авторизация и JWT"""
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from fastapi import HTTPException, Security, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from config import get_settings

settings = get_settings()
security = HTTPBearer()


def create_app_token(data: dict, expires_delta: timedelta = None) -> str:
    """Создать JWT-токен приложения (не Stealthnet JWT!)"""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.jwt_expire_minutes)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_app_token(token: str) -> dict:
    """Декодировать JWT-токен приложения"""
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security),
) -> dict:
    """Dependency: извлекает пользователя из JWT-токена приложения"""
    token = credentials.credentials
    payload = decode_app_token(token)
    if "user_id" not in payload:
        raise HTTPException(status_code=401, detail="Invalid token payload")
    return payload
