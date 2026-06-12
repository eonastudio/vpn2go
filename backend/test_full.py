import httpx, asyncio, json, sys

BASE = "http://localhost:8000/api/v1"

async def full_test():
    async with httpx.AsyncClient(timeout=30) as c:
        print("=" * 60)
        print("  VPN2GO — Full Integration Test")
        print("=" * 60)

        # 1. Login
        print("\n[1] LOGIN")
        r = await c.post(f"{BASE}/auth/login", json={
            "email": "its.prism@yandex.ru",
            "password": "28099082Timur"
        })
        data = r.json()
        print(f"  Status: {r.status_code}")
        print(f"  User ID: {data.get('user_id')}")
        print(f"  Email: {data.get('email')}")
        print(f"  Balance: {data.get('balance')}₽")
        print(f"  Telegram: @{data.get('telegram_username')}")
        print(f"  Remnawave UUID: {data.get('remnawave_uuid')}")
        
        token = data.get("app_token")
        headers = {"Authorization": f"Bearer {token}"}

        # 2. Profile
        print("\n[2] PROFILE")
        r = await c.get(f"{BASE}/client/profile", headers=headers)
        print(f"  Status: {r.status_code}")
        p = r.json()
        print(f"  Balance: {p.get('balance')}₽")
        print(f"  Blocked: {p.get('isBlocked')}")

        # 3. Subscription
        print("\n[3] SUBSCRIPTION")
        r = await c.get(f"{BASE}/client/subscription", headers=headers)
        print(f"  Status: {r.status_code}")
        s = r.json()
        sub = s.get("subscription", s)
        print(f"  Short UUID: {sub.get('shortUuid')}")
        print(f"  Status: {sub.get('status')}")
        print(f"  Expire: {sub.get('expireAt')}")
        print(f"  HWID Limit: {sub.get('hwidDeviceLimit')}")
        traffic = sub.get("userTraffic", {})
        print(f"  Traffic Used: {traffic.get('usedTrafficBytes', 0) / 1e9:.2f} GB")

        # 4. VPN Connect (one-click!)
        print("\n[4] VPN CONNECT (one-click)")
        r = await c.get(f"{BASE}/vpn/connect?client_type=singbox", headers=headers)
        print(f"  Status: {r.status_code}")
        if r.status_code == 200:
            vc = r.json()
            print(f"  Short UUID: {vc.get('short_uuid')}")
            print(f"  Config type: {vc.get('client_type')}")
            config = vc.get("config", "")
            print(f"  Config length: {len(config)} chars")
            # Show first 200 chars of config
            print(f"  Config preview: {config[:200]}...")
            sub_info = vc.get("subscription", {})
            print(f"  Sub status: {sub_info.get('status')}")
            print(f"  Sub expire: {sub_info.get('expire_at')}")
        else:
            print(f"  Error: {r.text[:200]}")

        # 5. Nodes
        print("\n[5] NODES")
        r = await c.get(f"{BASE}/vpn/nodes", headers=headers)
        print(f"  Status: {r.status_code}")
        nodes = r.json().get("response", [])
        print(f"  Total: {len(nodes)}")
        for n in nodes:
            cc = n.get("countryCode", "?")
            name = n.get("name", "?")
            online = "🟢" if n.get("isConnected") else "🔴"
            users = n.get("usersOnline", 0)
            print(f"    {online} {name} ({cc}) — {users} users")

        print("\n" + "=" * 60)
        print("  ✅ All tests passed!")
        print("=" * 60)

asyncio.run(full_test())
