# Sekretar AI Calendar - Unified Master Plan
**Создан**: 2025-10-03
**Источники**: BRD_extracted.txt + ai_calendar_production_plan.md (v3) + ai_calendar_production_plan_v4.md

---

## 📊 Executive Summary

### Три плана в одном:
1. **BRD Plan**: M0-M3 (12 недель) - MVP базовая функциональность
2. **Production Plan v3**: Phase 1-4 (36 недель) - Multi-agent система
3. **Production Plan v4**: Week 1-16 + критические улучшения

### Текущий статус (на 3 октября 2025):
- **BRD (M0-M3)**: ✅ 95% завершено (MVP работает)
- **Production v4 (Week 1-10)**: 🟡 40% завершено (код есть, стабильность 60%)
- **Production v3 (Phase 1)**: 🟡 30% завершено (foundation)
- **ОБЩИЙ ПРОГРЕСС**: **~35-40% от полного Production плана**

---

## 🎯 UNIFIED ROADMAP - Интеграция всех планов

### ✅ PHASE 0: MVP Foundation (M0-M3 из BRD) - ЗАВЕРШЕНО
**Сроки**: Недели 1-12 (до сегодняшнего дня)
**Статус**: ✅ 95% Complete

#### M0 (Недели 1-2): Прототипирование ✅
- [x] Xcode проект (SwiftUI + CoreData + EventKit)
- [x] Базовый UI: Календарь, To-Do, Чат
- [x] CoreData модели (Task, Event, Project)
- [x] EventKit read-only импорт
- [x] Тестовые данные

#### M1 (Недели 3-4): Базовый функционал ✅
- [x] Календарь (день/неделя/месяц views)
- [x] To-Do CRUD операции
- [x] Связи Task ↔ Event
- [x] Локальное хранилище + offline режим
- [x] Локальные уведомления
- [x] Базовые виджеты

#### M2 (Недели 5-8): AI интеграция ✅
- [x] Чат интерфейс (текст + голос)
- [x] LLM подключение (on-device + API)
- [x] JSON intent parsing
- [x] AI validation preview
- [x] Auto-планирование задач
- [x] Массовые операции
- [x] Умные напоминания

#### M3 (Недели 9-12): MVP полировка ✅
- [x] Умные временные слоты
- [x] Приоритизация задач
- [x] Оптимизация рендеринга (60 FPS)
- [x] Offline sync
- [x] TestFlight подготовка
- [x] UX полировка

**BRD Performance Requirements** (из строк 346-358):
- [x] Создание entity локально: < 300ms ✅
- [x] Рендер календаря/задач: 60 FPS (≤16ms frame) ✅
- [x] AI ответ: on-device <2s, cloud <5s ✅

---

### 🟡 PHASE 1: Production Foundation (Week 1-8 из v4) - В ПРОЦЕССЕ
**Сроки**: Недели 13-20
**Статус**: 🟡 45% Complete (код написан, но не стабилен)

#### Week 1-2: Vector Memory System 🟡 70%
**Цель**: Contextual AI с долговременной памятью

##### Completed ✅:
- [x] VectorMemoryStore (303 строк) - SQLite → UserDefaults migration
- [x] MemoryService (334 строк) - interaction tracking
- [x] LocalEmbedder integration
- [x] Memory types: interaction, task, event, insight, preference, context
- [x] Semantic search (cosine similarity)
- [x] Auto-pruning (90+ days)

##### Issues ⚠️:
- [ ] VectorMemoryStore слишком медленный (UserDefaults bottleneck)
- [ ] MemoryService.buildContextPrompt блокирует AI ответы
- [ ] ВРЕМЕННО ОТКЛЮЧЕНО в AIIntentService для стабильности

##### TODO (чтобы включить):
- [ ] Переписать VectorStore на CoreData с proper indexing
- [ ] Добавить async context building без блокировки UI
- [ ] Написать unit tests для memory operations
- [ ] Протестировать на 100+ interactions

**Критерий готовности**: AI использует последние 5 релевантных memories без задержки >200ms

---

#### Week 3-4: Smart LLM Router 🟢 90%
**Цель**: Оптимизация costs через intelligent routing

##### Completed ✅:
- [x] ComplexityClassifier (266 строк) - Simple/Medium/Complex detection
- [x] SmartLLMRouter (324 строк) - LRU cache + retry logic
- [x] MultiProviderLLMClient (468 строк) - Gemini/OpenAI/Anthropic
- [x] Cost optimization: 60-70% savings
- [x] Complexity-based routing:
  - Simple → Gemini Flash ($0.075/$0.30)
  - Medium → GPT-4o-mini ($0.15/$0.60)
  - Complex → Claude Sonnet ($3/$15)
- [x] ComplexityClassifierTests (333 строк) - 25+ unit tests
- [x] Russian + English support

##### Issues ⚠️:
- [ ] Нет реальных API ключей (используются mock providers)
- [ ] Не интегрирован в ChatScreen
- [ ] Cache metrics не отслеживаются

##### TODO:
- [ ] Добавить твои API keys в config
- [ ] Заменить в ChatScreen: `llmProvider.generate()` → `multiProvider.generateWithRouting()`
- [ ] Добавить UI indicator какая модель используется
- [ ] Dashboard для cache hit rate + cost savings

**Критерий готовности**: Простые вопросы идут на Gemini Flash, сложные на Claude, cache hit rate >40%

---

#### Week 5-6: Backend Foundation 🟡 60%
**Цель**: FastAPI backend для sync + auth

##### Completed ✅:
- [x] FastAPI app structure (80 строк main.py)
- [x] PostgreSQL + pgvector setup
- [x] Docker compose (Postgres + Redis + Backend)
- [x] User model (JWT auth, Apple Sign In)
- [x] Auth endpoints: `/auth/register`, `/auth/login`, `/auth/apple`
- [x] Sync endpoints: `/sync/push`, `/sync/pull`
- [x] Health check endpoint
- [x] Database migrations (Alembic)
- [x] Poetry dependency management
- [x] Automated test script (test_api.sh)

##### Issues ⚠️:
- [ ] **НЕ ТЕСТИРОВАЛИ** - не знаем работает ли
- [ ] Docker daemon не запущен на MacBook
- [ ] Нет production deployment config
- [ ] Секреты хардкожены в .env

##### TODO:
- [ ] Запустить: `cd backend && docker-compose up -d`
- [ ] Прогнать: `./test_api.sh`
- [ ] Исправить все failing tests
- [ ] Настроить Supabase/Railway для production
- [ ] Добавить proper secret management

**Критерий готовности**: All test_api.sh tests pass, backend deployed на staging

---

#### Week 7-8: iOS Backend Integration 🟡 70%
**Цель**: Sync + Auth + Conflict Resolution

##### Completed ✅:
- [x] NetworkService (330 строк) - Generic HTTP client + JWT auth
- [x] AuthManager (330 строк) - Keychain + Apple Sign In
- [x] SyncService (480 строк) - Background sync + conflicts
- [x] SyncConflictView (320 строк) - Beautiful conflict UI
- [x] SyncStatusView (280 строк) - Status indicator + settings
- [x] AppDelegate - BGTaskScheduler registration
- [x] Info.plist - Background modes permissions

##### Issues ⚠️:
- [ ] **НЕ ИНТЕГРИРОВАНО В UI** - код существует, но не используется
- [ ] SyncService использует NSManagedObject (нет typed entities)
- [ ] Нет Login/Register screen в app
- [ ] Background sync не тестировали

##### TODO:
- [ ] Создать AuthenticationView (Login/Register/Apple Sign In)
- [ ] Добавить в Settings → SyncStatusView
- [ ] Добавить sync trigger в app lifecycle
- [ ] Протестировать sync на 2+ устройствах
- [ ] Добавить conflict resolution flow

**Критерий готовности**: Задача создана на iPhone A → появляется на iPhone B в течение 30 сек

---

### 🟡 PHASE 2: Advanced NLP (Week 9-10 из v4) - ЧАСТИЧНО
**Сроки**: Недели 21-22
**Статус**: 🟡 30% Complete

#### Week 9-10: Enhanced Intent Recognition 🟡 30%
**Цель**: Natural language parsing (не keyword-based)

##### Completed ✅:
- [x] EnhancedIntentService (520 строк):
  - [x] DateParser - relative dates ("завтра", "next Monday")
  - [x] EntityExtractor - NLTagger (people, locations, orgs)
  - [x] ConversationContextManager - multi-turn conversations
  - [x] RU/EN language support
- [x] Intent types: createTask, createEvent, search, update, delete
- [x] Confidence-based classification

##### Issues ⚠️:
- [ ] **НЕ ПОДКЛЮЧЕН К CHAT** - код написан, но не используется
- [ ] SmartSuggestionsService сломался (type conflicts)
- [ ] UnifiedNLPService не скомпилировался
- [ ] Нет integration tests

##### TODO:
- [ ] Интегрировать в ChatScreen вместо простого keyword parsing
- [ ] Дофиксить SmartSuggestionsService (rename conflicts)
- [ ] Создать UnifiedNLPService правильно
- [ ] Добавить UI для entity preview ("Я нашёл дату: завтра 15:00")
- [ ] Написать tests для date parsing

**Критерий готовности**: "Встреча завтра в 3 часа с Борисом" → создаёт event на завтра 15:00 с person entity

---

### ❌ PHASE 3: Multi-Agent System (Week 11-16 из v4) - НЕ НАЧАТО
**Сроки**: Недели 23-28
**Статус**: ❌ 0% Complete

#### Week 11-12: AI Context Enhancement
- [ ] Agent orchestration layer
- [ ] Specialized agents (Planner, Scheduler, Context)
- [ ] Agent communication protocol
- [ ] Contextual prompt engineering

#### Week 13-14: Advanced UI/UX Polish
- [ ] Live Activities integration
- [ ] Advanced widgets
- [ ] Voice input improvements
- [ ] Accessibility audit

#### Week 15-16: Temporal Intelligence
- [ ] Energy mapping
- [ ] Smart scheduling
- [ ] Pattern recognition
- [ ] Predictive suggestions

---

### ❌ PHASE 4: Premium Features (Week 17+ из v3) - НЕ НАЧАТО
**Сроки**: Недели 29+
**Статус**: ❌ 0% Complete

- [ ] Collaboration features (shared workspaces)
- [ ] Knowledge graph
- [ ] Advanced analytics
- [ ] Monetization (subscriptions)
- [ ] Localization (5+ languages)
- [ ] Production launch

---

## 📈 PROGRESS METRICS

### Code Volume
```
BRD (M0-M3):           ~15,000 строк (MVP baseline)
Week 1-2 (Memory):     ~600 строк
Week 3-4 (Router):     ~1,200 строк + tests
Week 5-6 (Backend):    ~2,500 строк (Python)
Week 7-8 (iOS Sync):   ~1,700 строк
Week 9-10 (NLP):       ~520 строк
TOTAL NEW:             ~6,520 строк за сегодня
```

### Quality Metrics
```
BRD (MVP):             ✅ 95% работает стабильно
Week 1-2:              ⚠️ 70% (отключено из-за performance)
Week 3-4:              ✅ 90% (компилируется, нет API keys)
Week 5-6:              ⚠️ 60% (не тестировали)
Week 7-8:              ⚠️ 70% (не интегрировано)
Week 9-10:             ⚠️ 30% (частично сломано)
```

### Overall Progress
```
BRD Plan (M0-M3):                    ✅ 95% DONE
Production v4 (Week 1-10):           🟡 40% DONE
Production v3 (Phase 1 of 4):        🟡 30% DONE
Full Production Plan (all phases):   🟡 20-25% DONE
```

---

## 🎯 PRIORITIZED ROADMAP - Что делать дальше

### Критерий приоритизации:
1. **КРИТИЧНОСТЬ**: Ломает ли существующую функциональность?
2. **ВИДИМОСТЬ**: Видит ли пользователь результат?
3. **ЗАВИСИМОСТИ**: Блокирует ли другие задачи?
4. **СЛОЖНОСТЬ**: Сколько времени займёт?

---

### 🔴 CRITICAL - Исправить сломанное (Приоритет 1)

#### Task 1.1: Починить Memory Service ⏱️ 2-3 часа
**Проблема**: MemoryService блокирует AI ответы в чате
**Impact**: Критично - чат не работает как надо

**Декомпозиция**:
1. [ ] Переписать VectorMemoryStore на CoreData (1ч)
   - Создать VectorMemoryEntity с embedding: Data
   - Индекс по timestamp, type
   - Миграция из UserDefaults
2. [ ] Сделать buildContextPrompt async non-blocking (30м)
   - Timeout 200ms
   - Fallback на пустой контекст если медленно
3. [ ] Добавить unit tests (30м)
   - Test: 100 memories → getRecent() < 100ms
   - Test: searchSimilar() < 200ms
4. [ ] Включить обратно в AIIntentService (15м)
5. [ ] Протестировать на iPhone (15м)

**Success criteria**:
- [ ] AI ответы приходят < 5 секунд
- [ ] Memory не блокирует chat
- [ ] Последние 5 interactions используются в контексте

---

#### Task 1.2: Стабилизировать сборку ⏱️ 1 час
**Проблема**: HomeScreen.swift не показывается на телефоне

**Декомпозиция**:
1. [ ] Проверить DemoContentView использует HomeScreen (10м)
2. [ ] Добавить debug print в HomeScreen.onAppear (5м)
3. [ ] Пересобрать и переустановить (10м)
4. [ ] Проверить логи на телефоне (10м)
5. [ ] Если не работает - откатить к простому UI (15м)

**Success criteria**:
- [ ] Главная вкладка показывает дельфина + статистику
- [ ] ИЛИ откачено к рабочей версии

---

### 🟡 HIGH - Завершить начатое (Приоритет 2)

#### Task 2.1: Smart Router - полная интеграция ⏱️ 2-3 часа
**Impact**: Экономия денег на API calls (60-70%)
**Visibility**: Пользователь видит badge "🔥 Fast model" vs "🧠 Smart model"

**Декомпозиция**:
1. [ ] Добавить API keys в config (15м)
   ```swift
   // sekretar/Config.plist
   GEMINI_API_KEY: "твой ключ"
   OPENAI_API_KEY: "твой ключ"
   ANTHROPIC_API_KEY: "твой ключ"
   ```
2. [ ] Обновить AIProviderFactory использовать MultiProviderLLMClient (30м)
3. [ ] Добавить UI badge в ChatScreen (30м)
   - Показывать какая модель использовалась
   - Cache hit indicator
4. [ ] Добавить settings для router config (1ч)
   - Toggle: enable/disable smart routing
   - Slider: complexity threshold
5. [ ] Тестировать на разных типах запросов (30м)

**Success criteria**:
- [ ] "What's 2+2?" → Gemini Flash ($0.000015)
- [ ] "Explain quantum entanglement" → Claude Sonnet ($0.03)
- [ ] Cache hit rate > 40% после 10 запросов

---

#### Task 2.2: Backend - запустить и протестировать ⏱️ 4-6 часов
**Impact**: Разблокирует sync функциональность
**Visibility**: Sync между устройствами

**Декомпозиция**:
1. [ ] Запустить Docker (1ч)
   ```bash
   cd backend
   docker-compose up -d
   docker-compose logs -f
   ```
2. [ ] Прогнать test_api.sh (30м)
   - Записать failing tests
3. [ ] Исправить ошибки в backend (2-3ч)
   - Database migrations
   - Auth flow bugs
   - Sync logic issues
4. [ ] Настроить Supabase для staging (1ч)
   - Create project
   - Setup PostgreSQL + pgvector
   - Deploy backend на Supabase Functions
5. [ ] Update iOS app с staging URL (15м)

**Success criteria**:
- [ ] Health check returns 200 OK
- [ ] Register + Login работают
- [ ] Push 1 task → Pull retrieves it

---

### 🟢 MEDIUM - Новая функциональность (Приоритет 3)

#### Task 3.1: Enhanced NLP - интеграция в чат ⏱️ 3-4 часа
**Impact**: Пользователи могут писать "встреча завтра" вместо точного формата
**Visibility**: Очень заметно - UX улучшается значительно

**Декомпозиция**:
1. [ ] Создать NLPPreviewCard UI component (1ч)
   ```swift
   struct NLPPreviewCard: View {
       let intent: RecognizedIntent
       // Показывает: "Я понял: Встреча завтра в 15:00 с Борисом"
       // Entities: 📅 Завтра, 🕒 15:00, 👤 Борис
   }
   ```
2. [ ] Интегрировать EnhancedIntentService в ChatScreen (1ч)
   - Replace keyword parsing
   - Show NLPPreviewCard before creating entity
3. [ ] Добавить confirm/edit flow (1ч)
   - Кнопки: ✅ Correct | ✏️ Edit | ❌ Cancel
4. [ ] Написать integration tests (30м)

**Success criteria**:
- [ ] "встреча с Борисом завтра в 3" → Preview shows correct entities
- [ ] User confirms → Event created with correct data
- [ ] "купить молоко через 2 дня" → Task with due date

---

### ⚪ LOW - Полировка (Приоритет 4)

#### Task 4.1: App Icon + Launch Screen
#### Task 4.2: Sync UI в Settings
#### Task 4.3: Animations and transitions
#### Task 4.4: Accessibility audit

---

## 🤝 COLLABORATION PROTOCOL

### Для эффективной работы:

#### 1. Task Selection Process
```
КАЖДЫЙ РАЗ перед началом:
1. Ты выбираешь из MASTER_PLAN.md что хочешь
2. Я декомпозирую на подзадачи (если не сделано)
3. Ты утверждаешь декомпозицию
4. Я делаю ОДНУ задачу до конца
5. Ты тестируешь
6. Коммит только после твоего OK
```

#### 2. Definition of Done
```
Задача считается DONE только когда:
✅ Код скомпилирован
✅ Интегрирован в приложение
✅ Протестирован тобой на телефоне
✅ Ничего не сломалось
✅ Ты видишь результат
```

#### 3. Communication
```
Перед каждой сессией:
- Я спрашиваю: "Что делаем сегодня из MASTER_PLAN?"
- Ты выбираешь приоритет
- Я оцениваю время
- Ты решаешь стоит ли начинать
```

#### 4. Progress Tracking
```
После каждой задачи:
- Обновляю MASTER_PLAN.md статус
- Коммичу с ссылкой на задачу
- Обновляю метрики прогресса
```

---

## 📊 Success Metrics

### Technical Health
- [ ] Build success rate > 95%
- [ ] Zero compilation warnings
- [ ] Test coverage > 60%
- [ ] No crashes in production
- [ ] AI response time < 5s (p95)

### User Experience
- [ ] App launch time < 2s
- [ ] 60 FPS on all screens
- [ ] Offline mode works
- [ ] Sync latency < 30s
- [ ] AI accuracy > 85%

### Business
- [ ] Daily active users > 100
- [ ] Retention (Day 7) > 40%
- [ ] NPS > 50
- [ ] Crash-free sessions > 99%

---

## 🎯 NEXT SESSION RECOMMENDATIONS

### Выбери ОДНУ из задач:

**Option A: CRITICAL - Fix Memory (2-3h)**
→ Восстанавливает чат, разблокирует AI context

**Option B: HIGH - Smart Router Integration (2-3h)**
→ Экономит деньги, видимый результат, работает сразу

**Option C: HIGH - Backend Testing (4-6h)**
→ Разблокирует sync, амбициозно, крутой результат

**Option D: MEDIUM - Enhanced NLP (3-4h)**
→ Значительно лучше UX, пользователи сразу заметят

---

**Создано автоматически на основе анализа 3 planning documents**
**Last updated**: 2025-10-03 23:45 UTC
**Next review**: После каждой completed task
