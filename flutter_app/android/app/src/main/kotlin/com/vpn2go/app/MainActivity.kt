package com.vpn2go.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // TODO: Подключить sing-box bridge когда libbox.aar будет добавлен
        // singBoxBridge = SingBoxBridge(this)
        // singBoxBridge.configure(flutterEngine)
    }
}
