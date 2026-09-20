package com.shakedash.beercount

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.random.Random

/**
 * The Kotlin half of the shared beer log.
 *
 * Mirrors `lib/data/beer_log_file.dart` and `lib/data/widget_bridge.dart`.
 * Keep the two in step: same file name, same record shape, same preference
 * keys, and every preference value a String.
 *
 * The widget must be able to log a beer without a Flutter engine, so nothing
 * here touches Dart and nothing here parses the whole log.
 */
object BeerLog {
    private const val FILE_NAME = "beer_log.ndjson"
    private const val PREFS = "HomeWidgetPreferences"
    private const val KEY_DAY = "today_key"
    private const val KEY_COUNT = "today_count"
    private const val KEY_ML = "today_ml"

    data class Summary(val dayKey: String, val count: Int, val ml: Int)

    private val lock = Any()

    fun todayKey(now: Long = System.currentTimeMillis()): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(now))

    /** Reads the cached counter, resetting it when the day has rolled over. */
    fun summary(context: Context): Summary = synchronized(lock) {
        val today = todayKey()
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (readString(prefs, KEY_DAY) != today) {
            return Summary(today, 0, 0)
        }
        Summary(
            today,
            readString(prefs, KEY_COUNT)?.toIntOrNull() ?: 0,
            readString(prefs, KEY_ML)?.toIntOrNull() ?: 0,
        )
    }

    /** Appends one record and bumps the cached counter. Constant time. */
    fun append(context: Context, ml: Int): Summary = synchronized(lock) {
        val now = System.currentTimeMillis()
        val id = now.toString() + "-" +
            String.format(Locale.US, "%04x", Random.nextInt(0x10000))
        val line = JSONObject()
            .put("id", id)
            .put("ml", ml)
            .put("at", now)
            .toString()

        val file = File(context.filesDir, FILE_NAME)
        val prefix = if (needsLeadingNewline(file)) "\n" else ""
        file.appendText(prefix + line + "\n")

        val current = summary(context)
        val next = Summary(current.dayKey, current.count + 1, current.ml + ml)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_DAY, next.dayKey)
            .putString(KEY_COUNT, next.count.toString())
            .putString(KEY_ML, next.ml.toString())
            .apply()
        next
    }

    /**
     * Older home_widget versions stored ints as ints. Reading such a key as a
     * String throws, so fall back rather than crash the widget.
     */
    private fun readString(prefs: SharedPreferences, key: String): String? = try {
        prefs.getString(key, null)
    } catch (e: ClassCastException) {
        null
    }

    /** Stops a torn final line from fusing with the next record. */
    private fun needsLeadingNewline(file: File): Boolean {
        if (!file.exists() || file.length() == 0L) return false
        return RandomAccessFile(file, "r").use {
            it.seek(file.length() - 1)
            it.read() != '\n'.code
        }
    }
}
