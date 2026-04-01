package com.finanzas.aplicativo_gastos

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent

/**
 * Widget de Pantalla de Inicio: Balance Disponible
 * Los datos son empujados desde Flutter vía home_widget (SharedPreferences).
 */
class BalanceWidget : AppWidgetProvider() {

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

            val balance   = prefs.getString("hw_balance_amount",  "S/ ---") ?: "S/ ---"
            val income    = prefs.getString("hw_balance_income",  "—")       ?: "—"
            val expense   = prefs.getString("hw_balance_expense", "—")       ?: "—"
            val updated   = prefs.getString("hw_balance_updated", "")        ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_balance)
            views.setTextViewText(R.id.widget_balance_amount,  balance)
            views.setTextViewText(R.id.widget_balance_income,  income)
            views.setTextViewText(R.id.widget_balance_expense, expense)
            views.setTextViewText(R.id.widget_balance_updated, updated)

            // Tap → abre la app
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_balance_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
