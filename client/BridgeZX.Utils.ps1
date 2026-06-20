# 3. UTILIDADES
# ==========================================
if (-not ([System.Management.Automation.PSTypeName]'BridgeZX.Crc16Ccitt').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.IO;

namespace BridgeZX {
    public static class Crc16Ccitt {
        public static ushort ComputeFile(string path) {
            ushort crc = 0xFFFF;
            byte[] buffer = new byte[65536];

            using (FileStream fs = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.Read)) {
                int read;
                while ((read = fs.Read(buffer, 0, buffer.Length)) > 0) {
                    for (int i = 0; i < read; i++) {
                        crc = (ushort)(crc ^ (buffer[i] << 8));
                        for (int bit = 0; bit < 8; bit++) {
                            crc = ((crc & 0x8000) != 0)
                                ? (ushort)((crc << 1) ^ 0x1021)
                                : (ushort)(crc << 1);
                        }
                    }
                }
            }

            return crc;
        }
    }
}
"@
}

$script:Crc16Cache = @{}

function Test-NonEmpty([string]$s) { return -not [string]::IsNullOrWhiteSpace($s) }
function Test-Ip([string]$ip) { [System.Net.IPAddress]$addr=$null; return [System.Net.IPAddress]::TryParse($ip, [ref]$addr) }
function Safe-TestPath([string]$path) { if (-not (Test-NonEmpty $path)) { return $false }; return (Test-Path -LiteralPath $path) }
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
    $fi = [System.IO.FileInfo]::new($path)
    $key = "{0}|{1}|{2}" -f $fi.FullName, $fi.Length, $fi.LastWriteTimeUtc.Ticks
    if ($script:Crc16Cache.ContainsKey($key)) { return [UInt16]$script:Crc16Cache[$key] }

    $crc = [BridgeZX.Crc16Ccitt]::ComputeFile($fi.FullName)
    if ($script:Crc16Cache.Count -ge 128) { $script:Crc16Cache.Clear() }
    $script:Crc16Cache[$key] = $crc
    return [UInt16]$crc
}

# ==========================================
