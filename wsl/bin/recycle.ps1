#!/usr/bin/env psrun
#
# Move file(s) to the Recycle Bin.

# Default values
$Debug = $false
$Force = $false
$BackupWSL = $false
$Positional = @()

# Process command line arguments
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]
    switch -Wildcard ($arg) {
        "-Help" {
            $Help = $true
        }
        "-Debug" {
            $Debug = $true
        }
        "-Force" {
            $Force = $true
        }
        "-BackupWSL" {
            $BackupWSL = $true
        }
        default {
            $Positional += $arg
        }
    }
}

# Echo some debug stuff
if ($Debug) {
    Write-Host "NAME:    $MyInvocation.MyCommand.Name"
    Write-Host "WSL_CWD: $env:WSL_CWD"
    Write-Host "WSLENV:  $env:WSLENV"
    Write-Host
}

# Since WSL files are deleted immediately, we will optionally back them up first
# before deleting them, then recycle the backup. This will allow us to restore
# the file if we want.
$wslBackups = @()
if ($BackupWSL) {
    Write-Host "Backing up WSL files before deleting..."
    # Create a temporary directory to store the backups
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    $wslBackupDir = New-Item -ItemType Directory -Path (Join-Path $parent $name)
    if ($Debug) {
        Write-Host "  * created temporary directory '$wslBackupDir'"
    }
}

for ($i = 0; $i -lt $Positional.Count; $i++) {
    $file = $Positional[$i]

    if ($Debug) {
        Write-Host "Processing '$file'"
    }

    # If the WSL_CWD environment variable is set, then assume that the file is
    # a WSL path, and convert it to a Windows path.
    if ($env:WSL_CWD) {
        # If the file does not begin with a "/", then it's a relative path, so
        # we need to prepend the current working directory.
        if ($file -notmatch "^/") {
            if ($Debug) {
                Write-Host "  * prepending '$env:WSL_CWD' to '$file'"
            }
            $file = "$env:WSL_CWD/$file"
            Write-Host "  => '$file'"
        }
        if ($Debug) {
            Write-Host "  * converting '$file' to Windows path"
        }
        $file = wsl --exec wslpath -am $file
        If ($Debug) {
            Write-Host "  => '$file'"
        }
    }
    
    # Check if the file exists
    if (-not (Test-Path "$file")) {
        Write-Host "'$file' does not exist, skipping..."
        continue
    }

    # WSL files will get deleted immediately rather than being moved to the
    # Recycle Bin, so prompt the user before continuing.
    if ($file -match "^//wsl") {
        $prompt = "Delete '$file'? [Y/n] "
        $gerund = "deleting"
    } else {
        $prompt = "Recycle '$file'? [Y/n] "
        $gerund = "recycling"
    }

    # If Force is not set, then prompt the user before deleting the file.
    if (-not $Force) {
        $response = Read-Host -Prompt $prompt
        if ($response -ne "Y" -and $response -ne "y") {
            Write-Host "skipping '$file'..."
            continue
        }
    }

    # If this is a WSL file and backups are requested, then do that now
    if ($file -match "^//wsl" -and $BackupWSL) {
        # Create a backup of the file
        $backup = Join-Path $wslBackupDir (Split-Path $file -Leaf)
        if ($Debug) {
            Write-Host "  * backing up '$file' to '$backup'"
        }
        Copy-Item -Path $file -Destination $backup -Recurse -Force
        $wslBackups += $backup
    }

    if ($Debug) {
        Write-Host "  * $gerund '$file'"
    }

    # Move the file to the Recycle Bin
    if ((Get-Item "$file").PSIsContainer) {
        Add-Type -AssemblyName Microsoft.VisualBasic
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
            "$file",
            'OnlyErrorDialogs',
            'SendToRecycleBin'
        )
    } else {
        Add-Type -AssemblyName Microsoft.VisualBasic
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
            "$file",
            'OnlyErrorDialogs',
            'SendToRecycleBin'
        )
    }
}

# If we have any backups, then recycle them
if ($wslBackups.Count -gt 0) {
    Write-Host "Recycling WSL backups..."
    for ($i = 0; $i -lt $wslBackups.Count; $i++) {
        $file = $wslBackups[$i]
        if ($Debug) {
            Write-Host "  * recycling '$file'"
        }
        Add-Type -AssemblyName Microsoft.VisualBasic
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
            "$file",
            'OnlyErrorDialogs',
            'SendToRecycleBin'
        )
    }
}

# If the temporary directory still exists, then delete it
if ($wslBackupDir) {
    if ($Debug) {
        Write-Host "Deleting temporary directory '$wslBackupDir'"
    }
    Remove-Item -Path $wslBackupDir -Recurse -Force
}
