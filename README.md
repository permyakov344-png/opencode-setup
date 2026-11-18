# OpenCode: моя конфигурация

Перенос рабочей настройки OpenCode на другую машину: сабагенты, слэш-команды,
глобальные правила и провайдер модели. Один скрипт — и всё как на работе.

Проверено на **OpenCode v2.0.29**, Windows 10 и macOS (bash 3.2+, включая M1/M2).

---

## Быстрый старт

### macOS (дом, M1)

```bash
# 1. Один раз: вход в GitHub (репозиторий приватный)
brew install gh          # если gh ещё нет
gh auth login

# 2. Забрать конфигурацию
gh repo clone permyakov344-png/opencode-setup ~/opencode-setup
cd ~/opencode-setup

# 3. Поставить
bash install.sh
```

Скрипт спросит ключ RouterAI, сделает резервную копию текущей конфигурации и
разложит всё по местам. Потом откройте новый терминал.

Если OpenCode ещё не установлен, `install.sh` подскажет команду, но поставить
можно сразу:

```bash
brew install anomalyco/tap/opencode-v2     # или: npm install -g @opencode/cli
```

Проверка:

```bash
bash verify.sh
```

Ожидаемо: `ок: 13   предупреждений: 0   проблем: 0`.

### Windows (работа)

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
powershell -ExecutionPolicy Bypass -File verify.ps1
```

Ключ можно передать сразу, без вопроса:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -ApiKey "sk-..."
```

### После установки — в обоих случаях

Перезапустить терминал, открыть `opencode`, набрать `/` — в списке должны быть
`review`, `test`, `docs`, `sync`. В списке сабагентов — `reviewer`, `tester`, `docs`.

---

## Что внутри

```
config\
├─ opencode.json     ← провайдер RouterAI, модель по умолчанию, MCP
├─ AGENTS.md         ← глобальные правила работы (читаются всегда)
├─ agents\           ← сабагенты
│   ├─ reviewer.md
│   ├─ tester.md
│   └─ docs.md
└─ commands\         ← слэш-команды
    ├─ review.md
    ├─ test.md
    ├─ docs.md
    └─ sync.md

install.ps1 / install.sh        ← установка (Windows / macOS)
verify.ps1  / verify.sh         ← проверка, только чтение
синхронизация.bat / sync.sh     ← commit + pull --rebase + push этого репозитория
НАСТРОИТЬ.md                    ← промпт для агента: «прочитай и настрой»
```

Куда ставится: `~/.config/opencode` — глобальная конфигурация, действует во всех
проектах. На Windows это `%USERPROFILE%\.config\opencode`.
Если задан `XDG_CONFIG_HOME`, OpenCode берёт путь оттуда.

---

## Сабагенты

| Агент | Модель | Что делает | Чего не делает |
|---|---|---|---|
| `reviewer` | `opencode/deepseek-v4.1-flash-free` | читает `git diff` и `git status`, ищет баги, отчёт по серьёзности | не правит файлы (запрет на `edit`), из shell — только `git diff` / `git status` |
| `tester` | `opencode/deepseek-v4.1-flash-free` | пишет и правит тесты, запускает их | не меняет прод-код, не ставит зависимости; нет фреймворка — сообщает и останавливается |
| `docs` | `opencode/deepseek-v4.1-flash-free` | обновляет README, `docs/`, CHANGELOG | не меняет код; `AGENTS.md` править запрещено |

Права сабагентов урезаны явно, а не «на честном слове»: у `reviewer` запрещены
любые правки, у `tester` разрешён только запуск тестовых команд, у `docs` — только
markdown-файлы и `docs/`.

## Команды

| Команда | Что делает |
|---|---|
| `/review [цель]` | ревью текущих изменений через сабагента `reviewer` |
| `/test <файл>` | тесты для файла или модуля через `tester` |
| `/docs [цель]` | README и документация через `docs` |
| `/sync` | commit → `pull --rebase` → `push` текущего проекта |

## Порядок работы (из `AGENTS.md`)

1. Сделал фичу или фикс → `/test <файл>`, если есть тестовый фреймворк.
2. Перед `git commit` → `/review`.
3. После правок кода → сабагент `docs` проверяет README. Не изменились запуск,
   установка, API, CLI, env или структура — README не трогаем.
4. Одна строка, опечатка, форматирование → сабагентов не запускать, делать самому.

---

## Секреты

В репозитории **нет** и не должно быть:

- ключа RouterAI — в шаблоне стоит `__ROUTERAI_API_KEY__`, установщик подставляет
  ваш ключ уже на месте, в файл на диске;
- `service.json` — он машинно-зависимый, установщик его не трогает.

Хотите держать ключ вообще вне конфига — замените в `opencode.json` строку
`"apiKey"` на `"{env:ROUTERAI_API_KEY}"` и заведите переменную окружения.
Подстановка `{env:...}` в конфиге поддерживается; установщик и `verify` такой
вариант понимают.

---

## Синхронизация самого конфига

Поменяли агента или правило — запустите `sync.sh` (Mac) или двойной щелчок по
`синхронизация.bat` (Windows), либо `/sync` внутри OpenCode:
коммит → `pull --rebase` → `push`, без `--force`.

Правки конфигурации меняйте **в репозитории**, а не прямо в `~/.config/opencode`,
иначе они разъедутся. Порядок: правим `config\...` → `install` → `sync`.

---

## Если модель удалили из каталога

Сабагент начнёт падать с ошибкой вида «model not found». Лечение: открыть
`config/agents/<имя>.md`, заменить строку `model:` на доступную модель
(список — `/models` в OpenCode) и повторить установку.

Проверенные бесплатные варианты: `opencode/deepseek-v4.1-flash-free`,
`opencode/hy4-flash-free`, `opencode/mimo-v2.6-flash-free`.

По правилам `AGENTS.md`, если сабагент недоступен — работу надо сделать самому
и сказать об этом, а не молча падать.

---

## Требования

| | macOS | Windows |
|---|---|---|
| OpenCode | `brew install anomalyco/tap/opencode-v2` или `npm install -g @opencode/cli` | `npm install -g @opencode/cli` |
| Оболочка | bash 3.2+ (штатная) | PowerShell 5.1+ (штатный) |
| Git | `xcode-select --install` | [git-scm.com](https://git-scm.com) |
| GitHub CLI | `brew install gh` | `winget install GitHub.cli` |

Ключ RouterAI нужен для модели по умолчанию `routerai/deepseek-v4-pro-0813`.
Без него OpenCode работает, но эта модель недоступна.
