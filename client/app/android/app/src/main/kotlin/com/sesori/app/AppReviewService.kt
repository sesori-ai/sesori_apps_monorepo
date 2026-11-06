package com.sesori.app

import android.app.Activity
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.plugin.common.MethodChannel

/**
 * Shows Google Play's In-App Review card for the `requestReview` call.
 *
 * Play decides under its own quota whether the card appears and never says,
 * so a completed flow succeeds either way. A build without Google Play, such
 * as a sideloaded one or a device without Play services, fails the request.
 */
internal class AppReviewService(private val activity: Activity, private val channel: MethodChannel) {
    companion object {
        const val channelName = "com.sesori.app/app_review"
    }

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "requestReview") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val manager = ReviewManagerFactory.create(activity)
            manager.requestReviewFlow().addOnCompleteListener { request ->
                if (!request.isSuccessful) {
                    result.error("review_unavailable", request.exception?.message, null)
                    return@addOnCompleteListener
                }
                manager.launchReviewFlow(activity, request.result).addOnCompleteListener { result.success(null) }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
