# ==========================================
# BRIDGEZX CLIENT v0.3 (Stable)
# ==========================================

Set-StrictMode -Version Latest

# --- FIX: ELIMINAR MODO DE ERROR AGRESIVO ---
if (-not $global:PSDefaultParameterValues) { $global:PSDefaultParameterValues = @{} }
$ErrorActionPreference = 'Continue'
# --------------------------------------------

try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue | Out-Null } catch {}

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

Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; Add-Type -AssemblyName System.Net.NetworkInformation
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

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

# --- FUNCIÓN DE LIMPIEZA (Corregida: Añadida aquí) ---
function Cleanup-Connection {
    # Cierra forzosamente cualquier conexión abierta al salir
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