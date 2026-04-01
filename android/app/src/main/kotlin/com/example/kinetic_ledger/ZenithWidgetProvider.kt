package com.example.kinetic_ledger

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ZenithWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences   // home_widget passes SharedPreferences directly
    ) {
        appWidgetIds.forEach { widgetId ->

            // Read data saved from Flutter's HomeWidget.saveWidgetData()
            val rate       = widgetData.getString("rate", null) ?: "—"
            val subLabel   = widgetData.getString("sub_label", null) ?: "Tap app to load"
            val change     = widgetData.getString("change", null) ?: "—"
            val updated    = widgetData.getString("updated", null) ?: "not updated yet"
            val pairLabel  = widgetData.getString("pair_label", null) ?: "USD → INR"
            val flagLabel  = widgetData.getString("flag_label", null) ?: "🇺🇸 → 🇮🇳"
            val isPositive = widgetData.getBoolean("is_positive", true)

            // Combine flags + pair code for the header
            val header = "$flagLabel  $pairLabel"

            val views = RemoteViews(context.packageName, R.layout.zenith_widget).apply {

                setTextViewText(R.id.widget_flag, header)
                setTextViewText(R.id.widget_rate, rate)
                setTextViewText(R.id.widget_sub_label, subLabel)
                setTextViewText(R.id.widget_change, change)
                setTextViewText(R.id.widget_updated, updated)

                // Dynamic badge: green (positive) or red (negative)
                if (isPositive) {
                    setTextColor(R.id.widget_change, Color.parseColor("#4ADE80"))
                    setInt(R.id.widget_change, "setBackgroundResource", R.drawable.badge_green)
                } else {
                    setTextColor(R.id.widget_change, Color.parseColor("#FF6B6B"))
                    setInt(R.id.widget_change, "setBackgroundResource", R.drawable.badge_red)
                }

                // Tap widget → open app
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, launchIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
