package com.sesori.app

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The on-device speech channel. Android below 13 can't feed its recognizer audio
 * we capture ourselves, so it answers that it can't run and stays on the server.
 * Everything here runs on the main thread, which `SpeechRecognizer` requires.
 */
internal class OnDeviceSpeechService(
    private val context: Context,
    private val channel: MethodChannel,
) {
    companion object {
        const val channelName = "com.sesori.app/on-device-speech"

        // Not every recognizer reports readiness, and a dictation's audio waits on
        // this answer, so it can't wait long. A rejection normally comes well before.
        private const val START_WAIT_MILLIS = 1000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var session: Session? = null
    private var modelRequested = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                if (call.method == "prepare") result.success(false) else result.notImplemented()
            } else {
                handle(call, result)
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        session?.cancel()
        session = null
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<Int>("sessionId")
        val current = session?.takeIf { it.id == sessionId }
        when (call.method) {
            "prepare" -> prepare(result)
            "start" -> {
                val sampleRate = call.argument<Int>("sampleRate")
                if (sessionId == null || sampleRate == null) {
                    result.error("bad_arguments", null, null)
                    return
                }
                session?.cancel()
                session = null
                val started = try {
                    Session(id = sessionId, sampleRate = sampleRate)
                } catch (error: Exception) {
                    result.error("start_failed", error.toString(), null)
                    return
                }
                session = started
                started.start(result)
            }
            "sendAudio" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("bad_arguments", null, null)
                    return
                }
                current?.append(bytes)
                result.success(null)
            }
            "finish" -> {
                current?.finish()
                result.success(null)
            }
            "cancel" -> {
                current?.cancel()
                if (current != null) session = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * True when the device has an on-device recognizer, whatever its language. A
     * recognizer that can't serve a dictation rejects it, which falls back to the server.
     */
    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun prepare(result: MethodChannel.Result) {
        result.success(SpeechRecognizer.isOnDeviceRecognitionAvailable(context))
    }

    private fun recognitionIntent(): Intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    }

    /**
     * One dictation. Its audio goes through a pipe, and a segmented session keeps
     * listening through silence until that pipe closes.
     */
    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private inner class Session(val id: Int, private val sampleRate: Int) : RecognitionListener {
        private val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        private val writer: ExecutorService = Executors.newSingleThreadExecutor()
        private val pipe = ParcelFileDescriptor.createPipe()
        private val readSide: ParcelFileDescriptor = pipe[0]
        private val output = ParcelFileDescriptor.AutoCloseOutputStream(pipe[1])
        private val startWait = Runnable { answerStart() }
        private var pendingStart: MethodChannel.Result? = null
        private var ended = false

        /**
         * Answers once the recognizer is ready or [START_WAIT_MILLIS] has passed. A
         * rejection before then answers with an error, so the dictation can fall back.
         */
        fun start(result: MethodChannel.Result) {
            pendingStart = result
            try {
                recognizer.setRecognitionListener(this)
                recognizer.startListening(
                    recognitionIntent().apply {
                        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, readSide)
                        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, sampleRate)
                        putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE)
                    },
                )
                mainHandler.postDelayed(startWait, START_WAIT_MILLIS)
            } catch (error: RuntimeException) {
                rejectStart(error.toString())
            }
        }

        private fun answerStart() {
            mainHandler.removeCallbacks(startWait)
            pendingStart?.success(null)
            pendingStart = null
        }

        private fun rejectStart(reason: String) {
            mainHandler.removeCallbacks(startWait)
            pendingStart?.error("start_failed", reason, null)
            pendingStart = null
            ended = true
            release()
            if (session === this) session = null
        }

        fun append(bytes: ByteArray) {
            if (ended) return
            writer.execute {
                try {
                    output.write(bytes)
                } catch (error: IOException) {
                    mainHandler.post { fail("write failed: $error") }
                }
            }
        }

        fun finish() {
            if (ended) return
            writer.execute {
                try {
                    output.close()
                } catch (error: IOException) {
                    mainHandler.post { fail("close failed: $error") }
                }
            }
        }

        fun cancel() {
            if (ended) return
            answerStart()
            ended = true
            recognizer.cancel()
            release()
        }

        override fun onPartialResults(results: Bundle) {
            emitWords(confirmed = "", provisional = firstResult(results))
        }

        override fun onSegmentResults(results: Bundle) {
            emitWords(confirmed = firstResult(results), provisional = "")
        }

        override fun onEndOfSegmentedSession() = complete()

        /** A recognizer that doesn't segment ends here instead. */
        override fun onResults(results: Bundle) {
            emitWords(confirmed = firstResult(results), provisional = "")
            complete()
        }

        override fun onError(error: Int) {
            Log.i("OnDeviceSpeechService", "Recognizer error $error")
            if (error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE && !modelRequested) {
                // Goes through this recognizer because it is already connected to its service.
                modelRequested = true
                recognizer.triggerModelDownload(recognitionIntent())
            }
            if (pendingStart != null) {
                rejectStart("recognizer error $error")
                return
            }
            // Audio with no words in it, which the composer reports as an empty transcript.
            if (error == SpeechRecognizer.ERROR_NO_MATCH) complete() else fail("recognizer error $error")
        }

        override fun onReadyForSpeech(params: Bundle) = answerStart()

        override fun onBeginningOfSpeech() = Unit

        override fun onRmsChanged(rmsdB: Float) = Unit

        override fun onBufferReceived(buffer: ByteArray) = Unit

        override fun onEndOfSpeech() = Unit

        override fun onEvent(eventType: Int, params: Bundle) = Unit

        private fun firstResult(results: Bundle): String =
            results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()

        private fun emitWords(confirmed: String, provisional: String) {
            if (ended) return
            emit(mapOf("type" to "words", "confirmedDelta" to confirmed, "provisional" to provisional))
        }

        private fun complete() = endWith(mapOf("type" to "completed"))

        private fun fail(reason: String) = endWith(mapOf("type" to "failed", "reason" to reason))

        private fun endWith(event: Map<String, Any>) {
            if (ended) return
            emit(event)
            ended = true
            release()
            if (session === this) session = null
        }

        private fun emit(event: Map<String, Any>) {
            channel.invokeMethod("event", event + ("sessionId" to id))
        }

        private fun release() {
            // Android 13 only queues a model request, and crashes on it if destroyed first.
            mainHandler.post { recognizer.destroy() }
            writer.execute {
                try {
                    output.close()
                } catch (error: IOException) {
                    Log.w("OnDeviceSpeechService", "Could not close the audio pipe", error)
                }
            }
            writer.shutdown()
            readSide.close()
        }
    }
}
