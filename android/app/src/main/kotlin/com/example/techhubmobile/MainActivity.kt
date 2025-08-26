package com.example.techhubmobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.techhubmobile/permissions"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val permission = call.argument<String>("permission")
                    if (permission != null) {
                        val granted = ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.error("INVALID_ARGUMENT", "Permission argument is required", null)
                    }
                }
                "requestPermission" -> {
                    val permission = call.argument<String>("permission")
                    if (permission != null) {
                        ActivityCompat.requestPermissions(this, arrayOf(permission), 1001)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Permission argument is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
