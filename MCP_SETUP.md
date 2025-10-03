# MCP Servers Setup Guide

Этот гайд поможет подключить MCP серверы Sequential Thinking и Context7 к Claude Desktop.

---

## Что такое MCP?

Model Context Protocol (MCP) - это протокол для расширения возможностей Claude через внешние инструменты и сервисы.

---

## Рекомендуемые MCP серверы для проекта Sekretar

### 1. **Sequential Thinking MCP**
**Назначение**: Структурированное пошаговое мышление для сложных задач

**Возможности**:
- Разбивает сложные задачи на последовательные шаги
- Отслеживает прогресс выполнения
- Помогает не пропускать важные детали
- Идеально для имплементации сложных фич (например, Week 9-10)

**Установка**:
```bash
# Через npm (если доступен)
npm install -g @modelcontextprotocol/server-sequential-thinking

# Или через npx (без установки)
npx @modelcontextprotocol/server-sequential-thinking
```

---

### 2. **Context7 MCP** (alternative: Memory Server)
**Назначение**: Долгосрочная память и контекст между сессиями

**Возможности**:
- Сохраняет важные решения и контекст проекта
- Индексирует кодовую базу
- Помогает быстро находить релевантную информацию
- Идеально для крупных проектов с множеством файлов

**Альтернатива - Memory Server MCP**:
```bash
npm install -g @modelcontextprotocol/server-memory
```

---

## Конфигурация Claude Desktop

Чтобы подключить MCP серверы, нужно отредактировать конфигурационный файл Claude Desktop:

**Путь к конфигу**:
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`

---

## Пример конфигурации

Создай или отредактируй файл `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sequential-thinking"
      ],
      "env": {},
      "disabled": false
    },
    "memory": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-memory"
      ],
      "env": {
        "MEMORY_FILE_PATH": "/Users/borisalehin/sekretar/.claude_memory.json"
      },
      "disabled": false
    },
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/borisalehin/sekretar"
      ],
      "env": {},
      "disabled": false
    }
  }
}
```

---

## Детали конфигурации

### Sequential Thinking Server
```json
{
  "sequential-thinking": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
    "env": {},
    "disabled": false
  }
}
```

**Что делает**:
- Добавляет инструменты для пошагового планирования
- Помогает отслеживать выполнение сложных задач
- Создает структурированные планы действий

**Использование**:
```
User: Implement Week 9-10 features
Claude: (использует sequential thinking)
Step 1: Analyze requirements
Step 2: Design architecture
Step 3: Implement core features
...
```

---

### Memory Server
```json
{
  "memory": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"],
    "env": {
      "MEMORY_FILE_PATH": "/Users/borisalehin/sekretar/.claude_memory.json"
    },
    "disabled": false
  }
}
```

**Что делает**:
- Сохраняет важные факты о проекте
- Индексирует кодовую базу
- Помогает находить релевантные файлы
- Сохраняет контекст между сессиями

**Использование**:
```
User: Запомни что мы используем CoreData для хранения
Claude: (сохраняет в memory server)

... (новая сессия) ...

User: Какую БД мы используем?
Claude: (читает из memory server) CoreData
```

---

### Filesystem Server (Бонус)
```json
{
  "filesystem": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-filesystem",
      "/Users/borisalehin/sekretar"
    ],
    "env": {},
    "disabled": false
  }
}
```

**Что делает**:
- Быстрый доступ к файлам проекта
- Поиск по файловой системе
- Чтение/запись файлов без Bash команд

---

## Как применить конфигурацию

### Шаг 1: Установить Node.js (если не установлен)
```bash
# Проверить наличие Node.js
node --version

# Если нет - установить через Homebrew
brew install node
```

### Шаг 2: Создать конфигурационный файл
```bash
# Создать директорию если не существует
mkdir -p ~/Library/Application\ Support/Claude

# Создать/отредактировать конфиг
nano ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### Шаг 3: Вставить JSON конфигурацию
Скопируй JSON из примера выше и вставь в файл.

### Шаг 4: Перезапустить Claude Desktop
1. Полностью закрыть Claude Desktop (Cmd+Q)
2. Открыть заново
3. MCP серверы должны автоматически запуститься

---

## Проверка работы MCP серверов

После перезапуска Claude Desktop проверь:

### В новом чате:
```
User: /help
```

Ты должен увидеть новые MCP инструменты:
- `sequential-thinking` - планирование задач
- `memory` - сохранение/загрузка памяти
- `filesystem` - работа с файлами

### Тестирование Sequential Thinking:
```
User: Create a plan to implement user authentication
```

Claude должен использовать sequential thinking для создания структурированного плана.

### Тестирование Memory:
```
User: Remember: This project uses Swift and CoreData
Claude: (сохраняет в memory)

User: What technologies are we using?
Claude: (читает из memory) Swift and CoreData
```

---

## Альтернативные MCP серверы

Если Sequential Thinking или Context7 не доступны, можно попробовать:

### 1. **Thinking Server**
```json
{
  "thinking": {
    "command": "npx",
    "args": ["-y", "@anthropic/mcp-server-thinking"],
    "disabled": false
  }
}
```

### 2. **Git Server** (для работы с репозиторием)
```json
{
  "git": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-git",
      "--repository",
      "/Users/borisalehin/sekretar"
    ],
    "disabled": false
  }
}
```

### 3. **SQLite Server** (если понадобится БД интеграция)
```json
{
  "sqlite": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sqlite"],
    "disabled": false
  }
}
```

---

## Troubleshooting

### Проблема: MCP серверы не запускаются
**Решение**:
1. Проверь что Node.js установлен: `node --version`
2. Проверь путь к конфиг файлу
3. Проверь JSON синтаксис (используй JSONLint)
4. Проверь логи Claude Desktop:
   ```bash
   tail -f ~/Library/Logs/Claude/mcp*.log
   ```

### Проблема: Ошибка "command not found: npx"
**Решение**:
```bash
# Переустановить Node.js
brew reinstall node

# Проверить PATH
echo $PATH | grep node
```

### Проблема: MCP сервер запущен но не работает
**Решение**:
1. Установить пакет глобально:
   ```bash
   npm install -g @modelcontextprotocol/server-memory
   ```
2. Изменить команду в конфиге:
   ```json
   {
     "command": "mcp-server-memory",
     "args": []
   }
   ```

---

## Рекомендации для проекта Sekretar

### Обязательно установить:
1. ✅ **Sequential Thinking** - для сложных имплементаций (Week 9-10+)
2. ✅ **Memory Server** - для сохранения контекста проекта
3. ✅ **Filesystem Server** - для быстрого доступа к файлам

### Опционально:
4. **Git Server** - если нужна продвинутая работа с git
5. **SQLite Server** - если планируешь работу с БД напрямую

---

## Полная конфигурация для Sekretar

Вот готовая конфигурация которую можно сразу использовать:

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "env": {},
      "disabled": false
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "env": {
        "MEMORY_FILE_PATH": "/Users/borisalehin/sekretar/.claude_memory.json"
      },
      "disabled": false
    },
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/borisalehin/sekretar"
      ],
      "env": {},
      "disabled": false
    },
    "git": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-git",
        "--repository",
        "/Users/borisalehin/sekretar"
      ],
      "env": {},
      "disabled": false
    }
  },
  "globalShortcut": "CommandOrControl+Shift+Space"
}
```

Сохрани это в:
`~/Library/Application Support/Claude/claude_desktop_config.json`

---

## Следующие шаги

1. ✅ Создать конфигурационный файл
2. ✅ Перезапустить Claude Desktop
3. ✅ Проверить работу MCP серверов
4. ✅ Начать использовать Sequential Thinking для Week 9-10
5. ✅ Использовать Memory для сохранения важных решений проекта

---

**Создано**: 2025-10-03
**Для проекта**: Sekretar AI Calendar
**Поддержка**: MCP Protocol v1.0
