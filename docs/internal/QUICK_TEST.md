# Quick Testing Guide - 5 Minutes

Быстрая проверка всех основных компонентов за 5 минут.

---

## 🚀 Step 1: Backend (1 min)

```bash
cd backend

# Copy environment
cp .env.example .env

# Start services
docker-compose up -d

# Wait for services to be ready (15 seconds)
sleep 15

# Test health
curl http://localhost:8000/health

# Expected output:
# {"status":"healthy","version":"1.0.0",...}
```

✅ **Pass if:** JSON response с "status": "healthy"

---

## 🧪 Step 2: Backend API Tests (2 min)

```bash
# Run automated tests
./test_api.sh
```

✅ **Pass if:** Success Rate > 80%

**Expected output:**
```
================================
Test Summary
================================
Total Tests:  12
Passed:       12
Failed:       0

Success Rate: 100%

🎉 All tests passed!
```

---

## 📱 Step 3: iOS Unit Tests (1 min)

В Xcode:
1. Открыть проект `sekretar.xcodeproj`
2. Нажать `Cmd+U` (Run Tests)
3. Подождать ~30 секунд

✅ **Pass if:** Все тесты в `ComplexityClassifierTests` проходят (25+)

**Или из терминала:**
```bash
cd ..  # Back to project root
xcodebuild test -scheme sekretar -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | grep "Test Suite"
```

---

## 🔍 Step 4: Manual iOS Test (1 min)

1. Запустить iOS app в симуляторе
2. Создать задачу через TaskEditor: "Купить молоко"
3. Смотреть в Console в Xcode

✅ **Pass if:** В консоли видно:
```
📦 [LocalEmbedder] Initialized
💾 [VectorMemory] Added task: Купить молоко...
🧠 [MemoryService] ...
```

---

## 📊 Quick Results

| Component | Status | Time |
|-----------|--------|------|
| Backend Health | ⬜ | 15s |
| Backend API Tests | ⬜ | 2min |
| iOS Unit Tests | ⬜ | 30s |
| iOS Manual Test | ⬜ | 1min |

**Total Time:** ~4-5 minutes

---

## 🐛 Common Issues & Fixes

### Backend не стартует
```bash
# Check logs
docker-compose logs backend

# Common fix: rebuild
docker-compose down
docker-compose up --build -d
```

### test_api.sh fails with connection error
```bash
# Check backend is running
docker ps | grep ai_calendar

# Check ports
lsof -i :8000
lsof -i :5432

# Restart if needed
docker-compose restart
```

### iOS tests fail to compile
```bash
# Clean build
cd sekretar
xcodebuild clean -scheme sekretar
xcodebuild build -scheme sekretar
```

### "Module not found" errors
```bash
# Missing dependencies - check if SQLite.swift is added
# Open project in Xcode -> Package Dependencies
```

---

## ✅ Success Criteria

**READY TO PROCEED** if:
- ✅ Backend health returns 200 OK
- ✅ Backend API tests: Success Rate ≥ 80%
- ✅ iOS unit tests: All passed
- ✅ iOS manual test: Vector memory logs visible

**NEEDS ATTENTION** if:
- ⚠️ Backend API tests: Success Rate < 80%
- ⚠️ iOS unit tests: Any failures
- ⚠️ No vector memory logs in iOS console

---

## 📝 Report Results

Fill in [TEST_REPORT_TEMPLATE.md](TEST_REPORT_TEMPLATE.md) with detailed results.

For full testing checklist see [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md).
