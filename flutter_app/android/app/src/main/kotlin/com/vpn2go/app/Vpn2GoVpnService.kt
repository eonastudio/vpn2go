package com.vpn2go.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log

/**
 * VPN2GO — Android VPN Service
 * 
 * Использует sing-box (Go) для создания VPN-туннеля.
 * Конфиг приходит в формате sing-box JSON.
 */
class Vpn2GoVpnService : VpnService() {
    
    companion object {
        const val TAG = "Vpn2GoVPN"
        const val ACTION_CONNECT = "com.vpn2go.CONNECT"
        const val ACTION_DISCONNECT = "com.vpn2go.DISCONNECT"
        const val EXTRA_CONFIG = "config"
        const val EXTRA_SERVER_NAME = "server_name"
        const val NOTIFICATION_ID = 1
        const val CHANNEL_ID = "vpn2go_vpn_channel"
        
        var currentStatus: String? = "disconnected"
            private set
    }
    
    private var vpnInterface: ParcelFileDescriptor? = null
    // TODO: private var singBoxInstance: libbox.Box? = null
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra(EXTRA_CONFIG) ?: return START_NOT_STICKY
                val serverName = intent.getStringExtra(EXTRA_SERVER_NAME) ?: "VPN2GO"
                startVpn(config, serverName)
            }
            ACTION_DISCONNECT -> {
                stopVpn()
            }
        }
        return START_STICKY
    }
    
    private fun startVpn(configJson: String, serverName: String) {
        currentStatus = "connecting"
        showNotification(serverName)
        
        try {
            // Шаг 1: Создаём VPN-интерфейс
            val builder = Builder()
                .setSession("VPN2GO")
                .setMtu(1500)
                .addAddress("172.19.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("1.1.1.1")
                .addDnsServer("8.8.8.8")
                .setBlocking(true)
            
            // Добавляем IPv6 если нужно
            builder.addAddress("fd00::1", 128)
            addRoute("::", 0)
            
            vpnInterface = builder.establish()
            
            if (vpnInterface == null) {
                Log.e(TAG, "Failed to create VPN interface")
                currentStatus = "error"
                return
            }
            
            // Шаг 2: Запускаем sing-box с конфигом
            // TODO: Интеграция с libbox (sing-box Go library)
            // singBoxInstance = libbox.Box(configJson, vpnInterface!!.fd)
            // singBoxInstance?.start()
            
            currentStatus = "connected"
            Log.i(TAG, "VPN connected to $serverName")
            
        } catch (e: Exception) {
            Log.e(TAG, "VPN start failed", e)
            currentStatus = "error"
            stopVpn()
        }
    }
    
    private fun stopVpn() {
        currentStatus = "disconnecting"
        
        try {
            // TODO: singBoxInstance?.stop()
            // singBoxInstance = null
            
            vpnInterface?.close()
            vpnInterface = null
            
            currentStatus = "disconnected"
            Log.i(TAG, "VPN disconnected")
        } catch (e: Exception) {
            Log.e(TAG, "VPN stop failed", e)
        } finally {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN2GO Connection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows VPN connection status"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun showNotification(serverName: String) {
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("VPN2GO")
                .setContentText("Подключено к $serverName")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("VPN2GO")
                .setContentText("Подключено к $serverName")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setOngoing(true)
                .build()
        }
        
        startForeground(NOTIFICATION_ID, notification)
    }
    
    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}
