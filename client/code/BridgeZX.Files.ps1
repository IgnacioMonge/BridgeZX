# 4. SISTEMA DE ARCHIVOS Y RECURSOS
# ==========================================
function Get-ConfigPath { 
    $appData = [System.Environment]::GetFolderPath('LocalApplicationData')
    $configDir = Join-Path $appData "BridgeZX"
    if (-not (Test-Path $configDir)) { try { New-Item -ItemType Directory -Path $configDir -Force | Out-Null } catch {} }
    return Join-Path $configDir "config.json" 
}

function Load-Config {
    $cfgPath = Get-ConfigPath
    if (Test-Path $cfgPath) {
        try {
            $json = Get-Content $cfgPath -Raw | ConvertFrom-Json
            if ($json.Ip) { $txtIp.Text = $json.Ip }
        } catch {}
    }
}
function Save-Config { $data = @{ Ip = $txtIp.Text }; $data | ConvertTo-Json | Set-Content (Get-ConfigPath) }

# CARGA DE RECURSOS (Solo Base64 - Modo EXE)
function Get-AppIcon {
    if ($null -ne $global:B64_ICON -and $global:B64_ICON -ne "") {
        try {
            $bytes = [Convert]::FromBase64String($global:B64_ICON)
            $ms = New-Object System.IO.MemoryStream($bytes, 0, $bytes.Length)
            # Fix: Usar constructor simple para evitar errores de GDI+
            return [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::FromStream($ms)).GetHicon())
        } catch {}
    }
    return $null
}

function Get-LogoImage {
    if ($null -ne $global:B64_LOGO -and $global:B64_LOGO -ne "") {
        try {
            $bytes = [Convert]::FromBase64String($global:B64_LOGO)
            $ms = New-Object System.IO.MemoryStream($bytes, 0, $bytes.Length)
            return [System.Drawing.Image]::FromStream($ms)
        } catch {}
    }
    return $null
}

# Cargamos en variables globales para usarlas en UI
$global:AppIcon = Get-AppIcon
$global:LogoImage = Get-LogoImage

function New-CircleBitmap([System.Drawing.Color]$color) {
    $bmp = New-Object System.Drawing.Bitmap 14,14
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush $color
    $g.FillEllipse($brush, 1,1,11,11)
    $g.Dispose(); $brush.Dispose()
    return $bmp
}

# --- NUEVO: GESTIÓN DE COLA ---
function Refresh-QueueCache {
    # Recalcula el estado de la cola de archivos
    $state | Add-Member -NotePropertyName "FileErrorMsg" -NotePropertyValue $null -Force
    
    $files = $lstFiles.Items
    if ($files.Count -eq 0) { 
        $state.CachedFileOk = $false
        $state.QueueTotalSize = 0
        return 
    }

    $totalSize = 0
    $allOk = $true
    
    foreach ($item in $files) {
        try {
            # --- CAMBIO: Extraer la ruta real (.Value) del objeto de la lista ---
            # Si es texto antiguo (string) lo usa tal cual, si es objeto usa .Value
            $path = if ($item.Value) { $item.Value } else { $item }
            
            $fi = New-Object System.IO.FileInfo($path)
            if (-not $fi.Exists -or $fi.Length -eq 0) { $allOk = $false; break }
            $totalSize += $fi.Length
        } catch { $allOk = $false; break }
    }

    $state.QueueTotalSize = $totalSize

    if ($totalSize -gt $global:MAX_FILE_SIZE_BYTES) { 
        $state.FileErrorMsg = "Total queue size > $global:MAX_FILE_SIZE_MB MB"
        $state.CachedFileOk = $false
        return
    }

    $state.CachedFileOk = $allOk
}