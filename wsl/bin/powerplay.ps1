#!/usr/bin/env psrun
#
# Play audio files through powershell

Add-Type -AssemblyName PresentationCore

$mediaPlayer = New-Object system.windows.media.mediaplayer
$mediaPlayer.open($args[0])
$mediaPlayer.Play()
while (!($mediaPlayer.MediaEnded)) {
		Write-Host "Waiting for media player to exit"
    Start-Sleep -Milliseconds 500
}
$mediaPlayer.Close()
