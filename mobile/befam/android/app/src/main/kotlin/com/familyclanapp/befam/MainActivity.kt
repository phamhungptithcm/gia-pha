package com.familyclanapp.befam

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val VNPAY_CHANNEL = "befam.vnpay/mobile_sdk"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VNPAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "openCheckout") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val checkoutUrl = call.argument<String>("checkoutUrl")?.trim().orEmpty()
                if (checkoutUrl.isEmpty()) {
                    result.success(
                        mapOf(
                            "status" to "failed",
                            "message" to "Missing checkoutUrl"
                        )
                    )
                    return@setMethodCallHandler
                }
                openCheckoutInApp(checkoutUrl, result)
            }
    }

    private fun openCheckoutInApp(checkoutUrl: String, result: MethodChannel.Result) {
        val uri = try {
            Uri.parse(checkoutUrl)
        } catch (_: Throwable) {
            null
        }
        if (uri == null) {
            result.success(
                mapOf(
                    "status" to "failed",
                    "message" to "Invalid checkout URL"
                )
            )
            return
        }

        try {
            val customTabsIntent = CustomTabsIntent.Builder()
                .setShowTitle(true)
                .build()
            customTabsIntent.launchUrl(this, uri)
            result.success(mapOf("status" to "in_app_browser"))
            return
        } catch (_: Throwable) {
            // Continue to fallback.
        }

        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri))
            result.success(mapOf("status" to "external_browser"))
        } catch (error: ActivityNotFoundException) {
            result.success(
                mapOf(
                    "status" to "failed",
                    "message" to (error.message ?: "No browser activity available")
                )
            )
        }
    }
}
