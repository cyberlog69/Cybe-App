package com.cybe.cybe_app

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.ConnectivityManager
import android.net.DhcpInfo
import android.net.Uri
import android.net.wifi.WifiManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.ByteArrayOutputStream
import java.io.FileReader
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URL
import javax.net.ssl.HttpsURLConnection

class MainActivity : FlutterFragmentActivity() {
    private val APP_AUDIT_CHANNEL = "com.cybe.cybe_app/app_audit"
    private val MITM_DETECTOR_CHANNEL = "com.cybe.cybe_app/mitm_detector"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. App Audit Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_AUDIT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    val includeSystemApps = call.argument<Boolean>("includeSystemApps") ?: false
                    try {
                        val appsList = getInstalledAppsList(includeSystemApps)
                        result.success(appsList)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to fetch installed apps: ${e.message}", null)
                    }
                }
                "openAppDetails" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to open settings: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 2. MitM & ARP Detector Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MITM_DETECTOR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getGatewayAndArpInfo" -> {
                    try {
                        val info = getGatewayAndArpInfo()
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to inspect ARP table: ${e.message}", null)
                    }
                }
                "checkSslIntegrity" -> {
                    Thread {
                        try {
                            val isSecure = performSslIntegrityProbe()
                            runOnUiThread { result.success(isSecure) }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(false) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledAppsList(includeSystemApps: Boolean): List<Map<String, Any?>> {
        val pm = packageManager
        val flags = PackageManager.GET_PERMISSIONS
        val packages = pm.getInstalledPackages(flags)
        val resultList = mutableListOf<Map<String, Any?>>()

        for (pkg in packages) {
            val appInfo = pkg.applicationInfo ?: continue
            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            if (!includeSystemApps && isSystemApp) {
                continue
            }

            val appLabel = pm.getApplicationLabel(appInfo).toString()
            val packageName = pkg.packageName
            val versionName = pkg.versionName ?: "1.0.0"

            val requestedPermissions = pkg.requestedPermissions?.toList() ?: emptyList<String>()

            var iconBytes: ByteArray? = null
            try {
                val iconDrawable = pm.getApplicationIcon(appInfo)
                iconBytes = drawableToByteArray(iconDrawable)
            } catch (e: Exception) {
                // Ignore icon extraction failure
            }

            val appMap = mapOf(
                "appName" to appLabel,
                "packageName" to packageName,
                "versionName" to versionName,
                "isSystemApp" to isSystemApp,
                "permissions" to requestedPermissions,
                "iconBytes" to iconBytes
            )
            resultList.add(appMap)
        }

        return resultList
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
            val b = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(b)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            b
        }

        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
        return stream.toByteArray()
    }

    private fun getGatewayAndArpInfo(): Map<String, Any?> {
        var gatewayIp = "Unknown"
        var gatewayMac = "Unknown"
        val arpEntries = mutableListOf<Map<String, String>>()

        // Retrieve Gateway IP from WifiManager DhcpInfo
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val dhcpInfo: DhcpInfo? = wifiManager.dhcpInfo
            if (dhcpInfo != null && dhcpInfo.gateway != 0) {
                val ip = dhcpInfo.gateway
                gatewayIp = String.format(
                    "%d.%d.%d.%d",
                    ip and 0xff,
                    ip shr 8 and 0xff,
                    ip shr 16 and 0xff,
                    ip shr 24 and 0xff
                )
            }
        } catch (e: Exception) {
            // Fallback
        }

        // Read ARP Table from /proc/net/arp
        try {
            val br = BufferedReader(FileReader("/proc/net/arp"))
            var line: String? = br.readLine() // Skip header line
            while (br.readLine().also { line = it } != null) {
                val tokens = line!!.split("\\s+".toRegex())
                if (tokens.size >= 4) {
                    val ip = tokens[0]
                    val mac = tokens[3]
                    val flags = tokens[2]

                    if (mac != "00:00:00:00:00:00") {
                        arpEntries.add(mapOf("ip" to ip, "mac" to mac, "flags" to flags))
                        if (gatewayIp != "Unknown" && ip == gatewayIp) {
                            gatewayMac = mac
                        }
                    }
                }
            }
            br.close()
        } catch (e: Exception) {
            // Ignore if /proc/net/arp unreadable on restricted ROMs
        }

        return mapOf(
            "gatewayIp" to gatewayIp,
            "gatewayMac" to gatewayMac,
            "arpEntries" to arpEntries
        )
    }

    private fun performSslIntegrityProbe(): Boolean {
        return try {
            val url = URL("https://www.google.com/generate_204")
            val conn = url.openConnection() as HttpsURLConnection
            conn.connectTimeout = 3500
            conn.readTimeout = 3500
            conn.instanceFollowRedirects = false
            conn.connect()
            val code = conn.responseCode
            conn.disconnect()
            // 204 No Content is expected for Google probe without redirects
            code == 204 || code == 200
        } catch (e: Exception) {
            false
        }
    }
}
