# Download and run the script using: irm https://domain.com/path/to/script.ps1 | iex

# Define the URL for the RMM agent installer
$rmmURI = "https://app.atera.com/breeze/GenericTicketing/GetAgentSetupMSI?customerId=90&customerName=Simitive%20Limited&folderId=265&folderName=Workstations&integratorLogin=fergusbarker@westspring-it.co.uk&accountId=0013z00002WJbquAAD"
$rmmArgs = "/qn IntegratorLogin=fergusbarker@westspring-it.co.uk CompanyId=90 AccountId=0013z00002WJbquAAD FolderId=265"
$clientName = [System.Web.HttpUtility]::UrlDecode($rmmURI.Split("customerName=")[1].Split("&")[0])
$clientFolder = [System.Web.HttpUtility]::UrlDecode($rmmURI.Split("folderName=")[1].Split("&")[0])


# Define Functions
# Function to download and install the latest version of winget
function Install-Winget {
    Write-Host "Downloading and installing the latest version of winget..."
    $wingetURI = "https://aka.ms/getwinget"
    try {
        Invoke-RestMethod -Uri $wingetURI -OutFile $env:TMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
        Add-AppxPackage -Path $env:TMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
        Write-Host "winget installed successfully."
    }
    catch {
        Write-Host "Failed to download or install winget." -ForegroundColor Red
        $cont = Read-Host "Do you want to continue? (yes/no)"
        If ($cont -eq "no") { Exit 1 } else { $cont = $null }
    }
}

# Check for internet connection
$internetConnection = Test-Connection -ComputerName ([System.Uri]$rmmURI).Host -Count 1 -Quiet
if (!($internetConnection)) {
    # Warn the user about the lack of internet connection
    Write-Host "Unable to connect to the internet. Please check your connection and try again." -ForegroundColor Red
} else {
    Write-Host "Internet connection is available, proceeding..." -ForegroundColor Green
}
       
# Download and run the RMM agent installer
Write-Host "Downloading and running the RMM agent installer..."
try {
    Write-Host "Downloading the RMM agent installer for '$clientName' in '$clientFolder'..."
    Invoke-WebRequest -Uri $rmmURI -OutFile $env:TMP\setup.msi
    # Check if the MSI file exists
    if (!(Test-Path -Path $env:TMP\setup.msi)) {
        throw "Failed to download the RMM agent installer."
        Exit 1
    } else {
    $process = Start-Process msiexec.exe -ArgumentList "/i $env:TMP\setup.msi $rmmArgs" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "MSI installation failed with exit code: $($process.ExitCode)"
    } else {
        Write-Host "RMM agent installed successfully."
        # Remove the installer file
        Remove-Item -Path "$env:TMP\setup.msi" -Force -ErrorAction SilentlyContinue
    }
}}
catch {
    Write-Host "Failed to download or run the RMM agent installer." -ForegroundColor Red
    $cont = Read-Host "Do you want to continue? (yes/no)"
    If ($cont -eq "no") { Exit 1 } else { $cont = $null }    
}


# Ask the user if the device is to be imported to Intune Autopilot
$importToIntune = Read-Host "Do you want to import this device to Intune Autopilot? (yes/no)"
if ($importToIntune -eq "yes") {
    # Install the Get-WindowsAutoPilotInfo script
    Install-Script -Name Get-WindowsAutoPilotInfo -Force

    # Run the Get-WindowsAutoPilotInfo script and export the hash file to C:\HWID
    Write-Host "Running Get-WindowsAutoPilotInfo script and exporting hash file to C:\HWID..."
    Get-WindowsAutoPilotInfo -OutputFile "C:\HWID\AutoPilotHWID.csv"
}
else {
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
