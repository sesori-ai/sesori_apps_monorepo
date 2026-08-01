package com.sesori.app

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

internal class RecorderPrewarmService(private val channel: MethodChannel) {
    companion object {
        const val channelName = "com.sesori.app/recorder-prewarm"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "prewarm") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val sampleRate = call.argument<Int>("sampleRate")
            val bitRate = call.argument<Int>("bitRate")
            val numChannels = call.argument<Int>("numChannels")
            if (
                sampleRate == null || sampleRate <= 0 ||
                bitRate == null || bitRate <= 0 ||
                numChannels == null || numChannels !in 1..2
            ) {
                result.error(
                    "recorder_prewarm_invalid_arguments",
                    "Invalid recorder prewarm configuration",
                    null,
                )
                return@setMethodCallHandler
            }

            thread(name = "RecorderResourcePrewarm") {
                try {
                    prewarmAudioResources(
                        sampleRate = sampleRate,
                        bitRate = bitRate,
                        numChannels = numChannels,
                    )
                    mainHandler.post { result.success(null) }
                } catch (error: Exception) {
                    mainHandler.post {
                        result.error(
                            "recorder_prewarm_failed",
                            error.message,
                            null,
                        )
                    }
                }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    @SuppressLint("MissingPermission")
    private fun prewarmAudioResources(
        sampleRate: Int,
        bitRate: Int,
        numChannels: Int,
    ) {
        val format = MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_AAC,
            sampleRate,
            numChannels,
        ).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            setInteger(
                MediaFormat.KEY_AAC_PROFILE,
                MediaCodecInfo.CodecProfileLevel.AACObjectLC,
            )
        }
        val codecName = checkNotNull(
            MediaCodecList(MediaCodecList.REGULAR_CODECS).findEncoderForFormat(format),
        ) { "No AAC encoder available" }
        val codec = MediaCodec.createByCodecName(codecName)
        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            codec.stop()
        } finally {
            codec.release()
        }

        val channelConfig = if (numChannels == 1) {
            AudioFormat.CHANNEL_IN_MONO
        } else {
            AudioFormat.CHANNEL_IN_STEREO
        }
        val minimumBufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            channelConfig,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        check(minimumBufferSize > 0) { "Unsupported audio input configuration" }

        val recorder = AudioRecord(
            MediaRecorder.AudioSource.DEFAULT,
            sampleRate,
            channelConfig,
            AudioFormat.ENCODING_PCM_16BIT,
            minimumBufferSize * 2,
        )
        try {
            check(recorder.state == AudioRecord.STATE_INITIALIZED) {
                "AudioRecord failed to initialize"
            }
        } finally {
            recorder.release()
        }
    }
}
