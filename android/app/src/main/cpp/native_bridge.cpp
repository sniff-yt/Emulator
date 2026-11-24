#include <jni.h>
#include <string>
#include <android/log.h>
#include <unistd.h>
#include <sys/wait.h>
#include <cstdlib>

#define LOG_TAG "PCEmulator"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static pid_t g_pid = -1;

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_pc_1emulator_NativeBridge_hello(JNIEnv* env, jclass) {
    return env->NewStringUTF("PC Emulator native engine (box64+Wine hook ready)");
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_pc_1emulator_NativeBridge_initEngine(JNIEnv* env, jclass, jstring gamePath, jint ramMB, jint cores) {
    const char* path = env->GetStringUTFChars(gamePath, nullptr);
    LOGI("initEngine: %s (ram=%d cores=%d)", path, ramMB, cores);

    // Locate box64 + wine binaries shipped in jniLibs/<abi>/
    // Expected layout: libbox64.so, libwine.so (renamed executables)
    // We exec them via the Android linker.
    char box64[256];
    snprintf(box64, sizeof(box64), "%s/libbox64.so", getenv("LD_LIBRARY_PATH") ?: "");

    g_pid = fork();
    if (g_pid == 0) {
        // Child: launch wine via box64
        setenv("WINEPREFIX", "/data/local/tmp/.wine", 1);
        execlp("sh", "sh", "-c",
               "export LD_LIBRARY_PATH=/data/app/*/lib/arm64; "
               "box64 wine \"$1\"", "sh", path, (char*)nullptr);
        _exit(127);
    } else if (g_pid > 0) {
        LOGI("Launched emulation process pid=%d", g_pid);
    } else {
        LOGE("fork failed");
    }

    env->ReleaseStringUTFChars(gamePath, path);
    return g_pid > 0 ? 0 : -1;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_pc_1emulator_NativeBridge_stopEngine(JNIEnv*, jclass) {
    if (g_pid > 0) {
        kill(g_pid, SIGTERM);
        waitpid(g_pid, nullptr, 0);
        g_pid = -1;
        LOGI("stopEngine: terminated");
    }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_pc_1emulator_NativeBridge_isRunning(JNIEnv*, jclass) {
    if (g_pid <= 0) return JNI_FALSE;
    int status;
    pid_t r = waitpid(g_pid, &status, WNOHANG);
    if (r == 0) return JNI_TRUE; // still running
    g_pid = -1;
    return JNI_FALSE;
}