# 4. RECURSOS Y COLA DE ARCHIVOS
# ==========================================

# CARGA DE RECURSOS (Solo Base64 - Modo EXE)
function Get-AppIcon {
    if ($null -ne $global:B64_ICON -and $global:B64_ICON -ne "") {
        try {
            $bytes = [Convert]::FromBase64String($global:B64_ICON)
            $ms = New-Object System.IO.MemoryStream($bytes, 0, $bytes.Length)
            # Cargar ICO directamente para preservar multi-resolución (taskbar necesita 256/48/32/16)
            return New-Object System.Drawing.Icon($ms)
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

# --- GESTIÓN DE COLA ---
function Refresh-QueueCache {
    param([switch]$ForceDisk)

    $state.FileErrorMsg = $null

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
            $path = if ($item.PSObject.Properties['Value'] -and $item.Value) { $item.Value } else { $item }
            $size = $null
            $ok = $false

            if (-not $ForceDisk -and $item.PSObject.Properties['SizeBytes'] -and $item.PSObject.Properties['QueueFileOk']) {
                $size = $item.SizeBytes
                $ok = ($item.QueueFileOk -eq $true)
                if (-not $ok -and $item.PSObject.Properties['QueueFileError'] -and $item.QueueFileError) {
                    $state.FileErrorMsg = $item.QueueFileError
                }
            } else {
                $fi = New-Object System.IO.FileInfo($path)
                $size = if ($fi.Exists) { [long]$fi.Length } else { $null }

                if (-not $fi.Exists -or $fi.Length -eq 0) {
                    $ok = $false
                } elseif ($fi.Length -gt $global:MAX_SINGLE_FILE_BYTES) {
                    $state.FileErrorMsg = "$(Split-Path $path -Leaf) exceeds $global:MAX_SINGLE_FILE_MB MB limit"
                    $ok = $false
                } else {
                    $ok = $true
                }

                if ($item.PSObject.Properties['SizeBytes']) { $item.SizeBytes = $size }
                if ($item.PSObject.Properties['QueueFileOk']) { $item.QueueFileOk = $ok }
                if ($item.PSObject.Properties['QueueFileError']) { $item.QueueFileError = $state.FileErrorMsg }
                if ($item.PSObject.Properties['Label'] -and $fi.Exists) {
                    $item.Label = "{0}  [{1}]" -f (Split-Path $path -Leaf), (Format-Bytes $size)
                }
            }

            if (-not $ok) { $allOk = $false; break }
            $totalSize += [long]$size
        } catch { $allOk = $false; break }
    }

    $state.QueueTotalSize = $totalSize
    $state.CachedFileOk = $allOk
}
