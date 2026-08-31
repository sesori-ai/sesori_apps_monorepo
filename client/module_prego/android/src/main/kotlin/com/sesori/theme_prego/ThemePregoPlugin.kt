package com.sesori.theme_prego

import android.content.Context
import android.content.res.ColorStateList
import android.view.View
import android.widget.ProgressBar
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ThemePregoPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            NativeActivityIndicatorPlatformViewFactory.VIEW_TYPE,
            NativeActivityIndicatorPlatformViewFactory(),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}

private class NativeActivityIndicatorPlatformViewFactory :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    companion object {
        const val VIEW_TYPE = "sesori/native-activity-indicator"
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val argb = args as? Number
            ?: error("Invalid native activity indicator creation arguments")
        return NativeActivityIndicatorPlatformView(
            context = context,
            color = argb.toLong().toInt(),
        )
    }
}

private class NativeActivityIndicatorPlatformView(context: Context, color: Int) : PlatformView {
    // The default ProgressBar style is the indeterminate circular spinner; its
    // AnimatedVectorDrawable animates on RenderThread, outside Flutter's frame
    // pipeline. The Flutter widget owns semantics, so the view is hidden from
    // accessibility like its iOS counterpart.
    private val indicator = ProgressBar(context).apply {
        indeterminateTintList = ColorStateList.valueOf(color)
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
    }

    override fun getView(): View = indicator

    override fun dispose() {}
}
