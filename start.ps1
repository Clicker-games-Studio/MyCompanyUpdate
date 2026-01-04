# Filename: UpdateLoaderApp.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form (normal app look)
$form = New-Object System.Windows.Forms.Form
$form.Text = "Update Loader - BETA"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(600, 300)
$form.BackColor = [System.Drawing.Color]::White
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Add a label to display messages
$label = New-Object System.Windows.Forms.Label
$label.Text = "Starting..."
$label.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$label.ForeColor = [System.Drawing.Color]::Black
$label.AutoSize = $false
$label.TextAlign = 'MiddleCenter'
$label.Dock = 'Top'
$label.Height = 80
$form.Controls.Add($label)

# Add a progress bar
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Style = 'Continuous'
$progress.Minimum = 0
$progress.Maximum = 100
$progress.Value = 0
$progress.Dock = 'Bottom'
$progress.Height = 30
$form.Controls.Add($progress)

# Function to smoothly update progress
function Update-Progress($message, $start, $end, $steps=20) {
    $label.Text = $message
    $increment = ($end - $start) / $steps
    for ($i = 1; $i -le $steps; $i++) {
        $progress.Value = [math]::Min($start + ($increment * $i), $end)
        $form.Refresh()
        Start-Sleep -Milliseconds 200  # adjust for longer loading
    }
}

# Timer to start after form loads
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100
$timer.Add_Tick({
    $timer.Stop()

    Update-Progress "This update is in BETA..." 0 10
    Update-Progress "Loading to fetch scripts..." 10 50
    Update-Progress "Successfully fetched scripts!" 50 75
    Update-Progress "Searching for more scripts..." 75 90
    Update-Progress "Now running next script..." 90 98
    Update-Progress "Process completed. Exiting..." 98 100

    Start-Sleep -Milliseconds 1000
    $form.Close()
})
$timer.Start()

# Show the form
[void]$form.ShowDialog()
