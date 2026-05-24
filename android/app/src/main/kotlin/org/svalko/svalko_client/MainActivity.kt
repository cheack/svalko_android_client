package org.svalko.svalko_client

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "org.svalko/browser",
        ).setMethodCallHandler { call, result ->
            if (call.method == "openInDefaultBrowser") {
                val url = call.argument<String>("url") ?: run {
                    result.error("INVALID_ARG", "url is null", null)
                    return@setMethodCallHandler
                }
                openInDefaultBrowser(url)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openInDefaultBrowser(url: String) {
        // Use an intent selector to force the URL to open in a browser only.
        //
        // The selector intent targets apps that can handle a bare "http:" URI with
        // CATEGORY_BROWSABLE — only true browsers match this, not app-link handlers.
        // Android then uses that restricted set to resolve the main intent, so our own
        // app (and any other non-browser app-link handler) is excluded from the picker,
        // bypassing autoVerify App Links interception entirely.
        val browserSelector = Intent(Intent.ACTION_VIEW).apply {
            data = Uri.parse("http:")
            addCategory(Intent.CATEGORY_BROWSABLE)
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            selector = browserSelector
        }

        startActivity(intent)
    }
}
