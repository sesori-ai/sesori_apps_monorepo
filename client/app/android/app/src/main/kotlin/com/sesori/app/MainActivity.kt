package com.sesori.app

import android.Manifest
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
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

class MainActivity : FlutterActivity(), FlutterUiDisplayListener {
    private var recorderPrewarmService: RecorderPrewarmService? = null
    private var previewMicrophoneResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        recorderPrewarmService = RecorderPrewarmService(
            channel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                RecorderPrewarmService.channelName,
            ),
        )
        // Local feedback playbook only; unavailable in profile and release builds.
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "com.sesori.app/feedback_preview",
            ).setMethodCallHandler { call, result ->
                if (call.method != "requestMicrophoneAccess") {
                    result.notImplemented()
                } else if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                    // True means permission was already granted before this gesture.
                    result.success(true)
                } else if (previewMicrophoneResult != null) {
                    result.error("permission_request_pending", "A microphone permission request is already open.", null)
                } else {
                    previewMicrophoneResult = result
                    requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), PREVIEW_MICROPHONE_REQUEST_CODE)
                }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PREVIEW_MICROPHONE_REQUEST_CODE) return
        val result = previewMicrophoneResult ?: return
        previewMicrophoneResult = null
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        if (
            !granted && grantResults.isNotEmpty() &&
            !shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO)
        ) {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")),
            )
        }
        // Native UI interrupted the gesture; check permission on a fresh gesture.
        result.success(false)
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
        recorderPrewarmService?.dispose()
        recorderPrewarmService = null
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

    private companion object {
        const val PREVIEW_MICROPHONE_REQUEST_CODE = 43019
    }
}
