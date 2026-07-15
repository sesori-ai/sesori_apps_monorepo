package com.sesori.app

import android.content.Context
import android.content.res.ColorStateList
import android.view.View
import android.widget.ProgressBar
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NativeActivityIndicatorPlatformViewFactory :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val color = requireNotNull(args as? Number) {
            "Invalid native activity indicator creation arguments"
        }
        val indicator = ProgressBar(
            context,
            null,
            android.R.attr.progressBarStyleSmall
        ).apply {
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            isIndeterminate = true
            indeterminateTintList = ColorStateList.valueOf(color.toInt())
        }
        return NativeActivityIndicatorPlatformView(indicator)
    }

    companion object {
        const val VIEW_TYPE = "sesori/native-activity-indicator"
    }
}

private class NativeActivityIndicatorPlatformView(
    private val indicator: ProgressBar
) : PlatformView {

    override fun getView(): View = indicator

    override fun dispose() {
        indicator.visibility = View.GONE
    }
}
