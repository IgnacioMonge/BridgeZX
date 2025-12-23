# ========================================================
# BRIDGEZX - VERSION FINAL COMPILADA
# Generado: 12/23/2025 23:11:17
# ========================================================

# 0. CORRECCION DE ENTORNO (CRITICO)
if (-not $PSScriptRoot) { $PSScriptRoot = [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd("\") }
$ScriptRoot = $PSScriptRoot

# 1. CARGA DE LIBRERIAS
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.NetworkInformation

# 2. RECURSOS INCRUSTADOS
$global:B64_ICON = "AAABAAEAMDAQAAEABABoBgAAFgAAACgAAAAwAAAAYAAAAAEABAAAAAAAAAYAAAAAAAAAAAAAAAAAAAAAAAAIBQcAiqAWAA0TxgBLo8kAVmBDAHri7wAScqoA+NMkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAiIABkBGADAEEUAAARAAAEAANVQEMABUAgAgA0RkAFABEBQAFAQAAAAAVEQAMwVAIiIgBjNgAFQBQBEAEEdABAAAQwAABjQAAiIgAzZkAFABQEEAcEQAAAAABGQABDQAIgIgBmBmAFABFEQARAQABAAARFQAMwNAAiIABjNgADAEEUAAAREAAAAANVQEMAA0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAXEAAAAAADZjZmZjZmY2NgAAAAAAAAAAF3RERAAANmUzU1NTU1MzM2AAAAAAAAAHd3d3ERRANmU1MzMzMzMzMzAAAAAAAABHd3dxEURAY0VVVVNTMzUzU1YAAAAAAAABd3d3cRRAAyZVVVVVVVNTMzUAAAAAAAAAR3AAAAAABjRVVVVVVVVVVVVAAAAAAAAABHEAAGAABDIzVVVVVVVVVVUwAAAAAAAAAAQABlUAAGZlVVVVVVVVVVVUAAAAAAAAAEAEBFVUAGNFVVVVVVVVVVVTAAAAAAAiYzVVVVVVYANmVVVVVVVVVVVVQAAAAAAiJjNVVVVVUAY0ZjQ0NFVVVVVVQAAAAAAiZjNVVVVVAAAzY2NmY0VVVVVVUAAAAAAgIkZGZFVQAABlVVVVVUMzNVVVUAAAAAAAAAAABFVAAABDMzNjZTRERGM2AAAAAAAAAAAABFAAAAAAAAAABVVVVTUwAAAAAAAAAABAAAAAAAAAAAAABVVVUwQAAAAAAAAAAEVVVVQAAAAAQzM1Q1VVUwAAAAAAAAAAAEU1U1QAAAAAVVVVNVVVUAAAAAAAAAAAAEVTU1QAQEAAVVNVNFNTAAAAAAAAAAAAAEVVVVA1VVVQNTU1MAAAAAAAAAAAAAAAAEVVVVQ1MzVQVVVVMAAAAAAAAAAAAAAAAEVVVVRFVVVQVVVVUAAAAAAAAAAAAAAAAEVVVTA1VTVQVVVVQAAAAAAAAAAAAAAAAEVVVQA1VVVQVVVTAAAAAAAAAAAAAAAAAAQEAAA1VVVQRkZAAAAAAAAAAAAAAAAAAAAAAAA1VVVAAAAAAAAAAAAAAAAAAAAAAAAAAABlVVQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
$global:B64_LOGO = "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"

# --- INICIO DE BridgeZX.Config.ps1 ---
# 2. CONFIGURACIÃ“N
# ==========================================
$cfg = [pscustomobject]@{
    # NETWORK
    SOCKET_BUFFER_SIZE = 8192 
    CONN_FAIL_THRESHOLD = 2
    CONN_GRACE_MS = 3000
    LAIN_PORT = 6144
    
    # TRANSFERENCIA
    DESIRED_SEND_RATE_KBPS = 4
    TIMER_INTERVAL_MS = 50
    CHUNK_SIZE = 1024
    
    # TIMEOUTS
    CONNECT_TOTAL_TIMEOUT_MS = 30000
    CONNECT_RETRY_EVERY_MS = 250
    WAIT_ACK_TIMEOUT_MS = 120000
    SEND_STALL_TIMEOUT_MS = 10000
    CLOSE_GRACE_DELAY_MS = 650
    
    # SONDEO
    CONNECTION_CHECK_INTERVAL_MS = 3000
    CONNECTION_CHECK_TIMEOUT_MS = 1000
    CONNECTION_POLL_INTERVAL_MS = 100
    PING_TIMEOUT_MS = 600
    STATS_UPDATE_INTERVAL_MS = 400
    FILE_CACHE_DURATION_MS = 2000
    # Auto-connection probe intervals (ms)
    CONN_INTERVAL_PORT_CLOSED_MS    = 500    # IP reachable but LAIN/BridgeZX port closed
    CONN_INTERVAL_OPEN_NOTREADY_MS  = 1200   # Port open but app not in Ready state
    CONN_INTERVAL_OPEN_READY_MS     = 3500   # Stable Ready state, low-frequency probing
}

# Constantes derivadas (AHORA GLOBALES)
$global:LAIN_PORT = $cfg.LAIN_PORT
$global:CHUNK_SIZE = $cfg.CHUNK_SIZE
$global:MAX_BYTES_PER_TICK = [int][Math]::Max(128, [Math]::Floor($cfg.DESIRED_SEND_RATE_KBPS * 1024 * ($cfg.TIMER_INTERVAL_MS / 1000.0)))
$global:MAX_FILE_SIZE_MB = 2.0
$global:MAX_FILE_SIZE_BYTES = $global:MAX_FILE_SIZE_MB * 1048576

# ==========================================
# --- FIN DE BridgeZX.Config.ps1 ---

# --- INICIO DE BridgeZX.Utils.ps1 ---
# 3. UTILIDADES
# ==========================================
function Is-NonEmpty([string]$s) { return -not [string]::IsNullOrWhiteSpace($s) }
function Test-Ip([string]$ip) { [System.Net.IPAddress]$addr=$null; return [System.Net.IPAddress]::TryParse($ip, [ref]$addr) }
function Safe-TestPath([string]$path) { if (-not (Is-NonEmpty $path)) { return $false }; return (Test-Path -LiteralPath $path) }
function Safe-FileLength([string]$path) { if (-not (Safe-TestPath $path)) { return $null }; try { return (Get-Item -LiteralPath $path).Length } catch { return $null } }

# --- Normalizador 8.3 con soporte para sufijo de colisiÃ³n ---
function Normalize-Filename([string]$path, [int]$suffix = 0) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($path)
    $ext  = [System.IO.Path]::GetExtension($path).ToUpper()
    
    if ([string]::IsNullOrWhiteSpace($base)) { $base = "FILE" }
    
    # Limpieza de caracteres (A-Z, 0-9, _)
    $base = $base.ToUpperInvariant() -replace "[^A-Z0-9_]", "_"
    
    # Recortar extensiÃ³n a 4 caracteres (.EXT)
    if ($ext.Length -gt 4) { $ext = $ext.Substring(0, 4) }
    
    if ($suffix -gt 0) {
        # Reservar espacio para el sufijo (mÃ¡x 2 dÃ­gitos: 1-99)
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
            # ColisiÃ³n - buscar sufijo libre
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
# --- FIN DE BridgeZX.Utils.ps1 ---

# --- INICIO DE BridgeZX.Files.ps1 ---
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

# --- NUEVO: GESTIÃ“N DE COLA ---
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
# --- FIN DE BridgeZX.Files.ps1 ---

# --- INICIO DE BridgeZX.Network.ps1 ---
# 5. LÃ“GICA DE RED (Compatible LAIN/SnapZX)
# ==========================================
function Test-LainAppHandshake {
    param([string]$Ip, [int]$Port = $LAIN_PORT, [string]$ProbeName = "PING", [int]$TimeoutMs = 800)
    $oldEap = $ErrorActionPreference; $ErrorActionPreference = 'Stop'
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($Ip, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $client.EndConnect($iar) | Out-Null; $client.NoDelay = $true
        $ns = $client.GetStream(); $ns.ReadTimeout = $TimeoutMs; $ns.WriteTimeout = $TimeoutMs
        
        $nameBytes = [System.Text.Encoding]::ASCII.GetBytes($ProbeName)
        if ($nameBytes.Length -gt 255) { $nameBytes = $nameBytes[0..254] }
        $nlen = [int]$nameBytes.Length
        
        # --- PROTOCOLO V2 (15 Bytes Header) ---
        # Estructura: LAIN(4) + Size(4) + CRC(2) + FN(2) + Idx(1) + Tot(1) + NameLen(1)
        $hdr = New-Object byte[] (15 + $nlen)
        
        # Magic "LAIN"
        $hdr[0]=0x4C; $hdr[1]=0x41; $hdr[2]=0x49; $hdr[3]=0x4E; 
        
        # Marker "FN"
        $hdr[10]=0x46; $hdr[11]=0x4E; 
        
        # Metadatos V2 (Dummy para Handshake)
        $hdr[12]=1  # Index
        $hdr[13]=1  # Total
        
        # Name Length
        $hdr[14]=[byte]$nlen
        
        if ($nlen -gt 0) { [Array]::Copy($nameBytes, 0, $hdr, 15, $nlen) }
        
        $ns.Write($hdr, 0, $hdr.Length); $ns.Flush()
        
        # Esperar respuesta
        $buf = New-Object byte[] 64; $t0 = [Environment]::TickCount
        while ([Environment]::TickCount - $t0 -lt $TimeoutMs) {
            if (-not $ns.DataAvailable) { Start-Sleep -Milliseconds 30; continue }
            $r = $ns.Read($buf, 0, $buf.Length)
            if ($r -le 0) { break }
            for ($i = 0; $i -lt $r; $i++) { if ($buf[$i] -eq 0x06) { return $true } }
            if ($r -lt 10) { 
                try { $acc += [System.Text.Encoding]::ASCII.GetString($buf, 0, $r) } catch { }
                if ($acc.Contains("OK") -or $acc.Contains("ACK")) { return $true } 
            }
        }
        return $false
    } catch { return $false } finally { try { if ($client) { $client.Close(); $client.Dispose() } } catch { } }
}

function Apply-ButtonStyle {
    param($btn, $color)
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0; $btn.BackColor = $color; $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9); $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
}

# ==========================================
# --- FIN DE BridgeZX.Network.ps1 ---

# --- INICIO DE BridgeZX.State.ps1 ---
# 7. MÃQUINA DE ESTADOS Y LÃ“GICA (MULTI-FILE ROBUSTO V2)
# ==========================================
$timer=New-Object System.Windows.Forms.Timer; $timer.Interval=$cfg.TIMER_INTERVAL_MS
$connectionTimer=New-Object System.Windows.Forms.Timer; $connectionTimer.Interval=$cfg.CONNECTION_POLL_INTERVAL_MS
$script:TransferBlinkTimer=New-Object System.Windows.Forms.Timer; $script:TransferBlinkTimer.Interval=350; $script:TransferBlinkVisible=$true
$script:IsProcessingTick = $false

$state=[pscustomobject]@{
    Phase="Idle"; Ip=$null; 
    TransferQueue=@(); CurrentFileIndex=0; TotalQueueFiles=0; CurrentFileName=""; FilenameMap=@{};
    
    # Propiedad QueueTotalSize (Corregido)
    QueueTotalSize=0; 
    
    Bytes=$null; HeaderBytes=$null; HeaderSent=0; FileStream=$null; SendBuf=$null; SendBufOffset=0; SendBufCount=0; SendBufIsHeader=$false
    Total=0; HeaderLen=0; PayloadLen=0; Sent=0; Client=$null; Sock=$null; ConnectAR=$null; ConnectStartUtc=[DateTime]::MinValue; NextRetryUtc=[DateTime]::MinValue; WaitStartUtc=[DateTime]::MinValue
    TransferStartUtc=[DateTime]::MinValue; LastSendProgressUtc=[DateTime]::MinValue; LastStatsUpdate=[DateTime]::UtcNow; ProgressStarted=$false; UiProgress=0.0; TargetProgress=0.0; LastTickUtc=[DateTime]::UtcNow
    CloseObservedUtc=[DateTime]::MinValue; AckReceived=$false; AckBuffer=""; Cancelled=$false; IsCheckingConnection=$false; TransferActive=$false; IpAlive=$false; PortStatus="Unknown"; AppStatus="Unknown"
    AutoProbeSuspended=$false; LastAutoProbeIp=""; LastHandshakeUtc=[DateTime]::MinValue; LastPortProbeUtc=[DateTime]::MinValue; LastConnectionCheckUtc=[DateTime]::MinValue
    CachedFilePath=""; CachedFileOk=$null; CachedTransName=""; FileCacheLastCheckTicks=0; ConnCheckPhase="Idle"; ConnCheckIp=$null; ConnCheckForceProbe=$false; ConnCheckSkipHandshake=$false
    LastOpenVerifyUtc=[DateTime]::MinValue; ConnCheckStartUtc=[DateTime]::MinValue; NextAutoConnCheckUtc=[DateTime]::MinValue; PingTask=$null; ProbeClient=$null; ProbeTask=$null; ProbeAR=$null; ProbeStartUtc=[DateTime]::MinValue
    ConnFailCount=0; ConnFailThreshold=$cfg.CONN_FAIL_THRESHOLD; ConnGraceMs=$cfg.CONN_GRACE_MS; LastConnectedUtc=[DateTime]::MinValue
    
    # Bandera de cancelaciÃ³n
    LastTransferCancelled=$false;
    
    Path=$null
}
$script:StateLock=New-Object object
function Invoke-WithStateLock { param([scriptblock]$Action); [System.Threading.Monitor]::Enter($script:StateLock); try { & $Action } finally { [System.Threading.Monitor]::Exit($script:StateLock) } }

# --- LOGICA ---
function Start-ConnectionCheck([string]$ip, [bool]$forcePortProbe=$false, [bool]$skipHandshake=$false) {
    if ($state.Phase -ne "Idle" -or $state.TransferActive) { return }
    $now=[DateTime]::UtcNow
    if (-not $forcePortProbe -and $state.ConnCheckPhase -eq "Idle" -and $state.LastConnectionCheckUtc -ne [DateTime]::MinValue -and ($now-$state.LastConnectionCheckUtc).TotalMilliseconds -lt 250) { return }
    if ($state.ConnCheckPhase -ne "Idle") { $state.ConnCheckForceProbe = ($state.ConnCheckForceProbe -or $forcePortProbe); return }
    if (-not (Test-Ip $ip)) { Apply-ConnIndicatorStable "Gray" "Invalid IP"; $state.IpAlive=$false; $state.PortStatus="Unknown"; Update-Buttons-State; return }
    $state.IsCheckingConnection=$true; $state.ConnCheckIp=$ip; $state.ConnCheckForceProbe=$forcePortProbe; $state.ConnCheckSkipHandshake=$skipHandshake; $state.ConnCheckPhase="Pinging"; $state.ConnCheckStartUtc=$now; $state.LastConnectionCheckUtc=$now; $state.PingTask=$null; $state.IpAlive=$true
    if ($connectionTimer.Interval -ne $cfg.CONNECTION_POLL_INTERVAL_MS) { $connectionTimer.Interval = $cfg.CONNECTION_POLL_INTERVAL_MS }
}

function End-ConnectionCheck {
    $state.ConnCheckPhase="Idle"; $state.ConnCheckForceProbe=$false; $state.ConnCheckSkipHandshake=$false; $state.ConnCheckIp=$null; $state.IsCheckingConnection=$false; $state.PingTask=$null; $state.ProbeTask=$null
    try { if ($state.ProbeClient) { $state.ProbeClient.Close() } } catch { }; $state.ProbeClient=$null
    $state.AutoProbeSuspended = ($state.PortStatus -eq "Open" -and $state.AppStatus -eq "Ready")
    $nextMs = if ($state.PortStatus -ne "Open") { $cfg.CONN_INTERVAL_PORT_CLOSED_MS } elseif ($state.AppStatus -ne "Ready") { $cfg.CONN_INTERVAL_OPEN_NOTREADY_MS } else { $cfg.CONN_INTERVAL_OPEN_READY_MS }
    if ($connectionTimer.Interval -ne [int]$nextMs) { $connectionTimer.Interval = [int]$nextMs }
    $state.NextAutoConnCheckUtc = [DateTime]::UtcNow.AddMilliseconds([int]$nextMs)
    Update-Buttons-State
}

function Process-ConnectionCheckState {
    if (-not (Get-Variable -Name state -Scope Script -ErrorAction SilentlyContinue)) { return }
    if ($state.Phase -ne "Idle" -or $state.TransferActive) { return }
    $now=[DateTime]::UtcNow
    switch ($state.ConnCheckPhase) {
        "Idle" {
            if ($now -lt $state.NextAutoConnCheckUtc) { return }
            $ip=$txtIp.Text.Trim(); if ($ip -ne $state.LastAutoProbeIp) { $state.LastAutoProbeIp=$ip; $state.AutoProbeSuspended=$false; Start-ConnectionCheck -ip $ip -forcePortProbe:$true; return }
            if ($state.AutoProbeSuspended -and $state.PortStatus -eq "Open") { if ($state.LastOpenVerifyUtc -eq [DateTime]::MinValue -or (($now-$state.LastOpenVerifyUtc).TotalMilliseconds -ge 3500)) { $state.LastOpenVerifyUtc=$now; Start-ConnectionCheck -ip $ip -forcePortProbe:$true -skipHandshake:$false; return }; $state.NextAutoConnCheckUtc=$now.AddMilliseconds(3500); return }
            Start-ConnectionCheck -ip $ip -forcePortProbe:$false; return
        }
        "Pinging" {
            $state.PingTask=$null; $state.IpAlive=$true; $needProbe=$state.ConnCheckForceProbe -or $state.PortStatus -eq "Unknown" -or (($now-$state.LastPortProbeUtc).TotalMilliseconds -ge 1500)
            if (-not $needProbe) { End-ConnectionCheck; return }
            $state.LastPortProbeUtc=$now; try { $state.ProbeClient=New-Object System.Net.Sockets.TcpClient; $state.ProbeAR=$state.ProbeClient.BeginConnect($state.ConnCheckIp, $global:LAIN_PORT, $null, $null); $state.ProbeStartUtc=$now; $state.ConnCheckPhase="Probing" } catch { $state.PortStatus="Closed"; $state.AppStatus="Unknown"; Apply-ConnIndicatorStable "Yellow" "Port closed"; End-ConnectionCheck }; return
        }
        "Probing" {
            if ($state.ProbeAR) {
                if ($state.ProbeAR.IsCompleted) {
                    $ok=$false; try { $state.ProbeClient.EndConnect($state.ProbeAR); $ok=$true } catch { }
                    $state.PortStatus = if ($ok) { "Open" } else { "Closed" }
                    
                    if ($state.PortStatus -eq "Open") { 
                        # 1. Intentamos el handshake
                        $hsOk=$false; 
                        try { $hsOk=Test-LainAppHandshake -Ip $state.ConnCheckIp -Port $global:LAIN_PORT } catch { }; 
                        $state.AppStatus = if ($hsOk) { "Ready" } else { "NotRunning" }
                        $state.LastHandshakeUtc=$now

                        # 2. FIX: Solo reseteamos la cancelaciÃ³n SI el handshake es OK (Servidor 100% listo)
                        if ($hsOk) { $state.LastTransferCancelled = $false }

                    } else { 
                        $state.AppStatus="Unknown" 
                    }

                    # 3. Actualizar indicadores visuales
                    if ($state.PortStatus -eq "Open") { 
                        if ($state.AppStatus -eq "NotRunning") { 
                            # Si estamos esperando reinicio, mantenemos el ROJO y el mensaje de espera
                            # en lugar de mostrar el azul de "Server not ready"
                            if ($state.LastTransferCancelled) {
                                Apply-ConnIndicatorStable "Red" "Waiting for server restart..."
                            } else {
                                Apply-ConnIndicatorStable "Blue" "Port open, server not ready" 
                            }
                        } 
                        else { Apply-ConnIndicatorStable "Green" "Ready" } 
                    } else { 
                        # Si puerto cerrado y cancelado, mantenemos el mensaje, sino amarillo genÃ©rico
                        if ($state.LastTransferCancelled) {
                            Apply-ConnIndicatorStable "Red" "Waiting for server restart..."
                        } else {
                            Apply-ConnIndicatorStable "Yellow" "Spectrum not reachable" 
                        }
                    }

                    $state.ProbeAR=$null; End-ConnectionCheck; return
                }
                if ([int](($now-$state.ProbeStartUtc).TotalMilliseconds) -gt $cfg.CONNECTION_CHECK_TIMEOUT_MS) { $state.PortStatus="Closed"; $state.AppStatus="Unknown"; Apply-ConnIndicatorStable "Yellow" "Server not reachable"; $state.ProbeAR=$null; End-ConnectionCheck; return }
            }
            return
        }
    }
}

function Invoke-PortProbe { if ($state.Phase -ne "Idle") { return }; $ip=$txtIp.Text.Trim(); if (-not (Test-Ip $ip)) { Apply-ConnIndicatorStable "Gray" "Invalid IP"; return }; Apply-ConnIndicatorStable "Blue" "Probing..."; $state.AutoProbeSuspended=$false; $state.LastAutoProbeIp=$ip; Start-ConnectionCheck -ip $ip -forcePortProbe:$true; Process-ConnectionCheckState }

function Apply-ConnIndicatorStable($Level, $TipText) {
    if ($script:form -and $script:form.InvokeRequired) { $null = $script:form.BeginInvoke([Action]{ Apply-ConnIndicatorStable $Level $TipText }); return }
    $lblConnStatus.Text=$TipText
    
    # Color Rojo para errores crÃ­ticos
    if ($TipText -match "Closed|Lost|Reachable|Error|Fail") {
        $lblConnStatus.ForeColor = [System.Drawing.Color]::Red
    } else {
        $lblConnStatus.ForeColor = [System.Drawing.Color]::DarkGray
    }

    $now=[DateTime]::UtcNow
    if ($Level -eq "Blue") { $picConn.Image=$bmpBlue; $toolTip.SetToolTip($picConn, $TipText); return }
    if ($Level -eq "Green") { $state.ConnFailCount=0; $state.LastConnectedUtc=$now; $picConn.Image=$bmpGreen; $toolTip.SetToolTip($picConn, $TipText); return }
    if ($Level -eq "Red") { $picConn.Image=$bmpRed; $toolTip.SetToolTip($picConn, $TipText); return }
    if ($state.LastConnectedUtc -ne [DateTime]::MinValue -and ($now-$state.LastConnectedUtc).TotalMilliseconds -lt $state.ConnGraceMs) { $picConn.Image=$bmpGreen; return }
    $state.ConnFailCount++; if ($state.ConnFailCount -lt $state.ConnFailThreshold -and $state.LastConnectedUtc -ne [DateTime]::MinValue) { return }
    if ($Level -eq "Yellow") { $picConn.Image=$bmpYellow } else { $picConn.Image=$bmpGray }; $toolTip.SetToolTip($picConn, $TipText)
}

function Update-Buttons-State {
    if ($script:form -and $script:form.InvokeRequired) { $null = $script:form.BeginInvoke([Action]{ Update-Buttons-State }); return }
    
    Refresh-QueueCache
    
    if ($state.CachedFileOk) { 
        $count = $lstFiles.Items.Count
        $sizeStr = Format-Bytes $state.QueueTotalSize
        
        if ($count -gt 1) {
            $grpFile.Text = "Queue: $count files ($sizeStr)"
        } else {
            $grpFile.Text = "Queue: $sizeStr"
        }
    } else { 
        $grpFile.Text = "Transfer Queue" 
    }
    $grpFile.ForeColor = [System.Drawing.Color]::Black 

    if ($state.Phase -ne "Idle") { 
        $btnAdd.Enabled=$false; $btnRemove.Enabled=$false; $btnClear.Enabled=$false; $lstFiles.Enabled=$false;
        $btnSend.Enabled=$false; $btnCancel.Enabled=$true; $txtIp.Enabled=$false; 
        $btnSend.BackColor=[System.Drawing.Color]::Silver; $btnCancel.BackColor=[System.Drawing.Color]::IndianRed; $btnCancel.ForeColor=[System.Drawing.Color]::White; 
        return 
    }

    $btnAdd.Enabled=$true; $btnRemove.Enabled=($lstFiles.SelectedItems.Count -gt 0); $btnClear.Enabled=($lstFiles.Items.Count -gt 0); $lstFiles.Enabled=$true;
    $btnCancel.Enabled=$false; $txtIp.Enabled=$true; 
    $btnCancel.BackColor=[System.Drawing.Color]::LightGray; $btnCancel.ForeColor=[System.Drawing.Color]::Black
    
    $ipOk=Test-Ip ($txtIp.Text.Trim())
    $fileOk=($state.CachedFileOk -eq $true -and $lstFiles.Items.Count -gt 0)
    
    if ($fileOk -and $ipOk -and $state.PortStatus -eq "Open" -and $state.AppStatus -eq "Ready") { 
        $btnSend.Enabled=$true; $btnSend.BackColor=[System.Drawing.Color]::SeaGreen; 
        $lblStatus.Text="Ready to send queue."
        $lblStatus.ForeColor = [System.Drawing.Color]::DimGray
    } else { 
        $btnSend.Enabled=$false; $btnSend.BackColor=[System.Drawing.Color]::Silver; 
        
        if (-not $ipOk) { 
            $lblStatus.Text="Invalid IP address." 
        }
        elseif ($state.LastTransferCancelled) {
            $lblStatus.Text="Transfer cancelled."
        }
        elseif ($state.PortStatus -ne "Open") { 
            $lblStatus.Text="Spectrum not reachable." 
        } 
        elseif ($state.AppStatus -ne "Ready") { 
            $lblStatus.Text="Waiting for BridgeZX server." 
        } 
        elseif (-not $fileOk) { 
            $lblStatus.Text = if ($state.FileErrorMsg) { $state.FileErrorMsg } else { "Add files to queue." } 
        } 

        if ($lblStatus.Text -ne "Ready to send queue.") { $lblStatus.ForeColor = [System.Drawing.Color]::DimGray }
        if ($state.FileErrorMsg) { $lblStatus.ForeColor = [System.Drawing.Color]::Red }
    }
}

function Set-AppState($NewPhase) {
    if ($script:form -and $script:form.InvokeRequired) { $null = $script:form.BeginInvoke([Action]{ Set-AppState $NewPhase }); return }
    $state.Phase=$NewPhase; if ($NewPhase -eq "WaitingAck") { $progress.Visible=$false } else { $progress.Visible=$true }
    if ($NewPhase -eq "Idle") { $state.TransferActive=$false; $script:TransferBlinkTimer.Stop(); $picConn.Visible=$true; $lblStatus.Text="Ready."; $progress.Style=[System.Windows.Forms.ProgressBarStyle]::Continuous; $progress.Value=0 } else { $script:TransferBlinkTimer.Start() }
    Update-Buttons-State
}

function Format-Bytes([long]$bytes) { if ($bytes -lt 1024) { return "$bytes B" } elseif ($bytes -lt 1048576) { return "{0:F1} KB" -f ($bytes/1024) } else { return "{0:F1} MB" -f ($bytes/1048576) } }
function Update-Statistics {
    if ($state.Phase -ne "Sending") { return }; $elapsed=[DateTime]::UtcNow - $state.TransferStartUtc; if ($elapsed.TotalSeconds -le 0) { return }
    $speed=$state.Sent/$elapsed.TotalSeconds; $pct=if ($state.Total -gt 0) { [math]::Round(($state.Sent/$state.Total)*100, 0) } else { 0 }
    $lblStatus.Text="File {0}/{1}: {2}% ({3}/s)" -f ($state.CurrentFileIndex + 1), $state.TotalQueueFiles, $pct, (Format-Bytes $speed)
}

function Start-SendWorkflow {
    if ($state.Phase -ne "Idle") { return }; $ip=$txtIp.Text.Trim(); 
    Refresh-QueueCache
    if (-not $state.CachedFileOk) { return }
    if (-not (Test-LainAppHandshake -Ip $ip -Port $global:LAIN_PORT)) { 
        [System.Windows.Forms.MessageBox]::Show("Spectrum connection failed.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return 
    }
    
    $state.TransferQueue = @($lstFiles.Items | ForEach-Object { if ($_.Value) { $_.Value } else { $_ } })
    
    # --- NUEVO: Resolver colisiones de nombres ---
    $state.FilenameMap = Resolve-FilenameCollisions $state.TransferQueue
    
    $state.CurrentFileIndex = 0
    $state.TotalQueueFiles = $state.TransferQueue.Count
    $state.Ip = $ip
    $state.ConnectStartUtc=[DateTime]::UtcNow
    $state.TransferActive=$true
    $state.Cancelled=$false
    
    $connectionTimer.Stop()
    Set-AppState "Connecting"; $lblStatus.Text="Connecting..."; $lblConnStatus.Text="Connecting..."; $progress.Style=[System.Windows.Forms.ProgressBarStyle]::Marquee; 
    Start-ConnectAttempt; $timer.Start()
}

function Prepare-Current-File {
    if ($state.FileStream) { $state.FileStream.Close(); $state.FileStream=$null }
    
    if ($state.CurrentFileIndex -ge $state.TotalQueueFiles) { return $false }
    
    [string]$path = $state.TransferQueue[$state.CurrentFileIndex]
    
    try {
        if (-not (Test-Path $path)) { throw "File not found: $path" }
        
        $fi = Get-Item $path
        $plen = [int]$fi.Length
        
        # Usar nombre del mapa para evitar colisiones
        $transName = $state.FilenameMap[$path]
        if (-not $transName) { $transName = Normalize-Filename $path }
        
        $state.CurrentFileName = $transName
        $payloadCrc = Get-Crc16Ccitt -path $path
        
        [byte]$idx = $state.CurrentFileIndex + 1
        [byte]$tot = $state.TotalQueueFiles
        
        $nBytes=[System.Text.Encoding]::ASCII.GetBytes($transName); $nlen=$nBytes.Length; 
        
        $hdr=New-Object byte[] (15 + $nlen); 
        
        $hdr[0]=0x4C; $hdr[1]=0x41; $hdr[2]=0x49; $hdr[3]=0x4E; 
        [Array]::Copy([System.BitConverter]::GetBytes([UInt32]$plen), 0, $hdr, 4, 4); 
        [Array]::Copy([System.BitConverter]::GetBytes([UInt16]$payloadCrc), 0, $hdr, 8, 2); 
        $hdr[10]=0x46; $hdr[11]=0x4E; 
        $hdr[12]=$idx
        $hdr[13]=$tot
        $hdr[14]=[byte]$nlen; 
        if ($nlen -gt 0) { [Array]::Copy($nBytes, 0, $hdr, 15, $nlen) }
        
        $state.Path = $path
        $state.HeaderBytes=$hdr; $state.HeaderSent=0; 
        $state.FileStream=[System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read); 
        $state.SendBuf=New-Object byte[] $global:CHUNK_SIZE; $state.SendBufOffset=0; $state.SendBufCount=0; $state.SendBufIsHeader=$false; 
        $state.Total=($hdr.Length + $plen); $state.HeaderLen=$hdr.Length; $state.PayloadLen=$plen; $state.Sent=0; 
        $state.TransferStartUtc=[DateTime]::UtcNow; $state.AckReceived=$false; 
        
        return $true
    } catch {
        $timer.Stop()
        [System.Windows.Forms.MessageBox]::Show("Error preparing file '$path':`n" + $_.Exception.Message, "File Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Start-ConnectAttempt {
    try { if ($state.Sock) { $state.Sock.Close() }; if ($state.Client) { $state.Client.Close() }; $state.Client=New-Object System.Net.Sockets.TcpClient; $state.Client.SendBufferSize=$cfg.SOCKET_BUFFER_SIZE; $state.Client.SendTimeout=8000; $state.Client.ReceiveTimeout=500; $state.ConnectAR=$state.Client.BeginConnect($state.Ip, $global:LAIN_PORT, $null, $null) } catch { }
}

function Transfer-EngineTick {
    if ($script:IsProcessingTick) { return }
    $script:IsProcessingTick = $true
    
    try {
        switch ($state.Phase) {
            "Connecting" {
                if ([int]([DateTime]::UtcNow - $state.ConnectStartUtc).TotalMilliseconds -gt $cfg.CONNECT_TOTAL_TIMEOUT_MS) { Finish-Send $true; return }
                if ($state.ConnectAR -and $state.ConnectAR.IsCompleted) {
                    try {
                        $state.Client.EndConnect($state.ConnectAR); $state.Sock=$state.Client.Client; $state.Sock.NoDelay=$true; $state.Sock.Blocking=$false; $state.Sock.SendBufferSize=$cfg.SOCKET_BUFFER_SIZE
                        if (Prepare-Current-File) {
                            Set-AppState "Sending"
                            $state.ConnectAR=$null
                            $progress.Style=[System.Windows.Forms.ProgressBarStyle]::Continuous
                            $lblConnStatus.Text="Transferring..."
                            Apply-ConnIndicatorStable "Green" "Transferring..."
                        } else {
                            Finish-Send $false $true 
                        }
                    } catch { Start-ConnectAttempt; Start-Sleep -Milliseconds 250 }
                }
            }
            "Sending" {
                if ($state.Cancelled) { Finish-Send $false $true; return }
                if ($state.Sent -ge $state.Total) { 
                    Set-AppState "WaitingAck"
                    $state.WaitStartUtc=[DateTime]::UtcNow
                    $lblStatus.Text="Waiting ACK (" + $state.CurrentFileName + ")..."
                    $lblConnStatus.Text="Waiting ACK"
                    Apply-ConnIndicatorStable "Yellow" "Waiting verification..."
                    return 
                }
                
                $budget=$global:MAX_BYTES_PER_TICK
                while ($budget -gt 0 -and $state.Sent -lt $state.Total) {
                    if ($state.SendBufCount -le 0) {
                        if ($state.HeaderSent -lt $state.HeaderLen) { $fill=[Math]::Min($global:CHUNK_SIZE, ($state.HeaderLen - $state.HeaderSent)); [Array]::Copy($state.HeaderBytes, $state.HeaderSent, $state.SendBuf, 0, $fill); $state.SendBufCount=$fill; $state.SendBufIsHeader=$true } else { $read=$state.FileStream.Read($state.SendBuf, 0, $global:CHUNK_SIZE); if ($read -le 0) { break }; $state.SendBufCount=$read; $state.SendBufIsHeader=$false }; $state.SendBufOffset=0
                    }
                    $toSend=[Math]::Min($state.SendBufCount, $budget)
                    try {
                        if ($state.Sock.Poll(0, [System.Net.Sockets.SelectMode]::SelectWrite)) {
                            $n=$state.Sock.Send($state.SendBuf, $state.SendBufOffset, $toSend, [System.Net.Sockets.SocketFlags]::None); $state.Sent+=$n; $budget-=$n; $state.SendBufOffset+=$n; $state.SendBufCount-=$n; if ($state.SendBufIsHeader) { $state.HeaderSent+=$n }
                        } else { break }
                    } catch { break }
                }
                $pct=if ($state.Total -gt 0) { [int](($state.Sent/$state.Total)*100) } else { 0 }; if ($progress.Value -ne $pct) { $progress.Value=$pct }; Update-Statistics
            }
            "WaitingAck" {
                if ([int]([DateTime]::UtcNow - $state.WaitStartUtc).TotalMilliseconds -gt $cfg.WAIT_ACK_TIMEOUT_MS) { Finish-Send $true; return }
                try {
                    if ($state.Sock.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead)) {
                        $buf=New-Object byte[] 256; $r=$state.Sock.Receive($buf, 0, 256, [System.Net.Sockets.SocketFlags]::None)
                        if ($r -gt 0) { 
                            $txt=[System.Text.Encoding]::ASCII.GetString($buf,0,$r); 
                            if ($txt.Contains("OK") -or $txt.Contains("ACK") -or ($buf[0] -eq 6)) { 
                                $state.CurrentFileIndex++
                                if ($state.CurrentFileIndex -lt $state.TotalQueueFiles) {
                                    if (Prepare-Current-File) { 
                                        Set-AppState "Sending"
                                        $lblConnStatus.Text="Transferring..."
                                        Apply-ConnIndicatorStable "Green" "Transferring..."
                                    } else { Finish-Send $false $true }
                                } else {
                                    Set-AppState "Finalizing"; $state.CloseObservedUtc=[DateTime]::UtcNow 
                                }
                            } 
                        } else { Finish-Send $true }
                    }
                } catch { Finish-Send $true }
            }
            "Finalizing" { if ([int]([DateTime]::UtcNow - $state.CloseObservedUtc).TotalMilliseconds -gt 600) { Finish-Send $false; return } }
        }
    } catch { Finish-Send $false $true; [System.Windows.Forms.MessageBox]::Show("Transfer Error: " + $_.Exception.Message) }
    finally { $script:IsProcessingTick = $false }
}

function Finish-Send($timeout, $cancel=$false) {
    $timer.Stop()
    try { if ($state.FileStream) { $state.FileStream.Close() } } catch { }
    try { if ($state.Sock) { $state.Sock.Close() } } catch { }
    try { if ($state.Client) { $state.Client.Close() } } catch { }
    
    if ($timeout -or $cancel) { 
        $state.PortStatus = "Unknown"; 
        $state.AppStatus = "Unknown"; 
        $state.AutoProbeSuspended = $false
        $state.LastTransferCancelled = $true
    }

    Set-AppState "Idle"
    
    $msg = ""
    $icon = "Green"
    
    if ($cancel) { 
        $msg = "Cancelled. Waiting for server..." 
        $icon = "Red"   # <-- FIX: Cambiado a ROJO como pediste
    } elseif ($timeout) { 
        $msg = "Timed out. Waiting for server..." 
        $icon = "Red"
    } else { 
        $msg = "All files sent successfully."
    }

    Apply-ConnIndicatorStable $icon $msg
    $lblStatus.Text = $msg
    
    $connectionTimer.Start()
    
    if ($timeout -or $cancel) { 
        $state.NextAutoConnCheckUtc = [DateTime]::UtcNow 
        Invoke-PortProbe 
    }
}
# --- FIN DE BridgeZX.State.ps1 ---

# --- INICIO DE BridgeZX.UI.ps1 ---
# 6. INTERFAZ GRÃFICA (BridgeZX - MultiFile UI)
# ==========================================
function Show-AboutBox {
    $ab = New-Object System.Windows.Forms.Form; $ab.Text="About BridgeZX"; if($global:AppIcon){$ab.Icon=$global:AppIcon}
    # Aumentamos la altura a 350 para dar mÃ¡s espacio vertical
    $ab.Size=New-Object System.Drawing.Size(420, 350); $ab.StartPosition="CenterParent"; $ab.FormBorderStyle="FixedDialog"; $ab.MaximizeBox=$false; $ab.MinimizeBox=$false; $ab.BackColor=[System.Drawing.Color]::WhiteSmoke
    
    $abHeader = New-Object System.Windows.Forms.Panel; $abHeader.Height=65; $abHeader.Dock=[System.Windows.Forms.DockStyle]::Top; $abHeader.BackColor=[System.Drawing.Color]::Black
    $pbAbLogo = New-Object System.Windows.Forms.PictureBox; $pbAbLogo.Location=New-Object System.Drawing.Point(0,0); $pbAbLogo.Size=New-Object System.Drawing.Size(200,65); $pbAbLogo.SizeMode=[System.Windows.Forms.PictureBoxSizeMode]::Zoom; $pbAbLogo.BackColor=[System.Drawing.Color]::Transparent
    if($global:LogoImage){$pbAbLogo.Image=$global:LogoImage}; $abHeader.Controls.Add($pbAbLogo)
    
    $abHeader.Add_Paint({
        $g=$_.Graphics; $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias; $wPanel=$abHeader.Width; $hPanel=$abHeader.Height
        if (-not $global:LogoImage) { $f=New-Object System.Drawing.Font("Segoe UI",24,[System.Drawing.FontStyle]::Bold); $g.DrawString("BridgeZX",$f,[System.Drawing.Brushes]::White,15,10); $f.Dispose() }
        $stripeW=10; $startX=$wPanel-($stripeW*4)-20; $slant=12
        $colors=@([System.Drawing.Color]::FromArgb(216,0,0),[System.Drawing.Color]::FromArgb(255,216,0),[System.Drawing.Color]::FromArgb(0,192,0),[System.Drawing.Color]::FromArgb(0,192,222))
        for($i=0; $i-lt 4; $i++){
            $brush=New-Object System.Drawing.SolidBrush $colors[$i]; $x=$startX+($i*$stripeW)
            $pts=[System.Drawing.Point[]]@((New-Object System.Drawing.Point -Arg ($x-$slant),($hPanel)),(New-Object System.Drawing.Point -Arg ($x+$stripeW-$slant),($hPanel)),(New-Object System.Drawing.Point -Arg ($x+$stripeW),0),(New-Object System.Drawing.Point -Arg $x,0))
            $g.FillPolygon($brush,$pts); $brush.Dispose()
        }
    })
    $ab.Controls.Add($abHeader)

    # 1. DescripciÃ³n Principal (Y=80)
    $lblDesc=New-Object System.Windows.Forms.Label; $lblDesc.Text="Universal Queue Loader for ZX Spectrum`nusing ESP-12 via AY-3-8912"; $lblDesc.AutoSize=$true; $lblDesc.Font=New-Object System.Drawing.Font("Segoe UI",9); $lblDesc.Location=New-Object System.Drawing.Point(20,80); $ab.Controls.Add($lblDesc)

    # 2. CrÃ©ditos Alex Nihirash (Bajado a Y=130 para separar de la descripciÃ³n)
    $lblBased=New-Object System.Windows.Forms.Label; $lblBased.Text="Based on code from LAIN by Alex Nihirash"; $lblBased.AutoSize=$true; $lblBased.Font=New-Object System.Drawing.Font("Segoe UI",9); $lblBased.Location=New-Object System.Drawing.Point(20,130); $ab.Controls.Add($lblBased)
    
    # Enlace LAIN (Bajado a Y=150, 20px debajo del texto)
    $lnkLain=New-Object System.Windows.Forms.LinkLabel; $lnkLain.Text="https://github.com/nihirash/Lain"; $lnkLain.AutoSize=$true; $lnkLain.Location=New-Object System.Drawing.Point(20,150); 
    $lnkLain.LinkBehavior=[System.Windows.Forms.LinkBehavior]::HoverUnderline; 
    $lnkLain.Add_LinkClicked({ [System.Diagnostics.Process]::Start("https://github.com/nihirash/Lain") }); $ab.Controls.Add($lnkLain)

    # 3. CrÃ©ditos Tuyos (Bajado a Y=185 para separar del bloque anterior)
    $lblMe=New-Object System.Windows.Forms.Label; $lblMe.Text="(C) 2025 M. Ignacio Monge GarcÃ­a"; $lblMe.AutoSize=$true; $lblMe.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold); $lblMe.Location=New-Object System.Drawing.Point(20,185); $ab.Controls.Add($lblMe)
    
    # Enlace BridgeZX (Bajado a Y=205, 20px debajo del texto)
    $lnkBridge=New-Object System.Windows.Forms.LinkLabel; $lnkBridge.Text="https://github.com/IgnacioMonge/BridgeZX"; $lnkBridge.AutoSize=$true; $lnkBridge.Location=New-Object System.Drawing.Point(20,205); 
    $lnkBridge.LinkBehavior=[System.Windows.Forms.LinkBehavior]::HoverUnderline; 
    $lnkBridge.Add_LinkClicked({ [System.Diagnostics.Process]::Start("https://github.com/IgnacioMonge/BridgeZX") }); $ab.Controls.Add($lnkBridge)

    # BotÃ³n Cerrar (Bajado a Y=260)
    $btnClose=New-Object System.Windows.Forms.Button; $btnClose.Text="Close"; $btnClose.Size=New-Object System.Drawing.Size(80,28); $btnClose.Location=New-Object System.Drawing.Point(310,260); Apply-ButtonStyle $btnClose ([System.Drawing.Color]::Gray); $btnClose.Add_Click({$ab.Close()}); $ab.Controls.Add($btnClose)
    
    $ab.ShowDialog($form)|Out-Null
}

$form = New-Object System.Windows.Forms.Form
$null = $form.GetType().GetProperty("DoubleBuffered",[System.Reflection.BindingFlags] "NonPublic,Instance").SetValue($form,$true,$null)
$form.Text="BridgeZX Multi-Loader"; if($global:AppIcon){$form.Icon=$global:AppIcon}
$form.StartPosition="CenterScreen"; $form.AutoScaleMode=[System.Windows.Forms.AutoScaleMode]::Dpi
# AUMENTAMOS EL ALTO DE LA VENTANA PARA LA LISTA
$form.Font=New-Object System.Drawing.Font("Segoe UI",9); $form.ClientSize=New-Object System.Drawing.Size(600,420); $form.FormBorderStyle="FixedSingle"; $form.MaximizeBox=$false; $form.BackColor=[System.Drawing.Color]::WhiteSmoke

$pnlHeader=New-Object System.Windows.Forms.Panel; $pnlHeader.Height=65; $pnlHeader.Dock=[System.Windows.Forms.DockStyle]::Top; $pnlHeader.BackColor=[System.Drawing.Color]::Black
$pbLogo=New-Object System.Windows.Forms.PictureBox
$pbLogo.Location=New-Object System.Drawing.Point(5, 5) # Margen de 5px para que respire
$pbLogo.Size=New-Object System.Drawing.Size(200, 55)   # Ajustado para caber en altura 65
$pbLogo.SizeMode=[System.Windows.Forms.PictureBoxSizeMode]::Zoom
$pbLogo.BackColor=[System.Drawing.Color]::Black        # Fondo negro para fusionar
$pbLogo.Cursor=[System.Windows.Forms.Cursors]::Hand
$pbLogo.Add_Click({Show-AboutBox})

if($global:LogoImage){ $pbLogo.Image=$global:LogoImage }
$pnlHeader.Controls.Add($pbLogo)

$pnlHeader.Add_Paint({
    $g=$_.Graphics; $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias; $wPanel=$pnlHeader.Width; $hPanel=$pnlHeader.Height
    if (-not $global:LogoImage) { $f=New-Object System.Drawing.Font("Segoe UI",24,[System.Drawing.FontStyle]::Bold); $g.DrawString("BridgeZX",$f,[System.Drawing.Brushes]::White,15,10); $f.Dispose() }
    $stripeW=15; $totalBadgeW=($stripeW*4)+20; $startX=$wPanel-$totalBadgeW-10; $slant=15
    $colors=@([System.Drawing.Color]::FromArgb(216,0,0),[System.Drawing.Color]::FromArgb(255,216,0),[System.Drawing.Color]::FromArgb(0,192,0),[System.Drawing.Color]::FromArgb(0,192,222))
    for($i=0; $i-lt 4; $i++){
        $brush=New-Object System.Drawing.SolidBrush $colors[$i]; $x=$startX+($i*$stripeW)
        $pts=[System.Drawing.Point[]]@((New-Object System.Drawing.Point -Arg ($x-$slant),($hPanel)),(New-Object System.Drawing.Point -Arg ($x+$stripeW-$slant),($hPanel)),(New-Object System.Drawing.Point -Arg ($x+$stripeW),0),(New-Object System.Drawing.Point -Arg $x,0))
        $g.FillPolygon($brush,$pts); $brush.Dispose()
    }
    $fSub=New-Object System.Drawing.Font("Consolas",10,[System.Drawing.FontStyle]::Bold); $subText="Universal Multi-Loader"; $subSize=$g.MeasureString($subText,$fSub); $subX=$startX-$subSize.Width-15
    $subY=$hPanel-$subSize.Height-6 
    $g.DrawString($subText,$fSub,[System.Drawing.Brushes]::Yellow,$subX,$subY); $fSub.Dispose()
})

$grpConn=New-Object System.Windows.Forms.GroupBox; $grpConn.Text="Spectrum Connection"; $grpConn.Font=New-Object System.Drawing.Font("Segoe UI Semibold",9); $grpConn.Location=New-Object System.Drawing.Point(20,80); $grpConn.Size=New-Object System.Drawing.Size(560,65)
$lblIp=New-Object System.Windows.Forms.Label; $lblIp.Text="IP Address:"; $lblIp.Location=New-Object System.Drawing.Point(20,30); $lblIp.AutoSize=$true; $lblIp.Font=New-Object System.Drawing.Font("Segoe UI",9)
$txtIp=New-Object System.Windows.Forms.TextBox; $txtIp.Location=New-Object System.Drawing.Point(100,27); $txtIp.Size=New-Object System.Drawing.Size(180,23); $txtIp.Font=New-Object System.Drawing.Font("Segoe UI",9); $txtIp.Text="192.168.0.205"
$lblPort=New-Object System.Windows.Forms.Label; $lblPort.Text=": 6144"; $lblPort.Location=New-Object System.Drawing.Point(285,30); $lblPort.AutoSize=$true; $lblPort.ForeColor=[System.Drawing.Color]::Gray
$lblConnStatus=New-Object System.Windows.Forms.Label; $lblConnStatus.Text=""; $lblConnStatus.AutoSize=$false; $lblConnStatus.Location=New-Object System.Drawing.Point(340,27); $lblConnStatus.Size=New-Object System.Drawing.Size(170,20); $lblConnStatus.TextAlign=[System.Drawing.ContentAlignment]::MiddleRight; $lblConnStatus.ForeColor=[System.Drawing.Color]::DarkGray; $lblConnStatus.Font=New-Object System.Drawing.Font("Segoe UI",9)
$picConn=New-Object System.Windows.Forms.PictureBox; $picConn.Location=New-Object System.Drawing.Point(520,27); $picConn.Size=New-Object System.Drawing.Size(16,16); $picConn.Cursor=[System.Windows.Forms.Cursors]::Hand
$bmpGray=New-CircleBitmap ([System.Drawing.Color]::LightGray); $bmpGreen=New-CircleBitmap ([System.Drawing.Color]::LimeGreen); $bmpYellow=New-CircleBitmap ([System.Drawing.Color]::Gold); $bmpBlue=New-CircleBitmap ([System.Drawing.Color]::DeepSkyBlue); $bmpRed=New-CircleBitmap ([System.Drawing.Color]::Crimson); $picConn.Image=$bmpGray
$grpConn.Controls.AddRange(@($lblIp, $txtIp, $lblPort, $lblConnStatus, $picConn))

# --- GRUPO FILE AHORA ES LISTA ---
$grpFile=New-Object System.Windows.Forms.GroupBox; $grpFile.Text="Transfer Queue"; $grpFile.Font=New-Object System.Drawing.Font("Segoe UI Semibold",9); $grpFile.Location=New-Object System.Drawing.Point(20,155); $grpFile.Size=New-Object System.Drawing.Size(560,170)

$lstFiles=New-Object System.Windows.Forms.ListBox; $lstFiles.Location=New-Object System.Drawing.Point(20,25); 
$lstFiles.Size=New-Object System.Drawing.Size(430,130); $lstFiles.Font=New-Object System.Drawing.Font("Segoe UI",9); $lstFiles.SelectionMode=[System.Windows.Forms.SelectionMode]::MultiExtended
$lstFiles.HorizontalScrollbar=$true; $lstFiles.AllowDrop=$true
# --- NUEVO: Decirle que muestre la etiqueta bonita ---
$lstFiles.DisplayMember = "Label"

$btnAdd=New-Object System.Windows.Forms.Button; $btnAdd.Text="Add..."; $btnAdd.Location=New-Object System.Drawing.Point(460,25); $btnAdd.Size=New-Object System.Drawing.Size(80,25); Apply-ButtonStyle $btnAdd ([System.Drawing.Color]::SlateGray)
$btnRemove=New-Object System.Windows.Forms.Button; $btnRemove.Text="Remove"; $btnRemove.Location=New-Object System.Drawing.Point(460,55); $btnRemove.Size=New-Object System.Drawing.Size(80,25); Apply-ButtonStyle $btnRemove ([System.Drawing.Color]::IndianRed)
$btnClear=New-Object System.Windows.Forms.Button; $btnClear.Text="Clear All"; $btnClear.Location=New-Object System.Drawing.Point(460,85); $btnClear.Size=New-Object System.Drawing.Size(80,25); Apply-ButtonStyle $btnClear ([System.Drawing.Color]::Gray)

$grpFile.Controls.AddRange(@($lstFiles, $btnAdd, $btnRemove, $btnClear))

$pnlActions=New-Object System.Windows.Forms.Panel; $pnlActions.Location=New-Object System.Drawing.Point(20,335); $pnlActions.Size=New-Object System.Drawing.Size(560,40)
$btnSend=New-Object System.Windows.Forms.Button; $btnSend.Text="Send All"; $btnSend.Location=New-Object System.Drawing.Point(480,7); $btnSend.Size=New-Object System.Drawing.Size(80,25); Apply-ButtonStyle $btnSend ([System.Drawing.Color]::SeaGreen); $btnSend.Enabled=$false
$btnCancel=New-Object System.Windows.Forms.Button; $btnCancel.Text="Cancel"; $btnCancel.Location=New-Object System.Drawing.Point(390,7); $btnCancel.Size=New-Object System.Drawing.Size(80,25); Apply-ButtonStyle $btnCancel ([System.Drawing.Color]::LightGray); $btnCancel.ForeColor=[System.Drawing.Color]::Black; $btnCancel.Enabled=$false
$pnlActions.Controls.AddRange(@($btnSend, $btnCancel))

$progress=New-Object System.Windows.Forms.ProgressBar; $progress.Dock=[System.Windows.Forms.DockStyle]::Bottom; $progress.Height=10; $progress.Style=[System.Windows.Forms.ProgressBarStyle]::Continuous
$pnlStatus=New-Object System.Windows.Forms.Panel; $pnlStatus.Dock=[System.Windows.Forms.DockStyle]::Bottom; $pnlStatus.Height=25; $pnlStatus.BackColor=[System.Drawing.Color]::WhiteSmoke
$lblStatus=New-Object System.Windows.Forms.Label; $lblStatus.Text="Ready."; $lblStatus.AutoSize=$false; $lblStatus.Dock=[System.Windows.Forms.DockStyle]::Fill; $lblStatus.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft; $lblStatus.Padding=New-Object System.Windows.Forms.Padding(10,0,0,0); $lblStatus.ForeColor=[System.Drawing.Color]::DimGray; $pnlStatus.Controls.Add($lblStatus)
$form.Controls.AddRange(@($pnlHeader, $grpConn, $grpFile, $pnlActions, $progress, $pnlStatus))

$toolTip=New-Object System.Windows.Forms.ToolTip; $toolTip.SetToolTip($picConn, "Click to test connection")
$openDlg=New-Object System.Windows.Forms.OpenFileDialog; $openDlg.Filter="All files (*.*)|*.*"; $openDlg.Multiselect=$true
# --- FIN DE BridgeZX.UI.ps1 ---

# --- INICIO DE BRIDGEZX.ps1 ---
# ==========================================
# BRIDGEZX CLIENT v0.3 (Stable)
# ==========================================


# --- FIX: ELIMINAR MODO DE ERROR AGRESIVO ---
if (-not $global:PSDefaultParameterValues) { $global:PSDefaultParameterValues = @{} }
$ErrorActionPreference = 'Continue'
# --------------------------------------------


# Single-instance guard
try { 
    $createdNew = $false
    $script:BridgeZX_Mutex = New-Object System.Threading.Mutex($false, "Global\BridgeZX_ClientMutex", [ref]$createdNew)
    if (-not $createdNew) { 
        [System.Windows.Forms.MessageBox]::Show("Another BridgeZX client is already running.", "BridgeZX", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return 
    } 
} catch {}

function Invoke-UI { param([Parameter(Mandatory=$true)][scriptblock]$Action); if ($script:form -and $script:form.InvokeRequired) { $null = $script:form.BeginInvoke([Action]$Action) } else { & $Action } }

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}


# ==============================================================================
# BLOQUE DE INICIALIZACIÃ“N HÃBRIDA (Soporte PS1 y EXE)
# ==============================================================================

# 1. Definimos dÃ³nde estÃ¡n las imÃ¡genes fÃ­sicas para el modo desarrollo (PS1)
# Ajusta estos nombres si tus archivos se llaman diferente o estÃ¡n en carpetas

# 2. LÃ³gica para el ICONO ($global:B64_ICON)
# Si la variable NO existe (estamos en PS1), intentamos crearla desde el archivo.
if (-not (Test-Path variable:global:B64_ICON)) {
    if (Test-Path $RutaIcono) {
        $Bytes = [System.IO.File]::ReadAllBytes($RutaIcono)
        $global:B64_ICON = [System.Convert]::ToBase64String($Bytes)
    } else {
        # Si no hay archivo ni variable, la dejamos vacÃ­a para que no de error
        $global:B64_ICON = ""
    }
}

# 3. LÃ³gica para el LOGO ($global:B64_LOGO)
# Si la variable NO existe (estamos en PS1), intentamos crearla desde el archivo.
if (-not (Test-Path variable:global:B64_LOGO)) {
    if (Test-Path $RutaLogo) {
        $Bytes = [System.IO.File]::ReadAllBytes($RutaLogo)
        $global:B64_LOGO = [System.Convert]::ToBase64String($Bytes)
    } else {
        $global:B64_LOGO = ""
    }
}
# ==============================================================================


# --- FUNCIÃ“N DE LIMPIEZA (Corregida: AÃ±adida aquÃ­) ---
function Cleanup-Connection {
    # Cierra forzosamente cualquier conexiÃ³n abierta al salir
    try { if ($state.FileStream) { $state.FileStream.Close() } } catch {}
    try { if ($state.Sock) { $state.Sock.Close() } } catch {}
    try { if ($state.Client) { $state.Client.Close() } } catch {}
    try { if ($state.ProbeClient) { $state.ProbeClient.Close() } } catch {}
    try { if ($script:BridgeZX_Mutex) { $script:BridgeZX_Mutex.ReleaseMutex() } } catch {}
}

function Start-BridgeZX {
    $timer.Add_Tick({ Transfer-EngineTick })
    $connectionTimer.Add_Tick({ Invoke-WithStateLock { Process-ConnectionCheckState } })
    $script:TransferBlinkTimer.Add_Tick({ if ($state.TransferActive) { $picConn.Visible=-not $picConn.Visible } else { $picConn.Visible=$true } })
    $picConn.Add_Click({ Invoke-PortProbe })
    
# Handlers UI
    $btnAdd.Add_Click({ 
        if ($openDlg.ShowDialog() -eq "OK") { 
            foreach ($f in $openDlg.FileNames) { 
                # Verificar duplicados mirando el .Value (Ruta)
                $exists = $false; foreach($i in $lstFiles.Items){ if (($i.Value -eq $f) -or ($i -eq $f)) { $exists=$true; break } }
                
                if (-not $exists) { 
                    # --- CREAR OBJETO VISUAL ---
                    $sz = Format-Bytes (Safe-FileLength $f)
                    $name = Split-Path $f -Leaf
                    $lbl = "$name  [$sz]"
                    # Guardamos ruta en Value y texto en Label
                    $obj = [pscustomobject]@{ Value=$f; Label=$lbl }
                    $lstFiles.Items.Add($obj) 
                } 
            }
            Update-Buttons-State
        } 
    })
    
    $btnRemove.Add_Click({ 
        $sel = @($lstFiles.SelectedItems)
        foreach ($s in $sel) { $lstFiles.Items.Remove($s) }
        Update-Buttons-State
    })
    $btnClear.Add_Click({ $lstFiles.Items.Clear(); Update-Buttons-State })
    $lstFiles.Add_SelectedIndexChanged({ Update-Buttons-State })
    
    $lstFiles.Add_DragEnter({ if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $_.Effect='Copy' } })
    
    $lstFiles.Add_DragDrop({ 
        $files=$_.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
        foreach ($f in $files) { 
            # Verificar si es fichero y no duplicado
            if (Test-Path $f -PathType Leaf) {
                $exists = $false; foreach($i in $lstFiles.Items){ if (($i.Value -eq $f) -or ($i -eq $f)) { $exists=$true; break } }
                
                if (-not $exists) { 
                    # --- CREAR OBJETO VISUAL ---
                    $sz = Format-Bytes (Safe-FileLength $f)
                    $name = Split-Path $f -Leaf
                    $lbl = "$name  [$sz]"
                    $obj = [pscustomobject]@{ Value=$f; Label=$lbl }
                    $lstFiles.Items.Add($obj) 
                }
            }
        }
        Update-Buttons-State
    })

    $btnSend.Add_Click({ Start-SendWorkflow })
    $btnCancel.Add_Click({ $state.Cancelled=$true })
    $txtIp.Add_TextChanged({ End-ConnectionCheck; $state.IpAlive=$false; $state.PortStatus="Unknown"; Apply-ConnIndicatorStable "Gray" "Checking..."; Update-Buttons-State })

    $form.Add_Shown({ Load-Config; Update-Buttons-State }); 
    
    # Evento de cierre corregido (Ahora Cleanup-Connection existe)
    $form.Add_FormClosing({ Save-Config; $timer.Stop(); $connectionTimer.Stop(); Cleanup-Connection })

    Apply-ConnIndicatorStable "Gray" "Initializing..."
    $connectionTimer.Start(); Process-ConnectionCheckState
    [void]$form.ShowDialog()
}

Start-BridgeZX
# --- FIN DE BRIDGEZX.ps1 ---


# Arranque Seguro
if ($null -eq $script:form) { Start-BridgeZX }
