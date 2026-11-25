package com.example.pc_emulator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "pc_emulator/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "hello" -> result.success(NativeBridge.hello())
                    "initEngine" -> {
                        val gamePath = call.argument<String>("gamePath") ?: ""
                        val ramMB = call.argument<Int>("ramMB") ?: 2048
                        val cores = call.argument<Int>("cores") ?: 2
                        result.success(NativeBridge.initEngine(gamePath, ramMB, cores))
                    }
                    "stopEngine" -> { NativeBridge.stopEngine(); result.success(null) }
                    "isRunning" -> result.success(NativeBridge.isRunning())
                    "loadEngineLibs" -> result.success(NativeBridge.loadEngineLibs())
                    else -> result.notImplemented()
                }
            } catch (e: Throwable) {
                result.error("NATIVE_ERROR", e.message, null)
            }
        }
    }
}
