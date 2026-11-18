#!/usr/bin/env bash
#
# Проверка установленной конфигурации OpenCode (macOS / Linux).
# Ничего не меняет — только читает и показывает.
#
# Запуск:
#   bash verify.sh

set -u

CFG="$HOME/.config/opencode"

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_BAD=$'\033[31m'; C_HEAD=$'\033[36m'; C_DIM=$'\033[90m'; C_OFF=$'\033[0m'
else
  C_OK=''; C_WARN=''; C_BAD=''; C_HEAD=''; C_DIM=''; C_OFF=''
fi

OK=0; WARN=0; BAD=0
ok()   { printf '  %s[ok]%s    %s\n' "$C_OK" "$C_OFF" "$1"; OK=$((OK+1)); }
warn() { printf '  %s[!]%s     %s\n' "$C_WARN" "$C_OFF" "$1"; WARN=$((WARN+1)); }
bad()  { printf '  %s[нет]%s   %s\n' "$C_BAD" "$C_OFF" "$1"; BAD=$((BAD+1)); }
head_() { printf '%s%s%s\n' "$C_HEAD" "$1" "$C_OFF"; }

# 0 — JSON валиден, 1 — битый, 2 — нечем проверить.
# Проверяем запускаемость валидатора: python3 в Windows-окружении бывает
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

printf '\n'
head_ '=== Проверка конфигурации OpenCode ==='
printf 'Папка: %s\n' "$CFG"
printf 'Система: %s %s\n\n' "$(uname -s)" "$(uname -m)"

head_ 'Программа:'
if command -v opencode >/dev/null 2>&1; then
  VER=$(opencode --version 2>/dev/null | head -n 1)
  ok "opencode ${VER:-?} ($(command -v opencode))"
else
  bad 'opencode не найден — brew install anomalyco/tap/opencode-v2'
fi

printf '\n'
head_ 'Файлы конфигурации:'
for f in opencode.json AGENTS.md agents/reviewer.md agents/tester.md agents/docs.md \
         commands/review.md commands/test.md commands/docs.md commands/sync.md; do
  if [ -f "$CFG/$f" ]; then ok "$f"; else bad "$f"; fi
done

printf '\n'
head_ 'opencode.json:'
if [ -f "$CFG/opencode.json" ]; then
  json_valid "$CFG/opencode.json"
  VALID=$?

  case "$VALID" in
    0) ok 'JSON читается без ошибок' ;;
    2) warn 'JSON не проверить: нет рабочего python3 или node' ;;
    *) bad 'JSON битый' ;;
  esac

  MODEL=$(grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$CFG/opencode.json" 2>/dev/null | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/')
  if [ -n "$MODEL" ]; then ok "модель по умолчанию: $MODEL"; else warn 'модель по умолчанию не задана'; fi

  KEY=$(grep -o '"apiKey"[[:space:]]*:[[:space:]]*"[^"]*"' "$CFG/opencode.json" 2>/dev/null | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/')
  case "$KEY" in
    '') warn 'провайдер routerai не настроен — модель по умолчанию не заработает' ;;
    *__ROUTERAI*) bad 'ключ RouterAI не вписан — bash install.sh --api-key "sk-..."' ;;
    *'{env:'*) ok "ключ берётся из переменной окружения: $KEY" ;;
    *) ok "ключ RouterAI задан (…$(printf '%s' "$KEY" | tail -c 4))" ;;
  esac
fi

printf '\n'
head_ 'Модели сабагентов:'
if [ -d "$CFG/agents" ]; then
  for f in "$CFG"/agents/*.md; do
    [ -f "$f" ] || continue
    NAME=$(basename "$f" .md)
    M=$(sed -n 's/^model:[[:space:]]*//p' "$f" | head -n 1)
    if [ -n "$M" ]; then
      printf '  %-14s %s\n' "$NAME:" "$M"
    else
      printf '  %-14s %s\n' "$NAME:" '(не задана — берётся основная)'
    fi
  done
else
  bad 'папка agents отсутствует'
fi

printf '\n'
head_ 'Итог:'
printf '  ок: %s   предупреждений: %s   проблем: %s\n' "$OK" "$WARN" "$BAD"
if [ "$BAD" -eq 0 ]; then
  printf '  %sКонфигурация на месте.%s Откройте opencode, наберите / — должны быть review, test, docs, sync.\n' "$C_OK" "$C_OFF"
else
  printf '  %sЕсть проблемы%s — смотрите строки [нет] выше. Обычно помогает повторить install.sh.\n' "$C_WARN" "$C_OFF"
fi

printf '\n'
printf '%sЕсли сабагент пишет «model not found» — модель удалили из каталога.%s\n' "$C_DIM" "$C_OFF"
printf '%sОткройте config/agents/<имя>.md, замените model: на доступную, затем повторите install.sh.%s\n\n' "$C_DIM" "$C_OFF"

exit 0
