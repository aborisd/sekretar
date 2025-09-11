Project Progress (BRD Alignment)
================================

Current Phase: M2 — AI‑интеграция и расширенные функции

Completed
- Chat UI: базовый чат-интерфейс (без сетевого LLM).
- LLM абстракция: `LLMProviderProtocol` + `AIIntentService` (валидация и предпросмотр действий).
- Он‑девайс MLC-LLM проводка:
  - `MLCLLMProvider` (скелет, фолбэк до интеграции рантайма).
  - `ModelManager` (локальные модели, активная модель, директории).
  - `AIProviderFactory` (переключение провайдера; дефолт: `.mlc`).
  - Инициализация модели при старте приложения.
- Навигация: свайпы между разделами + нижний тулбар.

In Progress / Next
- Подключение MLCSwift и `dist` (рантайм и либы) через `mlc_llm package`.
- Реализация стриминговой генерации в `MLCLLMProvider` (вместо фолбэка).
- JSON‑режимы (интенты/аналитика/расписание) с ретраями парсинга.
- Экран управления моделями (выбор/загрузка/удаление).
- Оптимизация: контекст‑окно, KV‑кэш, параметры генерации, cancel/low‑power.

References
- Setup: `docs/MLC_SETUP.md`
- Config: `mlc-package-config.json`
- Code: `calendAI/MLCLLMProvider.swift`, `calendAI/ModelManager.swift`, `calendAI/AIProviderFactory.swift`, `calendAI/AIIntentService.swift`

