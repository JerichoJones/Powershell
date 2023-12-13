<#	This is my post Windows install script to optimize for gaming & install software
	*** Use at your own risk. ***
	
	Author: Jericho Jones
	Date: 06/24/2023
	Description:	Initiate Microsoft Store applications update
					Update Winget app repositories
					Run Chris Titus script
					Install Apps
					Disable High Performance Event Timer (HPET)
					Modify CPU resources reserved for background processes and system activities
					Set GPU priorities
					Enable Game Mode
					Rename the computer
					Prompt to reboot
#>

### Functions
function Install-WingetApp {
    param (
        [Parameter(Mandatory=$true)]
        [string]$applicationId
    )

    # Search for the application with winget using the Id field
    $searchResult = winget search --id $applicationId

    # Check if the application is found
    if ($searchResult -like "*$applicationId*") {
        # Extract the application lines, ignoring header lines
        $appLines = $searchResult -split "`n" | Where-Object { $_ -match $applicationId -and $_ -notmatch "^Name\s+Id" }
        $appList = @()

        foreach ($appLine in $appLines) {
            ($appLine -match '^(?<name>\S+)\s+(?<id>\S+)\s+(?<version>\S+)?\s+(?<match>\S+)?\s+(?<source>\S+)?$') | Out-Null
            $matches = $Matches

            $appList += [PSCustomObject]@{
                Name = $matches['name']
                Id = $matches['id']
                Version = $matches['version']
                Match = $matches['match']
                Source = $matches['source']
            }
        }

        # Remove duplicates based on the application ID
        $uniqueAppList = $appList | Sort-Object -Property Id -Unique

        # Check if there is more than one unique application found
        if ($uniqueAppList.Count -gt 1) {
            # Display the search results in a GUI and let the user choose the application
            $selectedApp = $uniqueAppList | Out-GridView -Title "Select the application to install" -OutputMode Single
        } else {
            $selectedApp = $uniqueAppList[0]
        }

        if ($selectedApp) {
            # Install the selected application using winget
            $installResult = winget install --id $selectedApp.Id --silent --scope=machine

            # Filter out lines without any words
            $installLines = $installResult -split "`n" | Where-Object { $_ -match '\w' }

            # Display the output of the install command
            $installLines | ForEach-Object { Write-Host $_ }

            # Check if the installation was successful
            #$installedApp = winget list --id $selectedApp.Id 2> $null
            $installedApp = winget list

            # Filter out header lines and lines with only '-' characters
            $installedAppLines = $installedApp -split "`n" | Where-Object { $_ -notmatch "^Name\s+Id\s+Version\s+Source" -and $_ -notmatch '^\s*-\s*$' }

            # Create the PSCustomObject for installed apps
            $installedAppList = @()
            foreach ($installedAppLine in $installedAppLines) {
                ($installedAppLine -match '^(?<name>\S+)\s+(?<id>\S+)\s+(?<version>\S+)?\s+(?<source>\S+)?$') | Out-Null
                $matches = $Matches

                $installedAppList += [PSCustomObject]@{
                    Name = $matches['name']
                    Id = $matches['id']
                    Version = $matches['version']
                    Source = $matches['source']
                }
            }

            # Check if the installed app's ID matches the selected app's ID
            $installedApp = $installedAppList | Where-Object { $_.Id -eq $selectedApp.Id -or $_.Id -eq $selectedApp.Match }

            if ($installedApp) {
                Write-Host "The application '$($selectedApp.Name)' was installed successfully."
            } else {
                Write-Host "The installation of the application '$($selectedApp.Id)' failed. Please check the logs and try again."
            }
        }
        else {
            Write-Host "No application was selected for installation."
        }
    } else {
        Write-Host "The application '$applicationId' was not found."
    }
}

# Disable HPET in Windows 10
# Requires administrative privileges

Function Disable-HPET {
    try {
        # Get all System devices
        $systemDevices = Get-PnpDevice | Where-Object { $_.Class -eq "System" }

        # Find HPET device
        $hpetDevice = $systemDevices | Where-Object { $_.FriendlyName -eq "High Precision Event Timer" }

        if ($null -ne $hpetDevice) {
            # Disable HPET device
            Disable-PnpDevice -InstanceId $hpetDevice.InstanceId -Confirm:$false
            #Write-Host "HPET disabled successfully." -ForegroundColor Green

            # Refresh device information and verify if HPET is disabled
            $updatedHpetDevice = Get-PnpDevice -InstanceId $hpetDevice.InstanceId
            if ($updatedHpetDevice.Status -eq "Disabled" -or $updatedHpetDevice.Status -eq "Error") { # Error seems to be the state when disabled
                Write-Host "HPET is now disabled." -ForegroundColor Green
            } else {
                Write-Host "Failed to disable HPET. Current status: $($updatedHpetDevice.Status)" -ForegroundColor Red
            }
        } else {
            Write-Host "HPET device not found." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error occurred while trying to disable HPET: $_" -ForegroundColor Red
    }
}

function Enable-GameMode {
    <#
    .SYNOPSIS
        Enables Game Mode in Windows 10.
    .DESCRIPTION
        This function enables Game Mode in Windows 10 by setting the appropriate registry key.
    .EXAMPLE
        Enable-GameMode
    #>

    # Check if the script is running with administrator privileges
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "You need to run this function as an Administrator."
        return
    }

    # Set the registry key to enable Game Mode
    try {
        $gameModeKeyPath = "HKCU:\Software\Microsoft\GameBar"
        $gameModeValueName = "AllowAutoGameMode"

        if (!(Test-Path $gameModeKeyPath)) {
            New-Item -Path $gameModeKeyPath -Force | Out-Null
        }

        Set-ItemProperty -Path $gameModeKeyPath -Name $gameModeValueName -Value 1
        Write-Host "Game Mode has been enabled." -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred while enabling Game Mode: $_" -ForegroundColor Red
    }
}

### This is where the work is done
Start-Transcript -Path $Env:TEMP\$($env:COMPUTERNAME)_StoreUpdate.log
$NewComputername = "My-PC"
Clear-Host

# Check if running with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as an administrator."
    #Start-Sleep -Seconds 5
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Set execution policy for the current session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Update all Microsoft Store applications
Write-Host "Step 1: Initiating Microsoft Store applications update..."
Get-Ciminstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod
Write-Host "Microsoft Store applications update initiated.`n" -ForegroundColor Green

# Wait for Desktop App Installer to be installed
Write-Host "Step 2: Waiting for Desktop App Installer to be installed..."
do
{
	Start-Sleep -Seconds 5
	$DesktopAppInstallerInstalled = Get-AppxPackage -Name Microsoft.DesktopAppInstaller
}
while (-not $DesktopAppInstallerInstalled)
Write-Host "Desktop App Installer is now installed.`n" -ForegroundColor Green

# Wait for Winget to be installed
Write-Host "Step 3: Waiting for Winget to be installed..."
do
{
	Start-Sleep -Seconds 5
}
while (-not (Get-Command winget -ErrorAction SilentlyContinue))
Write-Host "Winget is now installed.`n" -ForegroundColor Green

# Update the app repository
Write-Host "Step 4: Updating the app repositories..."
winget source update | Out-Null
Write-Host "Winget app repository has been updated.`n" -ForegroundColor Green

Write-Host "Step 5: Run Chris Titus script..."
Invoke-WebRequest -useb https://christitus.com/win | Invoke-Expression

Write-Host "Step 6: Install Apps..."
# Application Ids
$Apps = @(
	'CPUID.CPU-Z.GBT'
	'TechPowerUp.GPU-Z'
	'Guru3D.Afterburner'
    'Malwarebytes.Malwarebytes'
	'FastCopy.FastCopy'
    '7zip.7zip'
    'VideoLAN.VLC'
    'Notepad++.Notepad++'
    'Google.Drive'
    'XPDBZ4MPRKNN30' #'Opera GX'
    'DominikReichl.KeePass'
    'Valve.Steam'
    'Ubisoft.Connect'
    'GOG.Galaxy'
    'ElectronicArts.EADesktop'
    'VMware.WorkstationPro'
    'voidtools.Everything'
    'JAMSoftware.TreeSize.Free'
    'BitSum.ProcessLasso'
    'BitSum.ParkControl'
    'Microsoft.Teams'
    'Discord.Discord'
    'Telegram.TelegramDesktop'
    'Mobatek.MobaXterm'
    'qBittorrent.qBittorrent'
    'Citrix.Workspace'
    'ZeroTier.ZeroTierOne'
    'RevoUninstaller.RevoUninstaller'
    'VPNetwork.TorGuard'
)

ForEach ($App in $Apps)
{
    Write-Host "Installing $App...`n" -ForegroundColor Green
    #winget install $App --silent --accept-source-agreements --accept-package-agreements --scope=machine
	Install-WingetApp -applicationId $App
}

Write-Host "Step 6: Run Game fixes..."
# FIX FOR DESTINY 2 STUTTERING?
# https://www.reddit.com/r/Amd/comments/yvyqc7/disabling_multiplane_overlay_mpo_fixed_all/
#reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Dwm" /t reg_sz /v OverlayTestMode /d 00000005 /F

# Call the function to disable the High precision event timer
# https://www.youtube.com/watch?v=14QSlEvvzoA
Disable-HPET

<#
	This value represents the percentage of CPU resources reserved for background processes and system activities.
	By default, it is set to 20.

    The valid values for this entry are integers ranging from 0 to 100. A value of 0 means that the CPU will allocate
    all resources to multimedia applications, while a value of 100 means that the CPU will allocate all resources to non-multimedia applications.
#>
# Create the key if it does not exist
$SysProfRegistryPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
If (-NOT (Test-Path $SysProfRegistryPath)) {
  New-Item -Path $SysProfRegistryPath -Force | Out-Null
}
# Now set the value
New-ItemProperty -Path $SysProfRegistryPath -Name 'SystemResponsiveness' -Value 1 -PropertyType DWORD -Force

<# Set GPU priorities
Under the HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games
registry key, you may find several values that can be modified to optimize gaming performance.

Affinity:	This value defines the processor affinity for the gaming application.
			It is a bitmask that determines which CPU cores the application can run on.
			By default, it is set to 0, which means the application can run on any available core.
			Changing this value to a specific number will limit the application to run on that specific core or cores.

Background Only:	This is a boolean value (0 or 1) that indicates whether the task should run only in the background.
					Setting it to 1 will force the gaming application to run in the background,
					which might not be suitable for most gaming scenarios.

Clock Rate:		The "Clock Rate" value represents the time resolution, in 100-nanosecond intervals,
				for the scheduling of multimedia tasks under the Multimedia Class Scheduler Service (MMCSS).
				The default value is 10000, which corresponds to a 1-millisecond time resolution.
				Lower values indicate a finer time resolution, while higher values represent a coarser time resolution.

				Adjusting the "Clock Rate" value may impact the performance of multimedia and gaming applications.
				Decreasing the value can potentially improve the responsiveness of such applications by increasing
				the scheduler's time resolution. However, lower values may also increase CPU usage and power
				consumption.

GPU Priority:		This value defines the priority level for GPU resources. Higher values indicate higher priority.
					It ranges from 1 (lowest priority) to 31 (highest priority).
					By default, the value is set to 8 for gaming applications. Increasing this value may improve
					gaming performance by prioritizing GPU resources for the application.

Priority:			This value sets the priority level for CPU resources.
					It ranges from 1 (lowest priority) to 31 (highest priority).
					The default value for gaming applications is typically set to 8.
					Increasing this value can prioritize CPU resources for the gaming application,
					potentially improving performance.

Scheduling Category:	This value represents the scheduling category for the gaming application.
						It can be set to one of the following:

						High: The application gets higher priority and more resources.
						Medium: The application gets medium priority and resources.
						Low: The application gets lower priority and fewer resources.
#>

# Create the key if it does not exist
$GamesProfRegistryPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
If (-NOT (Test-Path $GamesProfRegistryPath)) {
  New-Item -Path $GamesProfRegistryPath -Force | Out-Null
}
# Set the values
New-ItemProperty -Path $GamesProfRegistryPath -Name 'GPU Priority' -Value 8 -PropertyType DWORD -Force
New-ItemProperty -Path $GamesProfRegistryPath -Name 'Priority' -Value 6 -PropertyType DWORD -Force
New-ItemProperty -Path $GamesProfRegistryPath -Name 'Scheduling Category' -Value 'High' -Force
New-ItemProperty -Path $GamesProfRegistryPath -Name 'SFIO Priority' -Value 'High' -Force

Write-Host "Step 7: Enable Game Mode..."
Enable-GameMode

# Download Intelligent standby list cleaner (ILSC)
# https://www.wagnardsoft.com/forums/viewtopic.php?t=1256/

# Go to this video for network tweaks
# https://www.youtube.com/watch?v=MUZ1jpnr71w

Write-Host "Step 8: Rename Computer..."
Rename-Computer -NewName $NewComputername

Write-Host "Step 9: Reboot Computer for settings to take affect"
Stop-Transcript
Write-Host "Install Log"
Write-Host "****************************************************"
Write-Host "****************************************************"
Get-Content $Env:TEMP\$($env:COMPUTERNAME)_StoreUpdate.log
Write-Host "****************************************************"
Write-Host "****************************************************"
