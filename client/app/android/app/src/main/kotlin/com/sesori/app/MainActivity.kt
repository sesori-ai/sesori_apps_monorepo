package com.sesori.app

import android.graphics.Color
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
    private var firebaseTestLabChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        recorderPrewarmService = RecorderPrewarmService(
            channel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                RecorderPrewarmService.channelName,
            ),
        )
        firebaseTestLabChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FIREBASE_TEST_LAB_CHANNEL_NAME,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isRunning" -> result.success(isRunningInFirebaseTestLab())
                    else -> result.notImplemented()
                }
            }
        }
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
        firebaseTestLabChannel?.setMethodCallHandler(null)
        firebaseTestLabChannel = null
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

    // Firebase documents this flag as `Settings.System` holding the exact string
    // "true", but that read returned false throughout a Play pre-launch report:
    // GA4 recorded 154 single-session installs of an unreleased version, each
    // reporting product events the runtime capability should have suppressed.
    // Google's own guidance describes the flag under instrumented-test behavior,
    // so a Robo crawl may set it elsewhere, differently, or not at all. Read every
    // settings table and accept any value — no real device carries this setting.
    private fun isRunningInFirebaseTestLab(): Boolean =
        Settings.System.getString(contentResolver, FIREBASE_TEST_LAB_SETTING) != null ||
            Settings.Global.getString(contentResolver, FIREBASE_TEST_LAB_SETTING) != null ||
            Settings.Secure.getString(contentResolver, FIREBASE_TEST_LAB_SETTING) != null

    private companion object {
        const val FIREBASE_TEST_LAB_CHANNEL_NAME = "com.sesori.app/firebase-test-lab"
        const val FIREBASE_TEST_LAB_SETTING = "firebase.test.lab"
    }
}
