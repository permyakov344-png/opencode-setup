#!/usr/bin/env bash
#
# Установка конфигурации OpenCode на macOS (и Linux).
#
# Что делает:
#   1. проверяет, установлен ли OpenCode;
#   2. делает резервную копию ~/.config/opencode;
#   3. копирует agents, commands, AGENTS.md и opencode.json;
#   4. вписывает ключ RouterAI;
#   5. показывает результат.
#
# Запуск:
#   bash install.sh
#   bash install.sh --api-key "sk-..."      # ключ сразу, без вопроса
#   bash install.sh --skip-key              # без ключа
#
# Проверено на bash 3.2 (штатный в macOS) — без mapfile и ассоциативных массивов.

set -u

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$REPO_DIR/config"
DST="$HOME/.config/opencode"

API_KEY="${ROUTERAI_API_KEY:-}"
SKIP_KEY=0
FORCE=0

# ---------- цвета ----------
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_BAD=$'\033[31m'; C_HEAD=$'\033[36m'; C_OFF=$'\033[0m'
else
  C_OK=''; C_WARN=''; C_BAD=''; C_HEAD=''; C_OFF=''
fi

ok()   { printf '  %s[ok]%s   %s\n' "$C_OK" "$C_OFF" "$1"; }
warn() { printf '  %s[!]%s    %s\n' "$C_WARN" "$C_OFF" "$1"; }
bad()  { printf '  %s[нет]%s  %s\n' "$C_BAD" "$C_OFF" "$1"; }
step() { printf '%s%s%s\n' "$C_HEAD" "$1" "$C_OFF"; }

# Проверка JSON. Возвращает 0 — валиден, 1 — битый, 2 — нечем проверить.
# Проверяем, что сам валидатор запускается: в Windows-окружении python3 бывает
# заглушкой Microsoft Store, которая падает на любом аргументе.
json_valid() {
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import json' >/dev/null 2>&1; then
    if python3 -c 'import json,sys; json.load(sys.stdin)' < "$1" >/dev/null 2>&1; then return 0; else return 1; fi
  fi
  if command -v node >/dev/null 2>&1 && node -e '0' >/dev/null 2>&1; then
    if node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' < "$1" >/dev/null 2>&1; then return 0; else return 1; fi
  fi
  return 2
}

# ---------- разбор аргументов ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --api-key)  shift; API_KEY="${1:-}"; [ -n "$API_KEY" ] || { bad "после --api-key нужен ключ"; exit 1; } ;;
    --api-key=*) API_KEY="${1#*=}" ;;
    --skip-key) SKIP_KEY=1 ;;
    --force|-f) FORCE=1 ;;
    -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
    *) bad "неизвестный аргумент: $1"; exit 1 ;;
  esac
  shift
done

printf '\n'
step '=== Установка конфигурации OpenCode ==='
printf 'Откуда: %s\n' "$SRC"
printf 'Куда:   %s\n' "$DST"
printf 'Система: %s %s\n\n' "$(uname -s)" "$(uname -m)"

# ---------- 0. проверка исходников ----------
if [ ! -d "$SRC" ]; then
  bad "не найдена папка config рядом со скриптом"
  printf '       запускайте install.sh из корня репозитория\n'
  exit 1
fi

# ---------- 1. OpenCode установлен? ----------
step '[1/5] OpenCode'
if command -v opencode >/dev/null 2>&1; then
  OC_PATH=$(command -v opencode)
  OC_VER=$(opencode --version 2>/dev/null | head -n 1)
  ok "opencode ${OC_VER:-?} ($OC_PATH)"
else
  bad 'opencode не найден в PATH'
  printf '\n'
  printf '       Установите одним из способов:\n'
  printf '         brew install anomalyco/tap/opencode-v2\n'
  printf '         npm install -g @opencode/cli\n'
  printf '         curl -fsSL https://opencode.ai/v2/install | bash\n'
  printf '\n'
  if [ "$FORCE" -eq 0 ]; then
    printf '       Продолжить установку конфигурации без OpenCode? [y/N] '
    read -r answer || answer=''
    case "$answer" in
      y|Y|д|Д) ;;
      *) printf 'Остановлено.\n'; exit 1 ;;
    esac
  fi
fi

# ---------- 2. резервная копия ----------
step '[2/5] Резервная копия'
STAMP=$(date '+%Y-%m-%d_%H%M%S')
BACKUP="$HOME/.config/opencode.backup-$STAMP"
if [ -d "$DST" ]; then
  mkdir -p "$(dirname "$BACKUP")"
  cp -R "$DST" "$BACKUP"
  ok "старая конфигурация сохранена: $BACKUP"
else
  mkdir -p "$DST"
  ok 'старой конфигурации не было — создаём с нуля'
fi

# ---------- 3. копирование ----------
step '[3/5] Агенты, команды, правила'
for sub in agents commands; do
  if [ -d "$SRC/$sub" ]; then
    mkdir -p "$DST/$sub"
    for f in "$SRC/$sub"/*; do
      [ -f "$f" ] || continue
      cp "$f" "$DST/$sub/"
    done
    ok "$sub: $(ls -1 "$SRC/$sub" | wc -l | tr -d ' ') файлов"
  fi
done
cp "$SRC/AGENTS.md" "$DST/AGENTS.md"
ok 'AGENTS.md'

# ---------- 4. opencode.json + ключ ----------
step '[4/5] opencode.json'

# если ключ не передан — попробуем взять из уже установленного конфига
if [ -z "$API_KEY" ] && [ -f "$DST/opencode.json" ]; then
  OLD_KEY=$(grep -o '"apiKey"[[:space:]]*:[[:space:]]*"[^"]*"' "$DST/opencode.json" 2>/dev/null | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/')
  case "$OLD_KEY" in
    ''|*__ROUTERAI*|*'{env:'*) OLD_KEY='' ;;
  esac
  if [ -n "$OLD_KEY" ]; then
    API_KEY="$OLD_KEY"
    ok 'найден рабочий ключ в старом конфиге — используем его'
  fi
fi

if [ -z "$API_KEY" ] && [ "$SKIP_KEY" -eq 0 ]; then
  warn 'ключ RouterAI нужен для модели по умолчанию routerai/deepseek-v4.1-flash-1017'
  printf '       Вставьте ключ и нажмите Enter (ввод не отображается).\n'
  printf '       Пустой Enter — пропустить (модель по умолчанию не заработает).\n'
  printf '       Ключ: '
  if [ -t 0 ]; then
    stty -echo 2>/dev/null
    read -r API_KEY || API_KEY=''
    stty echo 2>/dev/null
    printf '\n'
  else
    read -r API_KEY || API_KEY=''
  fi
fi

# подстановка ключа без sed -i: читаем шаблон целиком и заменяем строку
TPL=$(cat "$SRC/opencode.json"; printf 'x')
TPL=${TPL%x}
if [ -n "$API_KEY" ]; then
  TPL=${TPL//__ROUTERAI_API_KEY__/$API_KEY}
  ok 'ключ вписан'
else
  warn 'ключ не задан — конфигурация установлена, но routerai работать не будет'
  warn 'позже: bash install.sh --api-key "sk-..."'
fi
printf '%s' "$TPL" > "$DST/opencode.json"
ok 'opencode.json записан'

# мягкая валидация JSON, если есть чем
json_valid "$DST/opencode.json"
case $? in
  0) ok 'JSON валиден' ;;
  2) warn 'JSON не проверить: нет рабочего python3 или node' ;;
  *) bad 'JSON битый — проверьте opencode.json' ;;
esac

# ---------- 5. итог ----------
step '[5/5] Готово'
printf '\nУстановлено:\n'
( cd "$DST" && find . -type f ! -name 'service.json' | sed 's|^\./|  |' | sort )
printf '\nЧто дальше:\n'
printf '  1. Откройте новый терминал (или перезапустите opencode).\n'
printf '  2. Проверка:  bash %s/verify.sh\n' "$REPO_DIR"
printf '  3. В opencode наберите / — должны быть review, test, docs, sync, pro, flash.\n'
printf '\nСекреты (service.json, ключи) не копируются и не перезаписываются.\n\n'
