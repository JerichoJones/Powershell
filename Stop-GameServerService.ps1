<# I made this because this awful service really screws with Destiny2
 It causes major frame drops
 Author: Jericho Jones
 Date: 06/24/2023
 Updated: 07/15/2023
 Added...
	Minimize script window
	Press ScrollLock to close
#>

# Check if running with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Minimize the console window
$signature = @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@
$type = Add-Type -MemberDefinition $signature -Name WindowUtils -Namespace User32 -PassThru
$consoleWindow = (Get-Process -Id $PID).MainWindowHandle
$minimizeCommand = 6  # Minimize command
$type::ShowWindowAsync($consoleWindow, $minimizeCommand) >$NUL

Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class KeyboardHook {
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int VK_SCROLL = 0x91;

    private static IntPtr hookId = IntPtr.Zero;

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            KBDLLHOOKSTRUCT kbInfo = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            if (kbInfo.vkCode == VK_SCROLL) {
                Console.WriteLine("Scroll Lock key detected. Terminating the script gracefully...");
                UnhookWindowsHookEx(hookId);
                Environment.Exit(0);
            }
        }

        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }

    public static void StartHook() {
        IntPtr moduleHandle = GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName);
        hookId = SetWindowsHookEx(WH_KEYBOARD_LL, HookCallback, moduleHandle, 0);
    }
}
"@

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

# Start the keyboard hook
[KeyboardHook]::StartHook()

# Loop to continuously monitor and stop Gaming Services service
while ($true) {
    $service = Get-Service -Name "GamingServices" -ErrorAction SilentlyContinue

    if ($service -and $service.Status -eq 'Running') {
        Stop-GamingServicesService
    }

    # Delay between each iteration (in milliseconds)
    Start-Sleep -Milliseconds 1000
}
