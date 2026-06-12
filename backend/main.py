"""VPN2GO Backend — главный FastAPI приложение

Проксирует запросы между мобильным приложением и Stealthnet/Remnawave API.
Хранит API-ключи на сервере, не светит их в клиенте.
"""
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from config import get_settings
from api_clients import stealthnet, remnawave
from auth import create_app_token, get_current_user
from models import (
    LoginRequest, RegisterRequest, TokenResponse,
    VpnConfigResponse,
)

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    print(f"🚀 VPN2GO Backend starting on {settings.host}:{settings.port}")
    print(f"📡 Stealthnet: {settings.stealthnet_base_url}")
    print(f"🌐 Remnawave: {settings.remnawave_base_url}")
    yield
    print("👋 VPN2GO Backend shutting down")


app = FastAPI(
    title="VPN2GO API",
    description="Прокси-сервер между мобильным приложением и Stealthnet/Remnawave",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
#  AUTH — авторизация через Stealthnet
# ============================================================

@app.post("/api/v1/auth/login", response_model=TokenResponse)
async def login(req: LoginRequest):
    """
    Логин клиента.
    1. Авторизуемся в Stealthnet → получаем stealthnet_jwt
    2. Создаём свой app_token для мобильного приложения
    """
    try:
        sn_result = await stealthnet.login(req.email, req.password)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Stealthnet auth failed: {str(e)}")

    # Извлекаем данные из ответа Stealthnet
    # Ответ: { "token": "...", "client": { "id": "...", "email": "...", "remnawaveUuid": "..." } }
    sn_jwt = sn_result.get("token") or sn_result.get("jwt") or sn_result.get("access_token", "")
    client_data = sn_result.get("client") or sn_result.get("user") or sn_result
    user_id = str(client_data.get("id", ""))
    remnawave_uuid = client_data.get("remnawaveUuid", "")
    balance = client_data.get("balance", 0)
    tg_id = client_data.get("telegramId", "")
    tg_username = client_data.get("telegramUsername", "")

    # Создаём свой токен, в который запихиваем stealthnet_jwt
    app_token = create_app_token({
        "user_id": user_id,
        "email": req.email,
        "sn_jwt": sn_jwt,  # храним stealthnet JWT внутри нашего токена
    })

    return {
        "app_token": app_token,
        "stealthnet_jwt": sn_jwt,
        "user_id": user_id,
        "email": req.email,
        "remnawave_uuid": remnawave_uuid,
        "balance": balance,
        "telegram_id": tg_id,
        "telegram_username": tg_username,
        "expires_in": settings.jwt_expire_minutes * 60,
    }


@app.post("/api/v1/auth/register")
async def register(req: RegisterRequest):
    """Регистрация нового клиента через Stealthnet"""
    try:
        result = await stealthnet.register(req.email, req.password, username=req.username)
        return {"status": "ok", "data": result}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Registration failed: {str(e)}")


# ============================================================
#  CLIENT — данные клиента (нужен app_token)
# ============================================================

def _extract_sn_jwt(user: dict) -> str:
    """Достаём stealthnet_jwt из нашего app_token"""
    sn_jwt = user.get("sn_jwt")
    if not sn_jwt:
        raise HTTPException(status_code=401, detail="Stealthnet JWT not found in token")
    return sn_jwt


@app.get("/api/v1/client/profile")
async def get_profile(user=Depends(get_current_user)):
    """Профиль клиента (проксируем в Stealthnet)"""
    sn_jwt = _extract_sn_jwt(user)
    try:
        return await stealthnet.get_profile(sn_jwt)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch profile: {str(e)}")


@app.get("/api/v1/client/subscription")
async def get_subscription(user=Depends(get_current_user)):
    """
    Подписка клиента.
    Возвращает данные подписки из Stealthnet (связь с Remnawave).
    """
    sn_jwt = _extract_sn_jwt(user)
    try:
        return await stealthnet.get_subscription(sn_jwt)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch subscription: {str(e)}")


@app.get("/api/v1/client/balance")
async def get_balance(user=Depends(get_current_user)):
    """Баланс клиента"""
    sn_jwt = _extract_sn_jwt(user)
    try:
        return await stealthnet.get_balance(sn_jwt)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch balance: {str(e)}")


@app.get("/api/v1/client/devices")
async def get_devices(user=Depends(get_current_user)):
    """Устройства клиента (HWID)"""
    sn_jwt = _extract_sn_jwt(user)
    try:
        return await stealthnet.get_devices(sn_jwt)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch devices: {str(e)}")


@app.post("/api/v1/client/device/register")
async def register_device(
    hwid: str,
    platform: str = "android",
    os_version: str = "",
    device_model: str = "",
    user_agent: str = "",
    user=Depends(get_current_user),
):
    """
    Регистрация устройства (HWID).
    
    Вызывается при первом запуске приложения.
    Привязывает HWID устройства к подписке пользователя.
    """
    sn_jwt = _extract_sn_jwt(user)
    
    # Регистрируем через Remnawave API
    try:
        result = await remnawave.register_device(
            user_uuid=user.get("user_id", ""),
            hwid=hwid,
            platform=platform,
            os_version=os_version,
            device_model=device_model,
            user_agent=user_agent,
        )
        return {"status": "registered", "hwid": hwid, "result": result}
    except Exception as e:
        # Если Remnawave не принимает — пробуем через Stealthnet
        try:
            result = await stealthnet.register_device(sn_jwt, hwid, platform, os_version, device_model)
            return {"status": "registered", "hwid": hwid, "result": result}
        except Exception as e2:
            raise HTTPException(status_code=502, detail=f"Device registration failed: {str(e2)}")


@app.get("/api/v1/client/device/check/{hwid}")
async def check_device(hwid: str, user=Depends(get_current_user)):
    """
    Проверить, зарегистрировано ли устройство.
    Возвращает лимит устройств и текущее количество.
    """
    sn_jwt = _extract_sn_jwt(user)
    try:
        devices = await stealthnet.get_devices(sn_jwt)
        sub = await stealthnet.get_subscription(sn_jwt)
        
        sub_data = sub.get("subscription", sub)
        hwid_limit = sub_data.get("hwidDeviceLimit", 1)
        
        device_list = devices if isinstance(devices, list) else devices.get("devices", devices.get("data", []))
        registered_hwids = []
        for d in (device_list if isinstance(device_list, list) else []):
            if isinstance(d, dict):
                registered_hwids.append(d.get("hwid", ""))
        
        is_registered = hwid in registered_hwids
        
        return {
            "hwid": hwid,
            "is_registered": is_registered,
            "devices_count": len(registered_hwids),
            "devices_limit": hwid_limit,
            "can_register": len(registered_hwids) < hwid_limit or is_registered,
        }
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Device check failed: {str(e)}")


@app.get("/api/v1/client/payments")
async def get_payments(user=Depends(get_current_user)):
    """История платежей"""
    sn_jwt = _extract_sn_jwt(user)
    try:
        return await stealthnet.get_payments(sn_jwt)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch payments: {str(e)}")


# ============================================================
#  VPN — получение конфигов и управление подключением
# ============================================================

@app.get("/api/v1/vpn/connect")
async def vpn_connect(
    client_type: str = "singbox",
    hwid: str = "",
    platform: str = "android",
    os_version: str = "",
    device_model: str = "",
    user=Depends(get_current_user),
):
    """
    Подключение в один клик!
    1. Проверяем/регистрируем HWID устройства
    2. Берём подписку из Stealthnet → shortUuid
    3. Берём sing-box конфиг из Remnawave
    4. Отдаём готовый конфиг для подключения
    """
    sn_jwt = _extract_sn_jwt(user)
    
    # Шаг 1: Проверяем HWID (если передан)
    hwid_status = None
    if hwid:
        try:
            devices = await stealthnet.get_devices(sn_jwt)
            sub_data = await stealthnet.get_subscription(sn_jwt)
            sub_info = sub_data.get("subscription", sub_data)
            hwid_limit = sub_info.get("hwidDeviceLimit", 1)
            
            device_list = devices if isinstance(devices, list) else devices.get("devices", devices.get("data", []))
            registered = [d.get("hwid", "") for d in (device_list if isinstance(device_list, list) else []) if isinstance(d, dict)]
            
            if hwid not in registered:
                if len(registered) >= hwid_limit:
                    raise HTTPException(status_code=403, detail={
                        "error": "device_limit_exceeded",
                        "message": f"Лимит устройств ({hwid_limit}) превышен. Отвяжите устройство или улучшите тариф.",
                        "devices_count": len(registered),
                        "devices_limit": hwid_limit,
                    })
                # Регистрируем устройство
                try:
                    await remnawave.register_device(
                        user_uuid=sub_info.get("uuid", ""),
                        hwid=hwid,
                        platform=platform,
                        os_version=os_version,
                        device_model=device_model,
                    )
                except Exception:
                    pass  # Продолжаем даже если регистрация не удалась
            
            hwid_status = {
                "hwid": hwid,
                "is_registered": hwid in registered,
                "devices_count": len(registered),
                "devices_limit": hwid_limit,
            }
        except HTTPException:
            raise
        except Exception as e:
            hwid_status = {"hwid": hwid, "error": str(e)}
    
    # Шаг 2: Получаем подписку из Stealthnet
    try:
        sub_data = await stealthnet.get_subscription(sn_jwt)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to get subscription: {str(e)}")
    
    # Извлекаем shortUuid
    sub = sub_data.get("subscription", sub_data)
    short_uuid = sub.get("shortUuid", "")
    if not short_uuid:
        raise HTTPException(status_code=404, detail="No active subscription found")
    
    # Шаг 3: Получаем VPN конфиг из Remnawave
    try:
        config = await remnawave.get_subscription_config(short_uuid, client_type)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to get VPN config: {str(e)}")
    
    return {
        "short_uuid": short_uuid,
        "client_type": client_type,
        "config": config,
        "subscription": {
            "status": sub.get("status"),
            "expire_at": sub.get("expireAt"),
            "hwid_limit": sub.get("hwidDeviceLimit"),
            "traffic_used": sub.get("userTraffic", {}).get("usedTrafficBytes", 0),
        },
        "device": hwid_status,
    }


@app.get("/api/v1/vpn/config/{short_uuid}")
async def get_vpn_config(
    short_uuid: str,
    client_type: str = "singbox",
    user=Depends(get_current_user),
):
    """
    Получить VPN-конфиг для подключения.
    
    client_type: singbox | json | v2ray-json | mihomo | stash | clash
    
    Используется мобильным приложением для запуска sing-box.
    """
    try:
        config = await remnawave.get_subscription_config(short_uuid, client_type)
        return {
            "short_uuid": short_uuid,
            "client_type": client_type,
            "config": config,
        }
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch VPN config: {str(e)}")


@app.get("/api/v1/vpn/info/{short_uuid}")
async def get_vpn_info(short_uuid: str, user=Depends(get_current_user)):
    """Информация о подписке (из Remnawave)"""
    try:
        return await remnawave.get_subscription_info(short_uuid)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch VPN info: {str(e)}")


@app.get("/api/v1/vpn/nodes")
async def get_vpn_nodes(user=Depends(get_current_user)):
    """Список доступных VPN-нод"""
    try:
        return await remnawave.get_nodes()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch nodes: {str(e)}")


@app.get("/api/v1/vpn/nodes/metrics")
async def get_nodes_metrics(user=Depends(get_current_user)):
    """Метрики нод (нагрузка, пользователи)"""
    try:
        return await remnawave.get_nodes_metrics()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch metrics: {str(e)}")


# ============================================================
#  PUBLIC — публичные эндпоинты (без авторизации)
# ============================================================

@app.get("/api/v1/public/tariffs")
async def get_tariffs():
    """Список тарифов (публичный)"""
    try:
        return await stealthnet.get_tariffs()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch tariffs: {str(e)}")


@app.get("/api/v1/public/config")
async def get_public_config():
    """Публичная конфигурация проекта"""
    try:
        return await stealthnet.get_config()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch config: {str(e)}")


@app.get("/api/v1/public/health")
async def health():
    """Health check"""
    return {"status": "ok", "service": "vpn2go-backend", "version": "1.0.0"}


# ============================================================
#  RUN
# ============================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.host, port=settings.port, reload=settings.debug)
