package com.embervault.blazebound

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — WebView file-upload bridge
// ============================================================
// Dependency-free WebView file upload: the site's <input type="file">
// triggers the WebView's file selector, which hops here over a
// MethodChannel and returns the picked content:// URIs back to the
// WebView. No file_picker dependency (see gray_part_pitfalls.md §1).
// ============================================================
class MainActivity : FlutterActivity() {
    // [FORGE] Keep in sync with lib/relay/stage/portal_stage.dart → MethodChannel('...').
    private val channelName = "ember/pick"
    // Pushes the soft-keyboard (IME) height to Dart. Read from the real
    // WindowInsets so it is correct in landscape too, where Flutter's own
    // viewInsets are unreliable under a fullscreen IME.
    private val imeChannelName = "ember/ime"
    private val pickRequest = 0x7A11
    private var pendingResult: MethodChannel.Result? = null
    private var imeChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pinSoftInput()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        pinSoftInput()
    }

    // Freeze the window under the keyboard on API 30+ (below 30 the manifest's
    // adjustResize keeps working, which is where Flutter still reads the IME
    // inset from). The engine keeps reporting view.viewInsets.bottom either way,
    // so Dart can measure the keyboard while the WebView keeps its full size.
    private fun pinSoftInput() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "pick") {
                    val multiple = call.argument<Boolean>("multiple") ?: false
                    val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    openChooser(multiple, mimes, result)
                } else {
                    result.notImplemented()
                }
            }

        imeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, imeChannelName)
        installImeListener()
    }

    private fun installImeListener() {
        val density = resources.displayMetrics.density
        val root = window.decorView
        root.setOnApplyWindowInsetsListener { v: View, insets: WindowInsets ->
            val imePx: Int = if (Build.VERSION.SDK_INT >= 30) {
                insets.getInsets(WindowInsets.Type.ime()).bottom
            } else {
                @Suppress("DEPRECATION")
                insets.systemWindowInsetBottom
            }
            // Camera cutout only — NOT the nav bar. Keeps the WebView width
            // stable when the nav bar appears together with the keyboard.
            var cutL = 0; var cutT = 0; var cutR = 0; var cutB = 0
            val cutout = insets.displayCutout
            if (cutout != null) {
                cutL = cutout.safeInsetLeft
                cutT = cutout.safeInsetTop
                cutR = cutout.safeInsetRight
                cutB = cutout.safeInsetBottom
            }
            val payload = mapOf(
                "ime" to (imePx / density).toDouble(),
                "cutL" to (cutL / density).toDouble(),
                "cutT" to (cutT / density).toDouble(),
                "cutR" to (cutR / density).toDouble(),
                "cutB" to (cutB / density).toDouble()
            )
            imeChannel?.invokeMethod("insets", payload)
            v.onApplyWindowInsets(insets)
        }
    }

    private fun openChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        // Resolve any abandoned request before starting a new one.
        pendingResult?.success(emptyList<String>())
        pendingResult = result

        val valid = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                valid.isEmpty() -> type = "*/*"
                valid.size == 1 -> type = valid[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, valid.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(intent, null), pickRequest)
        } catch (e: Exception) {
            pendingResult = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return

        val result = pendingResult
        pendingResult = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        result.success(uris)
    }
}
