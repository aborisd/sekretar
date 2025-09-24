Project Progress (BRD Alignment)
================================

Current Phase: M2 — AI‑интеграция и расширенные функции (Complete)

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

In Progress / Next
 - Подключение MLCSwift и `dist` (рантайм и либы) через `mlc_llm package`.
 - Undo/Redo для применения расписания (базовый undo добавлен; расширить UX).
 - Экран управления моделями (выбор/загрузка/удаление).
 - Оптимизация: контекст‑окно, KV‑кэш, параметры генерации, cancel/low‑power.

References
- Setup: `docs/MLC_SETUP.md`
- Config: `mlc-package-config.json`
- Code: `sekretar/MLCLLMProvider.swift`, `sekretar/ModelManager.swift`, `sekretar/AIProviderFactory.swift`, `sekretar/AIIntentService.swift`
