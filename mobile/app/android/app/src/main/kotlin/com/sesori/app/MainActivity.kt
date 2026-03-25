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
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener

class MainActivity : FlutterActivity(), FlutterUiDisplayListener {

    override fun onCreate(savedInstanceState: Bundle?) {
        applyEdgeToEdge()
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)

        flutterEngine?.renderer?.addIsDisplayingFlutterUiListener(this)

        if (Build.VERSION.SDK_INT >= 31) {
            val rootLayout: FrameLayout = findViewById(android.R.id.content)
            rootLayout.setBackgroundColor(resources.getColor(R.color.splash_screen_background, null))

            View.inflate(this, R.layout.main_activity, rootLayout)

            splashScreen.setOnExitAnimationListener { splashScreenViewProvider ->
                splashScreenViewProvider.remove()
                hideSplashOverlay()
            }
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
