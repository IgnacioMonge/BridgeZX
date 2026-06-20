# build.ps1 - Script de compilacion BridgeZX v0.5.2
$Directorio = $PSScriptRoot
$Salida = Join-Path $Directorio "BridgeZX_FINAL.ps1"

Write-Host "Generando archivo maestro..." -ForegroundColor Cyan

# --- PASO 1: Preparar Recursos (Imagenes a Base64) ---
$RutaIcono = Join-Path $Directorio "bridgezx.ico"
$RutaLogo  = Join-Path $Directorio "bridgezx_logo.png"

$B64_ICON_STR = '""'
$B64_LOGO_STR = '""'

if (Test-Path $RutaIcono) {
    Write-Host "Incrustando Icono..." -ForegroundColor Green
    $Bytes = [System.IO.File]::ReadAllBytes($RutaIcono)
    $B64 = [Convert]::ToBase64String($Bytes)
    $B64_ICON_STR = "`"$B64`""
}

if (Test-Path $RutaLogo) {
    Write-Host "Incrustando Logo..." -ForegroundColor Green
    $Bytes = [System.IO.File]::ReadAllBytes($RutaLogo)
    $B64 = [Convert]::ToBase64String($Bytes)
    $B64_LOGO_STR = "`"$B64`""
}

# --- PASO 2: Construir el Contenido Final ---
$ContenidoFinal = @()
$ContenidoFinal += "# ========================================================"
$ContenidoFinal += "# BRIDGEZX v0.5.1 - VERSION FINAL COMPILADA"
$ContenidoFinal += "# Generado: $(Get-Date)"
$ContenidoFinal += "# ========================================================"
$ContenidoFinal += ""

# --- CORRECCIONES DE ENTORNO EXE ---
$ContenidoFinal += "# 0. CORRECCION DE ENTORNO (CRITICO)"
$ContenidoFinal += 'if (-not $PSScriptRoot) { $PSScriptRoot = [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd("\") }'
$ContenidoFinal += '$ScriptRoot = $PSScriptRoot'
$ContenidoFinal += ""

# --- CARGA DE LIBRERIAS PREVIA ---
$ContenidoFinal += "# 1. CARGA DE LIBRERIAS"
$ContenidoFinal += "Add-Type -AssemblyName System.Windows.Forms"
$ContenidoFinal += "Add-Type -AssemblyName System.Drawing"
$ContenidoFinal += "Add-Type -AssemblyName System.Net.NetworkInformation"
$ContenidoFinal += ""

# --- INYECCION DE RECURSOS ---
$ContenidoFinal += "# 2. RECURSOS INCRUSTADOS"
$ContenidoFinal += "`$global:B64_ICON = $B64_ICON_STR"
$ContenidoFinal += "`$global:B64_LOGO = $B64_LOGO_STR"
$BuildDate = (Get-Date -Format "yyyy-MM-dd HH:mm")
$ContenidoFinal += "`$global:BUILD_DATE = `"$BuildDate`""
$ContenidoFinal += ""

# --- PASO 3: Concatenar Archivos ---
# ORDEN: Config -> Utils -> Files(recursos/cola) -> Network -> UI(controles) -> State(logica) -> Main
$OrdenArchivos = @(
    "BridgeZX.Config.ps1",
    "BridgeZX.Utils.ps1",
    "BridgeZX.Files.ps1",
    "BridgeZX.Network.ps1",
    "BridgeZX.UI.ps1",
    "BridgeZX.State.ps1",
    "BRIDGEZX.ps1"
)

foreach ($archivo in $OrdenArchivos) {
    $ruta = Join-Path $Directorio $archivo
    if (Test-Path $ruta) {
        Write-Host "Procesando: $archivo" -ForegroundColor Green

        $lineas = Get-Content $ruta

        # FILTROS DE LIMPIEZA:
        $lineasFiltradas = $lineas | Where-Object {
            # Quitar carga de scripts externos (dot-sourcing)
            ($_ -notmatch '^\.\s+.*\$ScriptRoot\\BridgeZX\..*\.ps1') -and
            # Quitar Add-Type repetidos
            ($_ -notmatch 'Add-Type -AssemblyName') -and
            # Quitar StrictMode intermedio
            ($_ -notmatch 'Set-StrictMode') -and
            # Quitar intentos de cargar imagenes desde disco
            ($_ -notmatch '\$RutaIcono\s*=\s*Join-Path') -and
            ($_ -notmatch '\$RutaLogo\s*=\s*Join-Path') -and
            # Quitar calculo de ScriptRoot que falla en EXE
            ($_ -notmatch '\$ScriptRoot\s*=\s*Split-Path')
        }

        $ContenidoFinal += "# --- INICIO DE $archivo ---"
        $ContenidoFinal += $lineasFiltradas
        $ContenidoFinal += "# --- FIN DE $archivo ---"
        $ContenidoFinal += ""
    }
}

# Arranque seguro
$ContenidoFinal += "`r`n# Arranque Seguro`r`nif (`$null -eq `$script:form) { Start-BridgeZX }"

$ContenidoFinal | Set-Content $Salida -Encoding UTF8

# --- PASO 4: Validacion sintactica ---
Write-Host "Validando sintaxis..." -ForegroundColor Yellow
$errors = $null
$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $Salida -Raw), [ref]$errors)
if ($errors.Count -gt 0) {
    Write-Host "ADVERTENCIA: Se encontraron $($errors.Count) error(es) de sintaxis:" -ForegroundColor Red
    foreach ($err in $errors) { Write-Host "  Linea $($err.Token.StartLine): $($err.Message)" -ForegroundColor Red }
} else {
    Write-Host "Sintaxis OK" -ForegroundColor Green
}

Write-Host "Hecho! Archivo creado: $Salida" -ForegroundColor Cyan

