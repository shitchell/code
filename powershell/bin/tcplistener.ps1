#!/usr/bin/env psrun

# Default values
$LocalAny = "Loopback"
$Port = 8989
$Once = $false
$Positional = @()

# Process command line arguments
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]
    switch ($arg) {
        "-Help" {
            $Help = $true
        }
        "-Local" {
            $LocalAny = "Loopback"
        }
        "-Any" {
            $LocalAny = "Any"
        }
        "-Once" {
            $Once = $true
        }
        "-Forever" {
            $Once = $false
        }
        "-Port" {
            $Port = $args[$i + 1]
            $i++
        }
        default {
            $Positional += $arg
        }
    }
}

# Validate all of the numeric arguments
$numericArgs = @(
    @{ Name = "Port"; Value = $Port }
)
foreach ($arg in $numericArgs) {
    if ($arg.Value -notmatch "^\d+$") {
        Write-Error -Category InvalidArgument "Invalid $($arg.Name): $($arg.Value)"
        exit 1
    }
}

$endpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::$LocalAny, $Port)
$listener = New-Object System.Net.Sockets.TcpListener $endpoint
$listener.Start()

Write-Host "* listening on" $endpoint

do {
    while ($true) {
       if ($listener.Pending()) {
          $client = $listener.AcceptTcpClient()
          break;
       }
       start-sleep -Milliseconds 1000
    }
    $stream = $client.GetStream();
    $reader = New-Object System.IO.StreamReader $stream
    do {
        $line = $reader.ReadLine()
        Write-Host ">" $line -fore cyan
    } while ($line -and $line -ne ([char]4))
    Write-Host "---"

    $reader.Dispose()
    $stream.Dispose()
    $client.Dispose()
} while ($line -ne ([char]4))
$listener.Stop()
