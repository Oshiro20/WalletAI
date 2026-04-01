package com.finanzas.aplicativo_gastos

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent

/**
 * Widget de Pantalla de Inicio: Próximos Pagos Recurrentes
 * Los datos son empujados desde Flutter vía home_widget (SharedPreferences).
 */
class RecurringWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(
                "HomeWidgetPreferences",
                Context.MODE_PRIVATE
            )

            val name1   = prefs.getString("hw_recurring_name1",   "—")  ?: "—"
            val amount1 = prefs.getString("hw_recurring_amount1", "") ?: ""
            val name2   = prefs.getString("hw_recurring_name2",   "")  ?: ""
            val amount2 = prefs.getString("hw_recurring_amount2", "") ?: ""
            val name3   = prefs.getString("hw_recurring_name3",   "")  ?: ""
            val amount3 = prefs.getString("hw_recurring_amount3", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_recurring)
            views.setTextViewText(R.id.widget_recurring_name1,   name1)
            views.setTextViewText(R.id.widget_recurring_amount1, amount1)
            views.setTextViewText(R.id.widget_recurring_name2,   name2)
            views.setTextViewText(R.id.widget_recurring_amount2, amount2)
            views.setTextViewText(R.id.widget_recurring_name3,   name3)
            views.setTextViewText(R.id.widget_recurring_amount3, amount3)

            // Tap → abre la sección de pagos recurrentes
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                intent.putExtra("route", "/recurring")
                val pendingIntent = PendingIntent.getActivity(
                    context, 1, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_recurring_footer, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
