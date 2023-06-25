# I made this because this awful service really screws with Destiny2
# It causes major frame drops
# Author: Jericho Jones
# Date: 06/24/2023

# Check if running with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as an administrator."
    #Start-Sleep -Seconds 5
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Function to stop Gaming Services service
function Stop-GamingServicesService {
    $serviceName = "GamingServices"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($service) {
        if ($service.Status -eq 'Running') {
            Write-Host "$(Get-Date -Format "HH:mm:ss") Stopping Gaming Services service..."
            Stop-Service -Name $serviceName
            Write-Host "Gaming Services service has been stopped."
        }
        else {
            Write-Host "Gaming Services service is already stopped."
        }
    }
    else {
        Write-Host "Gaming Services service is not present on this system."
    }
}

# Loop to continuously monitor and stop Gaming Services service
while ($true) {
    $service = Get-Service -Name "GamingServices" -ErrorAction SilentlyContinue

    if ($service -and $service.Status -eq 'Running') {
        Stop-GamingServicesService
    }

    # Delay between each iteration (in seconds)
    Start-Sleep -Seconds 1
}
