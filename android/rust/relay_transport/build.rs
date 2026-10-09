use std::env;

// ============================================================
// build.rs — Android BoringSSL link ordering
// ============================================================
// btls-sys builds libssl.a + libcrypto.a and emits the -L search path.
// libssl references symbols that live in libcrypto (and vice-versa), so a
// single pass can leave undefined SSL_/X509_/EVP_ symbols depending on
// archive order. Wrap both in a linker group so the cross-references
// resolve regardless of order.
//
// Do NOT set CC_<target>/CXX_<target> in the build environment: that makes
// btls compile libssl.a for the HOST (COFF x86-64 on Windows), the Android
// linker silently drops those objects, and the .so ends up without SSL_*
// (dlopen: "cannot locate symbol SSL_CTX_free"). The NDK's
// android.toolchain.cmake must pick the compiler; keep only the NDK bin on
// PATH. CFLAGS_/CXXFLAGS_/BINDGEN_EXTRA_CLANG_ARGS_ are safe — cc/bindgen
// read them, btls ignores them.
fn main() {
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os == "android" {
        println!("cargo:rustc-link-arg=-Wl,--start-group");
        println!("cargo:rustc-link-arg=-lssl");
        println!("cargo:rustc-link-arg=-lcrypto");
        println!("cargo:rustc-link-arg=-Wl,--end-group");
    }
}
