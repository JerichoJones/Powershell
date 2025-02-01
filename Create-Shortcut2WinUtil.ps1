<#
.SYNOPSIS
    Creates a shortcut in the user's Start Menu to run Chris Titus WinUtil from GitHub with elevated privileges.

.DESCRIPTION
    This script generates a shortcut (.lnk) file in the user's personal Start Menu. The shortcut executes
    a PowerShell command that fetches and runs the Chris Titus WinUtil script from GitHub with elevated privileges. 
    The script supports selecting either the 'stable' or 'dev' branch. No admin privileges are needed to create the shortcut,
    but the shortcut will prompt for admin rights when launched.

.PARAMETER Branch
    Specifies the branch to use for the Chris Titus WinUtil script:
    - 'stable' for the stable branch (default)
    - 'dev' for the development branch

.PARAMETER WhatIf
    Simulates the creation of the shortcut without making changes, useful for testing.

.NOTES
    File Name      : Create-Shortcut2WinUtil.ps1
    Version        : 2.1.0
    Prerequisites  : PowerShell 5.1 or later
    Author         : JerichoJones
    Requirements   : Write access to the user's personal Start Menu folder
    Security Note  : This script fetches a script from an internet source. Ensure the source is trusted before execution.
                     The shortcut will prompt for admin rights when launched.
    Disclaimer     : This script is provided "as-is" without any warranty. Use at your own risk.
                     The author assumes no liability for damages arising from its use, including
                     but not limited to unintended system changes, data loss, or security vulnerabilities.

.LINK
    Chris Titus WinUtil: https://github.com/ChrisTitusTech/winutil
    Jericho Jones Create-Shortcut2WinUtil.ps1: https://github.com/JerichoJones/Powershell/blob/main/Create-Shortcut2WinUtil.ps1

.EXAMPLE
    .\Create-Shortcut2WinUtil.ps1
    Creates a shortcut for the stable branch with default settings.

.EXAMPLE
    .\Create-Shortcut2WinUtil.ps1 -Branch dev
    Creates a shortcut for the development branch.

.EXAMPLE
    .\Create-Shortcut2WinUtil.ps1 -Branch stable -Verbose
    Creates a stable branch shortcut with verbose output.

.EXAMPLE
    .\Create-Shortcut2WinUtil.ps1 -Branch dev -WhatIf
    Simulates shortcut creation for the dev branch without making changes.
#>

using namespace System.IO

param(
    [Parameter()]
    [ValidateSet('stable', 'dev')]
    [string]$Branch = 'stable',

    [switch]$WhatIf,

    [string]$PngUrl = "https://raw.githubusercontent.com/ChrisTitusTech/winutil/main/docs/assets/favicon.png"
)

# Helper function: Download icon file from GitHub and return its full path
function Get-CTTLogoIcon {
    param (
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[A-Za-z]:\\')]
        [string]$outputPath = (Join-Path -Path $env:USERPROFILE -ChildPath "AppData\Local\winutil\cttlogo.ico")
    )

    Write-Host "[DEBUG] Output path: $outputPath" -ForegroundColor Gray

    try {
        Add-Type -AssemblyName System.Drawing

        $graphicsPath = Join-Path -Path $env:USERPROFILE -ChildPath "AppData\Local\winutil"
        $inputPath = Join-Path -Path $graphicsPath -ChildPath "cttlogo.png"

        if (!(Test-Path -Path $graphicsPath)) {
            mkdir $graphicsPath
        }

        if (!(Test-Path -Path $inputPath)) {
            $pngPath = Join-Path -Path $env:TEMP -ChildPath "cttlogo.png"
            Invoke-WebRequest -Uri $PngUrl -OutFile $pngPath
            Move-Item -Path $pngPath -Destination $inputPath -Force
        }

        $image = [System.Drawing.Image]::FromFile($inputPath)
        $width = $image.Width
        $height = $image.Height

        Write-Host "[DEBUG] Image dimensions: $width x $height"

        $icon = [System.Drawing.Icon]::FromHandle($image.GetHicon())
        $iconStream = New-Object System.IO.MemoryStream
        $icon.Save($iconStream)
        $iconStream.ToArray() | Set-Content -Path $outputPath -Encoding Byte
        Write-Host "Icon created successfully at: $outputPath"

        return $outputPath

    } catch {
        Write-Host "[ERROR] Error creating icon: $_" -ForegroundColor Red;
        return $null
    } finally {
        if ($icon) {
            $icon.Dispose()
        }
        if ($image) {
            $image.Dispose()
        }
    }
}

# Helper function: Create shortcut
function New-Shortcut {
    param (
        [string]$TargetPath,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [string]$ShortcutPath,
        [string]$IconPath
    )

    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            throw "Creating shortcuts is not supported in PowerShell Core. Please run this script in Windows PowerShell."
        } else {
            $WScriptShell = New-Object -ComObject WScript.Shell
        }
        $shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
        $shortcut.TargetPath = $TargetPath
        $shortcut.Arguments = $Arguments
        $shortcut.WorkingDirectory = $WorkingDirectory
        $shortcut.Description = "Chris Titus WinUtil Shortcut"
        $shortcut.WindowStyle = 7 # Minimized
        $shortcut.IconLocation = "$IconPath, 0" # Use the first icon in the file
        $shortcut.Save()
        Write-Host "Shortcut created at $ShortcutPath" -ForegroundColor Green
    } catch {
        Write-Host "Error creating shortcut at $ShortcutPath" -ForegroundColor Red
        Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Yellow
        throw
    }
}

# Helper function: Modify shortcut for admin rights
function Update-ShortcutForAdmin {
    param (
        [string]$ShortcutPath
    )

    try {
        $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
        $bytes[0x15] = $bytes[0x15] -bor 0x20
        [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)
        Write-Host "Shortcut modified for admin rights" -ForegroundColor Green
    } catch {
        Write-Host "Error modifying shortcut for admin rights: $ShortcutPath" -ForegroundColor Red
        Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Yellow
        throw
    }
}

# Retrieve icon
$iconPath = Get-CTTLogoIcon
if (-not $iconPath) {
    Write-Host "Failed to create icon. Exiting..." -ForegroundColor Red
    exit
}

# Determine the user's personal Start Menu path and the final shortcut location
$userStartMenuPath = [System.Environment]::GetFolderPath('StartMenu')
$shortcutPath = Join-Path -Path $userStartMenuPath -ChildPath "Chris Titus WinUtil ($Branch branch).lnk"

# Build command for stable vs dev
$command = if ($Branch -eq 'stable') {
    "Invoke-Expression (Invoke-RestMethod 'https://christitus.com/win')"
} else {
    "Invoke-Expression (Invoke-RestMethod 'https://christitus.com/windev')"
}

$arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$command`""

if (-not $WhatIf) {
    try {
        New-Shortcut -TargetPath "powershell.exe" `
                        -Arguments $arguments `
                        -WorkingDirectory ([System.Environment]::GetFolderPath('MyDocuments')) `
                        -ShortcutPath $shortcutPath `
                        -IconPath $iconPath

        # Modify the shortcut to request admin rights
        Update-ShortcutForAdmin -ShortcutPath $shortcutPath

        Write-Host "Chris Titus WinUtil ($Branch branch) shortcut created successfully in your Start Menu. It will request admin rights when launched." -ForegroundColor Green
    } catch {
        Write-Host "An error occurred while creating or modifying the shortcut: $_" -ForegroundColor Red
    }
} else {
    Write-Host "WhatIf: Would create a shortcut for Chris Titus WinUtil ($Branch branch) in your Start Menu, which would request admin rights upon launch." -ForegroundColor Yellow
}
