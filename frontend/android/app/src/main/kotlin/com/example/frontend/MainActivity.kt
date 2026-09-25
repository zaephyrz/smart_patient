package com.example.frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Bundle

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.frontend/deeplink"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "getInitialDeepLink" -> {
                    val intent = intent
                    val data = intent?.data
                    if (data != null) {
                        result.success(data.toString())
                    } else {
                        result.success(null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        // Handle new deep link intents
        val data: Uri? = intent.data
        if (data != null) {
            // Send to Flutter
            flutterEngine?.dartExecutor?.binaryMessenger?.let {
                MethodChannel(it, CHANNEL)
                    .invokeMethod("onDeepLink", data.toString())
            }
        }
    }
}