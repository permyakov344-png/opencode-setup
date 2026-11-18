#!/usr/bin/env bash
#
# Синхронизация репозитория opencode-setup с GitHub (macOS / Linux).
#
#   bash sync.sh
#
# Что делает: commit (если есть изменения) → pull --rebase → push.
# Без force: история не перезаписывается.

set -u

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$REPO_DIR" || exit 1

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_BAD=$'\033[31m'; C_HEAD=$'\033[36m'; C_OFF=$'\033[0m'
else
  C_OK=''; C_BAD=''; C_HEAD=''; C_OFF=''
fi

printf '\n'
printf '%s=== opencode-setup: синхронизация с GitHub ===%s\n' "$C_HEAD" "$C_OFF"
printf 'Папка: %s\n\n' "$REPO_DIR"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  printf '%sЭто не git-репозиторий. Остановлено.%s\n' "$C_BAD" "$C_OFF"
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  printf '%sНе настроен remote "origin". Остановлено.%s\n' "$C_BAD" "$C_OFF"
  exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)

# --- 1. сохранить изменения ---
git add -A
if ! git diff --cached --quiet; then
  if ! git commit -q -m "Конфигурация OpenCode $(date '+%Y-%m-%d %H:%M')"; then
    printf '%sОшибка коммита.%s\n' "$C_BAD" "$C_OFF"
    exit 1
  fi
  printf '[1/3] Коммит создан.\n'
else
  printf '[1/3] Новых изменений нет.\n'
fi

# --- 2. забрать изменения ---
if ! git pull --rebase --autostash origin "$BRANCH"; then
  printf '\n%sОШИБКА при pull.%s Разберите конфликт и повторите.\n' "$C_BAD" "$C_OFF"
  exit 1
fi
printf '[2/3] Изменения с GitHub получены.\n'

# --- 3. отправить ---
if ! git push origin "$BRANCH"; then
  printf '\n%sОШИБКА при push.%s Ничего не потеряно: изменения на диске.\n' "$C_BAD" "$C_OFF"
  exit 1
fi
printf '[3/3] Отправлено на GitHub.\n\n'

printf 'Ветка: %s\n' "$BRANCH"
printf 'Последний коммит: %s\n' "$(git log --oneline -1)"
printf 'Репозиторий: https://github.com/permyakov344-png/opencode-setup\n\n'
