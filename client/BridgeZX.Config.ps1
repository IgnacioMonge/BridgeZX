# 2. CONFIGURACIÓN
# ==========================================
$cfg = [pscustomobject]@{
    # NETWORK
    SOCKET_BUFFER_SIZE = 16384
    CONN_FAIL_THRESHOLD = 2
    CONN_GRACE_MS = 3000
    LAIN_PORT = 6144

    # TRANSFERENCIA
    # 115200 baud = ~11.5 KB/s theoretical. With hardware UART on divMMC
    # and the tight recv loop on the server, let TCP backpressure set the
    # effective rate instead of throttling from the client.
    # Set to 0 to disable the artificial rate cap.
    DESIRED_SEND_RATE_KBPS = 0
    TIMER_INTERVAL_MS = 15
    CHUNK_SIZE = 14336
    
    # TIMEOUTS
    CONNECT_TOTAL_TIMEOUT_MS = 30000
    CONNECT_RETRY_EVERY_MS = 250
    WAIT_ACK_TIMEOUT_MS = 15000
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
$global:APP_VERSION = "0.5.3"
$global:LAIN_PORT = $cfg.LAIN_PORT
$global:CHUNK_SIZE = $cfg.CHUNK_SIZE
$global:MAX_BYTES_PER_TICK = if ($cfg.DESIRED_SEND_RATE_KBPS -gt 0) {
    [int][Math]::Max(128, [Math]::Floor($cfg.DESIRED_SEND_RATE_KBPS * 1024 * ($cfg.TIMER_INTERVAL_MS / 1000.0)))
} else {
    [int]::MaxValue
}
$global:MAX_SINGLE_FILE_MB = 2.0
$global:MAX_SINGLE_FILE_BYTES = $global:MAX_SINGLE_FILE_MB * 1048576

# PERSISTENCIA DE CONFIGURACIÓN
$script:LastOpenDir = $null

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
            $props = $json.PSObject.Properties
            $script:SuppressIpTextChanged = $true
            if ($props['IpHistory'] -and $json.IpHistory) {
                $script:IpHistory.Clear()
                foreach ($h in $json.IpHistory) { $null = $script:IpHistory.Add("$h") }
            }
            if ($props['Ip'] -and $json.Ip) { $txtIp.Text = $json.Ip }
            $script:SuppressIpTextChanged = $false
            if ($props['LastDir'] -and $json.LastDir -and (Test-Path $json.LastDir)) { $script:LastOpenDir = $json.LastDir }
            # Restaurar posición de ventana
            if ($props['WinX'] -and $props['WinY'] -and $null -ne $json.WinX -and $null -ne $json.WinY) {
                $screen = [System.Windows.Forms.Screen]::FromPoint((New-Object System.Drawing.Point($json.WinX, $json.WinY)))
                if ($screen.WorkingArea.Contains($json.WinX, $json.WinY)) {
                    $form.StartPosition = "Manual"
                    $form.Location = New-Object System.Drawing.Point($json.WinX, $json.WinY)
                }
            }
        } catch {}
    }
}

function Save-Config {
    try {
        $data = @{
            Ip = $txtIp.Text
            IpHistory = @($script:IpHistory)
            LastDir = $script:LastOpenDir
            WinX = $form.Location.X
            WinY = $form.Location.Y
        }
        $data | ConvertTo-Json | Set-Content (Get-ConfigPath) -ErrorAction Stop
    } catch { }
}

function Save-IpToHistory {
    param([string]$ip)
    $ip = $ip.Trim()
    if (-not (Test-Ip $ip)) { return }
    $script:IpHistory.Remove($ip) | Out-Null
    $script:IpHistory.Insert(0, $ip)
    while ($script:IpHistory.Count -gt 5) { $script:IpHistory.RemoveAt($script:IpHistory.Count - 1) }
}

# ==========================================
