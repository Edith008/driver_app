Param(
    [string]$EnvFile = ".env.local",
    [string]$Device,
    [switch]$Release
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$expandedEnvPath = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $repoRoot $EnvFile }

if (-not (Test-Path $expandedEnvPath)) {
    Write-Error "No se encontro el archivo de entorno: $expandedEnvPath"
    exit 1
}

$envMap = @{}
Get-Content $expandedEnvPath | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $parts = $line -split '=', 2
    if ($parts.Length -ne 2) { return }
    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    $envMap[$key] = $value
}

if (-not $envMap.ContainsKey('GOOGLE_MAPS_API_KEY') -or [string]::IsNullOrWhiteSpace($envMap['GOOGLE_MAPS_API_KEY'])) {
    Write-Error 'GOOGLE_MAPS_API_KEY no esta definido en el archivo proporcionado.'
    exit 1
}

$flutterExecutable = 'flutter'
$localFvmFlutter = Join-Path $repoRoot '.fvm/flutter_sdk/bin/flutter.bat'
if (Test-Path $localFvmFlutter) {
    $flutterExecutable = $localFvmFlutter
}

$arguments = @('run', "--dart-define=GOOGLE_MAPS_API_KEY=$($envMap['GOOGLE_MAPS_API_KEY'])")
if ($Device) {
    $arguments += '-d'
    $arguments += $Device
}
if ($Release.IsPresent) {
    $arguments += '--release'
}

Write-Host "Ejecutando: $flutterExecutable $($arguments -join ' ')" -ForegroundColor Cyan
$process = Start-Process -FilePath $flutterExecutable -ArgumentList $arguments -NoNewWindow -PassThru -Wait
exit $process.ExitCode
