# PowerShell Scripts

## Overview
This repository contains a collection of PowerShell scripts developed by Jericho Jones. These scripts are designed to perform various tasks such as creating shortcuts, reinstalling software, and stopping game server services.

## Scripts

### Create-Shortcut2WinUtil.ps1
- **Description**: This script generates a shortcut (.lnk) file in the user's Start Menu. The shortcut executes a PowerShell command that fetches and runs the Chris Titus WinUtil script from GitHub with elevated privileges. The script supports selecting either the 'stable' or 'dev' branch.
- **Parameters**:
  - `Branch`: Specifies the branch to use for the Chris Titus WinUtil script (default: 'stable').
  - `WhatIf`: Simulates the creation of the shortcut without making changes.
  - `PngUrl`: Specifies the URL of the PNG image to use as the icon.
- **Examples**:
  - `.\Create-Shortcut2WinUtil.ps1` - Creates a shortcut for the stable branch with default settings.
  - `.\Create-Shortcut2WinUtil.ps1 -Branch dev` - Creates a shortcut for the development branch.
- **Notes**: Requires PowerShell 5.1 or later and administrative privileges. The script now validates that the PNG image is square and resizes it if necessary to not exceed 256x256 pixels. Ensure the source is trusted before execution.
- **Link**: [Chris Titus WinUtil](https://github.com/ChrisTitusTech/winutil)
  
### Reinstall-Software-via-Winget_GithubEdition.ps1
- **Description**: Post Windows install script to optimize for gaming and install software. It updates Microsoft Store applications, runs Chris Titus script, installs apps, disables High Performance Event Timer (HPET), modifies CPU and GPU priorities, enables Game Mode, renames the computer, and prompts for a reboot.
- **Functions**:
  - `Install-WingetApp`: Installs applications using Winget.
  - `Disable-HPET`: Disables the High Precision Event Timer.
  - `Enable-GameMode`: Enables Game Mode in Windows 10.
- **Features**: 
  - Updates app repositories and installs several applications.
  - Modifies system settings for optimal gaming performance.
  - Handles administrative privileges and execution policies.

### Stop-GameServerService.ps1
- **Description**: Stops the Gaming Services service to prevent major frame drops in games like Destiny 2.
- **Notes**: Requires administrative privileges. The script minimizes the console window and continuously monitors and stops the Gaming Services service.
- **Updated**: 11/26/2023 - Added minimize script window and updated script termination method.

### Install-VSCodiumSandbox.ps1
- **Description**: Downloads and installs VSCodium in a Windows Sandbox environment with host drive mappings.
- **Parameters**: None
- **Actions**:
  1. Checks if the operating system is supported (Windows 10/11 Pro or Enterprise).
  2. Re-runs the script as Administrator if not already elevated.
  3. Checks if Windows Sandbox is enabled; if not, offers to enable it.
  4. Retrieves the latest VSCodium release URL from GitHub.
  5. Downloads the Windows x64 installer.
  6. Creates a Windows Sandbox configuration that:
     - Maps host C: and E: drives as read-only.
     - Automatically installs VSCodium silently on sandbox startup.
  7. Launches the configured Windows Sandbox instance.
- **Notes**: Requires PowerShell 5.1 or later and administrative privileges. Ensure Windows Sandbox is enabled in Windows Features.
 
## Author
Jericho Jones

## Disclaimer
These scripts are provided "as-is" without any warranty. Use at your own risk. The author assumes no liability for damages arising from their use, including but not limited to unintended system changes, data loss, or security vulnerabilities.
