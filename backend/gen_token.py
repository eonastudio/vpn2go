import sys
sys.path.insert(0, '/root/workspace/vpn2go/backend')
from auth import create_app_token
token = create_app_token({'user_id':'test','email':'test@test.com','sn_jwt':'fake'})
with open('/tmp/test_token.txt', 'w') as f:
    f.write(token)
print(f"OK len={len(token)}")
