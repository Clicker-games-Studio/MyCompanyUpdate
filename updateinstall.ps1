# ================= FORCE STA =================
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    powershell.exe -STA -NoExit -File $PSCommandPath
    exit
}

try {

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ================= HELPERS =================
function Convert-Size($bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    return "$bytes Bytes"
}

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ================= FORM =================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Update Installer"
$form.WindowState = 'Maximized'
$form.FormBorderStyle = 'None'
$form.BackColor = [System.Drawing.Color]::White

# ================= SCREEN 1: WELCOME =================
$screen1 = New-Object System.Windows.Forms.Panel
$screen1.Dock = 'Fill'

$title = New-Object System.Windows.Forms.Label
$title.Text = "UPDATE INSTALLER"
$title.Font = New-Object System.Drawing.Font("Arial",36,[System.Drawing.FontStyle]::Bold)
$title.TextAlign = 'MiddleCenter'
$title.Dock = 'Top'
$title.Height = 150
$screen1.Controls.Add($title)

$btnNext = New-Object System.Windows.Forms.Button
$btnNext.Text = "Next"
$btnNext.Font = New-Object System.Drawing.Font("Arial",16)
$btnNext.Size = New-Object System.Drawing.Size(200,60)
$screen1.Controls.Add($btnNext)

$form.Controls.Add($screen1)

# ================= SCREEN 2: DRIVE SELECTION =================
$screen2 = New-Object System.Windows.Forms.Panel
$screen2.Dock = 'Fill'
$screen2.Visible = $false

$info = New-Object System.Windows.Forms.Label
$info.Text = "Select the USB / external drive(s) to apply the update"
$info.Font = New-Object System.Drawing.Font("Arial",18)
$info.TextAlign = 'MiddleCenter'
$info.Dock = 'Top'
$info.Height = 60
$screen2.Controls.Add($info)

$container = New-Object System.Windows.Forms.Panel
$container.Dock = 'Fill'
$screen2.Controls.Add($container)

$panel = New-Object System.Windows.Forms.FlowLayoutPanel
$panel.FlowDirection = 'TopDown'
$panel.WrapContents = $false
$panel.AutoScroll = $true
$panel.Width = 700
$panel.Height = 350
$container.Controls.Add($panel)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Width = 700
$progressBar.Height = 30
$progressBar.Style = 'Continuous'
$container.Controls.Add($progressBar)

# Apply button
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Apply"
$btnApply.Font = New-Object System.Drawing.Font("Arial",14)
$btnApply.Size = New-Object System.Drawing.Size(120,50)
$container.Controls.Add($btnApply)

$form.Controls.Add($screen2)

# ================= SCREEN 3: COMPLETION =================
$screen3 = New-Object System.Windows.Forms.Panel
$screen3.Dock = 'Fill'
$screen3.Visible = $false

$lblComplete = New-Object System.Windows.Forms.Label
$lblComplete.Text = "Update installer is complete.`nBoot from your USB."
$lblComplete.Font = New-Object System.Drawing.Font("Arial",24,[System.Drawing.FontStyle]::Bold)
$lblComplete.TextAlign = 'MiddleCenter'
$lblComplete.AutoSize = $true
$lblComplete.Dock = 'None'
$screen3.Controls.Add($lblComplete)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Font = New-Object System.Drawing.Font("Arial",14)
$btnExit.Size = New-Object System.Drawing.Size(150,50)
$screen3.Controls.Add($btnExit)

$form.Controls.Add($screen3)

# ================= EVENTS =================
$btnNext.Add_Click({
    $screen1.Visible = $false
    $screen2.Visible = $true

    $panel.Controls.Clear()
    $global:checkboxes = @()

    $drives = Get-CimInstance Win32_LogicalDisk | Where-Object {
        ($_.DriveType -eq 2 -or $_.DriveType -eq 3) -and $_.DeviceID -ne "C:"
    }

    foreach ($d in $drives) {
        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text = "$($d.DeviceID) - $([Math]::Round($d.FreeSpace/1GB,2)) GB free of $([Math]::Round($d.Size/1GB,2)) GB"
        $cb.Font = New-Object System.Drawing.Font("Arial",14)
        $cb.AutoSize = $true
        $panel.Controls.Add($cb)
        $global:checkboxes += $cb
    }

    $panel.Left = ($container.ClientSize.Width - $panel.Width)/2
    $panel.Top  = 20

    $progressBar.Top = $panel.Top + $panel.Height + 20
    $progressBar.Left = ($container.ClientSize.Width - $progressBar.Width)/2

    $btnApply.Top = $progressBar.Top + $progressBar.Height + 20
    $btnApply.Left = ($container.ClientSize.Width - $btnApply.Width)/2
})

$btnApply.Add_Click({

    if (-not (Is-Admin)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Run this program as Administrator.",
            "Admin Required",
            'OK',
            'Error'
        )
        return
    }

    $selected = $checkboxes | Where-Object { $_.Checked }
    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Select at least one drive.")
        return
    }

    $isoPath = "C:\WinPE_x64.iso"
    if (-not (Test-Path $isoPath)) {
        [System.Windows.Forms.MessageBox]::Show("ISO not found at $isoPath")
        return
    }

    foreach ($cb in $selected) {
        $driveLetter = $cb.Text.Substring(0,2).TrimEnd(":")

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "FORMAT drive $driveLetter and apply ISO? ALL DATA WILL BE LOST.",
            "CONFIRM",
            'YesNo',
            'Warning'
        )

        if ($confirm -ne 'Yes') { continue }

        try {
            Format-Volume -DriveLetter $driveLetter -FileSystem FAT32 -Force

            $iso = Mount-DiskImage -ImagePath $isoPath -PassThru
            $isoDrive = ($iso | Get-Volume).DriveLetter + ":\"

            $files = Get-ChildItem -Path $isoDrive -Recurse
            $totalFiles = $files.Count
            $counter = 0
            $progressBar.Value = 0
            $form.Refresh()

            foreach ($f in $files) {
                $destination = $f.FullName.Replace($isoDrive, "$driveLetter`:\")
                if ($f.PSIsContainer) {
                    New-Item -Path $destination -ItemType Directory -Force | Out-Null
                } else {
                    Copy-Item $f.FullName $destination -Force
                }
                $counter++
                $progressBar.Value = [math]::Round(($counter/$totalFiles)*100)
                $form.Refresh()
            }

            # Create WinPE boot detection file
            $detectFile = "$driveLetter`:\WinPEBOOTABLE.detect"
            Set-Content -Path $detectFile -Value "Bootable=true" -Encoding ASCII

            Dismount-DiskImage -ImagePath $isoPath
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed on drive $driveLetter")
        }
    }

    $progressBar.Value = 0
    $screen2.Visible = $false
    $screen3.Visible = $true

    $lblComplete.Left = ($form.ClientSize.Width - $lblComplete.Width)/2
    $lblComplete.Top = 200
    $btnExit.Top = $lblComplete.Top + $lblComplete.Height + 30
    $btnExit.Left = ($form.ClientSize.Width - $btnExit.Width)/2
})

$btnExit.Add_Click({ $form.Close() })

# ================= LAYOUT =================
$form.Add_Shown({
    $btnNext.Left = ($form.ClientSize.Width - $btnNext.Width)/2
    $btnNext.Top  = 300
})

# ================= SHOW =================
[void]$form.ShowDialog()

}
catch {
    Write-Host "ERROR:" -ForegroundColor Red
    Write-Host $_
    Read-Host "Press ENTER to exit"
}
