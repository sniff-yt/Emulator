#include <jni.h>
#include <string>
#include <android/log.h>

#define LOG_TAG "PCEmulator"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_pc_1emulator_NativeBridge_hello(JNIEnv* env, jclass /*clazz*/) {
    return env->NewStringUTF("PC Emulator native engine ready (box64+Wine pending)");
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_pc_1emulator_NativeBridge_initEngine(JNIEnv* env, jclass /*clazz*/, jstring gamePath) {
    const char* path = env->GetStringUTFChars(gamePath, nullptr);
    LOGI("initEngine: %s", path);
    env->ReleaseStringUTFChars(gamePath, path);
    // TODO: spawn box64 + wine process here
    return 0;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_pc_1emulator_NativeBridge_stopEngine(JNIEnv* /*env*/, jclass /*clazz*/) {
    LOGI("stopEngine");
    // TODO: terminate emulation process
}