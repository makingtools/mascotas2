# ===================================================================
# Script para Desplegar un Proyecto Vite en GitHub Pages
# Versión: Limpia para evitar errores de sintaxis
# ===================================================================

# --- CONFIGURACIÓN Y BIENVENIDA ---
# El script asume que lo estás ejecutando desde la raíz de tu proyecto Vite.
$projectPath = Get-Location

Write-Host "=======================================================" -ForegroundColor Green
Write-Host "  Asistente de Despliegue de Vite en GitHub Pages"
Write-Host "======================================================="
Write-Host "Este script preparará y desplegará tu proyecto." -ForegroundColor Yellow
Write-Host "Asegúrate de ejecutarlo desde la carpeta raíz de tu proyecto."
Write-Host "Ubicación actual detectada: '$($projectPath.Path)'" -ForegroundColor Cyan

# --- Pide la información necesaria al usuario ---
$githubUser = Read-Host "`nPor favor, ingresa tu nombre de usuario de GitHub"
$repoName = Read-Host "Ingresa el nombre para tu nuevo repositorio en GitHub (ej. mi-proyecto-vite)"

# --- PASO 1: VERIFICACIÓN DE PREREQUISITOS ---
Write-Host "`n[Paso 1/7] Verificando prerequisitos..." -ForegroundColor Cyan

# Función para verificar si un comando existe
function Test-CommandExists {
    param($command)
    return (Get-Command $command -ErrorAction SilentlyContinue)
}

if (-not (Test-CommandExists "git")) {
    Write-Host "Error: Git no está instalado o no se encuentra en el PATH. Por favor, instálalo para continuar." -ForegroundColor Red
    exit
}
if (-not (Test-CommandExists "npm")) {
    Write-Host "Error: Node.js y npm no están instalados o no se encuentran en el PATH. Por favor, instálalos para continuar." -ForegroundColor Red
    exit
}
Write-Host "✓ Prerequisitos (git, npm) encontrados." -ForegroundColor Green


# --- PASO 2: CONFIGURACIÓN DE .gitignore ---
Write-Host "`n[Paso 2/7] Verificando y configurando .gitignore..." -ForegroundColor Cyan

$gitignorePath = Join-Path $projectPath ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    Write-Host "Creando archivo .gitignore..." -ForegroundColor Yellow
    New-Item ".gitignore" | Out-Null
}

$gitignoreContent = Get-Content $gitignorePath
# Función para agregar entradas a .gitignore si no existen
function Add-To-Gitignore {
    param($Pattern, $ContentToAdd)
    if (-not ($gitignoreContent | Select-String -Pattern $Pattern -Quiet)) {
        Write-Host "Agregando '$ContentToAdd' a .gitignore..." -ForegroundColor Magenta
        Add-Content $gitignorePath "`n$ContentToAdd"
    }
}

Add-To-Gitignore "^\.env\.*" "# Archivos de variables de entorno locales`n.env.*"
Add-To-Gitignore "^\/node_modules" "# Dependencias de Node`n/node_modules"
Add-To-Gitignore "^\/dist" "# Directorio de build`n/dist"

Write-Host "✓ .gitignore configurado correctamente." -ForegroundColor Green


# --- PASO 3: INSTALACIÓN DE DEPENDENCIAS ---
Write-Host "`n[Paso 3/7] Instalando dependencias del proyecto y de despliegue..." -ForegroundColor Cyan
Write-Host "Instalando dependencias del proyecto con 'npm install' (puede tardar)..." -ForegroundColor Gray
npm install

Write-Host "Instalando 'gh-pages' para el despliegue..." -ForegroundColor Gray
npm install gh-pages --save-dev


# --- PASO 4: CONFIGURACIÓN PARA GITHUB PAGES ---
Write-Host "`n[Paso 4/7] Configurando 'vite.config' y 'package.json' para el despliegue..." -ForegroundColor Cyan

# Modificar vite.config.ts o vite.config.js para agregar la base correcta
$viteConfigPath = if (Test-Path "vite.config.ts") { "vite.config.ts" } elseif (Test-Path "vite.config.js") { "vite.config.js" } else { $null }

if ($viteConfigPath) {
    $viteConfigContent = Get-Content $viteConfigPath -Raw
    if ($viteConfigContent -notmatch "base:") {
        $newViteConfig = $viteConfigContent -replace "(export default defineConfig\(\s*{)", "export default defineConfig({`n  base: '/$repoName/',"
        Set-Content -Path $viteConfigPath -Value $newViteConfig
        Write-Host "✓ '$viteConfigPath' actualizado con la base '/$repoName/'." -ForegroundColor Green
    } else {
        Write-Host "ADVERTENCIA: '$viteConfigPath' ya parece tener una configuración 'base'. Se omitió la modificación." -ForegroundColor Yellow
    }
} else {
    Write-Host "ERROR: No se encontró 'vite.config.ts' ni 'vite.config.js'. No se pudo configurar la base del proyecto." -ForegroundColor Red
    exit
}

# Modificar package.json para agregar los scripts de despliegue
$packageJsonPath = Join-Path $projectPath "package.json"
$packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
if (-not $packageJson.scripts.deploy) {
    $packageJson.scripts.predeploy = "npm run build"
    $packageJson.scripts.deploy = "gh-pages -d dist"
    $packageJson | ConvertTo-Json -Depth 4 | Set-Content $packageJsonPath
    Write-Host "✓ 'package.json' actualizado con los scripts 'predeploy' y 'deploy'." -ForegroundColor Green
} else {
    Write-Host "ADVERTENCIA: 'package.json' ya parece tener scripts de despliegue. Se omitió la modificación." -ForegroundColor Yellow
}


# --- PASO 5: INICIALIZACIÓN Y COMMIT EN GIT ---
Write-Host "`n[Paso 5/7] Preparando el repositorio de Git local..." -ForegroundColor Cyan
if (-not (Test-Path ".git")) {
    git init
    git add .
    git commit -m "Initial commit: Configuración inicial del proyecto para despliegue"
    git branch -M main
    Write-Host "✓ Repositorio Git inicializado y primer commit creado." -ForegroundColor Green
} else {
    Write-Host "✓ Repositorio Git ya existente. Omitiendo inicialización." -ForegroundColor Green
    Write-Host "Por favor, asegúrate de que tus cambios importantes están guardados (commit)." -ForegroundColor Yellow
    git add .
    git commit -m "Chore: Configuración para despliegue en GitHub Pages"
    Write-Host "✓ Cambios de configuración guardados en un nuevo commit." -ForegroundColor Green
}


# --- PASO 6: CREACIÓN Y SUBIDA A GITHUB ---
Write-Host "`n[Paso 6/7] Creando repositorio en GitHub y subiendo el código..." -ForegroundColor Cyan
Write-Host "Se usará GitHub CLI ('gh'). Si no has iniciado sesión ('gh auth login'), el script podría fallar." -ForegroundColor Yellow
try {
    gh repo create $repoName --public --source=. --remote=origin --push
    Write-Host "✓ ¡Repositorio '$repoName' creado y código subido exitosamente!" -ForegroundColor Green
}
catch {
    Write-Host "Error al usar GitHub CLI. Asegúrate de tenerlo instalado y de haber iniciado sesión." -ForegroundColor Red
    Write-Host "Puedes instalarlo desde https://cli.github.com/ y luego ejecutar 'gh auth login'." -ForegroundColor Red
    exit
}


# --- PASO 7: DESPLIEGUE EN GITHUB PAGES ---
Write-Host "`n[Paso 7/7] Desplegando el proyecto en GitHub Pages..." -ForegroundColor Cyan
Write-Host "Este proceso ejecutará 'npm run deploy' y puede tardar un momento..." -ForegroundColor Gray
npm run deploy

Write-Host "`n🎉 ¡Todo listo! 🎉" -ForegroundColor Green
Write-Host "Tu proyecto ha sido desplegado. En unos minutos, debería estar visible en:" -ForegroundColor Green
Write-Host "https://$githubUser.github.io/$repoName/" -ForegroundColor White