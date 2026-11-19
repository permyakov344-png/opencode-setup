# Требуется PowerShell 5.1+
<#
  Проверка установленной конфигурации OpenCode.
  Ничего не меняет — только читает и показывает.

  Запуск:
    powershell -ExecutionPolicy Bypass -File verify.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$cfg = Join-Path $env:USERPROFILE '.config\opencode'
$ok = 0; $warn = 0; $bad = 0

function Good($m) { Write-Host "  [ok]    $m" -ForegroundColor Green; $script:ok++ }
function Warn($m) { Write-Host "  [!]     $m" -ForegroundColor Yellow; $script:warn++ }
function Bad($m)  { Write-Host "  [нет]   $m" -ForegroundColor Red; $script:bad++ }

Write-Host ''
Write-Host '=== Проверка конфигурации OpenCode ===' -ForegroundColor Cyan
Write-Host "Папка: $cfg"
Write-Host ''

Write-Host 'Программа:' -ForegroundColor Cyan
$oc = Get-Command opencode -ErrorAction SilentlyContinue
if ($oc) {
  $ver = try { (& opencode --version) 2>$null } catch { $null }
  if ($ver) { Good "OpenCode $ver ($($oc.Source))" } else { Good "OpenCode ($($oc.Source))" }
} else {
  Bad 'OpenCode не найден в PATH — установите: npm install -g @opencode/cli'
}

Write-Host ''
Write-Host 'Файлы конфигурации:' -ForegroundColor Cyan
foreach ($f in @('opencode.json', 'AGENTS.md')) {
  if (Test-Path -LiteralPath (Join-Path $cfg $f)) { Good $f } else { Bad $f }
}
foreach ($f in @('reviewer.md', 'tester.md', 'docs.md')) {
  if (Test-Path -LiteralPath (Join-Path $cfg "agents\$f")) { Good "agents\$f" } else { Bad "agents\$f" }
}
foreach ($f in @('review.md', 'test.md', 'docs.md', 'sync.md', 'pro.md', 'flash.md')) {
  if (Test-Path -LiteralPath (Join-Path $cfg "commands\$f")) { Good "commands\$f" } else { Bad "commands\$f" }
}

Write-Host ''
Write-Host 'opencode.json:' -ForegroundColor Cyan
$cfgJson = Join-Path $cfg 'opencode.json'
if (Test-Path -LiteralPath $cfgJson) {
  try {
    $j = Get-Content -LiteralPath $cfgJson -Raw -Encoding UTF8 | ConvertFrom-Json
    Good 'JSON читается без ошибок'
    if ($j.model) { Good "модель по умолчанию: $($j.model)" } else { Warn 'модель по умолчанию не задана' }

    $key = $null
    try { $key = $j.provider.routerai.options.apiKey } catch { }
    if ($key -and $key -notlike '*__ROUTERAI*') {
      Good "ключ RouterAI задан (…$($key.Substring([Math]::Max(0, $key.Length - 4))))"
    } elseif ($key -like '*__ROUTERAI*') {
      Bad 'ключ RouterAI не вписан — запустите install.ps1 -ApiKey "sk-..."'
    } else {
      Warn 'провайдер routerai не настроен — модель по умолчанию работать не будет'
    }
  } catch {
    Bad "JSON битый: $($_.Exception.Message)"
  }
}

Write-Host ''
Write-Host 'Модели сабагентов:' -ForegroundColor Cyan
Get-ChildItem -LiteralPath (Join-Path $cfg 'agents') -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object {
  $line = Select-String -LiteralPath $_.FullName -Pattern '^model:\s*(.+)$' | Select-Object -First 1
  $name = '{0}:' -f $_.BaseName
  if ($line) {
    $m = $line.Matches[0].Groups[1].Value.Trim()
    Write-Host ('  {0,-14} {1}' -f $name, $m)
  } else {
    Write-Host ('  {0,-14} {1}' -f $name, '(не задана — берётся основная)') -ForegroundColor DarkGray
  }
}
Write-Host ''
Write-Host 'Итог:' -ForegroundColor Cyan
Write-Host "  ок: $ok   предупреждений: $warn   проблем: $bad"
if ($bad -eq 0) {
  Write-Host '  Конфигурация на месте. Откройте OpenCode, наберите / — должны быть review, test, docs, sync, pro, flash.' -ForegroundColor Green
} else {
  Write-Host '  Есть проблемы — смотрите строки [нет] выше. Обычно помогает перезапустить install.ps1.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Если сабагент пишет «model not found» — модель удалили из каталога.' -ForegroundColor DarkGray
Write-Host 'Откройте agents\*.md и замените model: на доступную (список — /models в OpenCode).' -ForegroundColor DarkGray
Write-Host ''
