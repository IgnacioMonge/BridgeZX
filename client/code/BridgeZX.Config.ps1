# 2. CONFIGURACIÓN
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