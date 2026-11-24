package com.example.pc_emulator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "pc_emulator/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        System.loadLibrary("pc_emulator_native")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "hello" -> result.success(nativeHello())
                "initEngine" -> {
                    val gamePath = call.argument<String>("gamePath") ?: ""
                    val ramMB = call.argument<Int>("ramMB") ?: 2048
                    val cores = call.argument<Int>("cores") ?: 2
                    result.success(nativeInitEngine(gamePath, ramMB, cores))
                }
                "stopEngine" -> { nativeStopEngine(); result.success(null) }
                "isRunning" -> result.success(nativeIsRunning())
                "loadEngineLibs" -> result.success(nativeLoadEngineLibs())
                else -> result.notImplemented()
            }
        }
    }

    private external fun nativeHello(): String
    private external fun nativeInitEngine(gamePath: String, ramMB: Int, cores: Int): Int
    private external fun nativeStopEngine()
    private external fun nativeIsRunning(): Boolean
    private external fun nativeLoadEngineLibs(): Boolean

    companion object {
        init { System.loadLibrary("pc_emulator_native") }
    }
}