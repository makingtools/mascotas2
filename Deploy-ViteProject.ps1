# ========================================================================
# Script Definitivo para Desplegar un Proyecto Vite en GitHub Pages
# Versión Mejorada: Más robusta, clara y confiable.
# ========================================================================

# --- CONFIGURACIÓN INICIAL ---
$projectPath = "C:\Users\Administrador\Desktop\mascotas"

# --- PASO 0: VERIFICACIÓN DE HERRAMIENTAS INDISPENSABLES ---
Write-Host "[Paso 0/7] Verificando que 'git' y 'gh' (GitHub CLI) estén instalados..." -ForegroundColor Cyan

$gitCheck = Get-Command git -ErrorAction SilentlyContinue
$ghCheck = Get-Command gh -ErrorAction SilentlyContinue

if (-not $gitCheck) {
    Write-Host "ERROR: Git no está instalado o no se encuentra en el PATH." -ForegroundColor Red
    Write-Host "Por favor, instala Git desde https://git-scm.com/ y vuelve a intentarlo." -ForegroundColor Yellow
    exit
}

if (-not $ghCheck) {
    Write-Host "ERROR: GitHub CLI (gh) no está instalado o no se encuentra en el PATH." -ForegroundColor Red
    Write-Host "Por favor, instala GitHub CLI desde https://cli.github.com/ y autentícate con 'gh auth login'." -ForegroundColor Yellow
    exit
}

Write-Host "¡Herramientas verificadas correctamente!" -ForegroundColor Green


# --- Pide la información necesaria al usuario ---
Write-Host "`nEste script desplegará tu proyecto Vite en GitHub Pages." -ForegroundColor Yellow
$githubUser = Read-Host "Paso A: Ingresa tu nombre de usuario de GitHub"
$repoName = Read-Host "Paso B: Ingresa el nombre para tu nuevo repositorio (ej. mi-app-vite)"


# --- PASO 1: NAVEGACIÓN Y SEGURIDAD ---
Write-Host "`n[Paso 1/7] Navegando al proyecto y configurando .gitignore..." -ForegroundColor Cyan
try {
    cd $projectPath
    Write-Host "Ubicado en: $projectPath" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: La ruta del proyecto '$projectPath' no existe. Actualiza la variable e inténtalo de nuevo." -ForegroundColor Red
    exit
}

# Configuración de .gitignore
$gitignorePath = ".gitignore"
if (-not (Test-Path $gitignorePath)) { New-Item $gitignorePath | Out-Null }
$gitignoreContent = Get-Content $gitignorePath
if (-not ($gitignoreContent | Select-String -Pattern "^/dist" -Quiet)) { Add-Content $gitignorePath "`n# Build output`n/dist" }
if (-not ($gitignoreContent | Select-String -Pattern "^/node_modules" -Quiet)) { Add-Content $gitignorePath "`n# Dependencies`n/node_modules" }
if (-not ($gitignoreContent | Select-String -Pattern "^\.env" -Quiet)) { Add-Content $gitignorePath "`n# Environment variables`n.env*`n!.env.example" }


# --- PASO 2: INSTALACIÓN DE DEPENDENCIAS ---
Write-Host "`n[Paso 2/7] Instalando dependencias (npm install)..." -ForegroundColor Cyan
npm install
Write-Host "`n[Paso 3/7] Instalando 'gh-pages' para el despliegue..." -ForegroundColor Cyan
npm install gh-pages --save-dev


# --- PASO 4: CONFIGURACIÓN DE ARCHIVOS DEL PROYECTO ---
Write-Host "`n[Paso 4/7] Configurando 'vite.config.ts' y 'package.json'..." -ForegroundColor Cyan

# Modificar vite.config.ts para añadir la propiedad 'base'
$viteConfigPath = "vite.config.ts"
if (Test-Path $viteConfigPath) {
    $viteConfigContent = Get-Content $viteConfigPath -Raw
    if (-not ($viteConfigContent -match 'base:\s*')) {
        $pattern = '(defineConfig\s*\(\s*{)'
        $replacement = "$1`n  base: '/$repoName/',"
        $newViteConfig = $viteConfigContent -replace $pattern, $replacement
        Set-Content -Path $viteConfigPath -Value $newViteConfig
        Write-Host "'vite.config.ts' actualizado." -ForegroundColor Green
    }
}

# Modificar package.json para añadir 'homepage' y scripts de despliegue
$packageJsonPath = "package.json"
$packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
$packageJson.homepage = "https://$githubUser.github.io/$repoName"
if (-not $packageJson.scripts.predeploy) {
    $packageJson.scripts | Add-Member -MemberType NoteProperty -Name "predeploy" -Value "npm run build"
    $packageJson.scripts | Add-Member -MemberType NoteProperty -Name "deploy" -Value "gh-pages -d dist"
}
$packageJson | ConvertTo-Json -Depth 5 | Set-Content $packageJsonPath
Write-Host "'package.json' actualizado con 'homepage' y scripts." -ForegroundColor Green


# --- PASO 5: INICIALIZACIÓN Y COMMIT LOCAL ---
Write-Host "`n[Paso 5/7] Preparando el repositorio local de Git..." -ForegroundColor Cyan
git init
git add .
git commit -m "Initial commit: Project setup and configuration for GitHub Pages"
git branch -M main
Write-Host "Repositorio local inicializado y primer commit creado." -ForegroundColor Green


# --- PASO 6: CREACIÓN, CONEXIÓN Y SUBIDA A GITHUB ---
Write-Host "`n[Paso 6/7] Subiendo tu código a GitHub..." -ForegroundColor Cyan
try {
    # 1. Crear el repositorio VACÍO en GitHub
    Write-Host " - Creando repositorio '$repoName' en GitHub..." -ForegroundColor Gray
    gh repo create "$repoName" --public --source=. --remote=origin --push
    gh repo create "$repoName" --public
    
    # 2. Conectar tu repositorio local con el de GitHub
    $repoUrl = "https://github.com/$githubUser/$repoName.git"
    Write-Host " - Conectando el repositorio local al remoto ($repoUrl)..." -ForegroundColor Gray
    git remote add origin $repoUrl
    
    # 3. Subir los archivos a la rama 'main'
    Write-Host " - Subiendo los archivos a la rama 'main'..." -ForegroundColor Gray
    git push -u origin main

    Write-Host "¡Código fuente subido a GitHub exitosamente!" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Ocurrió un problema al subir el código a GitHub." -ForegroundColor Red
    Write-Host "Posibles causas: Ya existe un repositorio con ese nombre, o problemas de autenticación con 'gh'."
    Write-Host "Revisa tu conexión y que hayas iniciado sesión con 'gh auth login'." -ForegroundColor Yellow
    exit
}


# --- PASO 7: DESPLIEGUE FINAL EN GITHUB PAGES ---
Write-Host "`n[Paso 7/7] Desplegando el proyecto en GitHub Pages..." -ForegroundColor Cyan
Write-Host "Ejecutando 'npm run deploy'. Esto compilará el proyecto y lo publicará." -ForegroundColor Gray
npm run deploy

Write-Host "`n`n🎉 ¡PROCESO COMPLETADO! 🎉" -ForegroundColor Green
Write-Host "Tu sitio estará disponible en unos minutos en la siguiente URL:" -ForegroundColor White
Write-Host "https://$githubUser.github.io/$repoName/" -ForegroundColor Cyan