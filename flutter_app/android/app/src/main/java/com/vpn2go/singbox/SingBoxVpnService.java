package com.vpn2go.singbox;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.net.VpnService;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

/**
 * VPN2GO — Android VPN Service
 * 
 * Simplified version that creates VPN tunnel.
 * Full sing-box integration will be added when libbox.aar is properly configured.
 */
public class SingBoxVpnService extends VpnService {

    private static final String TAG = "VPN2GO-SingBox";
    private static final String CHANNEL_ID = "vpn2go_vpn";
    private static final int NOTIFICATION_ID = 1;

    public static final String ACTION_CONNECT = "com.vpn2go.CONNECT";
    public static final String ACTION_DISCONNECT = "com.vpn2go.DISCONNECT";
    public static final String EXTRA_CONFIG = "config";
    public static final String EXTRA_SESSION_NAME = "session_name";

    private static volatile String currentStatus = "disconnected";

    private ParcelFileDescriptor vpnInterface;
    private File configPath;

    public static String getCurrentStatus() {
        return currentStatus;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        configPath = new File(getFilesDir(), "sing-box-config.json");
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_STICKY;

        switch (intent.getAction()) {
            case ACTION_CONNECT:
                String config = intent.getStringExtra(EXTRA_CONFIG);
                String sessionName = intent.getStringExtra(EXTRA_SESSION_NAME);
                if (config != null) {
                    startVpn(config, sessionName != null ? sessionName : "VPN2GO");
                }
                break;
            case ACTION_DISCONNECT:
                stopVpn();
                break;
        }

        return START_STICKY;
    }

    private void startVpn(String configJson, String sessionName) {
        Log.i(TAG, "Starting VPN: " + sessionName);
        currentStatus = "connecting";
        notifyStatusChanged();

        try {
            // Write config
            writeConfig(configJson);

            // Create VPN interface
            if (!createVpnInterface()) {
                Log.e(TAG, "Failed to create VPN interface");
                currentStatus = "error";
                notifyStatusChanged();
                return;
            }

            // TODO: Start sing-box with libbox
            // For now, just mark as connected
            currentStatus = "connected";
            notifyStatusChanged();
            showNotification(sessionName);
            Log.i(TAG, "VPN connected (simplified mode)");

        } catch (Exception e) {
            Log.e(TAG, "VPN start failed", e);
            currentStatus = "error";
            notifyStatusChanged();
            stopVpn();
        }
    }

    private void writeConfig(String configJson) throws IOException {
        try (FileOutputStream fos = new FileOutputStream(configPath)) {
            fos.write(configJson.getBytes());
        }
    }

    private boolean createVpnInterface() {
        Builder builder = new Builder();
        builder.setSession("VPN2GO");
        builder.setMtu(9000);
        builder.addAddress("172.19.0.1", 30);
        builder.addRoute("0.0.0.0", 0);
        builder.addAddress("fdfe:dcba:9876::1", 126);
        builder.addRoute("::", 0);
        builder.addDnsServer("1.1.1.1");
        builder.addDnsServer("8.8.8.8");
        builder.setBlocking(true);

        try {
            vpnInterface = builder.establish();
        } catch (Exception e) {
            Log.e(TAG, "VPN establish failed", e);
            return false;
        }

        return vpnInterface != null;
    }

    private void stopVpn() {
        Log.i(TAG, "Stopping VPN");
        currentStatus = "disconnecting";
        notifyStatusChanged();

        try {
            if (vpnInterface != null) {
                vpnInterface.close();
                vpnInterface = null;
            }
            currentStatus = "disconnected";
            notifyStatusChanged();
            Log.i(TAG, "VPN disconnected");
        } catch (Exception e) {
            Log.e(TAG, "VPN stop failed", e);
        } finally {
            stopForeground(true);
            stopSelf();
        }
    }

    private void notifyStatusChanged() {
        Intent intent = new Intent("com.vpn2go.STATUS_CHANGED");
        intent.putExtra("status", currentStatus);
        sendBroadcast(intent);
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, "VPN2GO Connection", NotificationManager.IMPORTANCE_LOW);
            channel.setDescription("VPN connection status");
            NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            manager.createNotificationChannel(channel);
        }
    }

    private void showNotification(String serverName) {
        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder = new Notification.Builder(this, CHANNEL_ID);
        } else {
            builder = new Notification.Builder(this);
        }
        Notification notification = builder
            .setContentTitle("VPN2GO")
            .setContentText("Подключено к " + serverName)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build();
        startForeground(NOTIFICATION_ID, notification);
    }

    @Override
    public void onDestroy() {
        stopVpn();
        super.onDestroy();
    }
}
