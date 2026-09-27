package com.shakedash.beercount

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.text.SimpleDateFormat
import java.time.LocalDate
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
    private const val KEY_WEEK = "week_key"
    private const val KEY_WEEK_COUNT = "week_count"
    private const val KEY_WEEK_GOAL = "week_goal"
    private const val KEY_WEEK_START = "week_start"

    /** Dart's `DateTime.sunday`. Both sides number weekdays ISO style. */
    private const val SUNDAY = 7

    data class Summary(
        val dayKey: String,
        val count: Int,
        val ml: Int,
        val weekCount: Int = 0,
        val goal: Int = 0,
    ) {
        val goalReached: Boolean get() = goal > 0 && weekCount >= goal
    }

    private val lock = Any()

    fun todayKey(now: Long = System.currentTimeMillis()): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(now))

    /**
     * Mirrors `weekStartOf` in lib/stats/buckets.dart. [weekStart] and
     * `dayOfWeek.value` are both ISO: Monday 1 .. Sunday 7.
     */
    fun weekKey(today: LocalDate, weekStart: Int): String {
        val delta = Math.floorMod(today.dayOfWeek.value - weekStart, 7)
        return today.minusDays(delta.toLong()).toString()
    }

    /**
     * Reads the cached counters, resetting the day and the week
     * independently when either has rolled over.
     */
    fun summary(context: Context): Summary = synchronized(lock) {
        val today = todayKey()
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val sameDay = readString(prefs, KEY_DAY) == today
        val sameWeek = readString(prefs, KEY_WEEK) == currentWeekKey(prefs)
        Summary(
            dayKey = today,
            count = if (sameDay) readInt(prefs, KEY_COUNT) else 0,
            ml = if (sameDay) readInt(prefs, KEY_ML) else 0,
            weekCount = if (sameWeek) readInt(prefs, KEY_WEEK_COUNT) else 0,
            goal = readInt(prefs, KEY_WEEK_GOAL),
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
        val next = current.copy(
            count = current.count + 1,
            ml = current.ml + ml,
            weekCount = current.weekCount + 1,
        )
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_DAY, next.dayKey)
            .putString(KEY_COUNT, next.count.toString())
            .putString(KEY_ML, next.ml.toString())
            .putString(KEY_WEEK, currentWeekKey(prefs))
            .putString(KEY_WEEK_COUNT, next.weekCount.toString())
            .apply()
        next
    }

    private fun currentWeekKey(prefs: SharedPreferences): String {
        val start = readString(prefs, KEY_WEEK_START)?.toIntOrNull()
            ?.takeIf { it in 1..7 } ?: SUNDAY
        return weekKey(LocalDate.now(), start)
    }

    private fun readInt(prefs: SharedPreferences, key: String): Int =
        readString(prefs, key)?.toIntOrNull() ?: 0

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
