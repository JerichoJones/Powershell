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
    Version        : 1.4.0
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
    .\Create-Shortcut2WinUtil.ps1 -Branch stable -Verbose
    Creates a stable branch shortcut while enabling verbose output.

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

function Get-CTTLogoIcon {
    param (
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[A-Za-z]:\\')]
        [string]$destinationPath = (Join-Path -Path $env:USERPROFILE -ChildPath "AppData\Local\winutil\cttlogo.ico")
    )

    try {
        $destinationDir = Split-Path -Path $destinationPath
        if (-not (Test-Path -Path $destinationDir)) {
            New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
        }
    } catch {
        Write-Host "Invalid destination path: $_" -ForegroundColor Red
        return $null
    }

    $pngFilePath = Join-Path -Path $destinationDir -ChildPath "cttlogo.png"

    try {
        Invoke-WebRequest -Uri $PngUrl -OutFile $pngFilePath
        Write-Host "Downloaded cttlogo.png to $pngFilePath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download cttlogo.png: $_" -ForegroundColor Red
        return $null
    }

    return $destinationPath
}

$iconPath = Get-CTTLogoIcon
if (-not $iconPath) {
    Write-Host "Failed to create icon. Exiting..." -ForegroundColor Red
    exit
}

$startMenuPath = [System.Environment]::GetFolderPath('StartMenu')
$shortcutPath = "$startMenuPath\Chris Titus WinUtil ($Branch branch).lnk"

$command = if ($Branch -eq 'stable') {
    'Invoke-Expression (Invoke-RestMethod "https://christitus.com/win")'
} else {
    'Invoke-Expression (Invoke-RestMethod "https://christitus.com/windev")'
}

if (-not $WhatIf) {
    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
        $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-Command `"$command`""
        $shortcut.WorkingDirectory = [System.Environment]::GetFolderPath('MyDocuments')
        $shortcut.Description = "Chris Titus WinUtil - $($Branch.ToUpper())"
        $shortcut.IconLocation = "$iconPath, 0"
        $shortcut.Save()

        # Elevate Shortcut to Run as Administrator
        $ShellApp = New-Object -ComObject Shell.Application
        $ShortcutFile = $ShellApp.Namespace($startMenuPath).ParseName("Chris Titus WinUtil ($Branch branch).lnk")
        if ($ShortcutFile) {
            $ShortcutFile.InvokeVerb("Run as administrator")
        }

        Write-Host "Chris Titus WinUtil ($Branch branch) shortcut created successfully in the Start Menu." -ForegroundColor Green
    } catch {
        Write-Host "Failed to create shortcut: $_" -ForegroundColor Red
        exit
    }
}

if ($WhatIf) {
    Write-Host "WhatIf: Would create a shortcut for Chris Titus WinUtil ($Branch branch) in the Start Menu." -ForegroundColor Yellow
}
