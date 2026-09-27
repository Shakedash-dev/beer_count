package com.shakedash.beercount

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Saves and opens backups through the system file dialogs (Storage Access
 * Framework), so the app needs no storage permission. One dialog at a time:
 * the Dart side awaits every call. Mirrors lib/data/document_files.dart.
 */
class DocumentFiles(private val activity: Activity) {
    private var pending: MethodChannel.Result? = null
    private var pendingContents: String? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "A file dialog is already open", null)
            return
        }
        when (call.method) {
            "save" -> {
                val contents = call.argument<String>("contents")
                if (contents == null) {
                    result.error("bad_args", "contents is required", null)
                    return
                }
                pendingContents = contents
                start(
                    result,
                    SAVE_REQUEST,
                    Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("application/json")
                        .putExtra(
                            Intent.EXTRA_TITLE,
                            call.argument<String>("name") ?: "beer_count.json",
                        ),
                )
            }
            // "*/*" because Drive and some file managers label .json files
            // as octet-stream, which would hide them behind a JSON filter.
            "open" -> start(
                result,
                OPEN_REQUEST,
                Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("*/*"),
            )
            else -> result.notImplemented()
        }
    }

    /** Returns true when [requestCode] belongs to this class. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SAVE_REQUEST && requestCode != OPEN_REQUEST) return false
        val result = pending ?: return true
        val contents = pendingContents
        pending = null
        pendingContents = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == SAVE_REQUEST) false else null)
            return true
        }

        // Off the main thread: the picked file may live on Drive.
        Thread {
            try {
                val resolver = activity.contentResolver
                val value: Any = if (requestCode == SAVE_REQUEST) {
                    val out = resolver.openOutputStream(uri, "wt")
                        ?: error("cannot write $uri")
                    out.use { it.write(contents!!.toByteArray(Charsets.UTF_8)) }
                    true
                } else {
                    val input = resolver.openInputStream(uri)
                        ?: error("cannot read $uri")
                    val bytes = input.use { it.readBytes() }
                    require(bytes.size <= MAX_BYTES) { "file is too large" }
                    bytes.toString(Charsets.UTF_8)
                }
                activity.runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("io", e.message, null) }
            }
        }.start()
        return true
    }

    private fun start(result: MethodChannel.Result, requestCode: Int, intent: Intent) {
        pending = result
        try {
            activity.startActivityForResult(intent, requestCode)
        } catch (e: ActivityNotFoundException) {
            pending = null
            pendingContents = null
            result.error("no_picker", "No file picker on this device", null)
        }
    }

    companion object {
        const val CHANNEL = "com.shakedash.beercount/files"
        private const val SAVE_REQUEST = 0xBEE1
        private const val OPEN_REQUEST = 0xBEE2

        /** Years of beers are well under 1 MB. Anything bigger is not ours. */
        private const val MAX_BYTES = 16 * 1024 * 1024
    }
}
