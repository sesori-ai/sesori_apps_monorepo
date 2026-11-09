package com.sesori.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.io.InputStream
import kotlin.concurrent.thread

/**
 * Opens the system document picker for any files, several at once, for the
 * composer's `pick` call, and copies each pick into `cacheDir/composer-picks/`
 * for shared core to read. Each pick clears the copies of the one before.
 *
 * It answers `{paths, oversizedCount}`, or `null` when the user dismisses the
 * picker. A file over the call's `maxBytes` is never copied: see
 * [copyPickedDocuments].
 */
internal class DocumentPickerService(private val activity: Activity, private val channel: MethodChannel) {
    companion object {
        const val channelName = "com.sesori.app/document-picker"
        private const val pickRequestCode = 0x5e5f
    }

    private class PendingPick(val result: MethodChannel.Result, val maxBytes: Long)

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pending: PendingPick? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "pick") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val maxBytes = call.argument<Number>("maxBytes")?.toLong()
            if (maxBytes == null || maxBytes <= 0) {
                result.error("document_picker_invalid_arguments", "Invalid document picker size limit", null)
                return@setMethodCallHandler
            }
            if (pending != null) {
                result.error("document_picker_busy", "A document pick is already open", null)
                return@setMethodCallHandler
            }
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
            pending = PendingPick(result = result, maxBytes = maxBytes)
            try {
                activity.startActivityForResult(intent, pickRequestCode)
            } catch (error: ActivityNotFoundException) {
                pending = null
                result.error("document_picker_unavailable", error.message, null)
            }
        }
    }

    /** Handles the picker's result; returns whether [requestCode] was this service's pick. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != pickRequestCode) return false
        val pick = pending ?: return true
        pending = null
        val uris = if (resultCode == Activity.RESULT_OK && data != null) pickedUris(data) else emptyList()
        if (uris.isEmpty()) {
            pick.result.success(null)
            return true
        }
        val root = File(activity.cacheDir, "composer-picks")
        thread(name = "composer-document-copy") {
            val copied = try {
                Result.success(copyPickedDocuments(documents = uris.map(::describe), root = root, maxBytes = pick.maxBytes))
            } catch (error: Exception) {
                Result.failure(error)
            }
            mainHandler.post {
                copied.fold(
                    onSuccess = { pick.result.success(mapOf("paths" to it.paths, "oversizedCount" to it.oversizedCount)) },
                    onFailure = { pick.result.error("document_picker_copy_failed", it.toString(), null) },
                )
            }
        }
        return true
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun pickedUris(data: Intent): List<Uri> {
        val clipData = data.clipData ?: return listOfNotNull(data.data)
        return (0 until clipData.itemCount).mapNotNull { clipData.getItemAt(it).uri }
    }

    /** Reads the name and size the provider reports, without opening the file. */
    private fun describe(uri: Uri): PickedDocument {
        var name: String? = null
        var size: Long? = null
        activity.contentResolver
            .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) return@use
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameIndex >= 0 && !cursor.isNull(nameIndex)) name = cursor.getString(nameIndex)
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
            }
        return PickedDocument(
            displayName = name,
            size = size,
            open = { activity.contentResolver.openInputStream(uri) ?: throw IOException("No content for $uri") },
        )
    }
}

/** A picked file as its provider describes it; [size] is null when the provider doesn't know it. */
internal class PickedDocument(val displayName: String?, val size: Long?, val open: () -> InputStream)

internal class CopiedDocuments(val paths: List<String>, val oversizedCount: Int)

/**
 * Clears [root], then copies each document into its own folder under it, so
 * two picks with one name don't collide.
 *
 * A document whose reported size is over [maxBytes] is counted as oversized
 * and never opened, so a large video isn't copied just to be turned away. One
 * of unknown size is copied until it passes [maxBytes], then dropped and
 * counted the same way.
 */
internal fun copyPickedDocuments(documents: List<PickedDocument>, root: File, maxBytes: Long): CopiedDocuments {
    root.deleteRecursively()
    val paths = mutableListOf<String>()
    var oversizedCount = 0
    documents.forEachIndexed { index, document ->
        val size = document.size
        if (size != null && size > maxBytes) {
            oversizedCount++
            return@forEachIndexed
        }
        val folder = File(root, index.toString())
        if (!folder.mkdirs()) throw IOException("Could not create $folder")
        val target = File(folder, safeFileName(displayName = document.displayName))
        if (copyAtMost(source = document.open, target = target, maxBytes = maxBytes)) {
            paths.add(target.path)
        } else {
            target.delete()
            oversizedCount++
        }
    }
    return CopiedDocuments(paths = paths, oversizedCount = oversizedCount)
}

/** The display name's last segment, or `file` when the provider gives none. */
internal fun safeFileName(displayName: String?): String {
    val name = displayName?.substringAfterLast('/')?.trim()
    return if (name.isNullOrEmpty() || name == "." || name == "..") "file" else name
}

/** Copies [source] into [target]; returns false, leaving a partial copy, once it passes [maxBytes]. */
private fun copyAtMost(source: () -> InputStream, target: File, maxBytes: Long): Boolean {
    source().use { input ->
        target.outputStream().use { output ->
            val buffer = ByteArray(64 * 1024)
            var copied = 0L
            while (true) {
                val read = input.read(buffer)
                if (read < 0) return true
                copied += read
                if (copied > maxBytes) return false
                output.write(buffer, 0, read)
            }
        }
    }
}
