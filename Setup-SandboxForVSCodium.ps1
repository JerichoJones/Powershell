<#
.SYNOPSIS
    Downloads and installs VSCodium in a Windows Sandbox environment with host drive mappings.

.DESCRIPTION
    This script performs the following actions:
    1. Checks if the operating system is supported (Windows 10/11 Pro or Enterprise).
    2. Re-runs the script as Administrator if not already elevated.
    3. Checks if Windows Sandbox is enabled; if not, offers to enable it.
    4. Retrieves the latest VSCodium release URL from GitHub.
    5. Downloads the Windows x64 installer.
    6. Creates a Windows Sandbox configuration that:
       - Maps host C: and E: drives as read-only.
       - Automatically installs VSCodium silently on sandbox startup.
    7. Launches the configured Windows Sandbox instance.

.EXAMPLE
    PS> .\Install-VSCodiumSandbox.ps1
    Runs the installation process and launches Windows Sandbox.

.PARAMETER None
    This script does not accept any parameters.

.INPUTS
    None.

.OUTPUTS
    None.

.NOTES
    Requirements:
      - Windows 10/11 Pro or Enterprise (to support the Windows Sandbox feature).
      - PowerShell 5.1 or newer.
      - Internet access to GitHub APIs.
    Additional Information:
      - Enabling Windows Sandbox requires administrative privileges and will trigger a system reboot.
    
    File Name  : Install-VSCodiumSandbox.ps1
    Author     : Jericho Jones
    Version    : 4.1
    Created    : 2025-01-27
    Last Update: 2025-02-07

.LINK
    https://github.com/VSCodium/vscodium
#>

# Function to check if the OS is supported
function Test-SupportedOS {
    $osVersion = [System.Environment]::OSVersion.Version
    $osName = Get-ComputerInfo | Select-Object -ExpandProperty WindowsEditionId

    # Check if it's Windows 10 or 11
    if ($osVersion.Major -eq 10 -and $osVersion.Build -ge 17134) { # Windows 10 1803 or later
        # Check if it's Pro or Enterprise edition
        if ($osName -like "*Pro*" -or $osName -like "*Enterprise*") {
            return $true
        }
    } elseif ($osVersion.Major -eq 10 -and $osVersion.Build -ge 22000) { # Windows 11 21H2 or later
        # Check if it's Pro or Enterprise edition
        if ($osName -like "*Pro*" -or $osName -like "*Enterprise*") {
            return $true
        }
    }
    return $false
}

Write-Host "Starting VSCodium Windows Sandbox Build..." -ForegroundColor Cyan
# Check if the OS is supported
if (-Not (Test-SupportedOS)) {
    Write-Error "This script requires Windows 10 (version 1803 or later) or Windows 11 Pro or Enterprise edition."
    exit 1
}

Write-Host "Operating system is supported." -ForegroundColor Green

# Re-run the script as Administrator if not already elevated
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator rights to run. Attempting to relaunch with elevated privileges..." -ForegroundColor Yellow

    # Build the argument string for the new process
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $MyInvocation.MyCommand.Path

    # Start new process with elevated privileges
    Start-Process powershell -Verb RunAs -ArgumentList $arguments

    # Exit the current process
    exit
}

# Disable default progress bar for all web requests
$ProgressPreference = 'SilentlyContinue'

# Check if Windows Sandbox is installed
$sandboxFeatureState = (Get-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM").State

Write-Host "Windows Sandbox Feature State: $sandboxFeatureState" -ForegroundColor White

if ($sandboxFeatureState -ne "Enabled") {
    Write-Host "Windows Sandbox is not enabled. You have the following options:" -ForegroundColor Yellow
    Write-Host "NOTE:   Enabling Windows Sandbox requires a system reboot." -ForegroundColor Yellow
    Write-Host "        Please re-run this script after restart to complete installation." -ForegroundColor Yellow
    Write-Host "`n"
    Write-Host "1. Install & Reboot - Installs Windows Sandbox and reboots your system."
    Write-Host "2. Install, No Reboot - Installs Windows Sandbox but does not reboot."
    Write-Host "3. Cancel - Cancels the installation of Windows Sandbox."

    $userChoice = Read-Host "Please choose (1, 2, or 3)"
    
    switch ($userChoice) {
        "1" {
            Write-Host "Installing Windows Sandbox and rebooting..." -ForegroundColor Yellow
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All -NoRestart
                Write-Host "Windows Sandbox has been enabled. Rebooting now to apply changes." -ForegroundColor Green
                Restart-Computer -Force
                exit
            } catch {
                Write-Error "Failed to enable Windows Sandbox. Error: $($_.Exception.Message)"
                Pause "Press any key to exit..."
                Exit 1
            }
        }
        "2" {
            Write-Host "Installing Windows Sandbox without rebooting..." -ForegroundColor Yellow
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All
                Write-Host "Windows Sandbox has been enabled. Please manually restart your system for changes to take effect." -ForegroundColor Green
                Exit 0
            } catch {
                Write-Error "Failed to enable Windows Sandbox. Error: $($_.Exception.Message)"
                Pause "Press any key to exit..."
                Exit 1
            }
        }
        "3" {
            Write-Host "Installation of Windows Sandbox cancelled." -ForegroundColor Yellow
            Pause "Press any key to exit..."
            Exit 2
        }
        default {
            Write-Host "Invalid option. Cancelling installation of Windows Sandbox." -ForegroundColor Red
            Pause "Press any key to exit..."
            Exit 1
        }
    }
} else {
    Write-Host "Windows Sandbox is already enabled." -ForegroundColor Green
}

# Create C:\Temp if it doesn't exist
$hostTempDir = "C:\Temp"
if (-not (Test-Path $hostTempDir)) {
    try {
        New-Item -Path $hostTempDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Host "Created host temp directory: $hostTempDir" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create host temp directory. Error: $($_.Exception.Message)"
        Pause "Press any key to exit..."
        Exit 1
    }
}

try {
    Write-Host "Connecting to GitHub..." -ForegroundColor Green
    $releaseInfo = Invoke-WebRequest -Uri "https://api.github.com/repos/VSCodium/vscodium/releases/latest" -UseBasicParsing -Headers @{"Accept-Encoding"="identity"}
    Write-Host "API response received. Starting download." -ForegroundColor Green
    $releaseInfo = $releaseInfo.Content | ConvertFrom-Json
} catch {
    Write-Error "Failed to retrieve the latest release information from GitHub. Error: $($_.Exception.Message)"
    Pause "Press any key to exit..."
    Exit 1
} finally {
    # Reset the progress preference
    $ProgressPreference = 'Continue'
}

# Find the asset URL for the VSCodium x64 Windows installer
$vscodiumUrl = $releaseInfo.assets | Where-Object { $_.browser_download_url -like "*VSCodiumSetup-x64-*.exe" } | Select-Object -ExpandProperty browser_download_url

if (-not $vscodiumUrl) {
    Write-Error "Could not find the VSCodium Windows x64 installer asset in the latest release."
    Pause "Press any key to exit..."
    Exit 1
}

# Check if multiple URLs are found and error out
if ($vscodiumUrl -is [array] -and $vscodiumUrl.Count -gt 1) {
    Write-Error "Multiple installer assets found. Unable to determine the correct one."
    Pause "Press any key to exit..."
    Exit 1
}

# Define where to save the file
$vscodiumInstallerPath = "$hostTempDir\vscodium-installer.exe"

# Disable progress bar for the download
$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri $vscodiumUrl -OutFile $vscodiumInstallerPath -UseBasicParsing
    Write-Host "VSCodium installer download completed." -ForegroundColor Green
} catch {
    Write-Error "Failed to download VSCodium installer. Error: $($_.Exception.Message)"
    Pause "Press any key to exit..."
    Exit 1
} finally {
    # Reset the progress preference
    $ProgressPreference = 'Continue'
}

# Check if the file was downloaded successfully
if (-not (Test-Path $vscodiumInstallerPath)) {
    Write-Error "VSCodium installer was not downloaded successfully."
    Pause "Press any key to exit..."
    Exit 1
}

# Create the Windows Sandbox configuration file
$wsbFilePath = "$env:USERPROFILE\Desktop\VSCodium_Sandbox.wsb"
$wsbContent = @"
<?xml version="1.0" encoding="utf-8"?>
<!--
Windows Sandbox Configuration File
This file demonstrates all supported settings for Windows Sandbox.
Any settings not specified here will use their built-in defaults:
  • vGPU defaults to 'Enable'
  • Networking defaults to 'Enable'
  • MappedFolder: If omitted, no host folders are shared.
  • ReadOnly defaults to true if not specified.
  • MemoryInMB: If omitted, the sandbox uses dynamic memory allocation.
  • ProcessorCount: If omitted, the sandbox assigns processors dynamically.
  
Supported Settings:
  1. <vGPU>: Enables or disables virtual GPU support.
  2. <Networking>: Enables or disables networking within the sandbox.
  3. <MappedFolders>: Specifies one or more folder mappings from the host to the sandbox.
       • Each <MappedFolder> requires:
           - <HostFolder>: The full path on the host.
           - <SandboxFolder>: The folder path inside the sandbox.
           - <ReadOnly>: Set to 'true' for read-only access or 'false' for read-write.
  4. <LogonCommand>: Specifies a command to run automatically after the sandbox starts.
       • Contains a <Command> element with the full command-line.
  5. <MemoryInMB>: Sets the amount of memory (in megabytes) allocated to the sandbox.
  6. <ProcessorCount>: Sets the number of processor cores allocated to the sandbox.
-->
<Configuration>
  <!-- Virtual GPU support: Options are 'Enable' or 'Disable'. (Default: Enable) -->
  <vGPU>Enable</vGPU>
  
  <!-- Networking: Options are 'Enable' or 'Disable'. (Default: Enable) -->
  <Networking>Enable</Networking>
  
  <!-- MappedFolders: Map one or more host folders to the sandbox -->
  <MappedFolders>
    <!-- Map the host C:\ drive to C:\CDrive in the sandbox (read-only) -->
    <MappedFolder>
      <HostFolder>C:\</HostFolder>
      <SandboxFolder>C:\CDrive</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <!-- Map the host E:\ drive to C:\EDrive in the sandbox (read-only) -->
    <MappedFolder>
      <HostFolder>E:\</HostFolder>
      <SandboxFolder>C:\EDrive</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <!-- Additional example: Map the host D:\Data folder to C:\Data in the sandbox with read-write access
    <MappedFolder>
      <HostFolder>D:\Data</HostFolder>
      <SandboxFolder>C:\Data</SandboxFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
     -->
  </MappedFolders>
  
  <!-- LogonCommand: Run a command automatically when the sandbox starts -->
  <LogonCommand>
    <Command>C:\CDrive\Temp\vscodium-installer.exe /VERYSILENT /NORESTART /LOG="C:\VSCodium_Install.log"</Command>
  </LogonCommand>
  
  <!-- MemoryInMB: Allocate 4096 MB of memory to the sandbox. (If omitted, memory is dynamically assigned.) -->
  <MemoryInMB>4096</MemoryInMB>
  
  <!-- ProcessorCount: Allocate 2 processor cores to the sandbox. (If omitted, the allocation is dynamic.) -->
  <ProcessorCount>4</ProcessorCount>
</Configuration>
"@


try {
    # Write the configuration to a .wsb file
    $wsbContent | Out-File -FilePath $wsbFilePath -Encoding utf8
    Write-Host "Sandbox configuration file created." -ForegroundColor Green
} catch {
    Write-Error "Failed to create Sandbox configuration file. Error: $($_.Exception.Message)"
    Pause "Press any key to exit..."
    Exit 1
}

# Launch Windows Sandbox with the new configuration
try {
    Write-Host "Starting VSCodium Windows Sandbox..." -ForegroundColor Cyan
    Start-Process -FilePath $wsbFilePath -ErrorAction Stop
} catch {
    Write-Error "Failed to launch Windows Sandbox. Error: $($_.Exception.Message)"
    return
}

Write-Host "VSCodium installer has been placed in host's C:\Temp" -ForegroundColor Green
Write-Host "Windows Sandbox launched with C: and E: drive mappings." -ForegroundColor Green
Write-Host "VSCodium Installation logs will be at C:\VSCodium_Install.log in the sandbox." -ForegroundColor Green
Pause "Press any key to exit..."