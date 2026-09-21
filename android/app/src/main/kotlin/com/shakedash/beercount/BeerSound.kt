package com.shakedash.beercount

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer

/**
 * The "beer logged" sound, shared by the app and the home-screen widget.
 *
 * Clips are `res/raw/beer_sound_1..N`, produced by `tool/convert_sounds.py`.
 * Each play takes the next clip and advances a cursor stored in the same
 * preferences file as the widget counter, so a tap in the app and a tap on
 * the widget continue one rotation. Silent and vibrate modes play nothing.
 */
object BeerSound {
    const val CHANNEL = "com.shakedash.beercount/sound"

    private const val PREFS = "HomeWidgetPreferences"
    private const val KEY_NEXT = "sound_next"
    private const val PREFIX = "beer_sound_"

    private val lock = Any()
    private var clips: IntArray? = null

    /** Held so a playing clip is not garbage collected mid-sound. */
    private val playing = mutableSetOf<MediaPlayer>()

    /**
     * Plays the next clip in the rotation. [onDone] runs exactly once, when
     * the clip ends or immediately if nothing plays. Never throws.
     */
    fun play(context: Context, onDone: () -> Unit = {}) {
        val resId = try {
            if (isMuted(context)) null else advance(context)
        } catch (t: Throwable) {
            null
        }
        if (resId == null) {
            onDone()
            return
        }

        var finished = false
        fun finish(player: MediaPlayer) {
            synchronized(lock) {
                if (finished) return
                finished = true
                playing.remove(player)
            }
            player.release()
            onDone()
        }

        val player = MediaPlayer()
        try {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            context.resources.openRawResourceFd(resId).use {
                player.setDataSource(it.fileDescriptor, it.startOffset, it.length)
            }
            player.setOnCompletionListener { finish(it) }
            player.setOnErrorListener { mp, _, _ -> finish(mp); true }
            player.prepare()
            synchronized(lock) { playing.add(player) }
            player.start()
        } catch (t: Throwable) {
            finish(player)
        }
    }

    /** Returns the clip to play now and moves the cursor to the one after. */
    private fun advance(context: Context): Int? = synchronized(lock) {
        val all = clips(context)
        if (all.isEmpty()) return null
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val index = Math.floorMod(readIndex(prefs), all.size)
        prefs.edit()
            .putString(KEY_NEXT, ((index + 1) % all.size).toString())
            .apply()
        all[index]
    }

    /**
     * Discovers beer_sound_1, beer_sound_2, ... until the first gap, so
     * adding a clip is only a re-run of the converter.
     */
    @SuppressLint("DiscouragedApi")
    private fun clips(context: Context): IntArray {
        clips?.let { return it }
        val found = mutableListOf<Int>()
        while (true) {
            val id = context.resources.getIdentifier(
                PREFIX + (found.size + 1),
                "raw",
                context.packageName,
            )
            if (id == 0) break
            found.add(id)
        }
        return found.toIntArray().also { clips = it }
    }

    private fun isMuted(context: Context): Boolean {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return false
        return audio.ringerMode != AudioManager.RINGER_MODE_NORMAL
    }

    /** Stored as a String, like every other value in this preferences file. */
    private fun readIndex(prefs: SharedPreferences): Int = try {
        prefs.getString(KEY_NEXT, null)?.toIntOrNull() ?: 0
    } catch (e: ClassCastException) {
        0
    }
}
