<#
.SYNOPSIS
    Creates a shortcut in the Start Menu to run Chris Titus WinUtil from GitHub with administrator privileges.

.DESCRIPTION
    This script generates a shortcut (.lnk) file in the user's Start Menu. The shortcut executes
    a PowerShell command that fetches and runs the Chris Titus WinUtil script from GitHub. The
    script supports selecting either the 'stable' or 'dev' branch. The shortcut requires administrative
    privileges and uses an icon sourced from the Chris Titus WinUtil repository.

.PARAMETER Branch
    Specifies the branch to use for the Chris Titus WinUtil script:
    - 'stable' for the stable branch (default)
    - 'dev' for the development branch

.PARAMETER WhatIf
    Simulates the creation of the shortcut without making changes, useful for testing.

.NOTES
    File Name      : Create-Shortcut2WinUtil.ps1
    Version        : 1.2.0
    Prerequisites  : PowerShell 5.1 or later
    Author         : JerichoJones
    Requirements   : Write access to the Start Menu folder and read access to system DLLs
    Security Note  : This script runs commands with elevated privileges and fetches a script from an
                     internet source. Ensure the source is trusted before execution.
    Disclaimer     : This script is provided "as-is" without any warranty. Use at your own risk.
                     The author assumes no liability for damages arising from its use, including
                     but not limited to unintended system changes, data loss, or security vulnerabilities.

.LINK
    Chris Titus WinUtil: https://github.com/ChrisTitusTech/winutil

.EXAMPLE
    .\Create-Shortcut2WinUtil.ps1
    Creates a shortcut for the stable branch with default settings.

.EXAMPLE
    .\Create-Shortcut2WinUtil.ps1 -Branch dev
    Creates a shortcut for the development branch.

.EXAMPLE
    .\Create-Shortcut2WinUtil.ps1 -Branch stable
    Explicitly specifies the stable branch, which is the default behavior.

.EXAMPLE
    .\Create-Shortcut2WinUtil.ps1 -Branch stable -Verbose
    Creates a stable branch shortcut while enabling verbose output for debugging.

.EXAMPLE
    .\Create-Shortcut2WinUtil.ps1 -Branch dev -WhatIf
    Shows what would happen if the script were to run with the dev branch, without actually creating the shortcut.
#>

param(
    [Parameter()]
    [ValidateSet('stable', 'dev')]
    [string]$Branch = 'stable',

    [switch]$WhatIf
)

function WinUtil-GetCTTLogoIcon {
    param (
        [string]$destinationPath = "$env:USERPROFILE\AppData\Local\winutil\cttlogo.ico"
    )

    $destinationDir = Split-Path -Path $destinationPath
    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
    }

    $pngUrl = "https://github.com/ChrisTitusTech/winutil/raw/main/docs/assets/favicon.png"
    $pngFilePath = Join-Path -Path $destinationDir -ChildPath "cttlogo.png"

    try {
        Invoke-WebRequest -Uri $pngUrl -OutFile $pngFilePath
        Write-Host "Downloaded cttlogo.png to $pngFilePath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download cttlogo.png: $_" -ForegroundColor Red
        return
    }

    try {
        Add-Type -AssemblyName System.Drawing
    } catch {
        Write-Host "Failed to load System.Drawing assembly: $_" -ForegroundColor Red
        return
    }

    try {
        $bitmap = [System.Drawing.Image]::FromFile($pngFilePath)
    } catch {
        Write-Host "Failed to load the PNG file: $_" -ForegroundColor Red
        return
    }

    $iconSizes = @(16, 32, 48, 64, 128, 256)
    $iconStreams = @()

    foreach ($size in $iconSizes) {
        $resizedBitmap = New-Object System.Drawing.Bitmap($bitmap, [System.Drawing.Size]::new($size, $size))
        $memoryStream = New-Object System.IO.MemoryStream
        $resizedBitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $iconStreams += [pscustomobject]@{ Size = $size; Stream = $memoryStream }
        $resizedBitmap.Dispose()
    }

    try {
        $fileStream = [System.IO.File]::Create($destinationPath)
        $writer = New-Object System.IO.BinaryWriter($fileStream)

        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$iconStreams.Count)

        $dataOffset = 6 + ($iconStreams.Count * 16)

        foreach ($icon in $iconStreams) {
            $streamLength = [int]$icon.Stream.Length
            $width = if ($icon.Size -eq 256) { 0 } else { [byte]$icon.Size }
            $height = if ($icon.Size -eq 256) { 0 } else { [byte]$icon.Size }
            $writer.Write([byte]$width)
            $writer.Write([byte]$height)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$streamLength)
            $writer.Write([UInt32]$dataOffset)
            $dataOffset += $streamLength
        }

        foreach ($icon in $iconStreams) {
            $icon.Stream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            $icon.Stream.CopyTo($fileStream)
            $icon.Stream.Dispose()
        }

        $writer.Close()
        $fileStream.Close()
        $bitmap.Dispose()

        Write-Host "Converted and saved cttlogo.ico to $destinationPath" -ForegroundColor Green
        return $destinationPath

    } catch {
        Write-Host "Failed to create the ICO file: $_" -ForegroundColor Red
    }
}

$iconPath = WinUtil-GetCTTLogoIcon
$startMenuPath = [System.Environment]::GetFolderPath('StartMenu')

if ($Branch -eq 'stable') {
    $command = 'Invoke-Expression (Invoke-RestMethod "https://christitus.com/win")'
} else {
    $command = 'Invoke-Expression (Invoke-RestMethod "https://christitus.com/windev")'
}

if (-not $WhatIf) {
    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
    } catch {
        Write-Host "Failed to create WScript.Shell object: $_" -ForegroundColor Red
        Pause
        exit
    }

    $shortcutPath = "$startMenuPath\Chris Titus WinUtil ($Branch branch).lnk"

    try {
        $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    } catch {
        Write-Host "Failed to create shortcut: $_" -ForegroundColor Red
        Pause
        exit
    }

    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-Command `"$command`""
    $shortcut.WorkingDirectory = [System.Environment]::GetFolderPath('MyDocuments')
    $shortcut.Description = "Chris Titus WinUtil - $($Branch.ToUpper())"
    $shortcut.IconLocation = "$iconPath, 0"

    try {
        $shortcut.Save()
    } catch {
        Write-Host "Failed to save the shortcut: $_" -ForegroundColor Red
        Pause
        exit
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
    } catch {
        Write-Host "Failed to read the shortcut file: $_" -ForegroundColor Red
        Pause
        exit
    }

    $bytes[0x15] = $bytes[0x15] -bor 0x20

    try {
        [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)
    } catch {
        Write-Host "Failed to modify the shortcut file for admin rights: $_" -ForegroundColor Red
        Pause
        exit
    }
}

if ($WhatIf) {
    Write-Host "WhatIf: Would create a shortcut for Chris Titus WinUtil ($Branch branch) in the Start Menu." -ForegroundColor Yellow
} else {
    Write-Host "Chris Titus WinUtil ($Branch branch) shortcut created successfully in the Start Menu." -ForegroundColor Green
}

Pause
