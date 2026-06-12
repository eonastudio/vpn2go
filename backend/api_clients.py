"""VPN2GO Backend — HTTP клиенты для Stealthnet и Remnawave"""
import httpx
from config import get_settings

settings = get_settings()


class StealthnetClient:
    """Клиент для Stealthnet API (TG-бот панель)"""

    def __init__(self):
        self.base_url = settings.stealthnet_base_url
        self.api_key = settings.stealthnet_api_key

    def _headers(self, client_jwt: str = None) -> dict:
        h = {
            "X-Api-Key": self.api_key,
            "Content-Type": "application/json",
        }
        if client_jwt:
            h["Authorization"] = f"Bearer {client_jwt}"
        return h

    async def login(self, email: str, password: str) -> dict:
        """Авторизация клиента → JWT + данные"""
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/auth/login",
                json={"email": email, "password": password},
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def register(self, email: str, password: str, **kwargs) -> dict:
        """Регистрация нового клиента"""
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/auth/register",
                json={"email": email, "password": password, **kwargs},
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_profile(self, client_jwt: str) -> dict:
        """Профиль клиента"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/client/profile",
                headers=self._headers(client_jwt),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_subscription(self, client_jwt: str) -> dict:
        """Подписка клиента (связь с Remnawave)"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/client/subscription",
                headers=self._headers(client_jwt),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_devices(self, client_jwt: str) -> dict:
        """Устройства клиента (HWID)"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/client/devices",
                headers=self._headers(client_jwt),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_balance(self, client_jwt: str) -> dict:
        """Баланс клиента"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/client/balance",
                headers=self._headers(client_jwt),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_payments(self, client_jwt: str) -> dict:
        """История платежей"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/client/payments",
                headers=self._headers(client_jwt),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_tariffs(self) -> dict:
        """Список тарифов (публичный)"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/tariffs",
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_config(self) -> dict:
        """Публичная конфигурация проекта"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/config",
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def register_device(self, client_jwt: str, hwid: str, platform: str = "android", os_version: str = "", device_model: str = "") -> dict:
        """Регистрация устройства (HWID)"""
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/client/devices",
                json={
                    "hwid": hwid,
                    "platform": platform,
                    "osVersion": os_version,
                    "deviceModel": device_model,
                },
                headers=self._headers(client_jwt),
            )
            resp.raise_for_status()
            return resp.json()


class RemnawaveClient:
    """Клиент для Remnawave API (оркестрация нод)"""

    def __init__(self):
        self.base_url = settings.remnawave_base_url
        self.api_key = settings.remnawave_api_key
        self.sub_base_url = settings.remnawave_sub_base_url

    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

    async def get_subscription_info(self, short_uuid: str) -> dict:
        """Информация о подписке по shortUuid"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/sub/{short_uuid}/info",
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_subscription_config(self, short_uuid: str, client_type: str = "singbox") -> str:
        """Получить конфиг подписки для конкретного клиента
        
        client_type: singbox | json | v2ray-json | mihomo | stash | clash
        """
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/sub/{short_uuid}/{client_type}",
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.text

    async def get_connection_keys(self, uuid: str) -> dict:
        """Ключи подключения (base64)"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/subscriptions/connection-keys/{uuid}",
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_nodes(self) -> dict:
        """Список всех нод"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/nodes",
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_node_by_uuid(self, uuid: str) -> dict:
        """Информация о ноде по UUID"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/nodes/{uuid}",
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_system_stats(self) -> dict:
        """Общая статистика системы"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/system/stats",
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def get_nodes_metrics(self) -> dict:
        """Метрики нод"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/system/nodes/metrics",
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def find_user_by_telegram_id(self, telegram_id: int) -> dict:
        """Найти пользователя по Telegram ID"""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/users/by-telegram-id/{telegram_id}",
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    async def register_device(self, user_uuid: str, hwid: str, platform: str = "android", os_version: str = "", device_model: str = "", user_agent: str = "") -> dict:
        """Регистрация HWID устройства через Remnawave"""
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/hwid/devices",
                json={
                    "userUuid": user_uuid,
                    "hwid": hwid,
                    "platform": platform,
                    "osVersion": os_version,
                    "deviceModel": device_model,
                    "userAgent": user_agent,
                },
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()


# Синглтоны
stealthnet = StealthnetClient()
remnawave = RemnawaveClient()
