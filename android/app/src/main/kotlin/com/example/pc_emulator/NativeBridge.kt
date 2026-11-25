package com.example.pc_emulator

// JNI symbols in native_bridge.cpp are Java_com_example_pc_1emulator_NativeBridge_*,
// taking a jclass, so they must be static methods on this class.
object NativeBridge {
    init { System.loadLibrary("pc_emulator_native") }

    @JvmStatic external fun hello(): String
    @JvmStatic external fun initEngine(gamePath: String, ramMB: Int, cores: Int): Int
    @JvmStatic external fun stopEngine()
    @JvmStatic external fun isRunning(): Boolean
    @JvmStatic external fun loadEngineLibs(): Boolean
}
