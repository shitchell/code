#!/usr/bin/env psrun
#
# Play audio files through PowerShell

Add-Type -AssemblyName PresentationCore

$mediaPlayer = New-Object system.windows.media.mediaplayer

# Trap for Ctrl+C to ensure proper cleanup
Register-EngineEvent PowerShell.Exiting -Action {
    Write-Host "" # Newline away from the while loop "..." dots
    $mediaPlayer.Stop()
    $mediaPlayer.Close()
    $mediaEndedEvent.Set()
} | Out-Null

# Open and play the media file
$mediaPlayer.open($args[0])
$mediaPlayer.Play()

Write-Host -NoNewline "Waiting for media player to exit"
while ($mediaPlayer.Position.TotalSeconds -ne $mediaPlayer.NaturalDuration.TimeSpan.TotalSeconds) {
    Write-Host -NoNewline "."
    Start-Sleep -Milliseconds 500
}

$mediaPlayer.Close()
# Write-Host "Media playback ended."
