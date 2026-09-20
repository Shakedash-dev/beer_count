package com.shakedash.beercount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Locale

/**
 * One-tap beer logging from the home screen.
 *
 * Deliberately does not start a Flutter engine: a tap appends one line to the
 * shared NDJSON log, bumps a small SharedPreferences counter, and re-renders.
 * The app picks the new entry up when it next resumes.
 */
class BeerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val summary = BeerLog.summary(context)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, summary))
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
                BeerLog.summary(context)
            } catch (t2: Throwable) {
                return
            }
        }
        renderAll(context, summary)
    }

    companion object {
        const val ACTION_LOG = "com.shakedash.beercount.LOG"
        const val EXTRA_ML = "ml"

        private const val ML_THIRD = 333
        private const val ML_HALF = 500

        fun renderAll(context: Context, summary: BeerLog.Summary) {
            AppWidgetManager.getInstance(context).updateAppWidget(
                ComponentName(context, BeerWidgetProvider::class.java),
                buildViews(context, summary),
            )
        }

        private fun buildViews(
            context: Context,
            summary: BeerLog.Summary,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.beer_widget)
            views.setTextViewText(R.id.beer_count, summary.count.toString())
            views.setTextViewText(
                R.id.beer_sub,
                String.format(
                    Locale.US,
                    "today · %.1f L",
                    summary.ml / 1000.0,
                ),
            )
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
