# ===================================================================
# Script para Desplegar un Proyecto Vite en GitHub Pages
# ===================================================================

# --- CONFIGURACIÓN INICIAL ---
$projectPath = "C:\Users\Administrador\Desktop\mascotas"

# --- Pide la información necesaria al usuario ---
Write-Host "Este script preparará y desplegará tu proyecto Vite en GitHub Pages." -ForegroundColor Yellow
$githubUser = Read-Host "Por favor, ingresa tu nombre de usuario de GitHub"
$repoName = Read-Host "Ingresa el nombre para tu nuevo repositorio en GitHub (ej. mi-proyecto-mascotas)"

# --- PASO 1: VERIFICACIÓN DE PREREQUISITOS Y SEGURIDAD ---
Write-Host "`n[Paso 1/6] Verificando prerequisitos y seguridad..." -ForegroundColor Cyan

# Navegar a la ruta del proyecto
try {
    cd $projectPath
    Write-Host "Ubicado en: $projectPath" -ForegroundColor Green
}
catch {
    Write-Host "Error: La ruta del proyecto '$projectPath' no existe. Por favor, actualiza la variable `$projectPath` en el script." -ForegroundColor Red
    exit
}

# Verificar que .gitignore existe y contiene .env.local
$gitignorePath = Join-Path $projectPath ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    Write-Host "Creando archivo .gitignore..." -ForegroundColor Yellow
    New-Item ".gitignore" | Out-Null
}

$gitignoreContent = Get-Content $gitignorePath
if (-not ($gitignoreContent | Select-String -Pattern "^\.env.*" -Quiet)) {
    Write-Host "IMPORTANTE: Agregando '.env.*' a tu .gitignore para proteger tus variables de entorno." -ForegroundColor Magenta
    Add-Content $gitignorePath "`n# Archivos de variables de entorno locales`n.env.*"
}

if (-not ($gitignoreContent | Select-String -Pattern "^node_modules" -Quiet)) {
    Write-Host "Agregando 'node_modules' a tu .gitignore..." -ForegroundColor Magenta
    Add-Content $gitignorePath "`n# Dependencias`n/node_modules"
}

if (-not ($gitignoreContent | Select-String -Pattern "^dist" -Quiet)) {
    Write-Host "Agregando 'dist' a tu .gitignore..." -ForegroundColor Magenta
    Add-Content $gitignorePath "`n# Directorio de build`n/dist"
}


# --- PASO 2: INSTALACIÓN DE DEPENDENCIAS ---
Write-Host "`n[Paso 2/6] Instalando dependencias del proyecto y de despliegue..." -ForegroundColor Cyan
Write-Host "Esto puede tardar unos minutos..." -ForegroundColor Gray
npm install
npm install gh-pages --save-dev


# --- PASO 3: CONFIGURACIÓN PARA GITHUB PAGES ---
Write-Host "`n[Paso 3/6] Configurando 'vite.config.ts' y 'package.json' para el despliegue..." -ForegroundColor Cyan

# Modificar vite.config.ts para agregar la base correcta
$viteConfigPath = Join-Path $projectPath "vite.config.ts"
$viteConfigContent = Get-Content $viteConfigPath -Raw
if (-not ($viteConfigContent.Contains("base:"))) {
    $newViteConfig = $viteConfigContent -replace "(export default defineConfig\({)", "export default defineConfig({\n  base: '/$repoName/',"
    Set-Content -Path $viteConfigPath -Value $newViteConfig
    Write-Host "'vite.config.ts' actualizado con la base '/$repoName/'." -ForegroundColor Green
} else {
    Write-Host "'vite.config.ts' ya parece tener una configuración 'base'." -ForegroundColor Yellow
}

# Modificar package.json para agregar los scripts de despliegue
$packageJsonPath = Join-Path $projectPath "package.json"
$packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
if (-not $packageJson.scripts.predeploy) {
    $packageJson.scripts | Add-Member -MemberType NoteProperty -Name "predeploy" -Value "npm run build"
    $packageJson.scripts | Add-Member -MemberType NoteProperty -Name "deploy" -Value "gh-pages -d dist"
    $packageJson | ConvertTo-Json -Depth 4 | Set-Content $packageJsonPath
    Write-Host "'package.json' actualizado con los scripts 'predeploy' y 'deploy'." -ForegroundColor Green
} else {
    Write-Host "'package.json' ya parece tener scripts de despliegue." -ForegroundColor Yellow
}


# --- PASO 4: INICIALIZACIÓN DE GIT ---
Write-Host "`n[Paso 4/6] Inicializando el repositorio de Git local..." -ForegroundColor Cyan
git init
git add .
git commit -m "Initial commit: Setup project structure"
git branch -M main


# --- PASO 5: SUBIDA A GITHUB ---
Write-Host "`n[Paso 5/6] Creando repositorio en GitHub y subiendo el código..." -ForegroundColor Cyan
Write-Host "Necesitarás tener instalado el 'GitHub CLI'. Si no lo tienes, el script se detendrá." -ForegroundColor Yellow
try {
    gh repo create "$githubUser/$repoName" --public --source=. --push
    Write-Host "¡Repositorio creado y código subido exitosamente!" -ForegroundColor Green
}
catch {
    Write-Host "Error al usar GitHub CLI. Asegúrate de tenerlo instalado y de haber iniciado sesión ('gh auth login')." -ForegroundColor Red
    exit
}


# --- PASO 6: DESPLIEGUE EN GITHUB PAGES ---
Write-Host "`n[Paso 6/6] Desplegando el proyecto en GitHub Pages..." -ForegroundColor Cyan
Write-Host "Este proceso ejecutará 'npm run deploy' y puede tardar un momento." -ForegroundColor Gray
npm run deploy

Write-Host "`n🎉 ¡Todo listo! 🎉" -ForegroundColor Green
Write-Host "Tu proyecto ha sido desplegado. En unos minutos, debería estar visible en:" -ForegroundColor Green
Write-Host "https://$githubUser.github.io/$repoName/" -ForegroundColor White