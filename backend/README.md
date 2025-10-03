# AI Calendar Backend

FastAPI backend для AI Calendar приложения с multi-agent системой и vector memory.

## 🚀 Quick Start

### Prerequis

ites
- Python 3.11+
- Docker & Docker Compose
- Poetry

### Local Development with Docker

1. **Скопируйте environment variables:**
```bash
cp .env.example .env
# Отредактируйте .env и добавьте свои API ключи
```

2. **Запустите сервисы:**
```bash
docker-compose up -d
```

3. **Проверьте health:**
```bash
curl http://localhost:8000/health
```

4. **Откройте API docs:**
```
http://localhost:8000/api/docs
```

### Local Development без Docker

1. **Установите PostgreSQL с pgvector:**
```bash
# macOS
brew install postgresql@16
brew install pgvector

# Или используйте только postgres контейнер:
docker-compose up -d postgres redis
```

2. **Установите зависимости:**
```bash
poetry install
```

3. **Запустите сервер:**
```bash
poetry run uvicorn app.main:app --reload
```

## 📦 Architecture

```
backend/
├── app/
│   ├── api/              # API endpoints (Week 5-8)
│   │   ├── auth.py       # JWT authentication
│   │   ├── ai.py         # AI processing endpoints
│   │   └── sync.py       # Sync endpoints
│   ├── models/           # SQLAlchemy models
│   │   ├── user.py       # User model
│   │   ├── task.py       # Task model (server-side copy)
│   │   └── memory.py     # Memory model (RAG)
│   ├── services/         # Business logic (Week 9+)
│   │   ├── auth_service.py
│   │   ├── llm_router.py
│   │   └── agents/       # Multi-agent system (Phase 2)
│   ├── db/               # Database connection
│   ├── config.py         # Settings
│   └── main.py           # FastAPI app
├── tests/                # Tests
├── docker-compose.yml    # Local development
└── Dockerfile
```

## 🗄️ Database Schema

### Users
- `id` (UUID): Primary key
- `email` (String): Unique email
- `apple_id` (String): Apple Sign In ID
- `tier` (String): free, basic, pro, premium, teams
- `preferences` (JSONB): User preferences

### Tasks
- `id` (UUID): Primary key
- `user_id` (UUID): Foreign key to users
- `title`, `notes`, `due_date`, `priority`
- `version` (Integer): For conflict resolution

### Memories (RAG)
- `id` (BigInt): Primary key
- `user_id` (UUID): Foreign key to users
- `content` (Text): Memory content
- `embedding` (Vector(768)): pgvector embedding
- `memory_type` (String): interaction, task, event, insight, preference, context

## 🔌 API Endpoints

### Phase 1 (Week 5-8)
- `GET /health` - Health check
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/apple` - Apple Sign In
- `POST /api/v1/sync/push` - Push changes from iOS
- `GET /api/v1/sync/pull` - Pull changes to iOS

### Phase 2 (Week 9-16)
- `POST /api/v1/ai/process` - Process AI request through agent system
- `GET /api/v1/ai/insights` - Get AI insights
- `POST /api/v1/ai/schedule` - Smart scheduling

### Phase 3 (Week 17+)
- `GET /api/v1/memory/search` - Semantic search in memories
- `POST /api/v1/collab/*` - Collaboration endpoints

## 🧪 Testing

```bash
# Run all tests
poetry run pytest

# Run with coverage
poetry run pytest --cov=app --cov-report=html

# Run specific test file
poetry run pytest tests/test_auth.py
```

## 📊 Monitoring

### Health Check
```bash
curl http://localhost:8000/health
```

### Database Inspection
```bash
# Connect to PostgreSQL
docker exec -it ai_calendar_postgres psql -U postgres -d ai_calendar

# View tables
\dt

# Check vector extension
\dx
```

### Redis Inspection
```bash
# Connect to Redis
docker exec -it ai_calendar_redis redis-cli

# Monitor keys
KEYS *
```

## 🔐 Authentication

Backend использует JWT токены для аутентификации:

1. iOS app логинится через `/api/v1/auth/login` или `/api/v1/auth/apple`
2. Получает JWT token
3. Включает token в header: `Authorization: Bearer <token>`
4. Backend валидирует token и извлекает user_id

## 📈 Roadmap

- [x] **Week 5-6**: Backend Foundation (Current)
  - [x] FastAPI setup
  - [x] PostgreSQL + pgvector
  - [x] Docker compose
  - [ ] JWT authentication
  - [ ] Basic sync endpoints

- [ ] **Week 7-8**: iOS Backend Integration
  - [ ] NetworkService в iOS
  - [ ] Sync service
  - [ ] Conflict resolution

- [ ] **Week 9-16**: Multi-Agent System
  - [ ] LangGraph orchestrator
  - [ ] Specialized agents
  - [ ] Agent communication

## 🛠️ Development

### Code Style
```bash
# Format code
poetry run black app/

# Lint
poetry run ruff check app/

# Type checking
poetry run mypy app/
```

### Database Migrations
```bash
# Create migration
poetry run alembic revision --autogenerate -m "description"

# Run migrations
poetry run alembic upgrade head
```

## 📝 Notes

- Vector memory from Week 1-2 (iOS) will sync to PostgreSQL pgvector
- Smart router from Week 3-4 will be replicated in backend for server-side AI
- Agent system (Phase 2) will be gradually enabled via feature flags
