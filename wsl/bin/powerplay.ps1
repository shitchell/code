#!/usr/bin/env psrun
#
# Play audio files through powershell

Add-Type -AssemblyName PresentationCore

$mediaPlayer = New-Object system.windows.media.mediaplayer
$mediaPlayer.open($args[0])
$mediaPlayer.Play()
while (!($mediaPlayer.MediaEnded)) {
    Start-Sleep -Milliseconds 500
}
$mediaPlayer.Close()
