package com.vpn2go.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.vpn2go.singbox.SingBoxBridge

class MainActivity : FlutterActivity() {
    private lateinit var singBoxBridge: SingBoxBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        singBoxBridge = SingBoxBridge(this)
        singBoxBridge.configure(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        singBoxBridge.onActivityResult(requestCode, resultCode)
    }

    override fun onDestroy() {
        if (::singBoxBridge.isInitialized) {
            singBoxBridge.dispose()
        }
        super.onDestroy()
    }
}
