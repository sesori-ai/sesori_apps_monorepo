package com.sesori.app

import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

private const val CLIPBOARD_CHANNEL = "sesori/clipboard"

/** Longest edge (px) kept when re-encoding a pasted clipboard image, mirroring the picker. */
private const val MAX_IMAGE_EDGE = 2048

class MainActivity : FlutterActivity(), FlutterUiDisplayListener {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLIPBOARD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readImage" -> readImageAsync(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Resolves the clipboard image off the UI thread. The clip URI is captured on
     * the calling (main) thread, then decode + JPEG re-encode run on a worker so a
     * large pasted image never blocks the UI thread (dropped frames / ANR). The
     * result is delivered back on the UI thread, as [MethodChannel.Result] requires.
     */
    private fun readImageAsync(result: MethodChannel.Result) {
        val uri = currentClipboardImageUri()
        if (uri == null) {
            result.success(null)
            return
        }
        Thread {
            // Catch Throwable, not just Exception, so a decode OutOfMemoryError
            // degrades to an empty paste instead of crashing the app.
            val payload = try {
                decodeClipboardImage(uri)
            } catch (_: Throwable) {
                null
            }
            runOnUiThread { result.success(payload) }
        }.start()
    }

    /**
     * The content URI of the current clipboard image, or null. Android exposes
     * clipboard images as content URIs (there is no raw-bitmap clipboard API), so
     * a clip without a URI — uncommon — reads as empty.
     */
    private fun currentClipboardImageUri(): Uri? {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return null
        val clip = clipboard.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        return clip.getItemAt(0).uri
    }

    /**
     * Decodes the image at [uri] and re-encodes it as downscaled JPEG
     * (`{bytes, mimeType, filename}`). A bounds-only first pass + `inSampleSize`
     * keeps a huge source from ever being fully decoded into memory.
     */
    private fun decodeClipboardImage(uri: Uri): Map<String, Any>? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSizeFor(bounds.outWidth, bounds.outHeight, MAX_IMAGE_EDGE)
        }
        val decoded = contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        } ?: return null

        val resized = downscale(decoded, MAX_IMAGE_EDGE)
        val output = ByteArrayOutputStream()
        resized.compress(Bitmap.CompressFormat.JPEG, 85, output)
        return mapOf(
            "bytes" to output.toByteArray(),
            "mimeType" to "image/jpeg",
            "filename" to "clipboard.jpg",
        )
    }

    /** Largest power-of-two subsample that keeps the longest edge >= [maxEdge]. */
    private fun sampleSizeFor(width: Int, height: Int, maxEdge: Int): Int {
        var sample = 1
        var longest = maxOf(width, height)
        while (longest / 2 >= maxEdge) {
            longest /= 2
            sample *= 2
        }
        return sample
    }

    private fun downscale(bitmap: Bitmap, maxEdge: Int): Bitmap {
        val longest = maxOf(bitmap.width, bitmap.height)
        if (longest <= maxEdge || longest == 0) return bitmap
        val scale = maxEdge.toFloat() / longest
        return Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * scale).toInt(),
            (bitmap.height * scale).toInt(),
            true,
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        applyEdgeToEdge()
        installSplashScreen()
        super.onCreate(savedInstanceState)

        flutterEngine?.renderer?.addIsDisplayingFlutterUiListener(this)

        if (Build.VERSION.SDK_INT >= 31) {
            val rootLayout: FrameLayout = findViewById(android.R.id.content)
            rootLayout.setBackgroundColor(resources.getColor(R.color.splash_screen_background, null))

            View.inflate(this, R.layout.main_activity, rootLayout)
        }
    }

    override fun onDestroy() {
        flutterEngine?.renderer?.removeIsDisplayingFlutterUiListener(this)
        super.onDestroy()
    }

    override fun onFlutterUiDisplayed() {
        if (Build.VERSION.SDK_INT >= 31) {
            hideSplashOverlay()
        }
    }

    override fun onFlutterUiNoLongerDisplayed() {
    }

    private fun hideSplashOverlay() {
        val splashContainer: ViewGroup? = findViewById(R.id.container)
        splashContainer?.visibility = View.GONE
    }

    private fun applyEdgeToEdge() {
        if (Build.VERSION.SDK_INT < 30) {
            return
        }

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        if (Build.VERSION.SDK_INT >= 35) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION)
        } else if (Build.VERSION.SDK_INT in 31..34 && usesGestureNavigation()) {
            val systemUiVisibility = window.decorView.systemUiVisibility
            window.decorView.systemUiVisibility =
                systemUiVisibility or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        } else if (Build.VERSION.SDK_INT == 30) {
            window.addFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION)
        }
    }

    private fun getNavigationMode(): Int? {
        return try {
            Settings.Secure.getInt(contentResolver, "navigation_mode")
        } catch (_: Settings.SettingNotFoundException) {
            null
        }
    }

    private fun usesGestureNavigation(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return false
        }
        return getNavigationMode() == 2
    }
}
