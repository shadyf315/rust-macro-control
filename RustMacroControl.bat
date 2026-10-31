@echo off
rem Website: https://shadyf315.github.io/rust-macro-control/
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -Command "$ErrorActionPreference='Stop'; try { $p='%~f0'; $a=[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8) -split '\r?\n'; $k=[Array]::IndexOf($a,':PSCODE'); $j=[Array]::IndexOf($a,':ENDPSCODE'); if($k -lt 0 -or $j -le $k){throw 'Embedded script not found.'}; $src=$a[($k+1)..($j-1)] -join [Environment]::NewLine; & ([scriptblock]::Create($src)) } catch { Write-Host $_.Exception.ToString() -ForegroundColor Red }"
pause
exit /b

:PSCODE
$ErrorActionPreference = 'Stop'

# Keep one controller process so two copies cannot send input at the same time.
$singleMutex = [System.Threading.Mutex]::new($false, 'Local\RustMacroController')
$mutexOwned = $false
try { $mutexOwned = $singleMutex.WaitOne(0) }
catch [System.Threading.AbandonedMutexException] { $mutexOwned = $true }
if (-not $mutexOwned) { throw 'Контроллер уже запущен: используйте его окно, не запускайте второй экземпляр.' }

# Last working timing values, kept for rollback:
# hot wait 1000ms; E hold ~1500ms; pre-E 100ms; post-E 50ms;
# digit down 30-60ms; digit gap 40-80ms; pre-Enter 50ms; Enter down 30ms; cycle gap 100ms.

Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Threading;

public static class MacroInput {
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [StructLayout(LayoutKind.Sequential)] struct KeyboardInput { public ushort vk; public ushort scan; public uint flags; public uint time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct MouseInput { public int dx; public int dy; public uint data; public uint flags; public uint time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] struct InputUnion { [FieldOffset(0)] public KeyboardInput keyboard; [FieldOffset(0)] public MouseInput mouse; }
    [StructLayout(LayoutKind.Sequential)] struct Input { public uint type; public InputUnion union; }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    public static uint SendScanCode(ushort scan, uint flags) {
        Input input = new Input(); input.type = 1;
        input.union.keyboard = new KeyboardInput { vk = 0, scan = scan, flags = flags, time = 0, extra = UIntPtr.Zero };
        return SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input)));
    }
    public static uint SendVirtualKey(ushort vk, uint flags) {
        Input input = new Input(); input.type = 1;
        input.union.keyboard = new KeyboardInput { vk = vk, scan = 0, flags = flags, time = 0, extra = UIntPtr.Zero };
        return SendInput(1, new Input[] { input }, Marshal.SizeOf(typeof(Input)));
    }
}

public static class RightShiftHotkey {
    [StructLayout(LayoutKind.Sequential)] struct Point { public int x; public int y; }
    [StructLayout(LayoutKind.Sequential)] struct Msg {
        public IntPtr hwnd; public uint message; public UIntPtr wParam;
        public IntPtr lParam; public uint time; public Point pt;
    }
    delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] struct KeyboardData { public uint vkCode; public uint scanCode; public uint flags; public uint time; public IntPtr extra; }
    [DllImport("user32.dll", SetLastError=true)] static extern IntPtr SetWindowsHookEx(int id, HookProc callback, IntPtr module, uint threadId);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet=CharSet.Auto)] static extern IntPtr GetModuleHandle(string name);
    [DllImport("user32.dll")] static extern int GetMessage(out Msg msg, IntPtr hwnd, uint min, uint max);
    [DllImport("user32.dll")] static extern bool PeekMessage(out Msg msg, IntPtr hwnd, uint min, uint max, uint remove);
    [DllImport("user32.dll")] static extern bool TranslateMessage(ref Msg msg);
    [DllImport("user32.dll")] static extern IntPtr DispatchMessage(ref Msg msg);
    public static int ToggleRequested;
    public static int Running;
    public static int Ready;
    public static int ErrorCode;
    public static int ConsumeToggle() { return Interlocked.Exchange(ref ToggleRequested, 0); }
    public static int ToggleRunning() {
        int oldValue, newValue;
        do { oldValue = Thread.VolatileRead(ref Running); newValue = oldValue == 0 ? 1 : 0; }
        while (Interlocked.CompareExchange(ref Running, newValue, oldValue) != oldValue);
        return newValue;
    }
    public static int IsRunning() { return Thread.VolatileRead(ref Running); }
    static Thread worker;
    static HookProc callback = HookCallback;
    static IntPtr hookHandle;
    static int rightShiftDown;
    static IntPtr HookCallback(int code, IntPtr wParam, IntPtr lParam) {
        if (code >= 0) {
            int message = wParam.ToInt32();
            KeyboardData data = (KeyboardData)Marshal.PtrToStructure(lParam, typeof(KeyboardData));
            if (data.vkCode == 0xA1) {
                if (message == 0x0100 || message == 0x0104) {
                    if (Interlocked.Exchange(ref rightShiftDown, 1) == 0) Interlocked.Exchange(ref ToggleRequested, 1);
                } else if (message == 0x0101 || message == 0x0105) Interlocked.Exchange(ref rightShiftDown, 0);
            }
        }
        return CallNextHookEx(hookHandle, code, wParam, lParam);
    }
    public static void Start() {
        worker = new Thread(() => {
            Msg m; PeekMessage(out m, IntPtr.Zero, 0, 0, 0);
            hookHandle = SetWindowsHookEx(13, callback, GetModuleHandle(null), 0);
            if (hookHandle == IntPtr.Zero) { ErrorCode = Marshal.GetLastWin32Error(); Ready = -1; return; }
            Ready = 1;
            try { while (GetMessage(out m, IntPtr.Zero, 0, 0) > 0) { TranslateMessage(ref m); DispatchMessage(ref m); } }
            finally { UnhookWindowsHookEx(hookHandle); }
        });
        worker.IsBackground = true; worker.Start();
    }
}
'@

$oldLink = Join-Path (Split-Path -Parent $p) 'Вставка цифр.lnk'
if (Test-Path -LiteralPath $oldLink) { Remove-Item -LiteralPath $oldLink -Force }
$root = Split-Path -Parent $p
$state = Join-Path $root '.digits-index'
$listPath = Join-Path $root 'digits.txt'
$items = @(Get-Content -LiteralPath $listPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d{4}$' })
if (!$items.Count) { throw 'В digits.txt нет строк ровно из четырёх цифр.' }
function Reset-ListPointer {
    Set-Content -LiteralPath $state -Value '0' -NoNewline
}
function Skip-ListPointer {
    $pointer = 0
    if (Test-Path -LiteralPath $state) { [void][int]::TryParse((Get-Content -LiteralPath $state -Raw).Trim(), [ref]$pointer) }
    if ($pointer -lt 0 -or $pointer -ge $items.Count) { $pointer = 0 }
    Set-Content -LiteralPath $state -Value (($pointer + 1) % $items.Count) -NoNewline
}
function Show-RepositoryLink {
    Write-Host '  Version v1.1.0 | GitHub: https://github.com/shadyf315/rust-macro-control' -ForegroundColor DarkGray
}
function Show-NumberedList {
    $pageSize = 25
    $page = 0
    $lastPage = [Math]::Max(0, [Math]::Ceiling($items.Count / $pageSize) - 1)
    do {
        Clear-Host
        Write-Host '  ╔══════════════════════════════════════════════╗' -ForegroundColor DarkCyan
        Write-Host '  ║              СПИСОК ВАРИАЦИЙ                 ║' -ForegroundColor Cyan
        Write-Host '  ╠══════════════════════════════════════════════╣' -ForegroundColor DarkCyan
        $first = $page * $pageSize
        $last = [Math]::Min($first + $pageSize - 1, $items.Count - 1)
        for ($n = $first; $n -le $last; $n++) {
            Write-Host ('  {0,5}.  {1}' -f ($n + 1), $items[$n]) -ForegroundColor White
        }
        Write-Host '  ╠══════════════════════════════════════════════╣' -ForegroundColor DarkCyan
        Write-Host ('  Страница {0}/{1}  |  1 — далее  2 — назад  0 — выход' -f ($page + 1), ($lastPage + 1)) -ForegroundColor Yellow
        Show-RepositoryLink
        $pageChoice = Read-Host 'Введите цифру (0-2)'
        if ($pageChoice -eq '1' -and $page -lt $lastPage) { $page++ }
        elseif ($pageChoice -eq '2' -and $page -gt 0) { $page-- }
    } while ($pageChoice -ne '0')
}
function Show-ControlPanel {
    Clear-Host
    Write-Host '  ╔══════════════════════════════════════════════╗' -ForegroundColor DarkCyan
    Write-Host '  ║              R U S T   C O N T R O L         ║' -ForegroundColor Cyan
    Write-Host '  ╠══════════════════════════════════════════════╣' -ForegroundColor DarkCyan
    Write-Host '  ║   1   Запустить / продолжить скрипт          ║' -ForegroundColor White
    Write-Host '  ║   2   Сбросить список цифр                   ║' -ForegroundColor White
    Write-Host '  ║   3   Пропустить следующую запись            ║' -ForegroundColor White
    Write-Host '  ║   4   Просмотреть нумерованный список         ║' -ForegroundColor White
    Write-Host '  ║   0   Выход                                  ║' -ForegroundColor White
    Write-Host '  ╠══════════════════════════════════════════════╣' -ForegroundColor DarkCyan
    Write-Host '  ║   Right Shift   Пауза / продолжить           ║' -ForegroundColor Yellow
    Write-Host '  ╚══════════════════════════════════════════════╝' -ForegroundColor DarkCyan
    Show-RepositoryLink
    Write-Host '  Выберите пункт (0-4): ' -NoNewline -ForegroundColor Cyan
}

function Show-Menu {
    Clear-Host
    Show-RepositoryLink
    Write-Host '  ╔══════════════════════════════════════════════╗' -ForegroundColor DarkCyan
    Write-Host '  ║              R U S T   C O N T R O L         ║' -ForegroundColor Cyan
    Write-Host '  ╠══════════════════════════════════════════════╣' -ForegroundColor DarkCyan
    Write-Host '  ║                                              ║' -ForegroundColor DarkCyan
    Write-Host '  ║   1   Открыть управление скриптом            ║' -ForegroundColor White
    Write-Host '  ║   2   Сбросить список цифр                   ║' -ForegroundColor White
    Write-Host '  ║   3   Пропустить следующую запись            ║' -ForegroundColor White
    Write-Host '  ║   4   Просмотреть нумерованный список         ║' -ForegroundColor White
    Write-Host '  ║   0   Выход                                  ║' -ForegroundColor White
    Write-Host '  ║                                              ║' -ForegroundColor DarkCyan
    Write-Host '  ╚══════════════════════════════════════════════╝' -ForegroundColor DarkCyan
    Write-Host '       Во время работы: Right Shift — пауза' -ForegroundColor DarkGray
    Show-RepositoryLink
}
do {
    Show-Menu
    $choice = Read-Host 'Выберите пункт (0-4)'
    if ($choice -eq '2') {
        Reset-ListPointer
        Write-Host 'Позиция списка сброшена.' -ForegroundColor Green
        Start-Sleep -Seconds 1
    } elseif ($choice -eq '3') {
        Skip-ListPointer
        Write-Host 'Следующая запись пропущена.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    } elseif ($choice -eq '4') {
        Show-NumberedList
    }
} while ($choice -in @('2','3','4','g','G'))
if ($choice -ne '1') { exit }

[RightShiftHotkey]::Start()
for ($q = 0; $q -lt 40 -and [RightShiftHotkey]::Ready -eq 0; $q++) { Start-Sleep -Milliseconds 50 }
if ([RightShiftHotkey]::Ready -ne 1) {
    throw "Не удалось зарегистрировать правый Shift. Код ошибки: $([RightShiftHotkey]::ErrorCode)"
}

Show-ControlPanel
$toggleMacro = {
    if ([RightShiftHotkey]::ConsumeToggle() -eq 1) {
        $newState = [RightShiftHotkey]::ToggleRunning()
        if ($newState -ne 0) { Write-Host '  ● СКРИПТ РАБОТАЕТ' -ForegroundColor Green }
        else { Write-Host '  ◼ ПАУЗА — нажмите Right Shift для продолжения' -ForegroundColor Yellow }
    }
}
$pauseSecond = {
    for ($waitPart = 0; $waitPart -lt 20; $waitPart++) {
        Start-Sleep -Milliseconds 50
        & $toggleMacro
        while ([RightShiftHotkey]::IsRunning() -eq 0) {
            Start-Sleep -Milliseconds 20
            & $toggleMacro
        }
    }
    return $true
}
$pauseMenu = {
    param([int]$ticks)
    for ($waitPart = 0; $waitPart -lt $ticks; $waitPart++) {
        Start-Sleep -Milliseconds 10
        & $toggleMacro
        while ([RightShiftHotkey]::IsRunning() -eq 0) {
            Start-Sleep -Milliseconds 20
            & $toggleMacro
        }
    }
    return $true
}

$attemptsSinceRespawn = 0

try {
    while ($true) {
        & $toggleMacro
        if ([Console]::KeyAvailable) {
            $consoleKey = [Console]::ReadKey($true).KeyChar
            if ($consoleKey -eq '0') { break }
            if ($consoleKey -eq '2') { Reset-ListPointer; Write-Host '  ✓ Список сброшен.' -ForegroundColor Cyan }
            if ($consoleKey -eq '3') { Skip-ListPointer; Write-Host '  → Следующая запись пропущена.' -ForegroundColor Yellow }
            if ($consoleKey -eq '4') { Show-NumberedList; Show-ControlPanel }
            if ($consoleKey -eq '1') { [RightShiftHotkey]::Running = 1; Write-Host '  ● Скрипт запущен.' -ForegroundColor Green }
        }
        if ([RightShiftHotkey]::IsRunning() -eq 0) { Start-Sleep -Milliseconds 10; continue }

        $index = 0
        if (Test-Path -LiteralPath $state) { $n = 0; [void][int]::TryParse((Get-Content -LiteralPath $state -Raw).Trim(), [ref]$n); $index = $n }
        if ($index -lt 0 -or $index -ge $items.Count) { $index = 0 }
        try {
            if (-not (& $pauseMenu 5)) { continue }

            # E remains held through the existing circular-menu sequence.
            [void][MacroInput]::SendScanCode(0x12, 0x0008)
            if (-not (& $pauseSecond)) { continue }
            [MacroInput]::mouse_event(0x0001, 82, 177, 0, [UIntPtr]::Zero)
            if (-not (& $pauseMenu 10)) { continue }
            [MacroInput]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
            Start-Sleep -Milliseconds 50
            [MacroInput]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
            if (-not (& $pauseMenu 30)) { continue }
            [void][MacroInput]::SendScanCode(0x12, 0x000A)
            if (-not (& $pauseMenu 3)) { continue }
            $digitScans = @{ '1'=0x02; '2'=0x03; '3'=0x04; '4'=0x05; '5'=0x06; '6'=0x07; '7'=0x08; '8'=0x09; '9'=0x0A; '0'=0x0B }
            foreach ($digit in $items[$index].ToCharArray()) {
                $scan = [System.UInt16]$digitScans[[string]$digit]
                [void][MacroInput]::SendScanCode($scan, 0x0008)
                Start-Sleep -Milliseconds (Get-Random -Minimum 20 -Maximum 40)
                [void][MacroInput]::SendScanCode($scan, 0x000A)
                Start-Sleep -Milliseconds (Get-Random -Minimum 20 -Maximum 50)
                if (-not (& $pauseMenu 1)) { continue }
            }
            if (-not (& $pauseMenu 3)) { continue }
            [void][MacroInput]::SendScanCode(0x1C, 0x0008)
            Start-Sleep -Milliseconds 20
            [void][MacroInput]::SendScanCode(0x1C, 0x000A)
            Set-Content -LiteralPath $state -Value (($index + 1) % $items.Count) -NoNewline
            $attemptsSinceRespawn++
            if ($attemptsSinceRespawn -ge 5) {
                $attemptsSinceRespawn = 0
                [RightShiftHotkey]::Running = 0
                [void][RightShiftHotkey]::ConsumeToggle()
                Write-Host '5 попыток завершено. Возродитесь вручную у первого отмеченного спальника, затем нажмите Right Shift для продолжения.' -ForegroundColor Yellow
            }
        } finally {
            [MacroInput]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
            [void][MacroInput]::SendScanCode(0x12, 0x000A)
        }
        if ([RightShiftHotkey]::IsRunning() -ne 0) { [void](& $pauseMenu 5) }
    }
} finally {
    if ($mutexOwned) { $singleMutex.ReleaseMutex(); $singleMutex.Dispose() }
}
:ENDPSCODE

