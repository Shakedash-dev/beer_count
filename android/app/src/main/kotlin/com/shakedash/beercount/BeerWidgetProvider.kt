package com.shakedash.beercount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.widget.RemoteViews
import java.util.Locale

/**
 * One-tap beer logging from the home screen.
 *
 * Deliberately does not start a Flutter engine: a tap appends one line to the
 * shared NDJSON log, bumps a small SharedPreferences counter, and re-renders.
 * The app picks the new entry up when it next resumes.
 *
 * RemoteViews cannot run a real animator, so the "pop" after a tap is a short
 * scripted sequence of widget updates - see [Frame] and [animate].
 */
class BeerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val summary = BeerLog.summary(context)
        val views = buildViews(context, summary, Frame.RESTING, 0)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_LOG) return
        val ml = intent.getIntExtra(EXTRA_ML, 0)
        if (ml <= 0) return

        // A throwing receiver shows a system "isn't responding" dialog.
        // Logging a beer must never do that.
        val summary = try {
            BeerLog.append(context, ml)
        } catch (t: Throwable) {
            try {
                render(context, BeerLog.summary(context), Frame.RESTING, 0)
            } catch (ignored: Throwable) {
                // Nothing left worth trying.
            }
            return
        }

        val pillId = if (ml == ML_HALF) R.id.beer_half else R.id.beer_third
        // Keep the receiver alive until both the animation and the sound end.
        val pending = goAsync()
        var outstanding = 2
        val done = {
            synchronized(pending) {
                outstanding--
                if (outstanding == 0) pending.finish()
            }
        }
        BeerSound.play(context) { done() }
        try {
            animate(context, summary, ml, pillId) { done() }
        } catch (t: Throwable) {
            done()
        }
    }

    /**
     * One step of the tap animation. [countSp] pops the number, [pillLit]
     * fills the tapped pill, and a non-null [subText] flashes the delta over
     * the usual "today - x L" line.
     */
    private data class Frame(
        val delayMs: Long,
        val countSp: Float,
        val pillLit: Boolean,
        val subText: String?,
    ) {
        companion object {
            val RESTING = Frame(0, RESTING_SP, false, null)
        }
    }

    private fun animate(
        context: Context,
        summary: BeerLog.Summary,
        ml: Int,
        pillId: Int,
        onDone: () -> Unit,
    ) {
        val delta = String.format(Locale.US, "+%d ML", ml)
        val frames = listOf(
            Frame(0, 47f, true, delta),
            Frame(110, 39f, true, delta),
            Frame(200, 34f, false, delta),
            Frame(300, RESTING_SP, false, delta),
            Frame(560, RESTING_SP, false, null),
        )

        val handler = Handler(Looper.getMainLooper())
        frames.forEachIndexed { index, frame ->
            handler.postDelayed({
                try {
                    render(context, summary, frame, pillId)
                } catch (ignored: Throwable) {
                    // A dropped frame is not worth crashing the widget host.
                }
                if (index == frames.lastIndex) onDone()
            }, frame.delayMs)
        }
    }

    private fun render(
        context: Context,
        summary: BeerLog.Summary,
        frame: Frame,
        pillId: Int,
    ) {
        AppWidgetManager.getInstance(context).updateAppWidget(
            ComponentName(context, BeerWidgetProvider::class.java),
            buildViews(context, summary, frame, pillId),
        )
    }

    companion object {
        const val ACTION_LOG = "com.shakedash.beercount.LOG"
        const val EXTRA_ML = "ml"

        private const val ML_THIRD = 333
        private const val ML_HALF = 500

        private const val RESTING_SP = 32f
        private const val AMBER = 0xFFE8A33D.toInt()
        private const val INK = 0xFF0B0B0C.toInt()
        private const val DIM = 0xFF8A8780.toInt()

        fun renderAll(context: Context, summary: BeerLog.Summary) {
            AppWidgetManager.getInstance(context).updateAppWidget(
                ComponentName(context, BeerWidgetProvider::class.java),
                buildViews(context, summary, Frame.RESTING, 0),
            )
        }

        private fun buildViews(
            context: Context,
            summary: BeerLog.Summary,
            frame: Frame,
            litPillId: Int,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.beer_widget)
            views.setTextViewText(R.id.beer_count, summary.count.toString())
            views.setTextViewTextSize(
                R.id.beer_count,
                TypedValue.COMPLEX_UNIT_SP,
                frame.countSp,
            )
            views.setTextViewText(
                R.id.beer_sub,
                frame.subText ?: String.format(
                    Locale.US,
                    "today · %.1f L",
                    summary.ml / 1000.0,
                ),
            )
            views.setTextColor(
                R.id.beer_sub,
                if (frame.subText != null) AMBER else DIM,
            )

            for (id in intArrayOf(R.id.beer_third, R.id.beer_half)) {
                val lit = frame.pillLit && id == litPillId
                views.setInt(
                    id,
                    "setBackgroundResource",
                    if (lit) R.drawable.widget_pill_active else R.drawable.widget_pill,
                )
                views.setTextColor(id, if (lit) INK else AMBER)
            }

            views.setOnClickPendingIntent(R.id.beer_open, openApp(context))
            views.setOnClickPendingIntent(
                R.id.beer_third,
                logIntent(context, ML_THIRD, 11),
            )
            views.setOnClickPendingIntent(
                R.id.beer_half,
                logIntent(context, ML_HALF, 12),
            )
            return views
        }

        private fun logIntent(
            context: Context,
            ml: Int,
            requestCode: Int,
        ): PendingIntent {
            val intent = Intent(context, BeerWidgetProvider::class.java)
                .setAction(ACTION_LOG)
                .putExtra(EXTRA_ML, ml)
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun openApp(context: Context): PendingIntent {
            val intent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            return PendingIntent.getActivity(
                context,
                10,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
