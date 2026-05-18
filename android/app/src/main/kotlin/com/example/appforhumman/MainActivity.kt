package com.example.appforhumman

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.bur.app/voice_intent"
        private const val REQUEST_SPEECH = 43701
    }

    private var pendingSpeechResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognizeEnglish" -> launchEnglishSpeechRecognizer(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun launchEnglishSpeechRecognizer(result: MethodChannel.Result) {
        if (pendingSpeechResult != null) {
            result.error("busy", "Speech recognition already in progress", null)
            return
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak in English…")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }

        try {
            pendingSpeechResult = result
            startActivityForResult(intent, REQUEST_SPEECH)
        } catch (e: ActivityNotFoundException) {
            pendingSpeechResult = null
            result.error(
                "unavailable",
                "No speech recognizer found. Install or update the Google app.",
                null,
            )
        } catch (e: Exception) {
            pendingSpeechResult = null
            result.error("failed", e.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_SPEECH) return

        val result = pendingSpeechResult
        pendingSpeechResult = null
        if (result == null) return

        if (resultCode == Activity.RESULT_OK && data != null) {
            val matches =
                data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            val text = matches?.firstOrNull()?.trim().orEmpty()
            if (text.isNotEmpty()) {
                result.success(text)
            } else {
                result.error("no_match", "No speech recognized", null)
            }
        } else {
            result.error("cancelled", "Speech recognition cancelled", null)
        }
    }
}
