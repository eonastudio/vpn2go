package com.vpn2go.singbox;

import android.annotation.SuppressLint;
import android.content.Context;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import java.security.MessageDigest;
import java.util.UUID;

/**
 * VPN2GO — Генерация уникального Hardware ID устройства
 * 
 * HWID генерируется один раз на основе:
 * - Android ID (уникален для устройства + подпись приложения)
 * - Модель устройства
 * - Salt приложения
 * 
 * HWID не содержит личной информации и не отслеживает пользователя.
 */
public class HwidGenerator {

    private static final String TAG = "VPN2GO-HWID";
    
    // Salt для хеширования (уникален для приложения)
    private static final String APP_SALT = "vpn2go_2026_salt";

    /**
     * Сгенерировать уникальный HWID для устройства
     */
    @SuppressLint("HardwareIds")
    public static String generate(Context context) {
        try {
            // 1. Android ID (64-bit, уникален для device+app combination)
            String androidId = Settings.Secure.getString(
                context.getContentResolver(),
                Settings.Secure.ANDROID_ID
            );

            // 2. Модель устройства
            String model = Build.MODEL;
            String manufacturer = Build.MANUFACTURER;
            String device = Build.DEVICE;

            // 3. Комбинируем и хешируем
            String raw = String.format("%s|%s|%s|%s|%s",
                androidId != null ? androidId : "unknown",
                manufacturer,
                model,
                device,
                APP_SALT
            );

            String hwid = sha256(raw);
            
            Log.i(TAG, "HWID generated: " + hwid.substring(0, 8) + "...");
            return hwid;

        } catch (Exception e) {
            Log.e(TAG, "HWID generation failed, using fallback", e);
            return generateFallback();
        }
    }

    /**
     * Получить информацию об устройстве
     */
    public static String[] getDeviceInfo(Context context) {
        return new String[] {
            "android",                          // platform
            Build.VERSION.RELEASE,               // osVersion
            Build.MANUFACTURER + " " + Build.MODEL,  // deviceModel
            Build.DEVICE,                        // deviceCode
            String.valueOf(Build.VERSION.SDK_INT) // sdkVersion
        };
    }

    /**
     * SHA-256 хеширование
     */
    private static String sha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes("UTF-8"));
            
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (Exception e) {
            return generateFallback();
        }
    }

    /**
     * Fallback генерация (если SHA-256 недоступен)
     */
    private static String generateFallback() {
        String uuid = UUID.randomUUID().toString().replace("-", "");
        return uuid.substring(0, 24);
    }
}
