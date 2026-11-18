# Требуется PowerShell 5.1+ (есть в Windows 10/11 из коробки)
<#
  Установка конфигурации OpenCode.

  Что делает:
    1. проверяет, установлен ли OpenCode;
    2. делает резервную копию текущей папки конфигурации;
    3. копирует agents, commands, AGENTS.md и opencode.json;
    4. вписывает ключ RouterAI (спрашивает или берёт из переменной окружения);
    5. показывает, что получилось.

  Запуск:
    powershell -ExecutionPolicy Bypass -File install.ps1
    powershell -ExecutionPolicy Bypass -File install.ps1 -ApiKey "sk-..." -Force
#>
[CmdletBinding()]
param(
  [string]$ApiKey = $env:ROUTERAI_API_KEY,
  [switch]$SkipKey,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$here      = $PSScriptRoot
$srcConfig = Join-Path $here 'config'
$dstConfig = Join-Path $env:USERPROFILE '.config\opencode'

Write-Host ''
Write-Host '=== Установка конфигурации OpenCode ===' -ForegroundColor Cyan
Write-Host "Откуда: $srcConfig"
Write-Host "Куда:   $dstConfig"
Write-Host ''

if (-not (Test-Path -LiteralPath $srcConfig)) {
  throw "Не найдена папка config рядом со скриптом. Запускайте install.ps1 из корня репозитория."
}

# ---------- 1. OpenCode установлен? ----------
$oc = Get-Command opencode -ErrorAction SilentlyContinue
if ($oc) {
  $ver = try { (& opencode --version) 2>$null } catch { 'неизвестна' }
  Write-Host "[1/5] OpenCode найден: $($oc.Source)  версия $ver" -ForegroundColor Green
} else {
  Write-Host '[1/5] OpenCode НЕ найден в PATH.' -ForegroundColor Yellow
  Write-Host '      Установите:  npm install -g @opencode/cli'
  Write-Host '      Затем закройте и откройте терминал заново.'
  if (-not $Force) {
    $go = Read-Host '      Продолжить установку конфигурации без OpenCode? (y/n)'
    if ($go -notmatch '^[yYдД]') { Write-Host 'Остановлено.'; exit 1 }
  }
}

# ---------- 2. Резервная копия ----------
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
if (Test-Path -LiteralPath $dstConfig) {
  $backup = Join-Path $env:USERPROFILE ".config\opencode.backup-$stamp"
  Copy-Item -LiteralPath $dstConfig -Destination $backup -Recurse -Force
  Write-Host "[2/5] Старая конфигурация сохранена: $backup" -ForegroundColor Green
} else {
  New-Item -ItemType Directory -Force -Path $dstConfig | Out-Null
  Write-Host '[2/5] Старой конфигурации не было — создаём с нуля.' -ForegroundColor Green
}

# ---------- 3. Копирование ----------
foreach ($sub in @('agents', 'commands')) {
  $s = Join-Path $srcConfig $sub
  $d = Join-Path $dstConfig $sub
  if (Test-Path -LiteralPath $s) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Copy-Item -Path (Join-Path $s '*') -Destination $d -Force
  }
}
Copy-Item -LiteralPath (Join-Path $srcConfig 'AGENTS.md') -Destination (Join-Path $dstConfig 'AGENTS.md') -Force
Write-Host '[3/5] Агенты, команды и AGENTS.md скопированы.' -ForegroundColor Green

# ---------- 4. opencode.json + ключ ----------
$tplSrc = Join-Path $srcConfig 'opencode.json'
$tplDst = Join-Path $dstConfig 'opencode.json'

# Если дома уже есть рабочий конфиг с ключом — не затираем его ключ, берём оттуда
$existingKey = $null
if ((Test-Path -LiteralPath $tplDst) -and -not $ApiKey) {
  try {
    $old = Get-Content -LiteralPath $tplDst -Raw -Encoding UTF8 | ConvertFrom-Json
    $k = $old.provider.routerai.options.apiKey
    if ($k -and $k -notlike '*__ROUTERAI*' -and $k -notlike '*{env:*') { $existingKey = $k }
  } catch { }
}

if (-not $ApiKey -and $existingKey) {
  $ApiKey = $existingKey
  Write-Host '[4/5] Найден рабочий ключ в старом конфиге — используем его.' -ForegroundColor Green
}

if (-not $ApiKey -and -not $SkipKey) {
  Write-Host '[4/5] Ключ RouterAI нужен для модели по умолчанию (routerai/deepseek-v4-pro-0813).' -ForegroundColor Yellow
  Write-Host '      Вставьте ключ и нажмите Enter. Пустой Enter — пропустить (модель по умолчанию работать не будет).'
  $sec = Read-Host '      Ключ RouterAI' -AsSecureString
  if ($sec -and $sec.Length -gt 0) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
  }
}

$json = Get-Content -LiteralPath $tplSrc -Raw -Encoding UTF8
if ($ApiKey) {
  $json = $json.Replace('__ROUTERAI_API_KEY__', $ApiKey.Trim())
  Write-Host '[4/5] Ключ вписан в конфигурацию.' -ForegroundColor Green
} else {
  Write-Host '[4/5] Ключ не задан. Конфигурация установлена, но модель routerai работать не будет.' -ForegroundColor Yellow
  Write-Host '      Позже: powershell -ExecutionPolicy Bypass -File install.ps1 -ApiKey "sk-..."' -ForegroundColor Yellow
}

# пишем без BOM — OpenCode читает JSON строго
[System.IO.File]::WriteAllText($tplDst, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host '[4/5] opencode.json записан.' -ForegroundColor Green

# ---------- 5. Итог ----------
Write-Host '[5/5] Готово.' -ForegroundColor Green
Write-Host ''
Write-Host 'Установлено:' -ForegroundColor Cyan
Get-ChildItem -LiteralPath $dstConfig -Recurse -File |
  Where-Object { $_.Name -ne 'service.json' } |
  ForEach-Object { '  ' + $_.FullName.Replace($dstConfig, '') }
Write-Host ''
Write-Host 'Что дальше:' -ForegroundColor Cyan
Write-Host '  1. Откройте терминал заново (или перезапустите OpenCode).'
Write-Host '  2. Проверка:  powershell -ExecutionPolicy Bypass -File verify.ps1'
Write-Host '  3. В OpenCode наберите /  и убедитесь, что есть review, test, docs, sync.'
Write-Host ''
Write-Host 'Секреты (service.json, ключи) в репозиторий не входят и не перезаписываются.' -ForegroundColor DarkGray
Write-Host ''
