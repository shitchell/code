#!/usr/bin/env psrun
#
# Display a notification in the Windows 10 notification area

# Default values
$Title = $null
$Icon = "Info"
$Timeout = 5000
$Text = $null
$Beep = $false
$BeepCount = 1
$BeepFrequency = 1000
$BeepDuration = 1000
$ActionURI = $null
$Positional = @()

# Process command line arguments
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]
    switch ($arg) {
        "-Help" {
            $Help = $true
        }
        "-Beep" {
            $Beep = $true
        }
        "-Text" {
            $Text = $args[$i + 1]
            $i++
        }
        "-Title" {
            $Title = $args[$i + 1]
            $i++
        }
        "-Icon" {
            $Icon = $args[$i + 1]
            $i++
        }
        "-Timeout" {
            $Timeout = $args[$i + 1]
            $i++
        }
        "-BeepCount" {
            $BeepCount = $args[$i + 1]
            $i++
        }
        "-BeepFrequency" {
            $BeepFrequency = $args[$i + 1]
            $i++
        }
        "-BeepDuration" {
            $BeepDuration = $args[$i + 1]
            $i++
        }
        "-ActionURI" {
            $ActionURI = $args[$i + 1]
            $i++
        }
        default {
            $Positional += $arg
        }
    }
}

# Validate the Icon argument
if ($Icon -notin @("Info", "Warning", "Error", "None")) {
    Write-Error -Category InvalidArgument "Invalid Icon: $Icon"
    exit 1
}

# Validate all of the numeric arguments
$numericArgs = @(
    @{ Name = "Timeout"; Value = $Timeout },
    @{ Name = "BeepCount"; Value = $BeepCount },
    @{ Name = "BeepFrequency"; Value = $BeepFrequency },
    @{ Name = "BeepDuration"; Value = $BeepDuration }
)
foreach ($arg in $numericArgs) {
    if ($arg.Value -notmatch "^\d+$") {
        Write-Error -Category InvalidArgument "Invalid $($arg.Name): $($arg.Value)"
        exit 1
    }
}

# If Text wasn't set, generate it by joining the positional arguments with a space
if (!$Text) {
    $Text = $Positional -join " "
}

# Require a message
if (!$Text) {
    Write-Error -Category InvalidArgument "Must specify -Text"
    $Help = $true
}

# If the user requested help, print the help text and exit
if ($Help) {
    Write-Host "Usage: notify [-Text <message>] [-Title <title>] [-Icon <icon>] [-Timeout <milliseconds>] [-Beep] [-ActionURI <uri>]"
    Write-Host ""
    Write-Host "Display a notification in the Windows 10 notification area"
    Write-Host ""
    Write-Host "Popup Options:"
    Write-Host "  -Text <text>        The main body of the notification"
    Write-Host "  -Title <title>      The title of the notification"
    Write-Host "  -Icon <icon>        The icon to display"
    Write-Host "  -Timeout <timeout>  The number of milliseconds to display the notification"
    Write-Host ""
    Write-Host "Sound Options:"
    Write-Host "  -Beep               Play a beep sound"
    Write-Host "  -BeepCount <count>  The number of times to play the beep"
    Write-Host "  -BeepFrequency <freq>  The frequency of the beep"
    Write-Host "  -BeepDuration <duration>  The duration of the beep"
    Write-Host ""
    Write-Host "Action Options:"
    Write-Host "  -ActionURI <uri>    The URI to open when the notification is clicked"
    exit 0
}


Add-Type -AssemblyName System.Windows.Forms
$global:balmsg = New-Object System.Windows.Forms.NotifyIcon
# Get the parent process's icon
$parentPid = (Get-WmiObject Win32_Process -Filter "ProcessId = $pid").ParentProcessId
$path = (Get-Process -id $parentPid).Path
# $path = (Get-Process -id $pid)
Write-Host $path
# $path = (Get-Process -id $pid).Path

$balmsg.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
# If an icon was specified, use it
if ($Icon) {
    $balmsg.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::$Icon
}
# If a title was specified, use it
if ($Title) {
    $balmsg.BalloonTipTitle = $Title
}
$balmsg.BalloonTipText = $Text
$balmsg.Visible = $true

# If an action was specified, and the user clicked the notification, open the URI
# if ($ActionURI) {
#     register-objectevent $balmsg "BalloonTipClicked" {
#         Start-Process $ActionURI
#     }
# }

# If a sound was specified, play it
if ($Beep) {
    for ($i = 0; $i -lt $BeepCount; $i++) {
        [System.Console]::Beep($BeepFrequency, $BeepDuration)
    }
}

Write-Host "Displaying notification: $Text"
$balmsg.ShowBalloonTip($Timeout)
