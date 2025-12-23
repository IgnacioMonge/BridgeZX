# 5. LÓGICA DE RED (Compatible LAIN/SnapZX)
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