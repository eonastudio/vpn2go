package com.vpn2go.singbox;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.VpnService;
import android.os.Build;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

/**
 * VPN2GO — Flutter ↔ Android bridge для sing-box
 * 
 * MethodChannel: Flutter → Android (connect, disconnect, getStatus)
 * EventChannel: Android → Flutter (status changes, stats)
 */
public class SingBoxBridge {

    private static final String METHOD_CHANNEL = "com.vpn2go/singbox";
    private static final String EVENT_CHANNEL = "com.vpn2go/singbox_events";

    private final Activity activity;
    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private BroadcastReceiver statusReceiver;

    private String pendingConfig;
    private String pendingSessionName;

    public SingBoxBridge(Activity activity) {
        this.activity = activity;
    }

    public void configure(FlutterEngine flutterEngine) {
        // Method Channel: Flutter → Native
        methodChannel = new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            METHOD_CHANNEL
        );

        methodChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "connect":
                    String config = call.argument("config");
                    String sessionName = call.argument("sessionName");
                    connect(config, sessionName, result);
                    break;

                case "disconnect":
                    disconnect(result);
                    break;

                case "getStatus":
                    result.success(SingBoxVpnService.getCurrentStatus());
                    break;

                case "getHwid":
                    result.success(HwidGenerator.generate(activity));
                    break;

                case "getDeviceInfo":
                    String[] info = HwidGenerator.getDeviceInfo(activity);
                    java.util.Map<String, String> deviceMap = new java.util.HashMap<>();
                    deviceMap.put("platform", info[0]);
                    deviceMap.put("osVersion", info[1]);
                    deviceMap.put("deviceModel", info[2]);
                    deviceMap.put("deviceCode", info[3]);
                    deviceMap.put("sdkVersion", info[4]);
                    result.success(deviceMap);
                    break;

                default:
                    result.notImplemented();
                    break;
            }
        });

        // Event Channel: Native → Flutter
        eventChannel = new EventChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            EVENT_CHANNEL
        );

        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
                registerStatusReceiver();
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
                unregisterStatusReceiver();
            }
        });
    }

    private void connect(String config, String sessionName, MethodChannel.Result result) {
        // Проверяем VPN-разрешение
        Intent vpnIntent = VpnService.prepare(activity);
        if (vpnIntent != null) {
            // Нужно разрешение — сохраняем и запрашиваем
            pendingConfig = config;
            pendingSessionName = sessionName;
            activity.startActivityForResult(vpnIntent, 1001);
            result.success("permission_required");
            return;
        }

        // Разрешение есть — запускаем
        startVpnService(config, sessionName);
        result.success(true);
    }

    private void disconnect(MethodChannel.Result result) {
        Intent intent = new Intent(activity, SingBoxVpnService.class);
        intent.setAction(SingBoxVpnService.ACTION_DISCONNECT);
        activity.startService(intent);
        result.success(true);
    }

    private void startVpnService(String config, String sessionName) {
        Intent intent = new Intent(activity, SingBoxVpnService.class);
        intent.setAction(SingBoxVpnService.ACTION_CONNECT);
        intent.putExtra(SingBoxVpnService.EXTRA_CONFIG, config);
        intent.putExtra(SingBoxVpnService.EXTRA_SESSION_NAME, sessionName);
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(intent);
        } else {
            activity.startService(intent);
        }
    }

    /**
     * Вызывать из Activity.onActivityResult для обработки VPN-разрешения
     */
    public void onActivityResult(int requestCode, int resultCode) {
        if (requestCode == 1001 && resultCode == Activity.RESULT_OK) {
            if (pendingConfig != null) {
                startVpnService(pendingConfig, pendingSessionName);
                pendingConfig = null;
                pendingSessionName = null;
            }
        }
    }

    private void registerStatusReceiver() {
        statusReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                String status = intent.getStringExtra("status");
                if (eventSink != null && status != null) {
                    eventSink.success(status);
                }
            }
        };

        IntentFilter filter = new IntentFilter("com.vpn2go.STATUS_CHANGED");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(statusReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            activity.registerReceiver(statusReceiver, filter);
        }
    }

    private void unregisterStatusReceiver() {
        if (statusReceiver != null) {
            try {
                activity.unregisterReceiver(statusReceiver);
            } catch (Exception ignored) {}
            statusReceiver = null;
        }
    }

    public void dispose() {
        unregisterStatusReceiver();
    }
}
