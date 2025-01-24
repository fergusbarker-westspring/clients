# Download and run the script using: irm https://domain.com/path/to/script.ps1 | iex

# Define the URL for the RMM agent installer
$rmmURI = "https://domain.com/path/to/rmm/installer.exe"

# Download and run the RMM agent installer
Write-Host "Downloading and running the RMM agent installer..."
try {
    Invoke-WebRequest -Uri $rmmURI -OutFile "$env:TEMP\installer.exe"
    Start-Process -FilePath "$env:TEMP\installer.exe" -Wait
} catch {
    Write-Host "Failed to download or run the RMM agent installer." -ForegroundColor Red
    exit 1
}

# Ask the user if the device is to be imported to Intune Autopilot
$importToIntune = Read-Host "Do you want to import this device to Intune Autopilot? (yes/no)"

if ($importToIntune -eq "yes") {
    # Check for internet connection
    $internetConnection = Test-Connection -ComputerName ([System.Uri]$rmmURI).Host -Count 1 -Quiet

    if ($internetConnection) {
        # Install the Get-WindowsAutoPilotInfo script
        Install-Script -Name Get-WindowsAutoPilotInfo -Force

        # Run the Get-WindowsAutoPilotInfo script with the -Online flag
        Write-Host "Running Get-WindowsAutoPilotInfo script..."
        Get-WindowsAutoPilotInfo -Online
    } else {
        # Warn the user about the lack of internet connection
        Write-Host "No internet connection detected. Please connect to a network."

        # Ask the user if they want to continue anyway
        $continueAnyway = Read-Host "Do you want to continue anyway? (yes/no)"

        if ($continueAnyway -eq "yes") {
            # Install the Get-WindowsAutoPilotInfo script
            Install-Script -Name Get-WindowsAutoPilotInfo -Force

            # Run the Get-WindowsAutoPilotInfo script and export the hash file to C:\HWID
            Write-Host "Running Get-WindowsAutoPilotInfo script and exporting hash file to C:\HWID..."
            Get-WindowsAutoPilotInfo -OutputFile "C:\HWID\AutoPilotHWID.csv"
        } else {
            Write-Host "Operation cancelled by user."
            exit 1
        }
    }
} else {
    Write-Host "Device will not be imported to Intune Autopilot."
}

# Skip through the OOBE using the specified parameters
Write-Host "Skipping through the OOBE..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "SkipMachineOOBE" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "SkipUserOOBE" /t REG_DWORD /d 1 /f

# Set the region, language, and keyboard layout
Write-Host "Setting region, language, and keyboard layout to 'United Kingdom'..."
Set-WinUILanguageOverride -Language en-GB
Set-WinUserLanguageList -LanguageList en-GB -Force
Set-WinSystemLocale -SystemLocale en-GB
Set-WinHomeLocation -GeoId 242
Set-WinUILanguageFallback -Language en-GB

# Set the local username and password
Write-Host "Setting local username and password..."
net user wsadmin L0cal01! /add
net localgroup administrators wsadmin /add

# Disable location services, ad tracking, and diagnostic reporting
Write-Host "Disabling location services, ad tracking, and diagnostic reporting..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global" /v "Value" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f

# Adjust power settings to prevent sleep
Write-Host "Adjusting power settings to prevent sleep..."
powercfg -change -standby-timeout-ac 0
powercfg -change -monitor-timeout-ac 0

# Optionally trigger Windows Updates
Write-Host "Checking for Windows Updates..."
Install-Module PSWindowsUpdate -Force
Import-Module PSWindowsUpdate
Get-WindowsUpdate -Install -AcceptAll -AutoReboot

# Reboot to apply all settings
Write-Host "Rebooting the system to apply all settings..."
Restart-Computer -Force
