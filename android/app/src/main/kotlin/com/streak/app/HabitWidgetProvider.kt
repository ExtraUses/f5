package com.streak.app

import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetReceiver

class HabitWidgetProvider : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = HabitWidget()

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        WidgetRefreshReceiver.keepFresh(context)
        GlanceWidgets.refreshSoon(context, glanceAppWidget, appWidgetIds, goAsync())
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        for (id in appWidgetIds) WidgetConfig.forget(context, id)
    }
}
