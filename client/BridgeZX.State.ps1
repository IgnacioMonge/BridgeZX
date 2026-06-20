# 7. MÁQUINA DE ESTADOS Y LÓGICA (MULTI-FILE ROBUSTO V2)
# ==========================================
$timer=New-Object System.Windows.Forms.Timer; $timer.Interval=$cfg.TIMER_INTERVAL_MS
$connectionTimer=New-Object System.Windows.Forms.Timer; $connectionTimer.Interval=$cfg.CONNECTION_POLL_INTERVAL_MS
$script:TransferBlinkTimer=New-Object System.Windows.Forms.Timer; $script:TransferBlinkTimer.Interval=350; $script:TransferBlinkVisible=$true
$script:IsProcessingTick = $false

$state=[pscustomobject]@{
    Phase="Idle"; Ip=$null; 
    TransferQueue=@(); CurrentFileIndex=0; TotalQueueFiles=0; CurrentFileName=""; FilenameMap=@{};
    
    # Propiedad QueueTotalSize (Corregido)
    QueueTotalSize=0; QueueTotalPayload=0; QueuePayloadSent=0;
    
    Bytes=$null; HeaderBytes=$null; HeaderSent=0; FileStream=$null; SendBuf=$null; SendBufOffset=0; SendBufCount=0; SendBufIsHeader=$false
    Total=0; HeaderLen=0; PayloadLen=0; Sent=0; Client=$null; Sock=$null; ConnectAR=$null; ConnectStartUtc=[DateTime]::MinValue; NextRetryUtc=[DateTime]::MinValue; WaitStartUtc=[DateTime]::MinValue
    TransferStartUtc=[DateTime]::MinValue; LastSendProgressUtc=[DateTime]::MinValue; LastStatsUpdate=[DateTime]::UtcNow; ProgressStarted=$false; UiProgress=0.0; TargetProgress=0.0; LastTickUtc=[DateTime]::UtcNow; CurrentFileVisualProgress=-1
    CloseObservedUtc=[DateTime]::MinValue; AckReceived=$false; AckBuffer=""; AckReadBuf=(New-Object byte[] 256); Cancelled=$false; IsCheckingConnection=$false; TransferActive=$false; IpAlive=$false; PortStatus="Unknown"; AppStatus="Unknown"
    HandshakeClient=$null; HandshakeSock=$null; HandshakeAR=$null; HandshakeStartUtc=[DateTime]::MinValue; HandshakeBytes=$null; HandshakeSent=0; HandshakeAckText=""; HandshakeReadBuf=(New-Object byte[] 64)
    AutoProbeSuspended=$false; LastAutoProbeIp=""; LastHandshakeUtc=[DateTime]::MinValue; LastPortProbeUtc=[DateTime]::MinValue; LastConnectionCheckUtc=[DateTime]::MinValue
    CachedFilePath=""; CachedFileOk=$null; CachedTransName=""; FileCacheLastCheckTicks=0; ConnCheckPhase="Idle"; ConnCheckIp=$null; ConnCheckForceProbe=$false; ConnCheckSkipHandshake=$false
    LastOpenVerifyUtc=[DateTime]::MinValue; ConnCheckStartUtc=[DateTime]::MinValue; NextAutoConnCheckUtc=[DateTime]::MinValue; PingTask=$null; ProbeClient=$null; ProbeTask=$null; ProbeAR=$null; ProbeSock=$null; ProbeStartUtc=[DateTime]::MinValue
    ProbeBytes=$null; ProbeSent=0; ProbeAckText=""; ProbeReadBuf=(New-Object byte[] 64)
    ConnFailCount=0; ConnFailThreshold=$cfg.CONN_FAIL_THRESHOLD; ConnGraceMs=$cfg.CONN_GRACE_MS; LastConnectedUtc=[DateTime]::MinValue
    
    # Bandera de cancelación
    LastTransferCancelled=$false;

    # Monitoring pause
    MonitoringPaused=$false;

    # Error de validación de cola
    FileErrorMsg=$null;
    LastQueueRejectMsg=$null; LastQueueRejectUtc=[DateTime]::MinValue;

    # Timestamp inicio de toda la sesión de envío (para resumen)
    QueueStartUtc=[DateTime]::MinValue;

    Path=$null
}
$script:StateLock=New-Object object
function Invoke-WithStateLock { param([scriptblock]$Action); [System.Threading.Monitor]::Enter($script:StateLock); try { & $Action } finally { [System.Threading.Monitor]::Exit($script:StateLock) } }

function Reset-ProbeClient {
    if ($state.ProbeAR -and $state.ProbeAR.IsCompleted -and $state.ProbeClient) {
        try { $state.ProbeClient.EndConnect($state.ProbeAR) | Out-Null } catch { }
    }
    try { if ($state.ProbeSock) { $state.ProbeSock.Close() } } catch { }
    try { if ($state.ProbeClient) { $state.ProbeClient.Close(); $state.ProbeClient.Dispose() } } catch { }
    $state.ProbeClient=$null
    $state.ProbeAR=$null
    $state.ProbeSock=$null
    $state.ProbeStartUtc=[DateTime]::MinValue
    $state.ProbeBytes=$null
    $state.ProbeSent=0
    $state.ProbeAckText=""
}

function Reset-SendHandshake {
    if ($state.HandshakeAR -and $state.HandshakeAR.IsCompleted -and $state.HandshakeClient) {
        try { $state.HandshakeClient.EndConnect($state.HandshakeAR) | Out-Null } catch { }
    }
    try { if ($state.HandshakeSock) { $state.HandshakeSock.Close() } } catch { }
    try { if ($state.HandshakeClient) { $state.HandshakeClient.Close(); $state.HandshakeClient.Dispose() } } catch { }
    $state.HandshakeClient=$null
    $state.HandshakeSock=$null
    $state.HandshakeAR=$null
    $state.HandshakeStartUtc=[DateTime]::MinValue
    $state.HandshakeBytes=$null
    $state.HandshakeSent=0
    $state.HandshakeAckText=""
}

function Start-SendHandshake([string]$ip) {
    Reset-SendHandshake
    $state.HandshakeBytes = New-LainHandshakePacket -ProbeName "PING"
    $state.HandshakeClient = New-Object System.Net.Sockets.TcpClient
    $state.HandshakeClient.NoDelay = $true
    $state.HandshakeAR = $state.HandshakeClient.BeginConnect($ip, $global:LAIN_PORT, $null, $null)
    $state.HandshakeStartUtc = [DateTime]::UtcNow
}

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
    Reset-ProbeClient
    $state.AutoProbeSuspended = ($state.PortStatus -eq "Open" -and $state.AppStatus -eq "Ready")
    $nextMs = if ($state.PortStatus -ne "Open") { $cfg.CONN_INTERVAL_PORT_CLOSED_MS } elseif ($state.AppStatus -ne "Ready") { $cfg.CONN_INTERVAL_OPEN_NOTREADY_MS } else { $cfg.CONN_INTERVAL_OPEN_READY_MS }
    if ($connectionTimer.Interval -ne [int]$nextMs) { $connectionTimer.Interval = [int]$nextMs }
    $state.NextAutoConnCheckUtc = [DateTime]::UtcNow.AddMilliseconds([int]$nextMs)
    Update-Buttons-State
}

function Complete-ConnectionCheckResult {
    if ($state.PortStatus -eq "Open" -and $state.AppStatus -eq "Ready") {
        $state.LastTransferCancelled = $false
    }

    if ($state.PortStatus -eq "Open") {
        if ($state.AppStatus -eq "NotRunning") {
            if ($state.LastTransferCancelled) {
                Apply-ConnIndicatorStable "Red" "Waiting for server restart..."
            } else {
                Apply-ConnIndicatorStable "Blue" "Port open, server not ready"
            }
        } else {
            Apply-ConnIndicatorStable "Green" "Ready"
        }
    } else {
        if ($state.LastTransferCancelled) {
            Apply-ConnIndicatorStable "Red" "Waiting for server restart..."
        } else {
            Apply-ConnIndicatorStable "Yellow" "Spectrum not reachable"
        }
    }

    End-ConnectionCheck
}

function Process-ProbeHandshakePhase {
    $now=[DateTime]::UtcNow
    if ([int](($now-$state.ProbeStartUtc).TotalMilliseconds) -gt $cfg.CONNECTION_CHECK_TIMEOUT_MS) {
        $state.AppStatus="NotRunning"
        $state.LastHandshakeUtc=$now
        Complete-ConnectionCheckResult
        return
    }

    if (-not $state.ProbeSock) { $state.AppStatus="NotRunning"; Complete-ConnectionCheckResult; return }

    while ($state.ProbeSent -lt $state.ProbeBytes.Length) {
        if (-not $state.ProbeSock.Poll(0, [System.Net.Sockets.SelectMode]::SelectWrite)) { return }
        try {
            $remaining = $state.ProbeBytes.Length - $state.ProbeSent
            $n = $state.ProbeSock.Send($state.ProbeBytes, $state.ProbeSent, $remaining, [System.Net.Sockets.SocketFlags]::None)
            if ($n -le 0) { return }
            $state.ProbeSent += $n
        } catch [System.Net.Sockets.SocketException] {
            if ($_.Exception.SocketErrorCode -eq [System.Net.Sockets.SocketError]::WouldBlock) { return }
            $state.AppStatus="NotRunning"
            $state.LastHandshakeUtc=$now
            Complete-ConnectionCheckResult
            return
        } catch {
            $state.AppStatus="NotRunning"
            $state.LastHandshakeUtc=$now
            Complete-ConnectionCheckResult
            return
        }
    }

    if (-not $state.ProbeSock.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead)) { return }
    try {
        $buf = $state.ProbeReadBuf
        $r = $state.ProbeSock.Receive($buf, 0, $buf.Length, [System.Net.Sockets.SocketFlags]::None)
        if ($r -le 0) { $state.AppStatus="NotRunning"; $state.LastHandshakeUtc=$now; Complete-ConnectionCheckResult; return }
        for ($i = 0; $i -lt $r; $i++) {
            if ($buf[$i] -eq 0x06) {
                $state.AppStatus="Ready"
                $state.LastHandshakeUtc=$now
                Complete-ConnectionCheckResult
                return
            }
        }
        if ($r -lt 10) {
            try { $state.ProbeAckText += [System.Text.Encoding]::ASCII.GetString($buf, 0, $r) } catch { }
            if ($state.ProbeAckText.Contains("OK") -or $state.ProbeAckText.Contains("ACK")) {
                $state.AppStatus="Ready"
                $state.LastHandshakeUtc=$now
                Complete-ConnectionCheckResult
            }
        }
    } catch [System.Net.Sockets.SocketException] {
        if ($_.Exception.SocketErrorCode -eq [System.Net.Sockets.SocketError]::WouldBlock) { return }
        $state.AppStatus="NotRunning"
        $state.LastHandshakeUtc=$now
        Complete-ConnectionCheckResult
    } catch {
        $state.AppStatus="NotRunning"
        $state.LastHandshakeUtc=$now
        Complete-ConnectionCheckResult
    }
}

function Process-ConnectionCheckState {
    if (-not (Get-Variable -Name state -Scope Script -ErrorAction SilentlyContinue)) { return }
    if ($state.MonitoringPaused) { return }
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

                    if ($state.PortStatus -ne "Open") {
                        $state.AppStatus="Unknown"
                        $state.ProbeAR=$null
                        Complete-ConnectionCheckResult
                        return
                    }

                    if ($state.ConnCheckSkipHandshake) {
                        $state.AppStatus="Ready"
                        $state.ProbeAR=$null
                        Complete-ConnectionCheckResult
                        return
                    }

                    try {
                        $state.ProbeAR=$null
                        $state.ProbeSock=$state.ProbeClient.Client
                        $state.ProbeSock.NoDelay=$true
                        $state.ProbeSock.Blocking=$false
                        $state.ProbeBytes=New-LainHandshakePacket -ProbeName "PING"
                        $state.ProbeSent=0
                        $state.ProbeAckText=""
                        $state.ConnCheckPhase="ProbeHandshake"
                    } catch {
                        $state.AppStatus="NotRunning"
                        $state.LastHandshakeUtc=$now
                        Complete-ConnectionCheckResult
                    }
                    return
                }
                if ([int](($now-$state.ProbeStartUtc).TotalMilliseconds) -gt $cfg.CONNECTION_CHECK_TIMEOUT_MS) { $state.PortStatus="Closed"; $state.AppStatus="Unknown"; Apply-ConnIndicatorStable "Yellow" "Server not reachable"; End-ConnectionCheck; return }
            }
            return
        }
        "ProbeHandshake" {
            Process-ProbeHandshakePhase
            return
        }
    }
}

function Invoke-PortProbe { if ($state.Phase -ne "Idle") { return }; $ip=$txtIp.Text.Trim(); if (-not (Test-Ip $ip)) { Apply-ConnIndicatorStable "Gray" "Invalid IP"; return }; Apply-ConnIndicatorStable "Blue" "Probing..."; $state.AutoProbeSuspended=$false; $state.LastAutoProbeIp=$ip; Start-ConnectionCheck -ip $ip -forcePortProbe:$true; Process-ConnectionCheckState }

function Toggle-Monitoring {
    if ($state.Phase -ne "Idle") { return }
    if ($state.MonitoringPaused) {
        # Resume
        $state.MonitoringPaused = $false
        $state.PortStatus = "Unknown"; $state.AppStatus = "Unknown"
        Apply-ConnIndicatorStable "Gray" "Resuming..."
        $connectionTimer.Start()
        $state.NextAutoConnCheckUtc = [DateTime]::UtcNow
    } else {
        # Pause
        $state.MonitoringPaused = $true
        $connectionTimer.Stop()
        End-ConnectionCheck
        $picConn.Image = $bmpGray
        $lblConnStatus.Text = "Paused"
        $lblConnStatus.ForeColor = $script:ThemeTextDim
        $toolTip.SetToolTip($picConn, "Click to resume monitoring")
    }
    Update-Buttons-State
}

function Apply-ConnIndicatorStable($Level, $TipText) {
    if ($script:form -and $script:form.InvokeRequired) { $l=$Level; $t=$TipText; $null = $script:form.BeginInvoke([Action]{ Apply-ConnIndicatorStable $l $t }.GetNewClosure()); return }
    $lblConnStatus.Text=$TipText
    
    # Color Rojo para errores críticos
    if ($TipText -match "Closed|Lost|Reachable|Error|Fail") {
        $lblConnStatus.ForeColor = $script:ThemeRed
    } else {
        $lblConnStatus.ForeColor = $script:ThemeTextDim
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
    $recentQueueReject = ($state.LastQueueRejectMsg -and $state.LastQueueRejectUtc -ne [DateTime]::MinValue -and (([DateTime]::UtcNow - $state.LastQueueRejectUtc).TotalSeconds -lt 4))
    
    if ($recentQueueReject) {
        $lblQueueInfo.Text = $state.LastQueueRejectMsg
        $lblQueueInfo.ForeColor = $script:ThemeRed
    } elseif ($state.CachedFileOk) {
        $count = $lstFiles.Items.Count
        $sizeStr = Format-Bytes $state.QueueTotalSize
        if ($count -gt 1) {
            $lblQueueInfo.Text = "$count files ($sizeStr)"
        } else {
            $lblQueueInfo.Text = "$sizeStr"
        }
        $lblQueueInfo.ForeColor = $script:ThemeTextDim
    } else {
        $lblQueueInfo.Text = if ($state.FileErrorMsg) { $state.FileErrorMsg } else { "Drag files here or click Add..." }
        $lblQueueInfo.ForeColor = if ($state.FileErrorMsg) { $script:ThemeRed } else { $script:ThemeTextDim }
    } 

    if ($state.Phase -ne "Idle") { 
        $btnAdd.Enabled=$false; $btnRemove.Enabled=$false; $btnClear.Enabled=$false; $lstFiles.Enabled=$false;
        $btnSend.Enabled=$false; $btnCancel.Enabled=$true; $txtIp.Enabled=$false; 
        $btnSend.BackColor=$script:ThemeSurface2; $btnCancel.BackColor=$script:ThemeRed; $btnCancel.ForeColor=[System.Drawing.Color]::White; 
        return 
    }

    $btnAdd.Enabled=$true; $btnRemove.Enabled=($lstFiles.SelectedItems.Count -gt 0); $btnClear.Enabled=($lstFiles.Items.Count -gt 0); $lstFiles.Enabled=$true;
    $btnCancel.Enabled=$false; $txtIp.Enabled=$true; 
    $btnCancel.BackColor=$script:ThemeSurface2; $btnCancel.ForeColor=$script:ThemeText
    
    $ipOk=Test-Ip ($txtIp.Text.Trim())
    $fileOk=($state.CachedFileOk -eq $true -and $lstFiles.Items.Count -gt 0)
    
    $connOk = ($state.PortStatus -eq "Open" -and $state.AppStatus -eq "Ready") -or $state.MonitoringPaused
    if ($fileOk -and $ipOk -and $connOk) {
        $btnSend.Enabled=$true; $btnSend.BackColor=$script:ThemeGreen
        if ($recentQueueReject) {
            $lblStatus.Text = $state.LastQueueRejectMsg
            $lblStatus.ForeColor = $script:ThemeRed
        } else {
            $lblStatus.Text="Ready to send queue."
            $lblStatus.ForeColor = $script:ThemeGreen
        }
    } else {
        $btnSend.Enabled=$false; $btnSend.BackColor=$script:ThemeSurface2;

        if (-not $ipOk) {
            $lblStatus.Text="Invalid IP address."
        }
        elseif ($state.MonitoringPaused -and -not $fileOk) {
            $lblStatus.Text="Monitoring paused."
        }
        elseif ($state.LastTransferCancelled) {
            $lblStatus.Text="Transfer cancelled."
        }
        elseif ($state.PortStatus -ne "Open" -and -not $state.MonitoringPaused) {
            $lblStatus.Text="Spectrum not reachable."
        }
        elseif ($state.AppStatus -ne "Ready" -and -not $state.MonitoringPaused) {
            $lblStatus.Text="Waiting for BridgeZX server."
        }
        elseif (-not $fileOk) {
            $lblStatus.Text = if ($state.FileErrorMsg) { $state.FileErrorMsg } else { "Add files to queue." }
        }

        if ($lblStatus.Text -ne "Ready to send queue.") { $lblStatus.ForeColor = $script:ThemeTextDim }
        if ($state.FileErrorMsg) { $lblStatus.ForeColor = $script:ThemeRed }
    }
}

function Set-AppState($NewPhase) {
    if ($script:form -and $script:form.InvokeRequired) { $p=$NewPhase; $null = $script:form.BeginInvoke([Action]{ Set-AppState $p }.GetNewClosure()); return }
    $state.Phase=$NewPhase
    if ($NewPhase -eq "Idle") {
        $state.TransferActive=$false; $script:TransferBlinkTimer.Stop(); $picConn.Visible=$true; $lblStatus.Text="Ready."
        $script:ProgressValue=0; $script:ConnectAnimActive=$false; $script:ConnectAnimTimer.Stop(); $script:CustomProgress.Invalidate()
        $form.Text = "BridgeZX v$global:APP_VERSION Multi-Loader"
    } elseif ($NewPhase -eq "Connecting" -or $NewPhase -eq "Handshaking") {
        $script:ConnectAnimActive=$true; $script:ConnectAnimOffset=0; $script:ConnectAnimTimer.Start()
        $script:TransferBlinkTimer.Start()
        try { [TaskbarProgress]::SetState($form.Handle, 1) } catch {}  # Indeterminate
    } else {
        $script:ConnectAnimActive=$false; $script:ConnectAnimTimer.Stop()
        $script:TransferBlinkTimer.Start()
        if ($NewPhase -eq "Sending") { try { [TaskbarProgress]::SetState($form.Handle, 2) } catch {} }  # Normal
    }
    Update-Buttons-State
    Refresh-TransferQueueVisual -Force
}

function Format-Bytes([long]$bytes) { if ($bytes -lt 1024) { return "$bytes B" } elseif ($bytes -lt 1048576) { return "{0:F1} KB" -f ($bytes/1024) } else { return "{0:F1} MB" -f ($bytes/1048576) } }
function Get-CurrentFilePayloadPercent {
    if (-not $state.TransferActive -or $state.PayloadLen -le 0) { return 0 }
    $payloadSent = [Math]::Max(0, [Math]::Min($state.PayloadLen, ($state.Sent - $state.HeaderLen)))
    return [int][Math]::Round(($payloadSent * 100.0) / $state.PayloadLen, 0)
}

function Refresh-TransferQueueVisual {
    param([switch]$Force)

    if (-not $lstFiles) { return }

    $pct = if ($state.TransferActive) { Get-CurrentFilePayloadPercent } else { -1 }
    if (-not $Force -and $pct -eq $state.CurrentFileVisualProgress) { return }

    $state.CurrentFileVisualProgress = $pct
    Invoke-UI { $lstFiles.Invalidate() }
}

function Request-TransferCancel {
    if ($state.Phase -eq "Idle" -or -not $state.TransferActive -or $state.Cancelled) { return }
    if ($state.Phase -eq "Finalizing") { return }

    $state.Cancelled = $true
    $lblStatus.Text = "Cancelling..."
    $lblStatus.ForeColor = $script:ThemeYellow
    $lblConnStatus.Text = "Cancelling..."
    Apply-ConnIndicatorStable "Red" "Cancelling..."
    Finish-Send $false $true
}

function Update-Statistics {
    if ($state.Phase -ne "Sending") { return }
    $now = [DateTime]::UtcNow
    if (($now - $state.LastStatsUpdate).TotalMilliseconds -lt 200) { return }
    $state.LastStatsUpdate = $now
    $elapsed = $now - $state.QueueStartUtc; if ($elapsed.TotalSeconds -le 0) { return }
    $curPayload = [Math]::Max(0, $state.Sent - $state.HeaderLen)
    $overallSent = $state.QueuePayloadSent + $curPayload
    $speed = $overallSent / $elapsed.TotalSeconds
    $pct = if ($state.Total -gt 0) { [math]::Round(($state.Sent/$state.Total)*100, 0) } else { 0 }
    # ETA
    $etaStr = ""
    if ($speed -gt 0) {
        $rem = [int](($state.QueueTotalPayload - $overallSent) / $speed)
        $etaStr = if ($rem -ge 60) { " ~{0:F0}m{1:F0}s" -f [Math]::Floor($rem/60), ($rem%60) } elseif ($rem -gt 0) { " ~{0}s" -f $rem } else { "" }
    }
    $newText = "File {0}/{1}: {2}  {3}%  ({4}/s){5}" -f ($state.CurrentFileIndex+1), $state.TotalQueueFiles, $state.CurrentFileName, $pct, (Format-Bytes $speed), $etaStr
    if ($lblStatus.Text -ne $newText) { $lblStatus.Text = $newText }
    # Title bar progress
    $overallPct = if ($state.QueueTotalPayload -gt 0) { [int]($overallSent * 100 / $state.QueueTotalPayload) } else { 0 }
    $newTitle = "BridgeZX {0}%" -f $overallPct
    if ($form.Text -ne $newTitle) { $form.Text = $newTitle }
}

function Start-SendWorkflow {
    if ($state.Phase -ne "Idle") { return }; $ip=$txtIp.Text.Trim(); 
    Refresh-QueueCache -ForceDisk
    if (-not $state.CachedFileOk) { return }
    if ($lstFiles.Items.Count -gt 255) {
        $state.FileErrorMsg = "Queue limit is 255 files."
        $lblStatus.Text = $state.FileErrorMsg
        $lblStatus.ForeColor = $script:ThemeRed
        $lblQueueInfo.Text = $state.FileErrorMsg
        $lblQueueInfo.ForeColor = $script:ThemeRed
        return
    }
    
    $state.TransferQueue = @($lstFiles.Items | ForEach-Object { if ($_.Value) { $_.Value } else { $_ } })

    # Resolver colisiones de nombres
    $state.FilenameMap = Resolve-FilenameCollisions $state.TransferQueue

    $state.CurrentFileIndex = 0
    $state.TotalQueueFiles = $state.TransferQueue.Count
    $state.Ip = $ip
    $state.ConnectStartUtc=[DateTime]::UtcNow
    $state.QueueStartUtc=[DateTime]::UtcNow
    $state.TransferActive=$true
    $state.Cancelled=$false
    $state.CurrentFileVisualProgress = -1
    $state.QueuePayloadSent = 0
    $state.QueueTotalPayload = 0
    foreach ($qPath in $state.TransferQueue) { try { $state.QueueTotalPayload += (Get-Item $qPath).Length } catch {} }

    $connectionTimer.Stop()
    End-ConnectionCheck
    Set-AppState "Handshaking"; $lblStatus.Text="Checking server..."; $lblConnStatus.Text="Checking server..."
    try {
        Start-SendHandshake $ip
        $timer.Start()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Spectrum connection failed.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Finish-Send $true
    }
}

function Prepare-Current-File {
    if ($state.FileStream) { $state.FileStream.Close(); $state.FileStream=$null }

    if ($state.CurrentFileIndex -ge $state.TotalQueueFiles) { return $false }

    # Resaltar archivo actual en la lista
    Invoke-UI { if ($state.CurrentFileIndex -lt $lstFiles.Items.Count) { $lstFiles.SelectedIndex = $state.CurrentFileIndex } }

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
        $state.TransferStartUtc=[DateTime]::UtcNow; $state.LastSendProgressUtc=$state.TransferStartUtc; $state.LastStatsUpdate=$state.TransferStartUtc; $state.AckReceived=$false; $state.AckBuffer="";
        Refresh-TransferQueueVisual -Force
        
        return $true
    } catch {
        $timer.Stop()
        [System.Windows.Forms.MessageBox]::Show("Error preparing file '$path':`n" + $_.Exception.Message, "File Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Start-ConnectAttempt {
    try {
        if ($state.Sock) { $state.Sock.Close(); $state.Sock=$null }
        if ($state.Client) { $state.Client.Close(); $state.Client=$null }
        $state.Client=New-Object System.Net.Sockets.TcpClient
        $state.Client.SendBufferSize=$cfg.SOCKET_BUFFER_SIZE; $state.Client.SendTimeout=8000; $state.Client.ReceiveTimeout=500
        $state.ConnectAR=$state.Client.BeginConnect($state.Ip, $global:LAIN_PORT, $null, $null)
    } catch {
        $lblStatus.Text = "Connection error. Retrying..."
        $state.NextRetryUtc = [DateTime]::UtcNow.AddMilliseconds($cfg.CONNECT_RETRY_EVERY_MS)
    }
}

function Process-SendHandshakePhase {
    $now = [DateTime]::UtcNow
    if ([int]($now - $state.HandshakeStartUtc).TotalMilliseconds -gt $cfg.CONNECTION_CHECK_TIMEOUT_MS) { Finish-Send $true; return }

    if ($state.HandshakeAR) {
        if (-not $state.HandshakeAR.IsCompleted) { return }
        try {
            $state.HandshakeClient.EndConnect($state.HandshakeAR) | Out-Null
            $state.HandshakeAR = $null
            $state.HandshakeSock = $state.HandshakeClient.Client
            $state.HandshakeSock.NoDelay = $true
            $state.HandshakeSock.Blocking = $false
        } catch {
            Finish-Send $true
            return
        }
    }

    if (-not $state.HandshakeSock) { return }

    while ($state.HandshakeSent -lt $state.HandshakeBytes.Length) {
        if (-not $state.HandshakeSock.Poll(0, [System.Net.Sockets.SelectMode]::SelectWrite)) { return }
        try {
            $remaining = $state.HandshakeBytes.Length - $state.HandshakeSent
            $n = $state.HandshakeSock.Send($state.HandshakeBytes, $state.HandshakeSent, $remaining, [System.Net.Sockets.SocketFlags]::None)
            if ($n -le 0) { return }
            $state.HandshakeSent += $n
        } catch [System.Net.Sockets.SocketException] {
            if ($_.Exception.SocketErrorCode -eq [System.Net.Sockets.SocketError]::WouldBlock) { return }
            Finish-Send $true
            return
        } catch {
            Finish-Send $true
            return
        }
    }

    if (-not $state.HandshakeSock.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead)) { return }
    try {
        $buf = $state.HandshakeReadBuf
        $r = $state.HandshakeSock.Receive($buf, 0, $buf.Length, [System.Net.Sockets.SocketFlags]::None)
        if ($r -le 0) { Finish-Send $true; return }
        for ($i = 0; $i -lt $r; $i++) {
            if ($buf[$i] -eq 0x06) {
                Reset-SendHandshake
                $state.ConnectStartUtc = [DateTime]::UtcNow
                $state.NextRetryUtc = [DateTime]::MinValue
                Set-AppState "Connecting"
                $lblStatus.Text = "Connecting..."
                $lblConnStatus.Text = "Connecting..."
                Start-ConnectAttempt
                return
            }
        }
        if ($r -lt 10) {
            try { $state.HandshakeAckText += [System.Text.Encoding]::ASCII.GetString($buf, 0, $r) } catch { }
            if ($state.HandshakeAckText.Contains("OK") -or $state.HandshakeAckText.Contains("ACK")) {
                Reset-SendHandshake
                $state.ConnectStartUtc = [DateTime]::UtcNow
                $state.NextRetryUtc = [DateTime]::MinValue
                Set-AppState "Connecting"
                $lblStatus.Text = "Connecting..."
                $lblConnStatus.Text = "Connecting..."
                Start-ConnectAttempt
            }
        }
    } catch [System.Net.Sockets.SocketException] {
        if ($_.Exception.SocketErrorCode -eq [System.Net.Sockets.SocketError]::WouldBlock) { return }
        Finish-Send $true
    } catch {
        Finish-Send $true
    }
}

function Transfer-EngineTick {
    if ($script:IsProcessingTick) { return }
    $script:IsProcessingTick = $true
    
    try {
        $continueTick = $true
        while ($continueTick) {
            $continueTick = $false
            if ($state.Phase -ne "Idle" -and $state.Cancelled) { Finish-Send $false $true; return }
            switch ($state.Phase) {
            "Handshaking" {
                Process-SendHandshakePhase
            }
            "Connecting" {
                if ([int]([DateTime]::UtcNow - $state.ConnectStartUtc).TotalMilliseconds -gt $cfg.CONNECT_TOTAL_TIMEOUT_MS) { Finish-Send $true; return }
                if ($state.NextRetryUtc -ne [DateTime]::MinValue -and [DateTime]::UtcNow -lt $state.NextRetryUtc) { return }
                if ($state.ConnectAR -and $state.ConnectAR.IsCompleted) {
                    try {
                        $state.Client.EndConnect($state.ConnectAR); $state.Sock=$state.Client.Client; $state.Sock.NoDelay=$true; $state.Sock.Blocking=$false; $state.Sock.SendBufferSize=$cfg.SOCKET_BUFFER_SIZE
                        if (Prepare-Current-File) {
                            Set-AppState "Sending"
                            $state.ConnectAR=$null
                            $script:ProgressValue=0; $script:CustomProgress.Invalidate()
                            $lblConnStatus.Text="Transferring..."
                            Apply-ConnIndicatorStable "Green" "Transferring..."
                            $continueTick = $true
                        } else {
                            Finish-Send $false $true
                        }
                    } catch {
                        $state.NextRetryUtc = [DateTime]::UtcNow.AddMilliseconds($cfg.CONNECT_RETRY_EVERY_MS)
                        Start-ConnectAttempt
                    }
                }
            }
            "Sending" {
                if ([int]([DateTime]::UtcNow - $state.LastSendProgressUtc).TotalMilliseconds -gt $cfg.SEND_STALL_TIMEOUT_MS) { Finish-Send $true; return }
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
                            $n=$state.Sock.Send($state.SendBuf, $state.SendBufOffset, $toSend, [System.Net.Sockets.SocketFlags]::None)
                            if ($n -le 0) { break }
                            $state.LastSendProgressUtc=[DateTime]::UtcNow
                            $state.Sent+=$n; $budget-=$n; $state.SendBufOffset+=$n; $state.SendBufCount-=$n; if ($state.SendBufIsHeader) { $state.HeaderSent+=$n }
                        } else { break }
                    } catch { break }
                }
                $curPl = [Math]::Max(0, $state.Sent - $state.HeaderLen); $ovSent = $state.QueuePayloadSent + $curPl; $ovPct = if ($state.QueueTotalPayload -gt 0) { [int]($ovSent * 100 / $state.QueueTotalPayload) } else { 0 }; if ($script:ProgressValue -ne $ovPct) { $script:ProgressValue=$ovPct; $script:CustomProgress.Invalidate(); try { [TaskbarProgress]::SetValue($form.Handle, [uint64]$ovSent, [uint64]$state.QueueTotalPayload) } catch {} }; Refresh-TransferQueueVisual; Update-Statistics
            }
            "WaitingAck" {
                if ([int]([DateTime]::UtcNow - $state.WaitStartUtc).TotalMilliseconds -gt $cfg.WAIT_ACK_TIMEOUT_MS) { Finish-Send $true; return }
                try {
                    if ($state.Sock.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead)) {
                        $buf=$state.AckReadBuf; $r=$state.Sock.Receive($buf, 0, $buf.Length, [System.Net.Sockets.SocketFlags]::None)
                        if ($r -gt 0) { 
                            for ($i = 0; $i -lt $r; $i++) { if ($buf[$i] -eq 6) { $state.AckReceived = $true; break } }
                            $state.AckBuffer += [System.Text.Encoding]::ASCII.GetString($buf,0,$r)
                            if ($state.AckBuffer.Length -gt 32) { $state.AckBuffer = $state.AckBuffer.Substring($state.AckBuffer.Length - 32) }
                            $ackText = $state.AckBuffer.Trim()
                            if ($state.AckReceived -or $ackText -eq "OK" -or $ackText -eq "ACK") {
                                $state.QueuePayloadSent += $state.PayloadLen
                                $state.CurrentFileIndex++
                                if ($state.CurrentFileIndex -lt $state.TotalQueueFiles) {
                                    if (Prepare-Current-File) { 
                                        Set-AppState "Sending"
                                        $lblConnStatus.Text="Transferring..."
                                        Apply-ConnIndicatorStable "Green" "Transferring..."
                                        $continueTick = $true
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
        }
    } catch { Finish-Send $false $true; [System.Windows.Forms.MessageBox]::Show("Transfer Error: " + $_.Exception.Message) }
    finally { $script:IsProcessingTick = $false }
}

function Finish-Send($timeout, $cancel=$false) {
    $timer.Stop()
    Reset-SendHandshake
    try { if ($state.FileStream) { $state.FileStream.Close(); $state.FileStream=$null } } catch { $state.FileStream=$null }
    try { if ($state.Sock) { $state.Sock.Close(); $state.Sock=$null } } catch { $state.Sock=$null }
    try { if ($state.Client) { $state.Client.Close(); $state.Client=$null } } catch { $state.Client=$null }
    $state.ConnectAR=$null
    
    if ($timeout -or $cancel) {
        $state.PortStatus = "Unknown";
        $state.AppStatus = "Unknown";
        $state.AutoProbeSuspended = $false
        $state.LastTransferCancelled = $true
    }

    Set-AppState "Idle"

    # Taskbar progress: red for error, clear for success
    if ($timeout -or $cancel) { try { [TaskbarProgress]::SetState($form.Handle, 4) } catch {} }
    else { try { [TaskbarProgress]::SetState($form.Handle, 0) } catch {} }
    
    $msg = ""
    $icon = "Green"
    
    if ($cancel) { 
        $msg = "Cancelled. Waiting for server..." 
        $icon = "Red"   # <-- FIX: Cambiado a ROJO como pediste
    } elseif ($timeout) { 
        $msg = "Timed out. Waiting for server..." 
        $icon = "Red"
    } else {
        # Resumen de transferencia exitosa
        $elapsed = [DateTime]::UtcNow - $state.QueueStartUtc
        $totalStr = Format-Bytes $state.QueueTotalSize
        if ($elapsed.TotalMinutes -ge 1) {
            $timeStr = "{0:F0}m {1:F0}s" -f [Math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
        } else {
            $timeStr = "{0:F0}s" -f $elapsed.TotalSeconds
        }
        $msg = "{0} file(s) sent ({1}) in {2}" -f $state.TotalQueueFiles, $totalStr, $timeStr
    }

    if ($timeout -or $cancel) {
        Apply-ConnIndicatorStable $icon $msg
    } else {
        Apply-ConnIndicatorStable "Green" "Ready"
    }
    $lblStatus.Text = $msg
    if (-not $timeout -and -not $cancel) { $lblStatus.ForeColor = $script:ThemeGreen }

    # Flash taskbar si la ventana no tiene foco
    try { if (-not $form.ContainsFocus) { [FlashWindow]::Flash($form.Handle, 3) } } catch {}

    # Sonido sutil al completar
    if (-not $timeout -and -not $cancel) { try { [System.Media.SystemSounds]::Asterisk.Play() } catch {} }

    # Guardar IP al historial tras envío exitoso
    if (-not $timeout -and -not $cancel) { Save-IpToHistory $state.Ip }

    # Auto-limpiar cola tras envío exitoso
    if (-not $timeout -and -not $cancel) { $lstFiles.Items.Clear() }

    if ($state.MonitoringPaused) {
        $picConn.Image = $bmpGray
        $lblConnStatus.Text = "Paused"
        $lblConnStatus.ForeColor = $script:ThemeTextDim
        $toolTip.SetToolTip($picConn, "Click to resume monitoring")
    } else {
        $connectionTimer.Start()
    }

    if ($timeout -or $cancel) {
        $state.NextAutoConnCheckUtc = [DateTime]::UtcNow
        Invoke-PortProbe
    }
}
