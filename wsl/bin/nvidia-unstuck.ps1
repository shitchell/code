#!/usr/bin/env psrun
# Script to fix stuck NVIDIA display adapter when external monitors aren't detected
# This disables and re-enables the NVIDIA GPU to refresh the display subsystem

Write-Host "Disabling and re-enabling NVIDIA Quadro M1200 adapter..." -ForegroundColor Yellow

$adapter = Get-PnpDevice -FriendlyName "NVIDIA Quadro M1200"

if ($adapter) {
    Write-Host "Found adapter: $($adapter.FriendlyName)" -ForegroundColor Cyan

    # Disable the adapter
    Write-Host "Disabling adapter..." -ForegroundColor Yellow
    Disable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false

    # Wait a moment
    Start-Sleep -Seconds 2

    # Re-enable the adapter
    Write-Host "Re-enabling adapter..." -ForegroundColor Yellow
    Enable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false

    Write-Host "`nAdapter reset complete!" -ForegroundColor Green
    Write-Host "Checking for displays..." -ForegroundColor Cyan

    # Show current displays
    Start-Sleep -Seconds 1
    Add-Type -AssemblyName System.Windows.Forms
    $screens = [System.Windows.Forms.Screen]::AllScreens
    Write-Host "`nDetected $($screens.Count) display(s):" -ForegroundColor Green
    $screens | ForEach-Object {
        Write-Host "  - $($_.DeviceName): $($_.Bounds.Width)x$($_.Bounds.Height) $(if ($_.Primary) {'(Primary)'})" -ForegroundColor White
    }
} else {
    Write-Host "Error: NVIDIA Quadro M1200 adapter not found!" -ForegroundColor Red
    exit 1
}
