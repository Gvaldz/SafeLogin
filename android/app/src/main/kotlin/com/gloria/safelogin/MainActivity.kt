package com.gloria.safelogin

import android.app.AppOpsManager
import android.content.Context
import android.location.LocationManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "safelogin/secure_window"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val enabled = call.arguments as? Boolean ?: true

                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }

                    result.success(null)
                }
                "detectFakeLocation" -> result.success(checkMockLocation())
                else -> result.notImplemented()
            }
        }
    }

    private fun checkMockLocation(): Boolean {
        return checkApi31AndAbove() || checkApi23To30() || checkPreApi23()
    }

    private fun checkApi31AndAbove(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return false
        }

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = locationManager.getProviders(true)

        return try {
            providers.any { provider ->
                locationManager.getLastKnownLocation(provider)?.isMock == true
            }
        } catch (e: SecurityException) {
            false
        }
    }

    private fun checkApi23To30(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        ) {
            return false
        }

        val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager

        return try {
            appOpsManager.checkOp(
                AppOpsManager.OPSTR_MOCK_LOCATION,
                Process.myUid(),
                packageName
            ) == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun checkPreApi23(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return false
        }

        return try {
            !Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ALLOW_MOCK_LOCATION
            ).isNullOrEmpty()
        } catch (e: Exception) {
            false
        }
    }
}
