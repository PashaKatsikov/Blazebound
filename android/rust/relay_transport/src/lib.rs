// ============================================================
// blazebound_relay — native config transport
// ============================================================
// Cloudflare fronts the config endpoint and 403s stock rustls/ureq and the
// Dart `http` client by their JA3/JA4 handshake. The request is sent here
// with wreq, whose Chrome emulation sets the BoringSSL TLS fingerprint AND
// the matching browser headers (incl. User-Agent) as ONE pair. We never set
// a User-Agent from outside: a browser UA over a non-browser handshake is
// exactly what the WAF cuts.
//
// The URL, method, header names and MIME are never plaintext in Dart — they
// are revealed from `veil.rs` on each call. The only thing crossing the FFI
// boundary back to Dart is "{status}\n{body}"; any transport failure (DNS,
// TLS, connect/read timeout, panic) collapses to status 0.
//
// This crate ALSO hosts the native vault (see `vault.rs` + the bb_vault_*
// FFI below): every "gray part" secret (UA fragments, WebView JS injections,
// notification copy, push-channel identity) lives here XOR-encoded and is
// handed to Dart re-encrypted under a session key + a per-call nonce, so no
// plaintext ever crosses the boundary and no decodable copy ships in Dart.
// ============================================================

mod vault;
mod veil;

use std::ffi::{c_char, c_uchar, CString};
use std::panic;
use std::ptr;
use std::slice;
use std::time::Duration;

use wreq::header::{HeaderName, HeaderValue};
use wreq::{Client, Method};
use wreq_util::Emulation;

const CONNECT_TIMEOUT_SECS: u64 = 10;
const TOTAL_TIMEOUT_SECS: u64 = 25;

/// Fetch the config. `body_ptr`/`body_len` is the (optional) request body.
///
/// Returns a freshly allocated C string `"{status}\n{body}"`. On any
/// transport error the status is `0`. The caller MUST release the pointer
/// with [`bb_relay_free`]; freeing it on the Dart side would corrupt the
/// Rust allocator's bookkeeping.
///
/// # Safety
/// `body_ptr` must be null or point to `body_len` readable bytes.
#[no_mangle]
pub unsafe extern "C" fn bb_relay_fetch(
    body_ptr: *const c_uchar,
    body_len: usize,
) -> *mut c_char {
    let body: Vec<u8> = if body_ptr.is_null() || body_len == 0 {
        Vec::new()
    } else {
        // SAFETY: contract documented above — caller guarantees the range.
        unsafe { slice::from_raw_parts(body_ptr, body_len).to_vec() }
    };

    let payload = match panic::catch_unwind(|| run(body)) {
        Ok(Ok(s)) => s,
        Ok(Err(())) | Err(_) => transport_error(),
    };

    CString::new(payload)
        .unwrap_or_else(|_| CString::new(transport_error()).unwrap())
        .into_raw()
}

/// Release a string returned by [`bb_relay_fetch`].
///
/// # Safety
/// `ptr` must be null or a pointer previously returned by `bb_relay_fetch`
/// and not yet freed.
#[no_mangle]
pub unsafe extern "C" fn bb_relay_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    // SAFETY: reclaim the CString we leaked with into_raw().
    unsafe {
        drop(CString::from_raw(ptr));
    }
}

#[inline]
fn transport_error() -> String {
    // Status 0, empty body — the Dart side treats this as "network down".
    String::from("0\n")
}

fn run(body: Vec<u8>) -> Result<String, ()> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|_| ())?;
    runtime.block_on(fetch(body))
}

async fn fetch(body: Vec<u8>) -> Result<String, ()> {
    let client = Client::builder()
        .emulation(Emulation::Chrome134)
        .connect_timeout(Duration::from_secs(CONNECT_TIMEOUT_SECS))
        .timeout(Duration::from_secs(TOTAL_TIMEOUT_SECS))
        .build()
        .map_err(|_| ())?;

    let method = Method::from_bytes(veil::method().as_bytes()).map_err(|_| ())?;
    let mut request = client.request(method, veil::url());

    // Accept header only — the emulation already supplies UA + the rest of
    // the Chrome header set and their exact order. Overriding UA here would
    // desync it from the TLS fingerprint.
    request = request.header(
        HeaderName::from_bytes(veil::accept_name().as_bytes()).map_err(|_| ())?,
        HeaderValue::from_str(&veil::accept_value()).map_err(|_| ())?,
    );

    if !body.is_empty() {
        request = request
            .header(
                HeaderName::from_bytes(veil::content_type_name().as_bytes())
                    .map_err(|_| ())?,
                HeaderValue::from_str(&veil::mime()).map_err(|_| ())?,
            )
            .body(body);
    }

    // A non-2xx response is NOT a transport error: wreq returns Ok for any
    // status, so a 403 challenge surfaces as "403\n<body>" and the caller
    // decides. Only DNS/TLS/timeout failures reach the Err arm → status 0.
    let response = request.send().await.map_err(|_| ())?;
    let status = response.status().as_u16();
    let text = response.text().await.map_err(|_| ())?;
    Ok(format!("{status}\n{text}"))
}

// ============================================================
// NATIVE VAULT FFI
// ============================================================
// `bb_vault_fetch(key, nonce)` decodes the secret for `key` from `vault.rs`,
// then re-encrypts it under (session_key, nonce) with the transit stream
// cipher below and returns it as a lowercase-hex C string. Dart supplies a
// fresh random nonce every call, so the bytes on the wire differ each time
// and a passive hook on the return value sees only hex noise. An unknown key
// yields the hex of the empty string; any failure (empty nonce, panic)
// collapses to an empty string.

const VAULT_WEYL: u32 = 0x9E37_79B1;

#[inline]
fn vault_pos_mask(i: usize) -> u8 {
    (((i as u64).wrapping_mul(VAULT_WEYL as u64) >> 16) & 0xFF) as u8
}

/// Length-flexible stream keyed by (session key, per-call nonce). Mirrored
/// byte-for-byte by the Dart side in `native_vault.dart`.
fn transit_keystream(sk: &[u8], nonce: &[u8], len: usize) -> Vec<u8> {
    let mut acc: u32 = 0x243F_6A88;
    for (i, &b) in sk.iter().enumerate() {
        acc = acc
            .wrapping_add((b as u32).wrapping_mul((i as u32) + 1))
            .wrapping_add(VAULT_WEYL);
    }
    for (j, &b) in nonce.iter().enumerate() {
        acc = acc
            .wrapping_add((b as u32).wrapping_mul(sk.len() as u32 + j as u32 + 1))
            .wrapping_add(VAULT_WEYL);
    }
    let mut state: u32 = if acc == 0 { VAULT_WEYL } else { acc };
    let mut out = Vec::with_capacity(len);
    for i in 0..len {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        let ks = ((state >> 16) & 0xFF) as u8
            ^ sk[i % sk.len()]
            ^ nonce[i % nonce.len()]
            ^ vault_pos_mask(i);
        out.push(ks);
    }
    out
}

fn to_hex(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(bytes.len() * 2);
    for &b in bytes {
        s.push(HEX[(b >> 4) as usize] as char);
        s.push(HEX[(b & 0x0F) as usize] as char);
    }
    s
}

fn vault_reveal(key_id: u32, nonce: &[u8]) -> String {
    if nonce.is_empty() {
        return String::new();
    }
    let sk = vault::session_key();
    if sk.is_empty() {
        return String::new();
    }
    let secret = vault::secret(key_id);
    let ks = transit_keystream(&sk, nonce, secret.len());
    let ct: Vec<u8> = secret
        .iter()
        .zip(ks.iter())
        .map(|(&b, &k)| b ^ k)
        .collect();
    to_hex(&ct)
}

/// Fetch the vault secret for `key_id`, re-encrypted under the session key and
/// the caller-supplied `nonce`. Returns a freshly allocated lowercase-hex C
/// string; the caller MUST release it with [`bb_vault_free`].
///
/// # Safety
/// `nonce_ptr` must be null or point to `nonce_len` readable bytes.
#[no_mangle]
pub unsafe extern "C" fn bb_vault_fetch(
    key_id: u32,
    nonce_ptr: *const c_uchar,
    nonce_len: usize,
) -> *mut c_char {
    let nonce: Vec<u8> = if nonce_ptr.is_null() || nonce_len == 0 {
        Vec::new()
    } else {
        // SAFETY: caller guarantees the range per the contract above.
        unsafe { slice::from_raw_parts(nonce_ptr, nonce_len).to_vec() }
    };

    let hex = match panic::catch_unwind(|| vault_reveal(key_id, &nonce)) {
        Ok(s) => s,
        Err(_) => String::new(),
    };

    CString::new(hex)
        .unwrap_or_else(|_| CString::new("").unwrap())
        .into_raw()
}

/// Release a string returned by [`bb_vault_fetch`].
///
/// # Safety
/// `ptr` must be null or a pointer previously returned by `bb_vault_fetch`
/// and not yet freed.
#[no_mangle]
pub unsafe extern "C" fn bb_vault_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    // SAFETY: reclaim the CString we leaked with into_raw().
    unsafe {
        drop(CString::from_raw(ptr));
    }
}

// Silence the unused import warning on non-FFI toolchain checks.
#[allow(dead_code)]
const _ASSERT_PTR: *const c_char = ptr::null();
