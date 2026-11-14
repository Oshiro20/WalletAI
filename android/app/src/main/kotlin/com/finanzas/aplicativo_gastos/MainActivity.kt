package com.finanzas.aplicativo_gastos

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var deepLinkChannel: MethodChannel? = null
    private var initialLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialLink = extractLink(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "walletai/deep_links",
        )
        deepLinkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    val link = initialLink
                    initialLink = null
                    result.success(link)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val link = extractLink(intent)
        if (link != null) {
            deepLinkChannel?.invokeMethod("onNewIntentLink", link)
        }
    }

    private fun extractLink(intent: Intent?): String? {
        if (intent?.action == Intent.ACTION_VIEW) {
            return intent.dataString
        }
        return null
    }
}
