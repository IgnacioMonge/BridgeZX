# ==========================================
# BRIDGEZX CLIENT v0.5.3
# ==========================================

Set-StrictMode -Version Latest

# --- FIX: ELIMINAR MODO DE ERROR AGRESIVO ---
if (-not $global:PSDefaultParameterValues) { $global:PSDefaultParameterValues = @{} }
$ErrorActionPreference = 'Continue'
# --------------------------------------------

Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; Add-Type -AssemblyName System.Net.NetworkInformation
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

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

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ==============================================================================
# BLOQUE DE INICIALIZACIÓN HÍBRIDA (Soporte PS1 y EXE)
# ==============================================================================

# 1. Definimos dónde están las imágenes físicas para el modo desarrollo (PS1)
# Ajusta estos nombres si tus archivos se llaman diferente o están en carpetas
$RutaIcono = Join-Path $PSScriptRoot "bridgezx.ico" 
$RutaLogo  = Join-Path $PSScriptRoot "bridgezx_logo.png" 

# 2. Lógica para el ICONO ($global:B64_ICON)
# Si la variable NO existe (estamos en PS1), intentamos crearla desde el archivo.
if (-not (Test-Path variable:global:B64_ICON)) {
    if (Test-Path $RutaIcono) {
        $Bytes = [System.IO.File]::ReadAllBytes($RutaIcono)
        $global:B64_ICON = [System.Convert]::ToBase64String($Bytes)
    } else {
        # Si no hay archivo ni variable, la dejamos vacía para que no de error
        $global:B64_ICON = ""
    }
}

# 3. Lógica para el LOGO ($global:B64_LOGO)
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

. "$ScriptRoot\BridgeZX.Resources.ps1"
. "$ScriptRoot\BridgeZX.Config.ps1"
. "$ScriptRoot\BridgeZX.Utils.ps1"
. "$ScriptRoot\BridgeZX.Files.ps1"
. "$ScriptRoot\BridgeZX.Network.ps1"
. "$ScriptRoot\BridgeZX.UI.ps1"
. "$ScriptRoot\BridgeZX.State.ps1"


# --- FUNCIÓN HELPER: Añadir archivo a la cola sin duplicados ---
function Add-FileToQueue([string]$filePath) {
    foreach ($i in $lstFiles.Items) {
        if (($i.Value -eq $filePath) -or ($i -eq $filePath)) { return }
    }
    $len = Safe-FileLength $filePath
    $name = Split-Path $filePath -Leaf
    if ($null -eq $len -or $len -le 0) {
        $state.FileErrorMsg = "$name is empty or unavailable"
        $state.LastQueueRejectMsg = $state.FileErrorMsg
        $state.LastQueueRejectUtc = [DateTime]::UtcNow
        if ($lblStatus) { $lblStatus.Text = $state.FileErrorMsg; $lblStatus.ForeColor = $script:ThemeRed }
        if ($lblQueueInfo) { $lblQueueInfo.Text = $state.FileErrorMsg; $lblQueueInfo.ForeColor = $script:ThemeRed }
        return
    }
    if ($len -gt $global:MAX_SINGLE_FILE_BYTES) {
        $state.FileErrorMsg = "$name exceeds $global:MAX_SINGLE_FILE_MB MB limit"
        $state.LastQueueRejectMsg = $state.FileErrorMsg
        $state.LastQueueRejectUtc = [DateTime]::UtcNow
        if ($lblStatus) { $lblStatus.Text = $state.FileErrorMsg; $lblStatus.ForeColor = $script:ThemeRed }
        if ($lblQueueInfo) { $lblQueueInfo.Text = $state.FileErrorMsg; $lblQueueInfo.ForeColor = $script:ThemeRed }
        return
    }
    $sz = Format-Bytes $len
    $lbl = "$name  [$sz]"
    $ok = $true
    $err = $null
    $obj = [pscustomobject]@{ Value=$filePath; Label=$lbl; SizeBytes=$len; QueueFileOk=$ok; QueueFileError=$err }
    $obj | Add-Member -MemberType ScriptMethod -Name "ToString" -Value { $this.Label } -Force
    $lstFiles.Items.Add($obj)
}

# --- FUNCIÓN DE LIMPIEZA ---
function Cleanup-Connection {
    try { if ($state.FileStream) { $state.FileStream.Close(); $state.FileStream=$null } } catch { $state.FileStream=$null }
    try { if ($state.Sock) { $state.Sock.Close(); $state.Sock=$null } } catch { $state.Sock=$null }
    try { if ($state.Client) { $state.Client.Close(); $state.Client=$null } } catch { $state.Client=$null }
    try { if ($state.ProbeSock) { $state.ProbeSock.Close(); $state.ProbeSock=$null } } catch { $state.ProbeSock=$null }
    try { if ($state.ProbeClient) { $state.ProbeClient.Close(); $state.ProbeClient=$null } } catch { $state.ProbeClient=$null }
    try { if ($state.HandshakeClient) { $state.HandshakeClient.Close(); $state.HandshakeClient=$null } } catch { $state.HandshakeClient=$null }
    $state.ConnectAR=$null; $state.ProbeAR=$null; $state.HandshakeAR=$null; $state.HandshakeSock=$null; $state.ProbeBytes=$null; $state.ProbeSent=0; $state.ProbeAckText=""
    # Limpieza GDI
    try { $bmpGray.Dispose() } catch {}
    try { $bmpGreen.Dispose() } catch {}
    try { $bmpYellow.Dispose() } catch {}
    try { $bmpBlue.Dispose() } catch {}
    try { $bmpRed.Dispose() } catch {}
    try { if ($global:AppIcon) { $global:AppIcon.Dispose() } } catch {}
    try { if ($global:LogoImage) { $global:LogoImage.Dispose() } } catch {}
    try { if ($script:MosaicBitmap) { $script:MosaicBitmap.Dispose() } } catch {}
    try { $script:PenBorder.Dispose() } catch {}
    try { $script:PenDisabled.Dispose() } catch {}
    try { $script:FontTitle.Dispose() } catch {}
    try { $script:FontSub.Dispose() } catch {}
    try { $script:FontAbout.Dispose() } catch {}
    try { $script:FontAboutVer.Dispose() } catch {}
    try { $script:FontAboutText.Dispose() } catch {}
    try { $script:FontAboutCredit.Dispose() } catch {}
    try { $script:FontButton.Dispose() } catch {}
    try { $script:BrushAccent.Dispose() } catch {}
    try { $script:BrushDisTxt.Dispose() } catch {}
    try { if ($script:BridgeZX_Mutex) { $script:BridgeZX_Mutex.Dispose(); $script:BridgeZX_Mutex=$null } } catch {}
}

# Drag-reorder state
$script:ListDragIndex = -1
$script:ListDragStart = $null

function Start-BridgeZX {
    $timer.Add_Tick({ Transfer-EngineTick })
    $connectionTimer.Add_Tick({ Invoke-WithStateLock { Process-ConnectionCheckState } })
    $script:TransferBlinkTimer.Add_Tick({ if ($state.TransferActive) { $picConn.Visible=-not $picConn.Visible } else { $picConn.Visible=$true } })
    $picConn.Add_Click({ Toggle-Monitoring })

    # Handlers UI
    $btnAdd.Add_Click({
        if ($script:LastOpenDir) { $openDlg.InitialDirectory = $script:LastOpenDir }
        if ($openDlg.ShowDialog() -eq "OK") {
            $script:LastOpenDir = [System.IO.Path]::GetDirectoryName($openDlg.FileNames[0])
            foreach ($f in $openDlg.FileNames) { Add-FileToQueue $f }
            if ($state.MonitoringPaused) { Toggle-Monitoring }
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

    # Drag & drop: external files/folders + internal reorder
    $lstFiles.Add_MouseDown({
        if ($state.Phase -ne "Idle" -or $_.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $idx = $lstFiles.IndexFromPoint($_.Location)
        if ($idx -ge 0) { $script:ListDragIndex = $idx; $script:ListDragStart = $_.Location }
    })
    $lstFiles.Add_MouseUp({ $script:ListDragIndex = -1 })
    $lstFiles.Add_DragEnter({
        if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
            $_.Effect='Copy'
            $lstFiles.BackColor = [System.Drawing.Color]::FromArgb(55, 60, 75)
        } elseif ($script:ListDragIndex -ge 0) {
            $_.Effect='Move'
        }
    })
    $lstFiles.Add_DragLeave({ $lstFiles.BackColor = $script:ThemeSurface2 })
    $lstFiles.Add_DragDrop({
        $lstFiles.BackColor = $script:ThemeSurface2
        if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
            $files=$_.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
            foreach ($f in $files) {
                if (Test-Path $f -PathType Container) {
                    Get-ChildItem $f -File -Recurse | ForEach-Object { Add-FileToQueue $_.FullName }
                } elseif (Test-Path $f -PathType Leaf) { Add-FileToQueue $f }
            }
            if ($state.MonitoringPaused) { Toggle-Monitoring }
        } elseif ($script:ListDragIndex -ge 0) {
            $pt = $lstFiles.PointToClient((New-Object System.Drawing.Point($_.X, $_.Y)))
            $dropIdx = $lstFiles.IndexFromPoint($pt)
            if ($dropIdx -ge 0 -and $dropIdx -ne $script:ListDragIndex) {
                $item = $lstFiles.Items[$script:ListDragIndex]
                $lstFiles.Items.RemoveAt($script:ListDragIndex)
                $lstFiles.Items.Insert($dropIdx, $item)
                $lstFiles.SelectedIndex = $dropIdx
            }
        }
        $script:ListDragIndex = -1
        Update-Buttons-State
    })

    # Doble-clic para eliminar
    $lstFiles.Add_DoubleClick({
        if ($state.Phase -ne "Idle") { return }
        $sel = @($lstFiles.SelectedItems)
        foreach ($s in $sel) { $lstFiles.Items.Remove($s) }
        Update-Buttons-State
    })

    # Tooltip + drag-reorder detection
    $lstFiles.Add_MouseMove({
        # Drag reorder: start after 4px threshold
        if ($script:ListDragIndex -ge 0 -and $_.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $script:ListDragStart) {
            if ([Math]::Abs($_.X - $script:ListDragStart.X) -gt 4 -or [Math]::Abs($_.Y - $script:ListDragStart.Y) -gt 4) {
                $lstFiles.DoDragDrop("__reorder__", [System.Windows.Forms.DragDropEffects]::Move)
                return
            }
        }
        # Tooltip
        $idx = $lstFiles.IndexFromPoint($_.Location)
        if ($idx -ge 0 -and $idx -lt $lstFiles.Items.Count) {
            $item = $lstFiles.Items[$idx]
            $path = if ($item.Value) { $item.Value } else { "$item" }
            if ($toolTip.GetToolTip($lstFiles) -ne $path) { $toolTip.SetToolTip($lstFiles, $path) }
        } else {
            if ($toolTip.GetToolTip($lstFiles) -ne "") { $toolTip.SetToolTip($lstFiles, "") }
        }
    })

    # Menú contextual handlers
    $ctxRemove.Add_Click({
        $sel = @($lstFiles.SelectedItems)
        foreach ($s in $sel) { $lstFiles.Items.Remove($s) }
        Update-Buttons-State
    })
    $ctxOpenFolder.Add_Click({
        if ($lstFiles.SelectedItem) {
            $path = if ($lstFiles.SelectedItem.Value) { $lstFiles.SelectedItem.Value } else { "$($lstFiles.SelectedItem)" }
            $dir = [System.IO.Path]::GetDirectoryName($path)
            if (Test-Path $dir) { [System.Diagnostics.Process]::Start("explorer.exe", "/select,`"$path`"") }
        }
    })
    $ctxMoveUp.Add_Click({
        $idx = $lstFiles.SelectedIndex
        if ($idx -gt 0) { $item=$lstFiles.Items[$idx]; $lstFiles.Items.RemoveAt($idx); $lstFiles.Items.Insert($idx-1,$item); $lstFiles.SelectedIndex=$idx-1 }
    })
    $ctxMoveDown.Add_Click({
        $idx = $lstFiles.SelectedIndex
        if ($idx -ge 0 -and $idx -lt ($lstFiles.Items.Count-1)) { $item=$lstFiles.Items[$idx]; $lstFiles.Items.RemoveAt($idx); $lstFiles.Items.Insert($idx+1,$item); $lstFiles.SelectedIndex=$idx+1 }
    })
    $ctxClearAll.Add_Click({ $lstFiles.Items.Clear(); Update-Buttons-State })

    # Atajos de teclado
    $form.KeyPreview = $true
    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'Escape' -and $state.Phase -ne "Idle") {
            $_.SuppressKeyPress = $true
            Request-TransferCancel
            return
        }
        if ($state.Phase -ne "Idle") { return }
        if ($_.KeyCode -eq 'Delete' -and $lstFiles.Enabled -and -not $txtIp.Focused) {
            if ($_.Shift -and $_.Control) {
                $lstFiles.Items.Clear(); Update-Buttons-State
            } else {
                $sel = @($lstFiles.SelectedItems)
                foreach ($s in $sel) { $lstFiles.Items.Remove($s) }
                Update-Buttons-State
            }
        }
        elseif ($_.Control -and $_.KeyCode -eq 'O') {
            $_.SuppressKeyPress = $true
            if ($script:LastOpenDir) { $openDlg.InitialDirectory = $script:LastOpenDir }
            if ($openDlg.ShowDialog() -eq "OK") {
                $script:LastOpenDir = [System.IO.Path]::GetDirectoryName($openDlg.FileNames[0])
                foreach ($f in $openDlg.FileNames) { Add-FileToQueue $f }
                Update-Buttons-State
            }
        }
    })

    # Reordenar cola
    $btnUp.Add_Click({
        $idx = $lstFiles.SelectedIndex
        if ($idx -gt 0) {
            $item = $lstFiles.Items[$idx]
            $lstFiles.Items.RemoveAt($idx)
            $lstFiles.Items.Insert($idx - 1, $item)
            $lstFiles.SelectedIndex = $idx - 1
        }
    })
    $btnDown.Add_Click({
        $idx = $lstFiles.SelectedIndex
        if ($idx -ge 0 -and $idx -lt ($lstFiles.Items.Count - 1)) {
            $item = $lstFiles.Items[$idx]
            $lstFiles.Items.RemoveAt($idx)
            $lstFiles.Items.Insert($idx + 1, $item)
            $lstFiles.SelectedIndex = $idx + 1
        }
    })

    $btnSend.Add_Click({ Start-SendWorkflow })
    $btnCancel.Add_Click({ Request-TransferCancel })
    $txtIp.Add_TextChanged({
        if ($script:SuppressIpTextChanged) { return }
        End-ConnectionCheck; $state.IpAlive=$false; $state.PortStatus="Unknown"
        if ($state.MonitoringPaused) { $picConn.Image=$bmpGray; $lblConnStatus.Text="Paused" }
        else { Apply-ConnIndicatorStable "Gray" "Checking..." }
        Update-Buttons-State
    })

    $form.Add_Shown({ Load-Config; Update-Buttons-State })

    # Evento de cierre
    $form.Add_FormClosing({ try { [TaskbarProgress]::SetState($form.Handle, 0) } catch {}; Save-Config; $timer.Stop(); $connectionTimer.Stop(); Cleanup-Connection })

    Apply-ConnIndicatorStable "Gray" "Initializing..."
    $connectionTimer.Start(); Process-ConnectionCheckState
    [void]$form.ShowDialog()
}

Start-BridgeZX
