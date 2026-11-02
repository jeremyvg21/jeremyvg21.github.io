# EVENTLIVE - sube exclusivamente los 14 PNG a la ruta ya configurada en GitHub Pages.
# Ejecutar desde PowerShell (en la carpeta descomprimida): .\SUBIR_EVENTLIVE_WINDOWS.ps1
$ErrorActionPreference = 'Stop'
$origin = Join-Path $PSScriptRoot 'assets\projects\eventlive'
if (-not (Test-Path $origin)) { throw 'Falta assets\projects\eventlive. Extrae el ZIP completo antes de ejecutar.' }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git no esta instalado o no figura en PATH.' }
$images = @(Get-ChildItem -Path $origin -Filter '*.png' -File)
if ($images.Count -ne 14) { throw "Se esperaban 14 capturas. Se encontraron $($images.Count)." }
$folder = Join-Path $env:TEMP ('eventlive-portafolio-' + [guid]::NewGuid().ToString('N'))
$repo = 'https://github.com/jeremyvg21/jeremyvg21.github.io.git'
Write-Host 'Clonando la version actual de main sin modificar otros proyectos...'
git clone --branch main --single-branch --depth 1 $repo $folder
if ($LASTEXITCODE -ne 0) { throw 'No se pudo clonar el repositorio. Revisa Git y autenticacion.' }
$dest = Join-Path $folder 'assets\projects\eventlive'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
foreach ($file in $images) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $dest $file.Name) -Force }
Push-Location $folder
try {
  git add -- assets/projects/eventlive/
  git diff --cached --quiet
  if ($LASTEXITCODE -eq 0) { Write-Host 'Las 14 imagenes ya estan publicadas, no se requieren cambios.'; exit 0 }
  git commit -m 'assets(eventlive): publicar 14 capturas DEMO originales'
  if ($LASTEXITCODE -ne 0) { throw 'No fue posible crear el commit. Configura user.name y user.email en Git.' }
  git push origin main
  if ($LASTEXITCODE -ne 0) { throw 'Error en el push. Revisa autenticacion de GitHub y cambios recientes en main.' }
  Write-Host 'Imagenes enviadas a GitHub. Comprueba el despliegue en Actions y abre:'
  Write-Host 'https://jeremyvg21.github.io/projects/eventlive.html'
} finally { Pop-Location }
