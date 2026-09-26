package com.sesori.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// The debug source set keeps preview APIs and their dependency out of other builds.
class FeedbackPreviewActivity : MainActivity() {
    private var previewMicrophoneResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sesori.app/feedback_preview",
        ).setMethodCallHandler { call, result ->
            if (call.method == "requestReview") {
                requestPreviewReview(result = result)
            } else if (call.method != "requestMicrophoneAccess") {
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

    private fun requestPreviewReview(result: MethodChannel.Result) {
        val manager = ReviewManagerFactory.create(this)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (!request.isSuccessful) {
                result.error(
                    "review_request_failed",
                    "Google Play could not prepare the review flow.",
                    request.exception?.stackTraceToString(),
                )
                return@addOnCompleteListener
            }
            manager.launchReviewFlow(this, request.result).addOnCompleteListener { flow ->
                if (flow.isSuccessful) {
                    // Completion does not report whether a prompt appeared or a rating was sent.
                    result.success(null)
                } else {
                    result.error(
                        "review_launch_failed",
                        "Google Play could not open the review flow.",
                        flow.exception?.stackTraceToString(),
                    )
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

    private companion object {
        const val PREVIEW_MICROPHONE_REQUEST_CODE = 43019
    }
}
