import httpx, asyncio, json, os
from dotenv import load_dotenv
load_dotenv("/root/workspace/vpn2go/backend/.env")

async def test():
    base = os.getenv('STEALTHNET_BASE_URL')
    key = os.getenv('STEALTHNET_API_KEY')
    print(f"URL: {base}")
    print(f"Key len: {len(key)}")
    
    async with httpx.AsyncClient() as client:
        # Login
        resp = await client.post(
            f"{base}/auth/login",
            json={"email": "its.prism@yandex.ru", "password": "28099082Timur"},
            headers={"X-Api-Key": key, "Content-Type": "application/json"},
        )
        print(f"\n=== LOGIN Response ===")
        print(f"Status: {resp.status_code}")
        data = resp.json()
        print(json.dumps(data, indent=2, ensure_ascii=False))
        
        # Get JWT
        jwt = data.get("token") or data.get("jwt") or data.get("access_token") or ""
        if not jwt:
            for k, v in data.items():
                if isinstance(v, str) and len(v) > 50:
                    jwt = v
                    print(f"\nFound JWT in key '{k}'")
                    break
        
        if jwt:
            print(f"\nJWT found: {jwt[:30]}...")
            
            # Profile
            resp2 = await client.get(
                f"{base}/client/profile",
                headers={"Authorization": f"Bearer {jwt}", "X-Api-Key": key},
            )
            print(f"\n=== PROFILE ===")
            print(f"Status: {resp2.status_code}")
            print(json.dumps(resp2.json(), indent=2, ensure_ascii=False)[:1000])
            
            # Subscription
            resp3 = await client.get(
                f"{base}/client/subscription",
                headers={"Authorization": f"Bearer {jwt}", "X-Api-Key": key},
            )
            print(f"\n=== SUBSCRIPTION ===")
            print(f"Status: {resp3.status_code}")
            print(json.dumps(resp3.json(), indent=2, ensure_ascii=False)[:2000])

asyncio.run(test())
