param([string]$RepoPath = "")
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Run-Git([string[]]$GitArgs) {
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) { throw ("Falló git: " + ($GitArgs -join " ")) }
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "No se encontró Git. Instala Git for Windows y vuelve a ejecutar el script." }
    $manifestPath = Join-Path $PSScriptRoot "MANIFIESTO.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.total_imagenes -ne 10 -or $manifest.imagenes.Count -ne 10) { throw "Manifiesto incompleto: se esperaban 10 PNG." }
    $sourceDir = Join-Path $PSScriptRoot "assets\projects\encuestas-inscripciones"
    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) { throw "No está la carpeta de imágenes dentro del ZIP extraído." }

    foreach ($entry in $manifest.imagenes) {
        $imagePath = Join-Path $sourceDir $entry.archivo
        if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { throw "Archivo faltante: $($entry.archivo)" }
        $actualHash = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $entry.sha256.ToLowerInvariant()) { throw "El hash SHA-256 no coincide: $($entry.archivo)" }
    }
    Write-Host "OK: 10 PNG originales verificados por SHA-256." -ForegroundColor Green

    if ([string]::IsNullOrWhiteSpace($RepoPath)) {
        $cwd = (Get-Location).Path
        if (Test-Path -LiteralPath (Join-Path $cwd ".git")) { $RepoPath = $cwd }
        else { $RepoPath = Join-Path $HOME "Documents\jeremyvg21.github.io" }
    }
    if (-not (Test-Path -LiteralPath $RepoPath)) {
        Write-Host "Clonando el repositorio público en: $RepoPath"
        Run-Git @("clone","https://github.com/jeremyvg21/jeremyvg21.github.io.git",$RepoPath)
    }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoPath ".git"))) { throw "La ruta no es un clon Git válido: $RepoPath" }
    $remote = (& git -C $RepoPath remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Falta el remoto origin." }
    if ($remote -notmatch 'github\.com[:/]jeremyvg21/jeremyvg21\.github\.io(?:\.git)?$') {
        throw "Origen Git incorrecto. Por seguridad no se modificará un repositorio diferente."
    }
    $branch = (& git -C $RepoPath branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne "main") { throw "La rama actual debe ser main, detectada: $branch. Corrige la rama antes de ejecutar." }
    $changes = @(& git -C $RepoPath status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw "No se pudo comprobar el estado del repositorio." }
    if ($changes.Count -gt 0 -and -not ($changes.Count -eq 1 -and [string]::IsNullOrWhiteSpace($changes[0]))) {
        throw "El repositorio tiene cambios locales. Guarda o confirma esos cambios antes de ejecutar para evitar sobrescribirlos."
    }
    Run-Git @("-C",$RepoPath,"fetch","origin","main")
    Run-Git @("-C",$RepoPath,"pull","--ff-only","origin","main")

    $targetDir = Join-Path $RepoPath "assets\projects\encuestas-inscripciones"
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    foreach ($entry in $manifest.imagenes) {
        $src = Join-Path $sourceDir $entry.archivo
        $dst = Join-Path $targetDir $entry.archivo
        Copy-Item -LiteralPath $src -Destination $dst -Force
        $hash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $entry.sha256.ToLowerInvariant()) { throw "Falló verificación después de copiar: $($entry.archivo)" }
    }
    Write-Host "Las 10 imágenes se copiaron únicamente en assets/projects/encuestas-inscripciones/" -ForegroundColor Green
    Run-Git @("-C",$RepoPath,"add","--","assets/projects/encuestas-inscripciones")
    & git -C $RepoPath diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Las 10 imágenes ya están registradas sin cambios. No es necesario crear un commit." -ForegroundColor Cyan
    } elseif ($LASTEXITCODE -eq 1) {
        Run-Git @("-C",$RepoPath,"commit","-m","assets(encuestas): publicar 10 capturas profesionales DEMO SCHOOL")
    } else { throw "No se pudo verificar el área de preparación de Git." }
    Run-Git @("-C",$RepoPath,"push","origin","main")
    $commit = (& git -C $RepoPath rev-parse HEAD).Trim()
    Write-Host ("OK: push realizado. Commit actual: " + $commit) -ForegroundColor Green
    Write-Host "Visita https://jeremyvg21.github.io/projects/encuestas-inscripciones.html y comprueba las imágenes cuando GitHub Pages despliegue." -ForegroundColor Cyan
} catch {
    Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host "No se realizará ningún push forzado. Revisa el error y vuelve a ejecutar." -ForegroundColor Yellow
    exit 1
}
