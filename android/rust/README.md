# Native config transport (`relay_transport`)

Cloudflare fronts the config endpoint and returns a **403 challenge** to stock
`rustls`/`ureq` and to the Dart `http` client — it fingerprints them by their
JA3/JA4 TLS handshake. This crate sends the config request with
[`wreq`](https://docs.rs/wreq) whose **Chrome emulation** reproduces a real
BoringSSL TLS fingerprint *and* the matching browser headers (including the
User-Agent) as **one pair**.

```
Client::builder()
    .emulation(Emulation::Chrome134)   // TLS fingerprint + UA + header order
    .connect_timeout(..)
    .timeout(..)
    .build()
```

> **Never set a User-Agent from outside the emulation.** A browser UA over a
> non-browser handshake is exactly what the WAF cuts. The TLS fingerprint and
> the headers must stay a single, consistent pair.

## Surface

- `bb_relay_fetch(body_ptr, body_len) -> *mut c_char` — performs the request and
  returns a freshly allocated C string `"{status}\n{body}"`. Any transport
  failure (DNS/TLS/connect/read timeout, or a panic) yields status `0`. A non-2xx
  HTTP response is **not** a transport error — e.g. a 403 surfaces as `"403\n…"`.
- `bb_relay_free(ptr)` — releases that string (free it in Rust, never in Dart).

The **URL, HTTP method, header names and MIME** are never plaintext in Dart (nor
as literals in the `.so`): they live XOR-encoded in `src/veil.rs` and are
revealed per call. Regenerate them with:

```
dart run tool/gen_relay_veil.dart
```

Dart talks to this library only through `lib/midway/rigging/native_relay.dart`.

## Native vault (gray-part secrets)

The same `.so` also hosts the **gray-part secret store** so that neither static
nor dynamic analysis of the app sees these strings in the clear:

- **User-Agent** fragments + Chrome/WebKit versions,
- the **WebView JS injections** (keyboard-seating script + the two bridge snippets),
- the **notification-promo screen** copy,
- the **push-channel** identity (id / name / description / small-icon name).

### How it defeats static *and* dynamic analysis

- **At rest:** every secret lives XOR-encoded (position_xor family, an
  independent vault salt) in `src/vault.rs` — decoded only inside the `.so`. No
  plaintext literal and no decodable Dart array ships in the APK. The Dart image
  only carries stable integer key ids and the session key (itself byte-XOR
  encoded).
- **In transit:** `bb_vault_fetch(key_id, nonce, nonce_len)` decodes the secret
  and **re-encrypts** it under *(session key, caller nonce)* with a stream cipher,
  returning lowercase **hex**. Dart supplies a fresh random 16-byte nonce every
  call, so the bytes on the wire differ each time — a passive hook on the FFI
  return sees only noise. Dart reverses the last step at the point of use; the
  plaintext exists for a single statement.
- `bb_vault_free(ptr)` releases the returned string (free it in Rust).

The transit cipher is mirrored byte-for-byte by `transit_keystream` in `src/lib.rs`
(Rust) and `NativeVault._transit` in `lib/midway/vault/native_vault.dart` (Dart).
An unknown key, empty nonce or panic collapses to an empty string; off Android
`NativeVault.get` returns `''` and each consumer keeps a generic, non-campaign QA
fallback.

Regenerate the vault (and recover the live UA values from `masked_bytes.dart`)
after changing any secret:

```
dart run tool/gen_vault.dart
```

> The push-channel **id** is unavoidably plaintext in `AndroidManifest.xml`
> (`default_notification_channel_id` is a resource value). The vault value for
> `PUSH_CHANNEL_ID` must equal it; `tool/forge/mint.dart` rotates both from the
> same source.

Dart talks to the vault only through `lib/midway/vault/native_vault.dart`.

## Building

```
powershell android/rust/build_android.ps1                      # all ABIs, release
powershell android/rust/build_android.ps1 -Abis arm64-v8a      # one ABI
```

Output: `android/app/src/main/jniLibs/<abi>/libblazebound_relay.so`, which AGP
packs automatically — a normal `flutter build` needs nothing extra. (Gradle can
also drive the build with `-Prelay.cargo=true`, kept opt-in so a machine without
the Rust/NDK toolchain still builds the app from the committed `.so`.)

Requirements: Rust with the Android targets
(`aarch64/armv7/x86_64-linux-android`), an Android NDK, and an Android-SDK CMake
with **major < 4** plus Ninja.

## BoringSSL cross-compile pitfalls (and the fixes baked into the build)

1. **403 from Cloudflare.** Cause: `rustls`/`ureq`, or a custom User-Agent laid
   over the Chrome emulation. Fix: `wreq` + `Emulation::Chrome134`, and do not
   override the UA.

2. **`dlopen: cannot locate symbol SSL_CTX_free` on device.** `btls-sys` builds
   BoringSSL in two passes (ssl, then crypto). If `CC_<target>`/`CXX_<target>`
   are set in the environment, the first pass compiles `libssl.a` for the **host**
   (COFF x86-64 on Windows); the Android linker silently drops those objects and
   the `.so` ships without `SSL_*`. Fix: **do not set `CC_`/`CXX_`** — let
   `android.toolchain.cmake` choose the compiler, keep only the NDK `bin` on
   `PATH`. `CFLAGS_<target>`/`CXXFLAGS_<target>`/`BINDGEN_EXTRA_CLANG_ARGS_*` are
   safe to set (cc/bindgen read them, btls ignores them for the BoringSSL cmake
   build). The build script verifies the shipped `.so` is ELF and still carries
   `SSL_CTX_free`.

3. **`libssl.a` / `libcrypto.a` don't link; undefined `SSL_`/`X509_`/`EVP_`.**
   Fix: `build.rs` links BoringSSL as a group —
   `-Wl,--start-group -lssl -lcrypto -Wl,--end-group` — so the cross-references
   resolve regardless of archive order. Confirm the final `.so` is
   `ELF … AArch64` (magic `7F 45 4C 46`), not COFF (`64 86`).

4. **CMake doesn't configure the NDK.** CMake 4 is incompatible with
   `android.toolchain.cmake`. Fix: use the newest Android-SDK CMake with
   **major < 4** (e.g. 3.22.1) and the **Ninja** generator.
   - Corollary seen on this toolchain: forcing `CMAKE_TOOLCHAIN_FILE` by hand
     makes `btls-sys` skip its `-DANDROID_ABI` define, so the NDK toolchain falls
     back to its armv7 default (`clang: error: unsupported argument 'armv7-a'`).
     Let btls set the toolchain itself.
   - `btls-sys` also forces `CMAKE_<LANG>_COMPILER_TARGET` to the bare triple
     (no API level), which drops the API from `--target` and the linker can't
     find `crtbegin_dynamic.o`. The build script appends a versioned
     `--target=<triple><api>` via `CFLAGS_*`/`CXXFLAGS_*` so it wins.
   - bindgen parses `openssl/base.h` with the **host** libclang, which defaults to
     a Windows target and can't see the NDK `usr/include`. It needs `--target`
     (btls adds only `--sysroot`): the script sets `BINDGEN_EXTRA_CLANG_ARGS` with
     a versioned target and a **forward-slash** sysroot (bindgen splits the value
     with shlex, so backslashes are eaten).

5. **The Chrome134 emulation stops passing.** Cloudflare rotated its rules and
   the fingerprint is stale. Fix: bump `wreq-util` and switch `Emulation` to the
   current Chrome (e.g. `Emulation::Chrome147`). Still never set the UA by hand.

6. **`dlopen` fails on device → native transport (and vault) silently degrade.**
   The `.so` has `NEEDED: libc++_shared.so` (BoringSSL is C++). `libc++_shared.so`
   is **not** a system library, so if it isn't shipped in `jniLibs/<abi>/`, the
   runtime `DynamicLibrary.open('libblazebound_relay.so')` throws
   *"library libc++_shared.so not found"*; `NativeRelay` catches it and returns
   status 0 → the config request looks like a network failure and the app always
   routes to the game, never the WebView. Fix: the build script copies the NDK's
   `libc++_shared.so` next to each ABI's `.so`. Verify with
   `llvm-readelf -d libblazebound_relay.so` (the `NEEDED` list) and confirm
   `jniLibs/<abi>/libc++_shared.so` exists.
