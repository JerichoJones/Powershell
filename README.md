# PowerShell Scripts

## Overview
This repository contains a collection of PowerShell scripts developed by Jericho Jones. These scripts are designed to perform various tasks such as creating shortcuts, reinstalling software, and stopping game server services.

## Scripts

### Create-Shortcut2WinUtil.ps1
- **Description**: Creates a shortcut in the Start Menu to run Chris Titus WinUtil from GitHub with administrator privileges.
- **Parameters**:
  - `Branch`: Specifies the branch to use for the Chris Titus WinUtil script (default: 'stable').
  - `WhatIf`: Simulates the creation of the shortcut without making changes.
- **Examples**:
  - `.\Create-Shortcut2WinUtil.ps1` - Creates a shortcut for the stable branch with default settings.
  - `.\Create-Shortcut2WinUtil.ps1 -Branch dev` - Creates a shortcut for the development branch.
- **Notes**: Requires PowerShell 5.1 or later and administrative privileges. Ensure the source is trusted before execution.
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

## Author
Jericho Jones

## Disclaimer
These scripts are provided "as-is" without any warranty. Use at your own risk. The author assumes no liability for damages arising from their use, including but not limited to unintended system changes, data loss, or security vulnerabilities.
