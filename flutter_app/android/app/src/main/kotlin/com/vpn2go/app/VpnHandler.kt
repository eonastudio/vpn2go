package com.vpn2go.app

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*

/**
 * VPN2GO — Нативный VPN handler для Android
 * 
 * Использует sing-box как VPN engine.
 * Подключается через Flutter MethodChannel.
 */
class VpnHandler(private val activity: Activity) {
    
    private val CHANNEL_NAME = "com.vpn2go/vpn"
    private var methodChannel: MethodChannel? = null
    private var vpnService: Vpn2GoVpnService? = null
    private val handler = Handler(Looper.getMainLooper())
    
    fun configure(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val config = call.argument<String>("config") ?: ""
                    val serverName = call.argument<String>("serverName") ?: "VPN2GO"
                    connect(config, serverName, result)
                }
                "disconnect" -> {
                    disconnect(result)
                }
                "getStatus" -> {
                    result.success(getStatus())
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun connect(configJson: String, serverName: String, result: MethodChannel.Result) {
        // Проверяем разрешение VPN
        val intent = VpnService.prepare(activity)
        if (intent != null) {
            // Нужно разрешение — запрашиваем
            pendingConfig = configJson
            pendingResult = result
            activity.startActivityForResult(intent, VPN_REQUEST_CODE)
            return
        }
        
        // Разрешение есть — запускаем сервис
        startVpnService(configJson, serverName)
        result.success(true)
    }
    
    private fun startVpnService(configJson: String, serverName: String) {
        val intent = Intent(activity, Vpn2GoVpnService::class.java).apply {
            action = Vpn2GoVpnService.ACTION_CONNECT
            putExtra(Vpn2GoVpnService.EXTRA_CONFIG, configJson)
            putExtra(Vpn2GoVpnService.EXTRA_SERVER_NAME, serverName)
        }
        activity.startService(intent)
        
        // Уведомляем Flutter о статусе
        sendStatusToFlutter("connecting")
    }
    
    private fun disconnect(result: MethodChannel.Result) {
        val intent = Intent(activity, Vpn2GoVpnService::class.java).apply {
            action = Vpn2GoVpnService.ACTION_DISCONNECT
        }
        activity.startService(intent)
        sendStatusToFlutter("disconnected")
        result.success(true)
    }
    
    private fun getStatus(): String {
        return Vpn2GoVpnService.currentStatus ?: "disconnected"
    }
    
    private fun sendStatusToFlutter(status: String) {
        handler.post {
            methodChannel?.invokeMethod("onVpnStatusChanged", mapOf("status" to status))
        }
    }
    
    fun sendStatsToFlutter(downloadSpeed: Long, uploadSpeed: Long, totalDown: Long, totalUp: Long) {
        handler.post {
            methodChannel?.invokeMethod("onVpnStatsUpdate", mapOf(
                "downloadSpeed" to downloadSpeed,
                "uploadSpeed" to uploadSpeed,
                "totalDownload" to totalDown,
                "totalUpload" to totalUp,
            ))
        }
    }
    
    companion object {
        const val VPN_REQUEST_CODE = 1001
        var pendingConfig: String? = null
        var pendingResult: MethodChannel.Result? = null
    }
}
