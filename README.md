# VPN2GO — Mobile VPN Client

Кастомный VPN-клиент для сервиса VPN2GO.

## Архитектура

```
┌─────────────────────────────────────────────────┐
│              Flutter App (iOS + Android)          │
│                                                   │
│  Login → API Proxy → sing-box VPN Engine          │
└───────────────┬─────────────────────┬─────────────┘
                │                     │
     ┌──────────▼──────┐   ┌─────────▼──────────┐
     │  Stealthnet     │   │   Remnawave        │
     │  API (TG Bot)   │   │   Panel API        │
     │                 │   │                    │
     │ • Auth/JWT      │   │ • VLESS configs    │
     │ • Subscriptions │   │ • Node management  │
     │ • Payments      │   │ • Statistics       │
     └─────────────────┘   └────────────────────┘
```

## Стек

| Компонент | Технология |
|-----------|-----------|
| Мобильное приложение | Flutter (Dart) |
| VPN Engine | sing-box (Go, нативная либа) |
| Backend Proxy | Python FastAPI |
| Протокол | Xray VLESS + Reality |
| Панель управления | Remnawave |
| Продажи | Stealthnet (TG Bot) |

## Структура проекта

```
vpn2go/
├── backend/                    # API-прокси (FastAPI)
│   ├── main.py                 # Главное приложение
│   ├── api_clients.py          # Клиенты Stealthnet + Remnawave
│   ├── auth.py                 # JWT авторизация
│   ├── config.py               # Конфигурация
│   ├── models.py               # Pydantic модели
│   ├── requirements.txt        # Зависимости Python
│   ├── Dockerfile              # Docker образ
│   └── .env.example            # Пример конфига
│
├── flutter_app/                # Мобильное приложение
│   ├── lib/
│   │   ├── main.dart           # Точка входа
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   └── home_screen.dart
│   │   ├── services/
│   │   │   ├── api_service.dart   # HTTP клиент
│   │   │   └── vpn_service.dart   # VPN подключение
│   │   └── theme/
│   │       └── app_theme.dart     # Тёмная тема
│   ├── android/
│   │   └── app/src/main/kotlin/com/vpn2go/app/
│   │       ├── VpnHandler.kt      # Flutter ↔ Android bridge
│   │       └── Vpn2GoVpnService.kt # Android VPN Service
│   └── pubspec.yaml
│
└── README.md
```

## Быстрый старт

### 1. Backend

```bash
cd backend
cp .env.example .env
# Заполни .env своими ключами

# Локально
pip install -r requirements.txt
python main.py

# Или через Docker
docker build -t vpn2go-backend .
docker run -p 8000:8000 --env-file .env vpn2go-backend
```

### 2. Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

## API Endpoints (Backend Proxy)

### Auth
| Method | Path | Описание |
|--------|------|----------|
| POST | `/api/v1/auth/login` | Логин → app_token |
| POST | `/api/v1/auth/register` | Регистрация |

### Client (нужен Bearer token)
| Method | Path | Описание |
|--------|------|----------|
| GET | `/api/v1/client/profile` | Профиль |
| GET | `/api/v1/client/subscription` | Подписка |
| GET | `/api/v1/client/balance` | Баланс |
| GET | `/api/v1/client/devices` | Устройства |

### VPN (нужен Bearer token)
| Method | Path | Описание |
|--------|------|----------|
| GET | `/api/v1/vpn/config/{short_uuid}` | VPN конфиг (sing-box) |
| GET | `/api/v1/vpn/info/{short_uuid}` | Инфо о подписке |
| GET | `/api/v1/vpn/nodes` | Список нод |
| GET | `/api/v1/vpn/nodes/metrics` | Метрики нод |

### Public
| Method | Path | Описание |
|--------|------|----------|
| GET | `/api/v1/public/tariffs` | Тарифы |
| GET | `/api/v1/public/config` | Конфиг проекта |
| GET | `/api/v1/public/health` | Health check |

## TODO

- [ ] Интеграция sing-box Go library (libbox) в Android
- [ ] Интеграция sing-box для iOS (NetworkExtension)
- [ ] Экран регистрации
- [ ] Экран профиля
- [ ] Push-уведомления
- [ ] Автоподключение при старте
- [ ] Kill Switch
- [ ] Split Tunneling
- [ ] Выбор протокола (VLESS/XTLS/Reality)
