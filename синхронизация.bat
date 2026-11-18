@echo off
rem ============================================================
rem  Синхронизация репозитория opencode-setup с GitHub.
rem  Двойной щелчок: сохранить правки конфигурации, забрать чужие,
rem  отправить. Без force: история не перезаписывается.
rem ============================================================
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo === opencode-setup: синхронизация с GitHub ===
echo Папка: %CD%
echo.

git rev-parse --git-dir >nul 2>&1
if errorlevel 1 (
  echo Это не git-репозиторий. Остановлено.
  if /i not "%~1"=="auto" pause
  exit /b 1
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
  echo Не настроен remote "origin". Остановлено.
  if /i not "%~1"=="auto" pause
  exit /b 1
)

for /f "tokens=1 delims=,." %%t in ("%TIME%") do set "NOW=%%t"

git add -A
git diff --cached --quiet
if errorlevel 1 (
  git commit -q -m "Конфигурация OpenCode %DATE% %NOW%"
  if errorlevel 1 goto err
  echo [1/3] Коммит создан.
) else (
  echo [1/3] Новых изменений нет.
)

git pull --rebase --autostash origin main
if errorlevel 1 goto err
echo [2/3] Изменения с GitHub получены.

git push origin main
if errorlevel 1 goto err
echo [3/3] Отправлено на GitHub.
echo.

for /f "delims=" %%i in ('git log --oneline -1') do echo Последний коммит: %%i
if /i not "%~1"=="auto" pause
exit /b 0

:err
echo.
echo ОШИБКА. Ничего не потеряно: изменения остались на диске.
if /i not "%~1"=="auto" pause
exit /b 1
