package com.indest.aimoviequiz

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of Stagenator claim-link handling.
 *
 * FCM notification taps deliver the data payload in the launch intent's
 * extras. The firebase_messaging plugin's delivery is racy (events lost while
 * the engine boots) AND replays (reopening the app re-delivers the task-root
 * intent, and the plugin re-fires from its cache). This class is the single
 * source of truth for "has this FCM message been handled": a persisted set of
 * consumed message ids that both the native capture and the Dart plugin path
 * (via the "consume" method) check before opening anything.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pendingClaimUrl: String? = null
    private var pendingLevelNumber: String? = null
    private var channel: MethodChannel? = null

    private fun consumeOnce(messageId: String): Boolean {
        val prefs = getSharedPreferences("stagenator_claim", MODE_PRIVATE)
        val seen = prefs.getStringSet("consumed_ids", emptySet())!!.toMutableSet()
        if (!seen.add(messageId)) return false // already handled
        while (seen.size > 40) seen.remove(seen.first()) // bound growth
        prefs.edit().putStringSet("consumed_ids", seen).apply()
        return true
    }

    private fun captureExtras(intent: Intent?, coldStart: Boolean) {
        val extras = intent?.extras ?: return
        val messageId = extras.getString("google.message_id")
            ?: extras.getString("google_message_id") ?: return
        val url = extras.getString("claimUrl")
        val level = extras.getString("levelNumber")
        if (url == null && level == null) return
        if (!consumeOnce(messageId)) return
        if (url != null && url.startsWith("https://")) pendingClaimUrl = url
        // levelNumber only matters on cold start — the warm path is handled by
        // the Flutter plugin's listener, and capturing it here on warm entries
        // would leave a stale value that a later plain open could replay.
        if (coldStart && level != null) pendingLevelNumber = level
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureExtras(intent, coldStart = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        captureExtras(intent, coldStart = false)
        pendingClaimUrl?.let { url ->
            pendingClaimUrl = null // consumed by this active push
            channel?.invokeMethod("claimUrl", url)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stagenator/claim"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingClaimUrl" -> {
                        result.success(pendingClaimUrl)
                        pendingClaimUrl = null // handed to Dart
                    }
                    "getPendingLevelNumber" -> {
                        result.success(pendingLevelNumber)
                        pendingLevelNumber = null // handed to Dart
                    }
                    // Dart plugin path asks before opening; returns true only
                    // the first time a message id is ever seen.
                    "consume" -> {
                        val id = call.arguments as? String
                        result.success(id != null && consumeOnce(id))
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
