# Testing Checklist - AI Calendar App

## 📋 Overview

Этот документ содержит полный чек-лист для тестирования всех реализованных компонентов (Week 1-6).

---

## ✅ Week 1-2: Vector Memory System

### VectorMemoryStore

**Файл:** `sekretar/VectorMemoryStore.swift`

- [ ] **1.1** Инициализация
  ```swift
  let store = VectorMemoryStore.shared
  // Проверить: БД создана в Documents/vector_memory.db
  ```

- [ ] **1.2** Добавление памяти
  ```swift
  try await store.addMemory(
      content: "Создана задача: Купить молоко",
      type: .task,
      metadata: ["task_id": "test-123", "priority": 1]
  )
  // Проверить: память сохранена, embedding сгенерирован
  ```

- [ ] **1.3** Semantic search
  ```swift
  let results = try await store.searchSimilar(
      query: "задачи про покупки",
      limit: 5,
      minSimilarity: 0.5
  )
  // Проверить: найдена память "Купить молоко" с similarity > 0.5
  ```

- [ ] **1.4** Statistics
  ```swift
  let stats = try store.getStats()
  print(stats.summary)
  // Проверить: totalMemories > 0, typeBreakdown корректен
  ```

- [ ] **1.5** Pruning
  ```swift
  try store.pruneOldMemories(olderThan: 90)
  // Проверить: старые записи удалены
  ```

### LocalEmbedder

**Файл:** `sekretar/LocalEmbedder.swift`

- [ ] **2.1** Генерация embedding
  ```swift
  let embedding = try await LocalEmbedder.shared.embed("Тестовая фраза")
  // Проверить: вектор размерности 768, не все нули
  ```

- [ ] **2.2** Semantic similarity
  ```swift
  let similarity = try await LocalEmbedder.shared.semanticSimilarity(
      "Купить молоко",
      "Купить хлеб"
  )
  // Проверить: similarity > 0.7 (высокая для похожих фраз)
  ```

- [ ] **2.3** Batch embedding
  ```swift
  let embeddings = try await LocalEmbedder.shared.embedBatch([
      "Первая фраза",
      "Вторая фраза",
      "Третья фраза"
  ])
  // Проверить: 3 вектора, каждый размерности 768
  ```

### MemoryService

**Файл:** `sekretar/MemoryService.swift`

- [ ] **3.1** Record interaction
  ```swift
  await MemoryService.shared.recordInteraction(
      userInput: "Создай задачу купить молоко",
      aiResponse: "Задача создана",
      intent: "createTask"
  )
  // Проверить: interaction записано в VectorMemoryStore
  ```

- [ ] **3.2** Record task action
  ```swift
  await MemoryService.shared.recordTaskAction(task, action: .created)
  // Проверить: task action записано с правильными metadata
  ```

- [ ] **3.3** Get relevant context
  ```swift
  let context = try await MemoryService.shared.getRelevantContext(
      for: "покупки",
      limit: 3
  )
  // Проверить: найдены релевантные воспоминания (similarity > 0.6)
  ```

- [ ] **3.4** Build context prompt
  ```swift
  let prompt = try await MemoryService.shared.buildContextPrompt(
      for: "что я планировал купить?",
      limit: 5
  )
  // Проверить: prompt содержит релевантные воспоминания
  ```

---

## ✅ Week 3-4: Smart Router + Validation

### ComplexityClassifier

**Файл:** `sekretar/ComplexityClassifier.swift`

- [ ] **4.1** Simple query classification
  ```swift
  let result = classifier.classify("создай задачу купить молоко")
  // Ожидаемо: .simple
  ```

- [ ] **4.2** Medium query classification
  ```swift
  let result = classifier.classify("перенеси встречу на завтра")
  // Ожидаемо: .medium
  ```

- [ ] **4.3** Complex query classification
  ```swift
  let result = classifier.classify("проанализируй мою продуктивность за месяц")
  // Ожидаемо: .complex
  ```

- [ ] **4.4** Detailed classification
  ```swift
  let detailed = classifier.classifyDetailed("оптимизируй расписание")
  // Проверить: complexity = .complex, confidence > 0.8, есть matchedPatterns
  ```

- [ ] **4.5** Run unit tests
  ```bash
  # В Xcode: Cmd+U или
  xcodebuild test -scheme sekretar -destination 'platform=iOS Simulator,name=iPhone 15'
  ```
  **Проверить:** Все 25+ тестов в `ComplexityClassifierTests.swift` проходят

### SmartLLMRouter

**Файл:** `sekretar/SmartLLMRouter.swift`

- [ ] **5.1** Route simple query
  ```swift
  let request = LLMRequest(input: "создай задачу", userTier: .free)
  let response = try await router.route(request)
  // Проверить: modelUsed = .geminiFlash, cached = false (first time)
  ```

- [ ] **5.2** Cache hit
  ```swift
  // Второй запрос с тем же input
  let response2 = try await router.route(request)
  // Проверить: cached = true, latency < 10ms
  ```

- [ ] **5.3** Router stats
  ```swift
  let stats = router.getStats()
  print("Total requests: \(stats.totalRequests)")
  print("Cache hit rate: \(stats.cacheHitRate)%")
  // Проверить: статистика корректна
  ```

- [ ] **5.4** Clear cache
  ```swift
  router.clearCache()
  let response3 = try await router.route(request)
  // Проверить: cached = false (кэш очищен)
  ```

### MultiProviderLLMClient

**Файл:** `sekretar/MultiProviderLLMClient.swift`

⚠️ **Требует API keys в RemoteLLM.plist**

- [ ] **6.1** Generate with routing
  ```swift
  let response = try await MultiProviderLLMClient.shared.generateWithRouting(
      "What is the weather today?",
      userTier: .free
  )
  // Проверить: получен ответ, модель выбрана автоматически
  ```

- [ ] **6.2** Get router stats
  ```swift
  let stats = MultiProviderLLMClient.shared.getRouterStats()
  // Проверить: requests count увеличился
  ```

### AIResponseValidator

**Файл:** `sekretar/AIResponseValidator.swift`

- [ ] **7.1** Validate correct response
  ```swift
  let response = AIResponse(
      action: "createTask",
      extractedData: ["title": "Test", "dueDate": Date().addingTimeInterval(86400)],
      confidence: 0.9,
      metadata: [:]
  )
  let validated = try await validator.validateAndImprove(
      response: response,
      context: ValidationContext(history: [], userPreferences: [:], currentContext: [:])
  )
  // Проверить: isValidated = true, warnings пустые
  ```

- [ ] **7.2** Validate date in past
  ```swift
  let response = AIResponse(
      action: "createTask",
      extractedData: ["title": "Test", "dueDate": Date().addingTimeInterval(-86400)],
      confidence: 0.9,
      metadata: [:]
  )
  // Проверить: validation fails или dueDate исправлена
  ```

- [ ] **7.3** Safety check
  ```swift
  let response = AIResponse(
      action: "createTask",
      extractedData: ["title": "<script>alert('xss')</script>"],
      confidence: 0.9,
      metadata: [:]
  )
  // Проверить: ValidationError.safetyViolation thrown
  ```

---

## ✅ Week 5-6: Backend Foundation

### Backend Setup

**Файлы:** `backend/`

- [ ] **8.1** Start backend
  ```bash
  cd backend
  cp .env.example .env
  # Добавить свои API keys в .env
  docker-compose up -d
  ```
  **Проверить:** 3 контейнера запущены (postgres, redis, backend)

- [ ] **8.2** Health check
  ```bash
  curl http://localhost:8000/health
  ```
  **Ожидаемый ответ:**
  ```json
  {
    "status": "healthy",
    "version": "1.0.0",
    "features": {
      "agent_system": false,
      "vector_memory": true,
      "smart_routing": true
    }
  }
  ```

- [ ] **8.3** API docs
  ```bash
  open http://localhost:8000/api/docs
  ```
  **Проверить:** Swagger UI открывается, видны endpoints для Auth и Sync

### Authentication API

- [ ] **9.1** Register user
  ```bash
  curl -X POST "http://localhost:8000/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d '{
      "email": "test@example.com",
      "password": "testpass123"
    }'
  ```
  **Ожидаемый ответ:**
  ```json
  {
    "access_token": "eyJ...",
    "token_type": "bearer",
    "user_id": "uuid-here",
    "email": "test@example.com",
    "tier": "free"
  }
  ```
  **Сохранить:** `access_token` для следующих тестов

- [ ] **9.2** Login user
  ```bash
  curl -X POST "http://localhost:8000/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{
      "email": "test@example.com",
      "password": "testpass123"
    }'
  ```
  **Проверить:** Получен тот же user_id

- [ ] **9.3** Apple Sign In (mock)
  ```bash
  curl -X POST "http://localhost:8000/api/v1/auth/apple" \
    -H "Content-Type: application/json" \
    -d '{
      "apple_id": "001234.abc.apple.com",
      "email": "apple@example.com",
      "full_name": "Test User"
    }'
  ```
  **Проверить:** Новый пользователь создан или существующий залогинен

### Sync API

Установить TOKEN из шага 9.1:
```bash
export TOKEN="your-token-here"
```

- [ ] **10.1** Push task
  ```bash
  curl -X POST "http://localhost:8000/api/v1/sync/push" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "tasks": [{
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "title": "Test task",
        "notes": "Test notes",
        "due_date": null,
        "priority": "medium",
        "completed_at": null,
        "is_deleted": false,
        "version": 1
      }]
    }'
  ```
  **Ожидаемый ответ:**
  ```json
  {
    "success": true,
    "conflicts": [],
    "server_time": "2024-01-..."
  }
  ```

- [ ] **10.2** Pull tasks
  ```bash
  curl -X GET "http://localhost:8000/api/v1/sync/pull" \
    -H "Authorization: Bearer $TOKEN"
  ```
  **Проверить:** Задача из 10.1 присутствует в ответе

- [ ] **10.3** Sync status
  ```bash
  curl -X GET "http://localhost:8000/api/v1/sync/status" \
    -H "Authorization: Bearer $TOKEN"
  ```
  **Ожидаемый ответ:**
  ```json
  {
    "user_id": "uuid",
    "total_tasks": 1,
    "last_modified_at": "2024-01-...",
    "server_time": "2024-01-..."
  }
  ```

- [ ] **10.4** Conflict resolution
  ```bash
  # Push task с старой версией
  curl -X POST "http://localhost:8000/api/v1/sync/push" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "tasks": [{
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "title": "Updated on client",
        "version": 1
      }]
    }'
  ```
  **Проверить:** `conflicts` содержит UUID задачи (server version = 2)

### Database Checks

- [ ] **11.1** PostgreSQL connection
  ```bash
  docker exec -it ai_calendar_postgres psql -U postgres -d ai_calendar
  ```
  ```sql
  -- Check tables
  \dt

  -- Check users
  SELECT id, email, tier FROM users;

  -- Check tasks
  SELECT id, title, version FROM tasks;

  -- Check pgvector extension
  \dx

  -- Exit
  \q
  ```

- [ ] **11.2** Redis connection
  ```bash
  docker exec -it ai_calendar_redis redis-cli
  ```
  ```redis
  PING
  # Expected: PONG

  KEYS *
  # Check if any keys exist

  exit
  ```

---

## 🔄 Integration Tests

### End-to-End Flow

- [ ] **12.1** iOS → Backend Flow (Manual)
  1. Открыть iOS app
  2. Создать задачу через TaskEditor
  3. Проверить в консоли: "💾 [VectorMemory] Added task: ..."
  4. Проверить в консоли: запись в MemoryService
  5. (Когда будет NetworkService) Проверить sync на backend

- [ ] **12.2** AI Chat with Memory (Manual)
  1. Открыть chat в iOS app
  2. Написать: "Создай задачу купить молоко"
  3. Создать задачу
  4. Написать: "Что я планировал купить?"
  5. **Проверить:** AI вспоминает про молоко из context

- [ ] **12.3** Smart Router Cost Optimization (Manual)
  1. В RemoteLLM.plist настроить multi provider
  2. Отправить simple query: "создай задачу"
  3. **Проверить:** использована Gemini Flash (дешевая)
  4. Отправить complex query: "проанализируй продуктивность"
  5. **Проверить:** использована Claude Sonnet (дорогая)

---

## 📊 Performance Tests

- [ ] **13.1** VectorMemoryStore performance
  ```swift
  // Добавить 1000 записей
  for i in 0..<1000 {
      try await store.addMemory(content: "Memory \(i)", type: .interaction)
  }

  // Измерить search time
  let start = Date()
  let results = try await store.searchSimilar(query: "test", limit: 10)
  let elapsed = Date().timeIntervalSince(start)
  print("Search time: \(elapsed * 1000)ms")
  // Целевое значение: < 500ms для 1000 записей
  ```

- [ ] **13.2** Router cache hit rate
  ```swift
  // Отправить 100 запросов, половина - дубликаты
  for i in 0..<100 {
      let query = i % 2 == 0 ? "создай задачу A" : "создай задачу B"
      _ = try await router.route(LLMRequest(input: query, userTier: .free))
  }

  let stats = router.getStats()
  print("Cache hit rate: \(stats.cacheHitRate)%")
  // Целевое значение: > 30%
  ```

- [ ] **13.3** Backend response time
  ```bash
  # Measure auth endpoint
  time curl -X POST "http://localhost:8000/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email": "test@example.com", "password": "testpass123"}'
  # Целевое значение: < 500ms

  # Measure sync endpoint
  time curl -X GET "http://localhost:8000/api/v1/sync/pull" \
    -H "Authorization: Bearer $TOKEN"
  # Целевое значение: < 1000ms
  ```

---

## 🐛 Error Handling Tests

- [ ] **14.1** Invalid JWT token
  ```bash
  curl -X GET "http://localhost:8000/api/v1/sync/pull" \
    -H "Authorization: Bearer invalid-token"
  ```
  **Ожидаемо:** 401 Unauthorized

- [ ] **14.2** Duplicate email registration
  ```bash
  # Register same email twice
  curl -X POST "http://localhost:8000/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d '{"email": "test@example.com", "password": "pass"}'
  ```
  **Ожидаемо:** 400 Bad Request "Email already registered"

- [ ] **14.3** TaskEditor save error handling
  1. В iOS TaskEditor ввести невалидные данные
  2. Нажать Save
  3. **Проверить:** context.rollback() вызван, пользователь видит ошибку

---

## 📝 Summary Report Template

После прохождения всех тестов заполнить:

```markdown
## Testing Report

**Date:** YYYY-MM-DD
**Tester:** Your Name

### Results Summary
- Total tests: X
- Passed: X
- Failed: X
- Skipped: X

### Critical Issues
1. [Issue description]
2. [Issue description]

### Performance Metrics
- Vector search (1000 records): XXms
- Cache hit rate: XX%
- Backend auth response: XXms
- Backend sync response: XXms

### Recommendations
1. [Recommendation]
2. [Recommendation]

### Next Steps
- [ ] Fix critical issues
- [ ] Optimize performance bottlenecks
- [ ] Implement Week 7-8 (iOS Backend Integration)
```

---

## 🚀 Quick Start Testing

**Для быстрой проверки основных функций:**

1. **Backend:**
   ```bash
   cd backend && docker-compose up -d
   curl http://localhost:8000/health
   ```

2. **iOS Unit Tests:**
   ```bash
   # В Xcode
   Cmd+U
   ```

3. **Manual iOS Test:**
   - Создать задачу → проверить в консоли vector memory
   - Открыть chat → проверить context enrichment

4. **Backend API Test:**
   ```bash
   ./backend/test_api.sh  # (создать скрипт из примеров выше)
   ```

---

**Удачи в тестировании! 🎯**
