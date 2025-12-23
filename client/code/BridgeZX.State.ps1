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
    QueueTotalSize=0; 
    
    Bytes=$null; HeaderBytes=$null; HeaderSent=0; FileStream=$null; SendBuf=$null; SendBufOffset=0; SendBufCount=0; SendBufIsHeader=$false
    Total=0; HeaderLen=0; PayloadLen=0; Sent=0; Client=$null; Sock=$null; ConnectAR=$null; ConnectStartUtc=[DateTime]::MinValue; NextRetryUtc=[DateTime]::MinValue; WaitStartUtc=[DateTime]::MinValue
    TransferStartUtc=[DateTime]::MinValue; LastSendProgressUtc=[DateTime]::MinValue; LastStatsUpdate=[DateTime]::UtcNow; ProgressStarted=$false; UiProgress=0.0; TargetProgress=0.0; LastTickUtc=[DateTime]::UtcNow
    CloseObservedUtc=[DateTime]::MinValue; AckReceived=$false; AckBuffer=""; Cancelled=$false; IsCheckingConnection=$false; TransferActive=$false; IpAlive=$false; PortStatus="Unknown"; AppStatus="Unknown"
    AutoProbeSuspended=$false; LastAutoProbeIp=""; LastHandshakeUtc=[DateTime]::MinValue; LastPortProbeUtc=[DateTime]::MinValue; LastConnectionCheckUtc=[DateTime]::MinValue
    CachedFilePath=""; CachedFileOk=$null; CachedTransName=""; FileCacheLastCheckTicks=0; ConnCheckPhase="Idle"; ConnCheckIp=$null; ConnCheckForceProbe=$false; ConnCheckSkipHandshake=$false
    LastOpenVerifyUtc=[DateTime]::MinValue; ConnCheckStartUtc=[DateTime]::MinValue; NextAutoConnCheckUtc=[DateTime]::MinValue; PingTask=$null; ProbeClient=$null; ProbeTask=$null; ProbeAR=$null; ProbeStartUtc=[DateTime]::MinValue
    ConnFailCount=0; ConnFailThreshold=$cfg.CONN_FAIL_THRESHOLD; ConnGraceMs=$cfg.CONN_GRACE_MS; LastConnectedUtc=[DateTime]::MinValue
    
    # Bandera de cancelación
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

                        # 2. FIX: Solo reseteamos la cancelación SI el handshake es OK (Servidor 100% listo)
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
                        # Si puerto cerrado y cancelado, mantenemos el mensaje, sino amarillo genérico
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
    
    # Color Rojo para errores críticos
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
