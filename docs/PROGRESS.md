Project Progress (BRD Alignment)
================================

Current Phase: Phase 0-1 — Foundation with Smart Routing (Week 3-4)

Completed
- Chat UI: базовый чат-интерфейс (без сетевого LLM).
- LLM абстракция: `LLMProviderProtocol` + `AIIntentService` (валидация и предпросмотр действий).
- Он‑девайс MLC-LLM проводка:
  - `MLCLLMProvider` (скелет, фолбэк до интеграции рантайма).
  - `ModelManager` (локальные модели, активная модель, директории).
  - `AIProviderFactory` (переключение провайдера; дефолт: `.mlc`).
  - Инициализация модели при старте приложения.
- Навигация: свайпы между разделами + нижний тулбар.
- Remote LLM: OpenAI‑совместимый провайдер с автодетектом конфига; secure серверные compose (vLLM/llama.cpp), TLS‑прокси; тест‑скрипты.
- Streaming: SSE в `RemoteLLMProvider` с кооперативной отменой.
- JSON‑режимы: intent и task analysis (строгий JSON + ретраи), schedule optimization (JSON с ISO8601 и валидацией) с предпросмотром и применением.
- Voice input: базовая диктовка (Speech) с кнопкой микрофона в чате.
- Массовые операции: мультиселект задач (завершить/удалить).
- App Intents/Shortcuts: «Добавь задачу», «Что сегодня?».

**Phase 0-1 Foundation Progress**

**Week 1-2: Vector Memory System (COMPLETED ✅)**
- ✅ **VectorMemoryStore**: Локальное хранилище векторной памяти с SQLite
  - On-device semantic search без внешних зависимостей
  - Поддержка 6 типов воспоминаний (interaction, task, event, insight, preference, context)
  - Cosine similarity search с min threshold
  - Auto-pruning старых воспоминаний (90+ дней)
  - Memory statistics и export для backup

- ✅ **LocalEmbedder**: On-device генерация embeddings
  - Использует NLEmbedding от Apple (встроенный)
  - Fallback на hash-based подход
  - Batch embedding support
  - Semantic similarity вычисления
  - Готов для интеграции CoreML модели

- ✅ **MemoryService**: Управление долговременной памятью
  - Auto-save всех взаимодействий пользователь-AI
  - Запись создания/изменения/удаления задач и событий
  - AI insights сохранение
  - Context retrieval для обогащения промптов
  - Pattern analysis (заглушка для Week 11-12)

- ✅ **Интеграция с существующими компонентами**:
  - AIIntentService обогащает запросы контекстом из памяти (top 3 relevant memories)
  - TaskEditor/EventEditor автоматически сохраняют действия в память
  - Chat ответы включают релевантный контекст
  - Все CRUD операции записываются в vector memory

**Week 3-4: Smart Router with Validation (COMPLETED ✅)**
- ✅ **HybridNLPProcessor**: Гибридная NLP система с локальным парсингом + cloud fallback
  - LocalNLUModel с keyword-based парсингом (TODO: интеграция CoreML модели)
  - CloudNLUService с интеграцией через SmartLLMRouter
  - ContextAwareParser для контекстных запросов
  - SpellingCorrector с Levenshtein distance для исправления опечаток
  - Поддержка compound commands (множественные команды в одном запросе)

- ✅ **ComplexityClassifier**: Классификация сложности запросов для оптимального роутинга
  - Simple patterns → Gemini Flash ($0.075/$0.30)
  - Medium patterns → GPT-4o-mini ($0.15/$0.60)
  - Complex patterns → Claude Sonnet ($3/$15)
  - Детальная классификация с confidence scoring
  - Unit тесты (ComplexityClassifierTests.swift)

- ✅ **SmartLLMRouter**: Интеллектуальный роутер для оптимизации costs (60-70% экономия)
  - Автоматический выбор модели на основе complexity + user tier
  - LRU кэширование с TTL (1 час для simple, 30 мин для medium, 10 мин для complex)
  - Retry logic с exponential backoff
  - Fallback на более дешевые модели при проблемах
  - Analytics и metrics (RouterStats)

- ✅ **MultiProviderLLMClient**: Multi-provider клиент с smart routing
  - Поддержка Gemini Flash, GPT-4o-mini, Claude Sonnet
  - Конфигурация через UserDefaults/Plist/Info.plist
  - Интеграция с AIResponseValidator
  - LLMProviderProtocol adapter для совместимости

- ✅ **AIResponseValidator**: Валидация и улучшение качества AI ответов
  - FactualAccuracyValidator (проверка дат, времени, обязательных полей)
  - ActionabilityValidator (проверка выполнимости действий)
  - ConsistencyValidator (проверка дублирования задач, конфликтов по времени)
  - SafetyValidator (защита от XSS, SQL injection, некорректных операций)
  - Автоматическая регенерация с corrections
  - Разрешение конфликтов (time overlap, duplicates)

**Week 5-6: Backend Foundation (COMPLETED ✅)**
- ✅ **FastAPI Backend**: Полная структура проекта
  - Poetry setup с зависимостями (FastAPI, SQLAlchemy, LangGraph, AI SDKs)
  - Async PostgreSQL через asyncpg
  - Redis support (для будущего caching)
  - CORS middleware для iOS app

- ✅ **Database Models** (SQLAlchemy + pgvector):
  - User model (email, Apple ID, tier, preferences)
  - Task model (server-side copy для sync)
  - Memory model (pgvector для RAG)
  - Versioning для conflict resolution

- ✅ **JWT Authentication**:
  - Email/password registration и login
  - Apple Sign In support
  - HTTP Bearer токены
  - get_current_user dependency

- ✅ **Sync API**:
  - `/api/v1/sync/push` - загрузка изменений с iOS
  - `/api/v1/sync/pull` - скачивание изменений на iOS
  - `/api/v1/sync/status` - статус синхронизации
  - Conflict resolution через версионирование

- ✅ **Docker Infrastructure**:
  - Docker Compose с PostgreSQL (pgvector), Redis, Backend
  - Health checks для всех сервисов
  - Volume persistence
  - .env configuration

- ✅ **Documentation**:
  - Полный README.md для backend
  - API docs (FastAPI автогенерация)
  - .env.example с примерами

In Progress / Next
**Week 7-8: iOS Backend Integration (NEXT PRIORITY)**
- NetworkService для HTTP запросов
- AuthManager для JWT токенов
- SyncService для автоматической синхронизации
- Conflict resolution UI

**Other TODO Items**
- Подключение MLCSwift и `dist` (рантайм и либы) через `mlc_llm package`
- Интеграция CoreML модели для LocalEmbedder (улучшение качества embeddings)
- Настройка конфигурации для Gemini/OpenAI/Anthropic API keys
- Тестирование SmartRouter в реальных условиях
- Undo/Redo для применения расписания (базовый undo добавлен; расширить UX)
- Экран управления моделями (выбор/загрузка/удаление)
- Оптимизация: контекст‑окно, KV‑кэш, параметры генерации, cancel/low‑power

References
- Setup: `docs/MLC_SETUP.md`
- Config: `mlc-package-config.json`
- Production Plan: `docs/ai_calendar_production_plan_v4.md`
- Code:
  - LLM Providers: `sekretar/MLCLLMProvider.swift`, `sekretar/RemoteLLMProvider.swift`, `sekretar/MultiProviderLLMClient.swift`
  - Models: `sekretar/ModelManager.swift`, `sekretar/AIProviderFactory.swift`
  - AI Services: `sekretar/AIIntentService.swift`, `sekretar/AIResponseValidator.swift`
  - NLP: `sekretar/HybridNLPProcessor.swift`, `sekretar/NaturalLanguageDateParser.swift`
  - Routing: `sekretar/ComplexityClassifier.swift`, `sekretar/SmartLLMRouter.swift`
  - Memory: `sekretar/VectorMemoryStore.swift`, `sekretar/MemoryService.swift`, `sekretar/LocalEmbedder.swift`
  - UI: `sekretar/TaskEditorView.swift`, `sekretar/EventEditorView.swift`
  - Backend: `backend/app/main.py`, `backend/app/api/`, `backend/app/models/`, `backend/app/services/`
- Tests: `sekretarTests/ComplexityClassifierTests.swift`, `sekretarTests/NaturalLanguageDateParserTests.swift`
- Backend Setup: `backend/README.md`, `backend/docker-compose.yml`, `backend/pyproject.toml`
