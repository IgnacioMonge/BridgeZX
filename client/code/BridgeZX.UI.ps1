# 6. INTERFAZ GRÁFICA (BridgeZX - MultiFile UI)
# ==========================================
function Show-AboutBox {
    $ab = New-Object System.Windows.Forms.Form; $ab.Text="About BridgeZX"; if($global:AppIcon){$ab.Icon=$global:AppIcon}
    # Aumentamos la altura a 350 para dar más espacio vertical
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

    # 1. Descripción Principal (Y=80)
    $lblDesc=New-Object System.Windows.Forms.Label; $lblDesc.Text="Universal Queue Loader for ZX Spectrum`nusing ESP-12 via AY-3-8912"; $lblDesc.AutoSize=$true; $lblDesc.Font=New-Object System.Drawing.Font("Segoe UI",9); $lblDesc.Location=New-Object System.Drawing.Point(20,80); $ab.Controls.Add($lblDesc)

    # 2. Créditos Alex Nihirash (Bajado a Y=130 para separar de la descripción)
    $lblBased=New-Object System.Windows.Forms.Label; $lblBased.Text="Based on code from LAIN by Alex Nihirash"; $lblBased.AutoSize=$true; $lblBased.Font=New-Object System.Drawing.Font("Segoe UI",9); $lblBased.Location=New-Object System.Drawing.Point(20,130); $ab.Controls.Add($lblBased)
    
    # Enlace LAIN (Bajado a Y=150, 20px debajo del texto)
    $lnkLain=New-Object System.Windows.Forms.LinkLabel; $lnkLain.Text="https://github.com/nihirash/Lain"; $lnkLain.AutoSize=$true; $lnkLain.Location=New-Object System.Drawing.Point(20,150); 
    $lnkLain.LinkBehavior=[System.Windows.Forms.LinkBehavior]::HoverUnderline; 
    $lnkLain.Add_LinkClicked({ [System.Diagnostics.Process]::Start("https://github.com/nihirash/Lain") }); $ab.Controls.Add($lnkLain)

    # 3. Créditos Tuyos (Bajado a Y=185 para separar del bloque anterior)
    $lblMe=New-Object System.Windows.Forms.Label; $lblMe.Text="(C) 2025 M. Ignacio Monge García"; $lblMe.AutoSize=$true; $lblMe.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold); $lblMe.Location=New-Object System.Drawing.Point(20,185); $ab.Controls.Add($lblMe)
    
    # Enlace BridgeZX (Bajado a Y=205, 20px debajo del texto)
    $lnkBridge=New-Object System.Windows.Forms.LinkLabel; $lnkBridge.Text="https://github.com/IgnacioMonge/BridgeZX"; $lnkBridge.AutoSize=$true; $lnkBridge.Location=New-Object System.Drawing.Point(20,205); 
    $lnkBridge.LinkBehavior=[System.Windows.Forms.LinkBehavior]::HoverUnderline; 
    $lnkBridge.Add_LinkClicked({ [System.Diagnostics.Process]::Start("https://github.com/IgnacioMonge/BridgeZX") }); $ab.Controls.Add($lnkBridge)

    # Botón Cerrar (Bajado a Y=260)
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