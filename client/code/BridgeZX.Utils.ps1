# 3. UTILIDADES
# ==========================================
function Is-NonEmpty([string]$s) { return -not [string]::IsNullOrWhiteSpace($s) }
function Test-Ip([string]$ip) { [System.Net.IPAddress]$addr=$null; return [System.Net.IPAddress]::TryParse($ip, [ref]$addr) }
function Safe-TestPath([string]$path) { if (-not (Is-NonEmpty $path)) { return $false }; return (Test-Path -LiteralPath $path) }
function Safe-FileLength([string]$path) { if (-not (Safe-TestPath $path)) { return $null }; try { return (Get-Item -LiteralPath $path).Length } catch { return $null } }

# --- Normalizador 8.3 con soporte para sufijo de colisión ---
function Normalize-Filename([string]$path, [int]$suffix = 0) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($path)
    $ext  = [System.IO.Path]::GetExtension($path).ToUpper()
    
    if ([string]::IsNullOrWhiteSpace($base)) { $base = "FILE" }
    
    # Limpieza de caracteres (A-Z, 0-9, _)
    $base = $base.ToUpperInvariant() -replace "[^A-Z0-9_]", "_"
    
    # Recortar extensión a 4 caracteres (.EXT)
    if ($ext.Length -gt 4) { $ext = $ext.Substring(0, 4) }
    
    if ($suffix -gt 0) {
        # Reservar espacio para el sufijo (máx 2 dígitos: 1-99)
        $suffixStr = "$suffix"
        $maxBase = 8 - $suffixStr.Length
        if ($base.Length -gt $maxBase) { $base = $base.Substring(0, $maxBase) }
        $base = "$base$suffixStr"
    } else {
        if ($base.Length -gt 8) { $base = $base.Substring(0, 8) }
    }
    
    return "$base$ext"
}

# --- Resolver colisiones en lista de archivos ---
function Resolve-FilenameCollisions([array]$paths) {
    $result = @{}          # path -> nombre normalizado final
    $usedNames = @{}       # nombre normalizado -> contador
    
    foreach ($path in $paths) {
        $baseName = Normalize-Filename $path 0
        
        if ($usedNames.ContainsKey($baseName)) {
            # Colisión - buscar sufijo libre
            $suffix = $usedNames[$baseName] + 1
            $newName = Normalize-Filename $path $suffix
            
            # Asegurar que el nuevo nombre tampoco colisione
            while ($usedNames.ContainsKey($newName) -and $suffix -lt 99) {
                $suffix++
                $newName = Normalize-Filename $path $suffix
            }
            
            $usedNames[$baseName] = $suffix
            $usedNames[$newName] = 0
            $result[$path] = $newName
        } else {
            $usedNames[$baseName] = 0
            $result[$path] = $baseName
        }
    }
    
    return $result
}

function Get-Crc16Ccitt([string]$path) {
    $fs = $null
    try {
        $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $crc = 0xFFFF; $buf = New-Object byte[] 8192
        while (($read = $fs.Read($buf, 0, $buf.Length)) -gt 0) {
            for ($i = 0; $i -lt $read; $i++) {
                $crc = $crc -bxor (([int]$buf[$i]) -shl 8)
                for ($bit = 0; $bit -lt 8; $bit++) {
                    if (($crc -band 0x8000) -ne 0) { $crc = ($crc -shl 1) -bxor 0x1021 } else { $crc = ($crc -shl 1) }
                    $crc = $crc -band 0xFFFF
                }
            }
        }
        return [UInt16]$crc
    } finally { if ($fs) { $fs.Close(); $fs.Dispose() } }
}

# ==========================================
