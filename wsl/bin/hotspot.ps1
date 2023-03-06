#!/usr/bin/env psrun
#
# Fetch info about the Windows Mobile Hotspot
#
# TODO:
# - Allow configuration using NetworkOperatorTetheringAccessPointConfiguration:
#   https://learn.microsoft.com/en-us/uwp/api/windows.networking.networkoperators.networkoperatortetheringaccesspointconfiguration?view=winrt-22621

# Check to see if a command line `-Enable` or `-Disable` flag was provided
param (
    [switch]$Enable,
    [switch]$Disable,
    [switch]$Help,

    # TODO
    [String]$Ssid = $null,
    [String]$Passphrase = $null,
    [String]$Band = $null,
    # If the Mobile Hotspot is already enabled, do not allow configuration
    # changes unless -Force is specified to ensure that the user intends to
    # stop / restart the Mobile Hotspot
    [switch]$Force = $false
)

# If the user requested help, print the help text and exit
if ($Help) {
    Write-Host "Usage: hotspot [-Enable|-Disable]"
    Write-Host ""
    Write-Host "Fetch info about the Windows Mobile Hotspot"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Enable   Enable the Mobile Hotspot"
    Write-Host "  -Disable  Disable the Mobile Hotspot"
    Write-Host "  -Help     Show this help text"
    exit 0
}

$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()
$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)

# If a command line argument was provided, enable or disable the Mobile Hotspot
if ($Enable -and $Disable) {
    Write-Error -Category InvalidArgument -Message "Cannot specify both -Enable and -Disable"
    exit 1
} elseif ($Enable) {
    $tetheringManager.StartTetheringAsync() | Out-Null
    Write-Host "Mobile Hotspot enabled"
    Write-Host ""
} elseif ($Disable) {
    $tetheringManager.StopTetheringAsync() | Out-Null
    Write-Host "Mobile Hotspot disabled"
    Write-Host ""
}

# Create an associative array to store the info
$hotspotInfo = @{}

# Check whether Mobile Hotspot is enabled
$hotspotEnabled = $tetheringManager.TetheringOperationalState
$hotspotInfo['Enabled'] = $hotspotEnabled -eq 'On'

# Get the configuration
$configuration = $tetheringManager.GetCurrentAccessPointConfiguration()
$hotspotInfo['SSID'] = $configuration.Ssid
$hotspotInfo['Token'] = $configuration.Passphrase
$hotspotInfo['Band'] = $configuration.Band

# Get client info
# Loop over all clients connected to the Mobile Hotspot
$clientCountConnected = $tetheringManager.ClientCount
$clientCountMax = $tetheringManager.MaxClientCount
$clientInfo = @()
$clients = $tetheringManager.GetTetheringClients()
$clients | ForEach-Object {
    $client = $_
    $info = @{
        'Name' = ($client.HostNames | Select -Index 0).RawName
        'IP' = ($client.HostNames | Select -Index 1).RawName
        'MAC' = $client.MacAddress
    }
    $clientInfo += $info
}

# Print a "Configuration" header
Write-Host "Configuration" -ForegroundColor Green
Write-Host "--------------" -ForegroundColor Green
## Get the length of the longest key
$maxKeyLength = $hotspotInfo.Keys | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum | Measure-Object -Character | Select-Object -ExpandProperty Characters
foreach ($key in $hotspotInfo.Keys) {
    ## Write each key, padded to the length of the longest key
    Write-Host "${key}:" -NoNewline
    Write-Host (" " * ($maxKeyLength - $key.Length + 3)) -NoNewline
    ## Write the value
    Write-Host "$($hotspotInfo[$key])"
}
Write-Host ""

# Print a "Clients" header
$connectedCount = "$clientCountConnected/$clientCountMax"
Write-Host "Clients ($connectedCount)" -ForegroundColor Green
Write-Host "--------------" -ForegroundColor Green
$firstRun = $true
foreach ($client in $clientInfo) {
    if ($firstRun) {
        $firstRun = $false
    } else {
        Write-Host ""
    }
    Write-Host "Name: $($client['Name'])"
    Write-Host "IP:   $($client['IP'])"
    Write-Host "MAC:  $($client['MAC'])"
}
