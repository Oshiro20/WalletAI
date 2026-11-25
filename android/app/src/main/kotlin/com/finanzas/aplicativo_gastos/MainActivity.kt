package com.finanzas.aplicativo_gastos

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
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

    @SuppressLint("BatteryLife")
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "walletai/background_permissions",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                        result.success(true)
                    } else {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        result.success(pm?.isIgnoringBatteryOptimizations(packageName) ?: false)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        openAppDetails()
                        result.success(false)
                    }
                }
                "openAppSettings" -> {
                    openAppDetails()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openAppDetails() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (_: Exception) {
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
