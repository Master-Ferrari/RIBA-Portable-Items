<#
.SYNOPSIS
    Собирает RIBA Portable Items из этой репы прямо в папку модов Barotrauma.

.DESCRIPTION
    RIBAXML.exe резолвит все пути от текущей директории: ссылки вида
    ../../Content/... должны попадать в <игра>/Content, а результат он кладёт
    в ../<имя из RIBAfilelist.xml>. То есть запускать его можно только из
    каталога вида <игра>/LocalMods/<что-то>.

    Скрипт это обходит: зеркалит рабочее дерево репы в служебный каталог
    <игра>/LocalMods/.riba-build-src (игра его не видит - там нет filelist.xml),
    заранее создаёт выходные папки, чтобы экзешник не спрашивал ничего с
    клавиатуры, и запускает сборку оттуда.

.PARAMETER GameDir
    Корень установленной игры. Если не задан - берётся из build.config.json,
    переменной окружения BAROTRAUMA_DIR, либо ищется через Steam.

.PARAMETER Launch
    Запустить игру после успешной сборки. Если игра уже запущена - ничего не делает.

.PARAMETER Restart
    Закрыть уже запущенную игру и поднять её заново. Игра читает моды один раз при
    старте, так что без перезапуска пересборка в ней не появится.

.PARAMETER Clean
    Снести выходную папку мода и staging перед сборкой.

.PARAMETER Publish
    Залить собранный мод в Steam Workshop. Настройки страницы (теги, видимость,
    описания по языкам, обложка) берутся из workshop.json в корне репы.
    Без -Yes только показывает, что будет сделано, и останавливается.
    Нужен запущенный Steam под аккаунтом-владельцем мода.

.PARAMETER Changelog
    Примечание к версии для -Publish.

.PARAMETER Yes
    Подтверждает заливку. Без него -Publish ничего не публикует.

.EXAMPLE
    .\build.ps1
    .\build.ps1 -Restart
    .\build.ps1 -Clean -Launch
    .\build.ps1 -GameDir "D:\Games\Barotrauma"
    .\build.ps1 -Publish -Changelog "1.13.4, распределитель энергии"
    .\build.ps1 -Publish -Changelog "..." -Yes
#>
[CmdletBinding()]
param(
    [string] $GameDir,
    [switch] $Launch,
    [switch] $Restart,
    [switch] $Clean,
    [switch] $Publish,
    [string] $Changelog,
    [switch] $Yes
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$configPath = Join-Path $repo 'build.config.json'

function Write-Step  ($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok    ($m) { Write-Host "    $m" -ForegroundColor Green }
function Write-Warn2 ($m) { Write-Host "    $m" -ForegroundColor Yellow }
function Write-Err   ($m) { Write-Host "    $m" -ForegroundColor Red }

# ---------------------------------------------------------------- игра ------

function Test-GameDir([string] $dir) {
    if ([string]::IsNullOrWhiteSpace($dir)) { return $false }
    if (-not (Test-Path (Join-Path $dir 'Content'))) { return $false }
    if (-not (Test-Path (Join-Path $dir 'Barotrauma.exe'))) { return $false }
    return $true
}

function Find-GameDirViaSteam {
    $steamRoot = $null
    try {
        $steamRoot = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath
    } catch {
        $steamRoot = 'C:\Program Files (x86)\Steam'
    }
    $vdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
    $roots = @($steamRoot)
    if (Test-Path $vdf) {
        $roots += ([regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"') |
                   ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' })
    }
    foreach ($r in ($roots | Sort-Object -Unique)) {
        $candidate = Join-Path $r 'steamapps\common\Barotrauma'
        if (Test-GameDir $candidate) { return $candidate }
    }
    return $null
}

function Resolve-GameDir {
    if (Test-GameDir $GameDir) { return (Resolve-Path $GameDir).Path }
    if ($GameDir) { throw "В -GameDir '$GameDir' не похоже на Barotrauma (нет Content\ и Barotrauma.exe)." }

    if (Test-Path $configPath) {
        $saved = (Get-Content $configPath -Raw | ConvertFrom-Json).gameDir
        if (Test-GameDir $saved) { return (Resolve-Path $saved).Path }
        Write-Warn2 "build.config.json указывает на несуществующую установку, ищу заново"
    }
    if (Test-GameDir $env:BAROTRAUMA_DIR) { return (Resolve-Path $env:BAROTRAUMA_DIR).Path }

    $found = Find-GameDirViaSteam
    if ($found) { return $found }

    throw @'
Не нашёл установленную Barotrauma.
Укажи путь явно:   .\build.ps1 -GameDir "X:\...\steamapps\common\Barotrauma"
(он запомнится в build.config.json)
'@
}

Write-Step 'Ищу игру'
$game = Resolve-GameDir
Write-Ok $game

$savedDir = $null
if (Test-Path $configPath) { $savedDir = (Get-Content $configPath -Raw | ConvertFrom-Json).gameDir }
if ($savedDir -ne $game) {
    [pscustomobject]@{ gameDir = $game } | ConvertTo-Json | Set-Content $configPath -Encoding utf8
    Write-Ok 'путь сохранён в build.config.json'
}

$localMods = Join-Path $game 'LocalMods'
if (-not (Test-Path $localMods)) { New-Item -ItemType Directory -Force $localMods | Out-Null }

# ------------------------------------------------------------- манифест -----

$manifestPath = Join-Path $repo 'RIBAfilelist.xml'
if (-not (Test-Path $manifestPath)) { throw "Нет RIBAfilelist.xml в $repo" }
[xml] $manifest = Get-Content $manifestPath -Encoding UTF8

$modName = $manifest.contentpackage.name
if ([string]::IsNullOrWhiteSpace($modName)) { throw 'В RIBAfilelist.xml у <contentpackage> нет атрибута name' }

$entries = @($manifest.contentpackage.ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.file })
if ($entries.Count -eq 0) { throw 'В RIBAfilelist.xml нет ни одной записи с file=' }

$outRoot = Join-Path $localMods $modName
$stage   = Join-Path $localMods '.riba-build-src'
$exe     = Join-Path $repo 'RIBAXML.exe'
if (-not (Test-Path $exe)) { throw "Нет RIBAXML.exe в $repo" }

Write-Step "Собираю `"$modName`" (modversion $($manifest.contentpackage.modversion), gameversion $($manifest.contentpackage.gameversion))"
Write-Ok "выход: $outRoot"

# -- сверка объявленной gameversion с установленной, чисто предупреждение ----
$vanilla = Join-Path $game 'Content\ContentPackages\Vanilla.xml'
if (Test-Path $vanilla) {
    [xml] $v = Get-Content $vanilla -Encoding UTF8
    if ($v.contentpackage.gameversion -ne $manifest.contentpackage.gameversion) {
        Write-Warn2 "gameversion в манифесте ($($manifest.contentpackage.gameversion)) != версии игры ($($v.contentpackage.gameversion))"
    }
}

if ($Clean) {
    Write-Step 'Чищу'
    foreach ($d in @($outRoot, $stage)) {
        if (Test-Path $d) { Remove-Item $d -Recurse -Force; Write-Ok "снёс $d" }
    }
}

# -------------------------------------------------------------- staging ----

Write-Step 'Зеркалю исходники в staging'
# RIBAXML.exe запускаем из репы, в staging его копировать незачем (23 МБ).
$robo = @(
    $repo, $stage, '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:2', '/W:1',
    '/XD', '.git', '.vscode', '.claude', 'backup',
    '/XF', 'RIBAXML.exe', 'build.ps1', 'build.cmd', 'build.config.json',
           '*.psd', '*.7z', '*.zip', '*.lnk', '*.code-workspace'
)
& robocopy @robo | Out-Null
# robocopy: 0-7 это успех, 8+ настоящая ошибка
if ($LASTEXITCODE -ge 8) { throw "robocopy не смог синхронизировать staging (код $LASTEXITCODE)" }
Write-Ok $stage

# Выходные папки создаём сами: иначе RIBAXML спросит "Создать все недостающие
# пути? y/n" через Console.ReadKey, а с перенаправленным stdin это исключение.
$null = New-Item -ItemType Directory -Force $outRoot
foreach ($e in $entries) {
    $rel = $e.file -replace '%ModDir%/', ''
    $dir = Split-Path (Join-Path $outRoot $rel) -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
}

# ---------------------------------------------------------------- сборка ----

Write-Step 'Запускаю RIBAXML'
$prevEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Push-Location $stage
try {
    # < nul, чтобы финальный Console.ReadKey ("тыкни") не завесил сборку.
    # Он при этом падает с InvalidOperationException уже ПОСЛЕ записи всех
    # файлов, поэтому код возврата ничего не значит - разбираем вывод.
    $output = cmd /c "`"$exe`" < nul 2>&1"
} finally {
    Pop-Location
    [Console]::OutputEncoding = $prevEncoding
}

$done = @{}
$errors = @()
$readKeyNoise = $false
foreach ($line in $output) {
    $s = [string]$line
    if ($s -match '^(.+?) - ОК$')                  { $done[$Matches[1]] = $true; continue }
    if ($s -match 'Cannot read keys')              { $readKeyNoise = $true; continue }
    if ($s -match '^\s*(тыкни|Unhandled exception)') { continue }
    if ($s -match '^\s+at ')                       { continue }
    if ($s -match '^!!!' -or $s -match 'Exception') { $errors += $s }
}

$expected = @($entries | ForEach-Object { Split-Path ($_.file -replace '%ModDir%/', '') -Leaf })
$expected += 'filelist.xml'
$missing = @($expected | Where-Object { -not $done.ContainsKey($_) })

foreach ($e in $errors) { Write-Err $e }

if ($missing.Count -gt 0) {
    Write-Err "не собралось: $($missing -join ', ')"
    Write-Host ''
    Write-Host 'Полный вывод RIBAXML:' -ForegroundColor DarkGray
    $output | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    exit 1
}

Write-Ok "$($done.Count) файлов - ОК"
if ($readKeyNoise) { Write-Ok 'финальный Console.ReadKey подавлен (это нормально)' }

# ------------------------------------------------------------------ итог ----

Write-Step 'Готово'
Write-Ok $outRoot
$size = (Get-ChildItem $outRoot -Recurse -File | Measure-Object -Property Length -Sum).Sum
Write-Ok ("{0} файлов, {1:N1} МБ" -f (Get-ChildItem $outRoot -Recurse -File).Count, ($size / 1MB))

$enabled = Join-Path $game 'config_player.xml'
if (Test-Path $enabled) {
    if ((Get-Content $enabled -Raw) -notmatch [regex]::Escape("LocalMods/$modName/filelist.xml")) {
        Write-Warn2 "мод не включён в config_player.xml - включи его в списке модов игры"
    }
}

if ($Publish) {
    Write-Step 'Публикация в Мастерскую'

    $toolDir = Join-Path $repo 'Tools\RibaPublish'
    $toolExe = Join-Path $toolDir 'bin\Release\net9.0\RibaPublish.exe'

    # утилита ссылается на Facepunch.Steamworks из папки игры, поэтому путь передаём в сборку
    & dotnet build $toolDir -c Release -p:BarotraumaDir="$game" -v quiet --nologo | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "не собралась Tools\RibaPublish (код $LASTEXITCODE)" }
    if (-not (Test-Path $toolExe)) { throw "не нашёлся $toolExe" }
    Write-Ok 'утилита собрана'

    $pubArgs = @('--content', $outRoot, '--repo', $repo)
    if ($Changelog) { $pubArgs += @('--changelog', $Changelog) }
    if ($Yes) { $pubArgs += '--yes' } else { $pubArgs += '--dry-run' }

    # steam_appid.txt должен лежать в текущей директории процесса
    Push-Location (Split-Path $toolExe -Parent)
    try { & $toolExe @pubArgs } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if (-not $Yes) {
        Write-Warn2 'это была холостая проверка — для настоящей заливки добавь -Yes'
    }
}

if ($Launch -or $Restart) {
    $running = @(Get-Process -Name 'Barotrauma' -ErrorAction SilentlyContinue)

    if ($running.Count -gt 0 -and -not $Restart) {
        Write-Step 'Игра уже запущена'
        Write-Warn2 'моды читаются один раз при старте - пересборка подхватится только после перезапуска'
        Write-Warn2 'перезапустить: build.cmd -Restart'
        return
    }

    if ($running.Count -gt 0) {
        Write-Step 'Закрываю игру'
        # сначала по-человечески: просим окно закрыться
        foreach ($p in $running) { $null = $p.CloseMainWindow() }
        try { Wait-Process -Name 'Barotrauma' -Timeout 12 -ErrorAction Stop } catch {}
        $left = @(Get-Process -Name 'Barotrauma' -ErrorAction SilentlyContinue)
        if ($left.Count -gt 0) {
            Write-Warn2 'не закрылась сама, снимаю принудительно'
            $left | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        Write-Ok 'закрыта'
    }

    Write-Step 'Запускаю игру'
    Start-Process 'steam://rungameid/602960'
    Write-Ok 'команда Steam отправлена'
}
