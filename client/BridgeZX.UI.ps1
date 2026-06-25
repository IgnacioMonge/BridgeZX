# 6. INTERFAZ GRÁFICA (BridgeZX v0.5.3 - Dark Theme)
# ==========================================

# --- PALETA DE COLORES ---
$script:ThemeBg       = [System.Drawing.Color]::FromArgb(28, 28, 36)
$script:ThemeSurface  = [System.Drawing.Color]::FromArgb(38, 38, 48)
$script:ThemeSurface2 = [System.Drawing.Color]::FromArgb(48, 48, 60)
$script:ThemeBorder   = [System.Drawing.Color]::FromArgb(60, 60, 75)
$script:ThemeText     = [System.Drawing.Color]::FromArgb(230, 230, 240)
$script:ThemeTextDim  = [System.Drawing.Color]::FromArgb(170, 170, 190)
$script:ThemeAccent   = [System.Drawing.Color]::FromArgb(0, 180, 220)
$script:ThemeGreen    = [System.Drawing.Color]::FromArgb(46, 160, 67)
$script:ThemeRed      = [System.Drawing.Color]::FromArgb(220, 60, 60)
$script:ThemeYellow   = [System.Drawing.Color]::FromArgb(220, 180, 0)

# --- SHARED GDI OBJECTS (reused across Paint handlers, never dispose until exit) ---
$script:PenBorder    = New-Object System.Drawing.Pen($script:ThemeBorder)
$script:PenDisabled  = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(50, 50, 65))
$script:FontTitle    = New-Object System.Drawing.Font("Segoe UI", 26, [System.Drawing.FontStyle]::Bold)
$script:FontSub      = New-Object System.Drawing.Font("Segoe UI", 9)
$script:FontAbout    = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$script:FontAboutVer = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$script:FontAboutText = New-Object System.Drawing.Font("Segoe UI", 9)
$script:FontAboutCredit = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$script:FontButton = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$script:BrushAccent  = New-Object System.Drawing.SolidBrush($script:ThemeAccent)
$script:BrushDisTxt  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 120, 145))

function Apply-ButtonStyle {
    param($btn, $color)
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = $script:ThemeBorder
    $btn.BackColor = $color
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Font = $script:FontButton
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    # Hover effect
    $hoverColor = [System.Drawing.Color]::FromArgb([Math]::Min(255, $color.R + 25), [Math]::Min(255, $color.G + 25), [Math]::Min(255, $color.B + 25))
    $btn.FlatAppearance.MouseOverBackColor = $hoverColor
    $btn.FlatAppearance.MouseDownBackColor = $color
    # Owner-draw para que el texto disabled sea visible en tema oscuro
    $btn.Add_EnabledChanged({
        if ($this.Enabled) { $this.ForeColor = [System.Drawing.Color]::White }
        else { $this.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 145) }
    })
    $btn.Add_Paint({
        if (-not $this.Enabled) {
            $g = $_.Graphics
            $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
            $sf = New-Object System.Drawing.StringFormat
            $sf.Alignment = [System.Drawing.StringAlignment]::Center
            $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
            $r = $this.ClientRectangle
            $rectF = New-Object System.Drawing.RectangleF($r.X, $r.Y, $r.Width, $r.Height)
            $g.Clear($this.BackColor)
            $g.DrawRectangle($script:PenDisabled, 0, 0, $r.Width-1, $r.Height-1)
            $g.DrawString($this.Text, $this.Font, $script:BrushDisTxt, $rectF, $sf)
            $sf.Dispose()
        }
    })
}

function New-SectionLabel {
    param([string]$text, [int]$x, [int]$y)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text.ToUpper()
    $lbl.AutoSize = $true
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8)
    $lbl.ForeColor = $script:ThemeAccent
    $lbl.BackColor = $script:ThemeBg
    $lbl.Location = New-Object System.Drawing.Point($x, $y)
    return $lbl
}

function Show-AboutBox {
    $ab = New-Object System.Windows.Forms.Form; $ab.Text="About BridgeZX"; if($global:AppIcon){$ab.Icon=$global:AppIcon}
    $ab.Size=New-Object System.Drawing.Size(420, 360); $ab.StartPosition="CenterParent"; $ab.FormBorderStyle="FixedDialog"; $ab.MaximizeBox=$false; $ab.MinimizeBox=$false; $ab.BackColor=$script:ThemeBg

    $abHeader = New-Object System.Windows.Forms.Panel; $abHeader.Height=60; $abHeader.Dock=[System.Windows.Forms.DockStyle]::Top; $abHeader.BackColor=$script:ThemeBg
    $abHeader.Add_Paint({
        $g=$_.Graphics; $wPanel=$abHeader.Width; $hPanel=$abHeader.Height
        $g.DrawImage($script:MosaicBitmap, 0, 0, $wPanel, $hPanel)
        $g.DrawLine($script:PenBorder, 0, $hPanel-1, $wPanel, $hPanel-1)
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $g.DrawString("BridgeZX", $script:FontAbout, [System.Drawing.Brushes]::White, 12, 10)
    })
    $ab.Controls.Add($abHeader)

    $buildStamp = if ((Test-Path variable:global:BUILD_DATE) -and $global:BUILD_DATE) { $global:BUILD_DATE } else { "dev" }
    $lblVer=New-Object System.Windows.Forms.Label; $lblVer.Text="Version $global:APP_VERSION  -  Build $buildStamp"; $lblVer.AutoSize=$true; $lblVer.Font=$script:FontAboutVer; $lblVer.ForeColor=$script:ThemeText; $lblVer.BackColor=$script:ThemeBg; $lblVer.Location=New-Object System.Drawing.Point(20,78); $ab.Controls.Add($lblVer)

    $lblDesc=New-Object System.Windows.Forms.Label; $lblDesc.Text="Universal Queue Loader for ZX Spectrum`nvia WiFi (ESP) over UART (AY / divMMC / ZX-Uno)"; $lblDesc.AutoSize=$true; $lblDesc.Font=$script:FontAboutText; $lblDesc.ForeColor=$script:ThemeTextDim; $lblDesc.BackColor=$script:ThemeBg; $lblDesc.Location=New-Object System.Drawing.Point(20,102); $ab.Controls.Add($lblDesc)

    $lblBased=New-Object System.Windows.Forms.Label; $lblBased.Text="Based on code from LAIN by Alex Nihirash"; $lblBased.AutoSize=$true; $lblBased.Font=$script:FontAboutText; $lblBased.ForeColor=$script:ThemeTextDim; $lblBased.BackColor=$script:ThemeBg; $lblBased.Location=New-Object System.Drawing.Point(20,150); $ab.Controls.Add($lblBased)
    $lnkLain=New-Object System.Windows.Forms.LinkLabel; $lnkLain.Text="https://github.com/nihirash/Lain"; $lnkLain.AutoSize=$true; $lnkLain.Location=New-Object System.Drawing.Point(20,170); $lnkLain.LinkColor=$script:ThemeAccent; $lnkLain.BackColor=$script:ThemeBg
    $lnkLain.LinkBehavior=[System.Windows.Forms.LinkBehavior]::HoverUnderline
    $lnkLain.Add_LinkClicked({ [System.Diagnostics.Process]::Start("https://github.com/nihirash/Lain") }); $ab.Controls.Add($lnkLain)

    $lblMe=New-Object System.Windows.Forms.Label; $lblMe.Text="(C) 2025-2026 M. Ignacio Monge Garcia"; $lblMe.AutoSize=$true; $lblMe.Font=$script:FontAboutCredit; $lblMe.ForeColor=$script:ThemeText; $lblMe.BackColor=$script:ThemeBg; $lblMe.Location=New-Object System.Drawing.Point(20,205); $ab.Controls.Add($lblMe)
    $lnkBridge=New-Object System.Windows.Forms.LinkLabel; $lnkBridge.Text="https://github.com/IgnacioMonge/BridgeZX"; $lnkBridge.AutoSize=$true; $lnkBridge.Location=New-Object System.Drawing.Point(20,225); $lnkBridge.LinkColor=$script:ThemeAccent; $lnkBridge.BackColor=$script:ThemeBg
    $lnkBridge.LinkBehavior=[System.Windows.Forms.LinkBehavior]::HoverUnderline
    $lnkBridge.Add_LinkClicked({ [System.Diagnostics.Process]::Start("https://github.com/IgnacioMonge/BridgeZX") }); $ab.Controls.Add($lnkBridge)

    $btnClose=New-Object System.Windows.Forms.Button; $btnClose.Text="Close"; $btnClose.Size=New-Object System.Drawing.Size(80,28); $btnClose.Location=New-Object System.Drawing.Point(310,275); Apply-ButtonStyle $btnClose $script:ThemeSurface2; $btnClose.Add_Click({$ab.Close()}); $ab.Controls.Add($btnClose)

    try { $ab.ShowDialog($form)|Out-Null } finally { $ab.Dispose() }
}

# === FORMULARIO PRINCIPAL ===
$form = New-Object System.Windows.Forms.Form
$null = $form.GetType().GetProperty("DoubleBuffered",[System.Reflection.BindingFlags] "NonPublic,Instance").SetValue($form,$true,$null)
$form.Text="BridgeZX v$global:APP_VERSION Multi-Loader"; if($global:AppIcon){$form.Icon=$global:AppIcon}
$form.StartPosition="CenterScreen"; $form.AutoScaleMode=[System.Windows.Forms.AutoScaleMode]::Dpi
$form.Font=New-Object System.Drawing.Font("Segoe UI",9); $form.ClientSize=New-Object System.Drawing.Size(620,500); $form.FormBorderStyle="FixedSingle"; $form.MaximizeBox=$false
$form.BackColor=$script:ThemeBg; $form.ForeColor=$script:ThemeText

# --- HEADER ---
$pnlHeader=New-Object System.Windows.Forms.Panel; $pnlHeader.Height=70; $pnlHeader.Dock=[System.Windows.Forms.DockStyle]::Top; $pnlHeader.BackColor=$script:ThemeBg; $pnlHeader.Cursor=[System.Windows.Forms.Cursors]::Hand
$pnlHeader.Add_Click({Show-AboutBox})

# Precalcular mosaico: partículas en los 4 colores Spectrum, cluster a la derecha
$script:MosaicPixels = @()
$rng = New-Object System.Random(42)
$mColors = @(
    [System.Drawing.Color]::FromArgb(216,0,0),
    [System.Drawing.Color]::FromArgb(255,216,0),
    [System.Drawing.Color]::FromArgb(0,200,0),
    [System.Drawing.Color]::FromArgb(0,180,220)
)
for ($i = 0; $i -lt 350; $i++) {
    $cx = 570 + $rng.Next(-240, 60)
    $cy = $rng.Next(-8, 78)
    $dist = [Math]::Abs($cx - 570)
    if ($rng.NextDouble() * 250 -lt $dist) { continue }
    # Heterogeneidad: mezcla de cuadrados tiny, small, medium y large
    $roll = $rng.NextDouble()
    $sz = if ($roll -lt 0.2) { $rng.Next(1, 4) } elseif ($roll -lt 0.5) { $rng.Next(4, 8) } elseif ($roll -lt 0.8) { $rng.Next(8, 14) } else { $rng.Next(14, 20) }
    $alpha = [int]([Math]::Max(45, 255 - $dist * 1.3))
    $baseColor = $mColors[$rng.Next(0, 4)]
    $color = [System.Drawing.Color]::FromArgb($alpha, $baseColor.R, $baseColor.G, $baseColor.B)
    $script:MosaicPixels += [pscustomobject]@{ X=$cx; Y=$cy; Size=$sz; Color=$color }
}

# Pre-render mosaic background into bitmap (once)
$script:MosaicBitmap = New-Object System.Drawing.Bitmap(620, 70)
$mg = [System.Drawing.Graphics]::FromImage($script:MosaicBitmap)
$mg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$mgBg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0, 0)), (New-Object System.Drawing.Point(620, 0)),
    [System.Drawing.Color]::FromArgb(22, 22, 30), [System.Drawing.Color]::FromArgb(32, 32, 42)
)
$mg.FillRectangle($mgBg, 0, 0, 620, 70); $mgBg.Dispose()
foreach ($px in $script:MosaicPixels) {
    $b = New-Object System.Drawing.SolidBrush($px.Color)
    $mg.FillRectangle($b, $px.X, $px.Y, $px.Size, $px.Size)
    $b.Dispose()
}
$mg.Dispose()

$pnlHeader.Add_Paint({
    $g=$_.Graphics; $wPanel=$pnlHeader.Width; $hPanel=$pnlHeader.Height
    $g.DrawImage($script:MosaicBitmap, 0, 0, $wPanel, $hPanel)
    $g.DrawLine($script:PenBorder, 0, $hPanel-1, $wPanel, $hPanel-1)
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.DrawString("BridgeZX", $script:FontTitle, [System.Drawing.Brushes]::White, 18, 8)
    $g.DrawString("Universal Multi-Loader", $script:FontSub, $script:BrushAccent, 22, 46)
})

# --- CONNECTION SECTION ---
$lblSecConn = New-SectionLabel "SPECTRUM CONNECTION" 22 84
$pnlConn=New-Object System.Windows.Forms.Panel; $pnlConn.Location=New-Object System.Drawing.Point(20,102); $pnlConn.Size=New-Object System.Drawing.Size(580,50); $pnlConn.BackColor=$script:ThemeSurface
# Borde sutil
$pnlConn.Add_Paint({ $_.Graphics.DrawRectangle($script:PenBorder, 0, 0, $pnlConn.Width-1, $pnlConn.Height-1) })

$lblIp=New-Object System.Windows.Forms.Label; $lblIp.Text="IP Address:"; $lblIp.Location=New-Object System.Drawing.Point(15,16); $lblIp.AutoSize=$true; $lblIp.Font=New-Object System.Drawing.Font("Segoe UI",9); $lblIp.ForeColor=$script:ThemeText; $lblIp.BackColor=$script:ThemeSurface
$script:SuppressIpTextChanged = $false
$script:IpHistory = [System.Collections.Generic.List[string]]::new()
$txtIp=New-Object System.Windows.Forms.TextBox; $txtIp.Location=New-Object System.Drawing.Point(95,13); $txtIp.Size=New-Object System.Drawing.Size(148,23); $txtIp.Font=New-Object System.Drawing.Font("Segoe UI",9.5); $txtIp.Text="192.168.0.205"; $txtIp.BackColor=$script:ThemeSurface2; $txtIp.ForeColor=$script:ThemeText; $txtIp.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle
$btnIpDrop=New-Object System.Windows.Forms.Button; $btnIpDrop.Location=New-Object System.Drawing.Point(243,13); $btnIpDrop.Size=New-Object System.Drawing.Size(22,23); $btnIpDrop.Text=[char]0x25BC; $btnIpDrop.FlatStyle=[System.Windows.Forms.FlatStyle]::Flat; $btnIpDrop.FlatAppearance.BorderColor=$script:ThemeBorder; $btnIpDrop.FlatAppearance.BorderSize=1; $btnIpDrop.BackColor=$script:ThemeSurface2; $btnIpDrop.ForeColor=$script:ThemeTextDim; $btnIpDrop.Font=New-Object System.Drawing.Font("Segoe UI",7); $btnIpDrop.Cursor=[System.Windows.Forms.Cursors]::Hand; $btnIpDrop.FlatAppearance.MouseOverBackColor=[System.Drawing.Color]::FromArgb(58,58,70)
# Popup ListBox for IP history
$script:IpPopup = New-Object System.Windows.Forms.ToolStripDropDown
$script:IpListHost = New-Object System.Windows.Forms.ToolStripControlHost(($script:IpListBox = New-Object System.Windows.Forms.ListBox))
$script:IpListBox.Font = New-Object System.Drawing.Font("Segoe UI",9.5); $script:IpListBox.BackColor=$script:ThemeSurface2; $script:IpListBox.ForeColor=$script:ThemeText; $script:IpListBox.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle; $script:IpListBox.ItemHeight=22; $script:IpListBox.IntegralHeight=$false
$script:IpListHost.Margin = New-Object System.Windows.Forms.Padding(0); $script:IpListHost.Padding = New-Object System.Windows.Forms.Padding(0); $script:IpListHost.AutoSize=$false
$script:IpPopup.Padding = New-Object System.Windows.Forms.Padding(0); $null = $script:IpPopup.Items.Add($script:IpListHost)
$script:IpListBox.Add_Click({
    if ($script:IpListBox.SelectedItem) {
        $script:SuppressIpTextChanged = $true
        $txtIp.Text = "$($script:IpListBox.SelectedItem)"
        $script:SuppressIpTextChanged = $false
        $script:IpPopup.Close()
    }
})
$script:IpPopupClosedUtc = [DateTime]::MinValue
$script:IpPopup.Add_Closed({ $script:IpPopupClosedUtc = [DateTime]::UtcNow })
$btnIpDrop.Add_Click({
    if ($script:IpHistory.Count -eq 0) { return }
    if (([DateTime]::UtcNow - $script:IpPopupClosedUtc).TotalMilliseconds -lt 300) { return }
    $script:IpListBox.Items.Clear()
    foreach ($h in $script:IpHistory) { $null = $script:IpListBox.Items.Add($h) }
    $itemCount = [Math]::Min($script:IpHistory.Count, 5)
    $popH = $itemCount * 22 + 4
    $script:IpListBox.Size = New-Object System.Drawing.Size(170, $popH)
    $script:IpListHost.Size = New-Object System.Drawing.Size(170, $popH)
    $pt = $pnlConn.PointToScreen((New-Object System.Drawing.Point($txtIp.Left, ($txtIp.Bottom + 1))))
    $script:IpPopup.Show($pt)
})
$lblPort=New-Object System.Windows.Forms.Label; $lblPort.Text=": 6144"; $lblPort.Location=New-Object System.Drawing.Point(270,16); $lblPort.AutoSize=$true; $lblPort.ForeColor=$script:ThemeText; $lblPort.BackColor=$script:ThemeSurface
$lblConnStatus=New-Object System.Windows.Forms.Label; $lblConnStatus.Text=""; $lblConnStatus.AutoSize=$false; $lblConnStatus.Location=New-Object System.Drawing.Point(340,13); $lblConnStatus.Size=New-Object System.Drawing.Size(190,23); $lblConnStatus.TextAlign=[System.Drawing.ContentAlignment]::MiddleRight; $lblConnStatus.ForeColor=$script:ThemeTextDim; $lblConnStatus.BackColor=$script:ThemeSurface; $lblConnStatus.Font=New-Object System.Drawing.Font("Segoe UI",9)
$picConn=New-Object System.Windows.Forms.PictureBox; $picConn.Location=New-Object System.Drawing.Point(540,16); $picConn.Size=New-Object System.Drawing.Size(16,16); $picConn.Cursor=[System.Windows.Forms.Cursors]::Hand; $picConn.BackColor=$script:ThemeSurface
$bmpGray=New-CircleBitmap ([System.Drawing.Color]::FromArgb(80,80,100)); $bmpGreen=New-CircleBitmap ([System.Drawing.Color]::FromArgb(46,160,67)); $bmpYellow=New-CircleBitmap ([System.Drawing.Color]::Gold); $bmpBlue=New-CircleBitmap ([System.Drawing.Color]::FromArgb(0,140,200)); $bmpRed=New-CircleBitmap ([System.Drawing.Color]::FromArgb(220,60,60)); $picConn.Image=$bmpGray
$pnlConn.Controls.AddRange(@($lblIp, $txtIp, $btnIpDrop, $lblPort, $lblConnStatus, $picConn))

# --- TRANSFER QUEUE SECTION ---
$lblSecQueue = New-SectionLabel "TRANSFER QUEUE" 22 162
$grpFile=New-Object System.Windows.Forms.Panel; $grpFile.Location=New-Object System.Drawing.Point(20,180); $grpFile.Size=New-Object System.Drawing.Size(580,210); $grpFile.BackColor=$script:ThemeSurface
$grpFile.Add_Paint({ $_.Graphics.DrawRectangle($script:PenBorder, 0, 0, $grpFile.Width-1, $grpFile.Height-1) })

# Label para info de cola (arriba de la lista)
$lblQueueInfo=New-Object System.Windows.Forms.Label; $lblQueueInfo.Text=""; $lblQueueInfo.AutoSize=$false; $lblQueueInfo.Location=New-Object System.Drawing.Point(15,8); $lblQueueInfo.Size=New-Object System.Drawing.Size(440,18); $lblQueueInfo.Font=New-Object System.Drawing.Font("Segoe UI",8); $lblQueueInfo.ForeColor=$script:ThemeTextDim; $lblQueueInfo.BackColor=$script:ThemeSurface

$lstFiles=New-Object System.Windows.Forms.ListBox; $lstFiles.Location=New-Object System.Drawing.Point(15,28)
$lstFiles.Size=New-Object System.Drawing.Size(455,170); $lstFiles.Font=New-Object System.Drawing.Font("Consolas",10); $lstFiles.SelectionMode=[System.Windows.Forms.SelectionMode]::MultiExtended
$lstFiles.HorizontalScrollbar=$true; $lstFiles.AllowDrop=$true
$lstFiles.BackColor=$script:ThemeSurface2; $lstFiles.ForeColor=$script:ThemeText; $lstFiles.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle
# Owner-draw: sent/current/pending styling + dark-theme selection
$lstFiles.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
$lstFiles.ItemHeight = 20
$lstFiles.Add_DrawItem({
    param($sender, $e)
    if ($e.Index -lt 0) { return }
    $g = $e.Graphics; $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $bounds = $e.Bounds; $text = "$($sender.Items[$e.Index])"
    $bgColor = $script:ThemeSurface2; $fgColor = $script:ThemeText; $prefix = ""; $progressPct = 0; $drawPartialHighlight = $false
    try {
        if ($state.TransferActive) {
            if ($e.Index -lt $state.CurrentFileIndex) {
                $fgColor = $script:ThemeGreen; $prefix = "$([char]0x2713) "
            } elseif ($e.Index -eq $state.CurrentFileIndex) {
                if ($state.TotalQueueFiles -gt 1) {
                    $bgColor = [System.Drawing.Color]::FromArgb(55, 62, 78)
                    $fgColor = $script:ThemeTextDim
                    $progressPct = Get-CurrentFilePayloadPercent
                    $drawPartialHighlight = $true
                } else {
                    $bgColor = [System.Drawing.Color]::FromArgb(0, 80, 110); $fgColor = [System.Drawing.Color]::White
                }
            } else { $fgColor = $script:ThemeTextDim }
        } else {
            if (($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -ne 0) {
                $bgColor = [System.Drawing.Color]::FromArgb(0, 90, 120); $fgColor = [System.Drawing.Color]::White
            }
        }
    } catch {}
    $bgBrush = New-Object System.Drawing.SolidBrush($bgColor)
    $g.FillRectangle($bgBrush, $bounds); $bgBrush.Dispose()
    $fgBrush = New-Object System.Drawing.SolidBrush($fgColor)
    $sf = New-Object System.Drawing.StringFormat
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $sf.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
    $textRect = New-Object System.Drawing.RectangleF(($bounds.X + 4), $bounds.Y, ($bounds.Width - 8), $bounds.Height)
    $displayText = $prefix + $text
    $g.DrawString($displayText, $e.Font, $fgBrush, $textRect, $sf)
    if ($drawPartialHighlight -and $progressPct -gt 0) {
        $clipWidth = [single][Math]::Min($textRect.Width, [Math]::Ceiling(($g.MeasureString($displayText, $e.Font).Width) * ($progressPct / 100.0)))
        if ($clipWidth -gt 0) {
            $stateClip = $g.Save()
            $g.SetClip((New-Object System.Drawing.RectangleF($textRect.X, $textRect.Y, $clipWidth, $textRect.Height)))
            $hlBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            $g.DrawString($displayText, $e.Font, $hlBrush, $textRect, $sf)
            $hlBrush.Dispose()
            $g.Restore($stateClip)
        }
        $accentWidth = [Math]::Max(1, [int](($progressPct / 100.0) * [Math]::Max(1, ($bounds.Width - 2))))
        $accentBrush = New-Object System.Drawing.SolidBrush($script:ThemeAccent)
        $g.FillRectangle($accentBrush, ($bounds.X + 1), ($bounds.Bottom - 2), $accentWidth, 1)
        $accentBrush.Dispose()
    }
    $fgBrush.Dispose(); $sf.Dispose()
})

$btnAdd=New-Object System.Windows.Forms.Button; $btnAdd.Text="Add..."; $btnAdd.Location=New-Object System.Drawing.Point(482,28); $btnAdd.Size=New-Object System.Drawing.Size(84,28); Apply-ButtonStyle $btnAdd ([System.Drawing.Color]::FromArgb(55,65,81))
$btnRemove=New-Object System.Windows.Forms.Button; $btnRemove.Text="Remove"; $btnRemove.Location=New-Object System.Drawing.Point(482,62); $btnRemove.Size=New-Object System.Drawing.Size(84,28); Apply-ButtonStyle $btnRemove ([System.Drawing.Color]::FromArgb(127,55,55))
$btnClear=New-Object System.Windows.Forms.Button; $btnClear.Text="Clear All"; $btnClear.Location=New-Object System.Drawing.Point(482,96); $btnClear.Size=New-Object System.Drawing.Size(84,28); Apply-ButtonStyle $btnClear $script:ThemeSurface2

# Botones de reordenar
$btnUp=New-Object System.Windows.Forms.Button; $btnUp.Text=[char]0x25B2; $btnUp.Location=New-Object System.Drawing.Point(482,140); $btnUp.Size=New-Object System.Drawing.Size(40,28); Apply-ButtonStyle $btnUp $script:ThemeSurface2
$btnDown=New-Object System.Windows.Forms.Button; $btnDown.Text=[char]0x25BC; $btnDown.Location=New-Object System.Drawing.Point(526,140); $btnDown.Size=New-Object System.Drawing.Size(40,28); Apply-ButtonStyle $btnDown $script:ThemeSurface2

$grpFile.Controls.AddRange(@($lblQueueInfo, $lstFiles, $btnAdd, $btnRemove, $btnClear, $btnUp, $btnDown))

# --- ACTIONS ---
$pnlActions=New-Object System.Windows.Forms.Panel; $pnlActions.Location=New-Object System.Drawing.Point(20,400); $pnlActions.Size=New-Object System.Drawing.Size(580,40); $pnlActions.BackColor=$script:ThemeBg
$btnSend=New-Object System.Windows.Forms.Button; $btnSend.Text="Send All"; $btnSend.Location=New-Object System.Drawing.Point(498,6); $btnSend.Size=New-Object System.Drawing.Size(84,30); Apply-ButtonStyle $btnSend $script:ThemeGreen; $btnSend.Font=New-Object System.Drawing.Font("Segoe UI Semibold",9.5); $btnSend.Enabled=$false
$btnCancel=New-Object System.Windows.Forms.Button; $btnCancel.Text="Cancel"; $btnCancel.Location=New-Object System.Drawing.Point(404,6); $btnCancel.Size=New-Object System.Drawing.Size(84,30); Apply-ButtonStyle $btnCancel $script:ThemeSurface2; $btnCancel.Enabled=$false
$pnlActions.Controls.AddRange(@($btnSend, $btnCancel))
$form.CancelButton = $btnCancel

# --- PROGRESS BAR (custom-drawn) ---
$script:CustomProgress = New-Object System.Windows.Forms.Panel; $script:CustomProgress.Dock=[System.Windows.Forms.DockStyle]::Bottom; $script:CustomProgress.Height=6; $script:CustomProgress.BackColor=$script:ThemeSurface2
$null = $script:CustomProgress.GetType().GetProperty("DoubleBuffered",[System.Reflection.BindingFlags]"NonPublic,Instance").SetValue($script:CustomProgress,$true,$null)
$script:ProgressValue = 0
$script:ConnectAnimActive = $false
$script:CustomProgress.Add_Paint({
    $g = $_.Graphics
    $g.Clear($script:ThemeSurface2)
    $pw = $script:CustomProgress.Width; $ph = $script:CustomProgress.Height
    if ($script:ConnectAnimActive) {
        # Animación tipo "indeterminate": bloque que se desplaza
        $blockW = 60; $x = $script:ConnectAnimOffset - $blockW
        if ($x -lt $pw) {
            $bx = [Math]::Max(0, $x); $bw = [Math]::Min($blockW, $pw - $bx)
            if ($bw -gt 0) {
                $brush = New-Object System.Drawing.SolidBrush($script:ThemeAccent)
                $g.FillRectangle($brush, $bx, 0, $bw, $ph)
                $brush.Dispose()
            }
        }
    }
    elseif ($script:ProgressValue -gt 0) {
        $w = [int](($script:ProgressValue / 100.0) * $pw)
        if ($w -gt 0) {
            $gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                (New-Object System.Drawing.Rectangle(0, 0, [Math]::Max(1,$w), $ph)),
                $script:ThemeAccent, $script:ThemeGreen,
                [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
            )
            $g.FillRectangle($gradBrush, 0, 0, $w, $ph)
            $gradBrush.Dispose()
        }
    }
})

# Progress placeholder (para compatibilidad con State.ps1 que usa $progress)
$progress=New-Object System.Windows.Forms.ProgressBar; $progress.Visible=$false; $progress.Height=0

# --- STATUS BAR ---
$pnlStatus=New-Object System.Windows.Forms.Panel; $pnlStatus.Dock=[System.Windows.Forms.DockStyle]::Bottom; $pnlStatus.Height=30; $pnlStatus.BackColor=[System.Drawing.Color]::FromArgb(20,20,28)
$pnlStatus.Add_Paint({ $_.Graphics.DrawLine($script:PenBorder, 0, 0, $pnlStatus.Width, 0) })
$lblStatus=New-Object System.Windows.Forms.Label; $lblStatus.Text="Ready."; $lblStatus.AutoSize=$false; $lblStatus.Dock=[System.Windows.Forms.DockStyle]::Fill; $lblStatus.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft; $lblStatus.Padding=New-Object System.Windows.Forms.Padding(12,0,0,0); $lblStatus.ForeColor=$script:ThemeTextDim; $lblStatus.Font=New-Object System.Drawing.Font("Segoe UI",8.5); $pnlStatus.Controls.Add($lblStatus)
$null = $lblStatus.GetType().GetProperty("DoubleBuffered",[System.Reflection.BindingFlags]"NonPublic,Instance").SetValue($lblStatus,$true,$null)
$null = $pnlStatus.GetType().GetProperty("DoubleBuffered",[System.Reflection.BindingFlags]"NonPublic,Instance").SetValue($pnlStatus,$true,$null)
$form.Controls.AddRange(@($pnlHeader, $lblSecConn, $pnlConn, $lblSecQueue, $grpFile, $pnlActions, $script:CustomProgress, $progress, $pnlStatus))

$toolTip=New-Object System.Windows.Forms.ToolTip; $toolTip.SetToolTip($picConn, "Click to test connection")
$toolTip.InitialDelay = 400; $toolTip.ReshowDelay = 200

# Menú contextual para la lista
$ctxMenu = New-Object System.Windows.Forms.ContextMenuStrip
$ctxMenu.BackColor = $script:ThemeSurface; $ctxMenu.ForeColor = $script:ThemeText
$ctxMenu.Renderer = New-Object System.Windows.Forms.ToolStripProfessionalRenderer
$ctxRemove = $ctxMenu.Items.Add("Remove selected")
$ctxOpenFolder = $ctxMenu.Items.Add("Open file location")
$null = $ctxMenu.Items.Add("-")
$ctxMoveUp = $ctxMenu.Items.Add("Move up")
$ctxMoveDown = $ctxMenu.Items.Add("Move down")
$null = $ctxMenu.Items.Add("-")
$ctxClearAll = $ctxMenu.Items.Add("Clear all")
$lstFiles.ContextMenuStrip = $ctxMenu

$openDlg=New-Object System.Windows.Forms.OpenFileDialog; $openDlg.Multiselect=$true
$openDlg.Filter="All files (*.*)|*.*"

# Timer para animación de connecting
$script:ConnectAnimTimer = New-Object System.Windows.Forms.Timer; $script:ConnectAnimTimer.Interval = 80
$script:ConnectAnimOffset = 0
$script:ConnectAnimTimer.Add_Tick({
    $script:ConnectAnimOffset = ($script:ConnectAnimOffset + 3) % ($script:CustomProgress.Width + 60)
    $script:CustomProgress.Invalidate()
})

# Flash taskbar helper (P/Invoke)
try {
    Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class FlashWindow {
    [StructLayout(LayoutKind.Sequential)] public struct FLASHWINFO {
        public uint cbSize; public IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout;
    }
    [DllImport("user32.dll")] public static extern bool FlashWindowEx(ref FLASHWINFO pwfi);
    public static void Flash(IntPtr handle, uint count) {
        FLASHWINFO fw = new FLASHWINFO();
        fw.cbSize = (uint)Marshal.SizeOf(typeof(FLASHWINFO)); fw.hwnd = handle;
        fw.dwFlags = 3; fw.uCount = count; fw.dwTimeout = 0;
        FlashWindowEx(ref fw);
    }
}
"@ -ErrorAction SilentlyContinue
} catch {}

# Taskbar progress API (ITaskbarList3)
try {
    Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class TaskbarProgress {
    [ComImport, Guid("ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ITaskbarList3 {
        void HrInit(); void AddTab(IntPtr h); void DeleteTab(IntPtr h); void ActivateTab(IntPtr h); void SetActiveAlt(IntPtr h);
        void MarkFullscreenWindow(IntPtr h, [MarshalAs(UnmanagedType.Bool)] bool f);
        void SetProgressValue(IntPtr h, ulong completed, ulong total);
        void SetProgressState(IntPtr h, int flags);
    }
    [ComImport, Guid("56fdf344-fd6d-11d0-958a-006097c9a090"), ClassInterface(ClassInterfaceType.None)]
    private class CTaskbarList {}
    private static ITaskbarList3 _tb = (ITaskbarList3)new CTaskbarList();
    public static void SetValue(IntPtr h, ulong completed, ulong total) { _tb.SetProgressValue(h, completed, total); }
    public static void SetState(IntPtr h, int state) { _tb.SetProgressState(h, state); }
}
"@ -ErrorAction SilentlyContinue
} catch {}
