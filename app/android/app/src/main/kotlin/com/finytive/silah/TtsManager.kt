package com.finytive.silah

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.util.Log
import java.util.Locale

object TtsManager {
    private const val TAG = "SilahTTS"
    private var tts: TextToSpeech? = null
    private var isInitialized = false
    private var pendingText: String? = null

    fun init(context: Context) {
        if (tts != null) return
        Handler(Looper.getMainLooper()).post {
            try {
                tts = TextToSpeech(context.applicationContext) { status ->
                    if (status == TextToSpeech.SUCCESS) {
                        isInitialized = true
                        val result = tts?.setLanguage(Locale.getDefault())
                        if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                            tts?.language = Locale.US
                        }
                        pendingText?.let { text ->
                            speakInternal(text)
                            pendingText = null
                        }
                    } else {
                        Log.e(TAG, "TTS initialization failed with status: $status")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing TTS", e)
            }
        }
    }

    fun speak(context: Context, text: String) {
        if (text.isBlank()) return
        Handler(Looper.getMainLooper()).post {
            if (tts == null || !isInitialized) {
                pendingText = text
                init(context)
            } else {
                speakInternal(text)
            }
        }
    }

    private fun speakInternal(text: String) {
        try {
            // Check if text contains Tamil Unicode range
            val hasTamil = text.any { it.code in 0x0B80..0x0BFF }
            if (hasTamil) {
                val taLocale = Locale("ta", "IN")
                val res = tts?.setLanguage(taLocale)
                if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
                    tts?.language = Locale.getDefault()
                }
            } else {
                tts?.language = Locale.getDefault()
            }
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "silah_notif_heading")
        } catch (e: Exception) {
            Log.e(TAG, "Error speaking text", e)
        }
    }

    fun stop() {
        try {
            tts?.stop()
        } catch (_: Exception) {}
    }
}
