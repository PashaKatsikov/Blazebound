<#
=============================================================
 build_android.ps1 — cross-compile libblazebound_relay.so
=============================================================
 Builds the native config transport for each Android ABI and drops the
 .so into android/app/src/main/jniLibs/<abi>/ so Gradle packs it.

 Why not plain `cargo ndk`:
   cargo-ndk exports CC_<target>/CXX_<target>. btls-sys then compiles the
   first BoringSSL pass (libssl.a) with the HOST compiler (COFF x86-64 on
   Windows); the Android linker silently drops those objects and the .so
   ships without SSL_* → dlopen "cannot locate symbol SSL_CTX_free".
   So we drive cargo directly, keep ONLY the NDK bin on PATH, and let
   android.toolchain.cmake choose the compiler (pitfall #2).

 Environment hygiene enforced here:
   • CC_<t>/CXX_<t>/AR_<t> are cleared (btls must not see them).
   • CFLAGS_/CXXFLAGS_/BINDGEN_EXTRA_CLANG_ARGS_ are kept — cc/bindgen
     read them, btls ignores them.
   • CMake: newest Android-SDK CMake with major < 4 (CMake 4 is
     incompatible with android.toolchain.cmake — pitfall #4), Ninja gen.
   • Linking uses -Wl,--start-group -lssl -lcrypto -Wl,--end-group from
     build.rs (pitfall #3).

 Usage:
   pwsh android/rust/build_android.ps1                 # all ABIs, release
   pwsh android/rust/build_android.ps1 -Abis arm64-v8a -Profile debug
=============================================================
#>
[CmdletBinding()]
param(
    [string[]] $Abis = @('arm64-v8a', 'armeabi-v7a', 'x86_64'),
    [ValidateSet('release', 'debug')] [string] $Profile = 'release',
    [int] $ApiLevel = 26
)

$ErrorActionPreference = 'Stop'
$crateDir = Join-Path $PSScriptRoot 'relay_transport'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$jniLibs = Join-Path $projectRoot 'android\app\src\main\jniLibs'

# ── Locate the Android SDK / NDK ──────────────────────────────
$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\sdk' }
if (-not (Test-Path $sdk)) { throw "Android SDK not found (set ANDROID_HOME). Looked at: $sdk" }

$ndkRoot = Get-ChildItem (Join-Path $sdk 'ndk') -Directory |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $ndkRoot) { throw "No NDK under $sdk\ndk" }
$ndk = $ndkRoot.FullName

# Newest CMake with major < 4 (CMake 4 breaks android.toolchain.cmake).
$cmakeDir = Get-ChildItem (Join-Path $sdk 'cmake') -Directory |
    Where-Object { [version]$_.Name -lt [version]'4.0.0' } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $cmakeDir) { throw "No CMake with major < 4 under $sdk\cmake" }
$cmakeBin = Join-Path $cmakeDir.FullName 'bin'

$llvmBin = Join-Path $ndk 'toolchains\llvm\prebuilt\windows-x86_64\bin'
if (-not (Test-Path $llvmBin)) { throw "NDK llvm bin not found: $llvmBin" }

Write-Host "SDK   : $sdk"
Write-Host "NDK   : $ndk"
Write-Host "CMake : $($cmakeDir.Name) ($cmakeBin)"

# ── Map ABI → Rust target triple + clang target (with API) ────
$triples = @{
    'arm64-v8a'   = 'aarch64-linux-android'
    'armeabi-v7a' = 'armv7-linux-androideabi'
    'x86_64'      = 'x86_64-linux-android'
    'x86'         = 'i686-linux-android'
}
# clang's own target spelling differs from the Rust triple for 32-bit arm.
$clangTargets = @{
    'arm64-v8a'   = 'aarch64-linux-android'
    'armeabi-v7a' = 'armv7a-linux-androideabi'
    'x86_64'      = 'x86_64-linux-android'
    'x86'         = 'i686-linux-android'
}

# ── Environment hygiene ───────────────────────────────────────
# Only the NDK bin (+ this CMake + Ninja) on PATH; nothing that would make
# btls pick a host compiler.
#
# Crucially we do NOT set CMAKE_TOOLCHAIN_FILE / ANDROID_ABI / ANDROID_PLATFORM:
# the cmake crate inside btls-sys selects android.toolchain.cmake AND passes
# -DANDROID_ABI for the Rust target itself. Forcing the toolchain file by hand
# suppresses that ABI define, so the NDK toolchain falls back to its armv7
# default and clang rejects "-march=armv7-a" on an aarch64 build (pitfall #4).
$env:PATH = "$llvmBin;$cmakeBin;$($env:PATH)"
$env:ANDROID_NDK_HOME = $ndk
$env:ANDROID_NDK_ROOT = $ndk
$env:CMAKE = Join-Path $cmakeBin 'cmake.exe'
$env:CMAKE_GENERATOR = 'Ninja'
$env:CMAKE_MAKE_PROGRAM = Join-Path $cmakeBin 'ninja.exe'

# Strip any CC_/CXX_/AR_ overrides for every target triple — these are the
# ones that corrupt the BoringSSL two-pass build.
foreach ($t in $triples.Values) {
    $u = $t.ToUpper().Replace('-', '_')
    Remove-Item "env:CC_$u", "env:CXX_$u", "env:AR_$u" -ErrorAction SilentlyContinue
}
Remove-Item env:CC, env:CXX, env:AR -ErrorAction SilentlyContinue

$profileFlag = if ($Profile -eq 'release') { '--release' } else { '' }
$targetSub = if ($Profile -eq 'release') { 'release' } else { 'debug' }

foreach ($abi in $Abis) {
    $triple = $triples[$abi]
    if (-not $triple) { throw "Unknown ABI: $abi" }
    $u = $triple.ToUpper().Replace('-', '_')

    Write-Host "`n=== Building $abi ($triple) ==="

    # Per-target linker = NDK clang for the chosen API level. The cc crate
    # auto-derives the C compiler from PATH (NO CC_ set).
    $clangTriple = $clangTargets[$abi]
    $linker = Join-Path $llvmBin "$clangTriple$ApiLevel-clang.cmd"
    if (-not (Test-Path $linker)) { $linker = Join-Path $llvmBin "$clangTriple$ApiLevel-clang" }
    Set-Item "env:CARGO_TARGET_${u}_LINKER" $linker

    # btls-sys forces CMAKE_<LANG>_COMPILER_TARGET to the bare triple (no API
    # level). With android.toolchain.cmake that drops the API from --target and
    # the linker can't find crtbegin_dynamic.o. cc/bindgen append these flags
    # LAST, so a versioned --target wins and the CRT resolves (pitfall #2/#3).
    $sysroot = (Resolve-Path (Join-Path $llvmBin '..\sysroot')).Path
    $verTarget = "--target=$clangTriple$ApiLevel"
    Set-Item "env:CFLAGS_$u" $verTarget
    Set-Item "env:CXXFLAGS_$u" $verTarget
    # bindgen (boring-sys) parses openssl/base.h with the HOST libclang, which
    # defaults to a Windows target and cannot see the NDK's usr/include. It
    # needs --target (btls only adds --sysroot). bindgen splits this var with
    # shlex, so use forward slashes — backslashes would be eaten as escapes.
    $sysrootFwd = $sysroot -replace '\\', '/'
    $env:BINDGEN_EXTRA_CLANG_ARGS = "$verTarget --sysroot=$sysrootFwd"

    Push-Location $crateDir
    try {
        & cargo build $profileFlag --target $triple
        if ($LASTEXITCODE -ne 0) { throw "cargo build failed for $abi" }
    } finally {
        Pop-Location
    }

    $soSrc = Join-Path $crateDir "target\$triple\$targetSub\libblazebound_relay.so"
    if (-not (Test-Path $soSrc)) { throw "Missing output: $soSrc" }

    $dstDir = Join-Path $jniLibs $abi
    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    Copy-Item $soSrc (Join-Path $dstDir 'libblazebound_relay.so') -Force
    Write-Host "copied → $dstDir\libblazebound_relay.so"

    # The .so dynamically needs libc++_shared.so (BoringSSL is C++). It is NOT a
    # system library, so it must ride along in jniLibs — otherwise dlopen() on
    # device fails with "library libc++_shared.so not found" and the whole
    # native transport silently degrades to status 0.
    $cxxTriples = @{
        'arm64-v8a'   = 'aarch64-linux-android'
        'armeabi-v7a' = 'arm-linux-androideabi'
        'x86_64'      = 'x86_64-linux-android'
    }
    $cxxSo = Join-Path $sysroot "usr\lib\$($cxxTriples[$abi])\libc++_shared.so"
    if (Test-Path $cxxSo) {
        Copy-Item $cxxSo (Join-Path $dstDir 'libc++_shared.so') -Force
        Write-Host "copied → $dstDir\libc++_shared.so"
    } else {
        Write-Warning "libc++_shared.so not found at $cxxSo"
    }

    # Sanity: the shipped .so must be an ELF shared object for this ABI and
    # must carry the BoringSSL SSL_* symbols (if btls had compiled libssl.a as
    # host COFF, the aarch64 link would drop them → dlopen SSL_CTX_free). The
    # .a files begin with the "!<arch>" header, so we inspect the .so instead.
    $dst = Join-Path $dstDir 'libblazebound_relay.so'
    $magic = ([System.IO.File]::ReadAllBytes($dst)[0..3] | ForEach-Object { $_.ToString('X2') }) -join ' '
    $readelf = Join-Path $llvmBin 'llvm-readelf.exe'
    $nm = Join-Path $llvmBin 'llvm-nm.exe'
    $machine = (& $readelf -h $dst | Select-String 'Machine:').ToString().Trim()
    $hasSsl = (& $nm $dst 2>$null | Select-String 'SSL_CTX_free') -ne $null
    $isElf = $magic -eq '7F 45 4C 46'
    Write-Host ("  so: magic {0} ({1}); {2}; SSL_CTX_free={3}" -f `
        $magic, $(if ($isElf) { 'ELF ok' } else { 'NOT ELF' }), $machine, $hasSsl)
}

Write-Host "`nDone. jniLibs under $jniLibs"
