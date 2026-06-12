import httpx, asyncio, json
from dotenv import load_dotenv
import os

load_dotenv("/root/workspace/vpn2go/backend/.env")

async def fix_test():
    base = os.getenv('STEALTHNET_BASE_URL')
    key = os.getenv('STEALTHNET_API_KEY')
    
    async with httpx.AsyncClient(timeout=30) as c:
        # Login
        r = await c.post(f"{base}/auth/login",
            json={"email": "its.prism@yandex.ru", "password": "28099082Timur"},
            headers={"X-Api-Key": key, "Content-Type": "application/json"})
        data = r.json()
        
        # Show exact structure
        print("=== LOGIN RESPONSE STRUCTURE ===")
        print(f"Top-level keys: {list(data.keys())}")
        print(f"  token: {data.get('token','?')[:30]}...")
        
        client = data.get("client", {})
        print(f"  client keys: {list(client.keys())}")
        print(f"  client.id: {client.get('id')}")
        print(f"  client.balance: {client.get('balance')}")
        print(f"  client.telegramUsername: {client.get('telegramUsername')}")
        print(f"  client.remnawaveUuid: {client.get('remnawaveUuid')}")

asyncio.run(fix_test())
