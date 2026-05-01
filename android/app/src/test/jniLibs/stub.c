#include <jni.h>
#include <string.h>
#include <stdlib.h>

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

static int g_model_loaded = 0;
static int g_n_past = 0;
static int g_n_ctx = 2048;
static char g_loaded_path[1024] = {0};
static float g_temperature = 0.7f;
static int g_top_k = 40;
static float g_top_p = 0.9f;
static float g_repeat_penalty = 1.1f;

EXPORT JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeLoadModel(
    JNIEnv *env, jobject thiz, jstring path, jint context_size) {
    const char *str = (*env)->GetStringUTFChars(env, path, NULL);
    if (!str) return JNI_FALSE;

    int is_valid = (strstr(str, ".gguf") != NULL);
    strncpy(g_loaded_path, str, sizeof(g_loaded_path) - 1);
    (*env)->ReleaseStringUTFChars(env, path, str);

    if (is_valid) {
        g_model_loaded = 1;
        g_n_ctx = context_size;
        g_n_past = 0;
        return JNI_TRUE;
    }
    g_model_loaded = 0;
    return JNI_FALSE;
}

EXPORT JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeFormatChat(
    JNIEnv *env, jobject thiz, jobjectArray roles, jobjectArray contents) {
    jsize len = (*env)->GetArrayLength(env, roles);
    if (len == 0) return (*env)->NewStringUTF(env, "");

    char buf[4096] = {0};
    for (jsize i = 0; i < len && i < 10; i++) {
        auto *role = (jstring)(*env)->GetObjectArrayElement(env, roles, i);
        auto *content = (jstring)(*env)->GetObjectArrayElement(env, contents, i);
        const char *r = (*env)->GetStringUTFChars(env, role, NULL);
        const char *c = (*env)->GetStringUTFChars(env, content, NULL);
        strcat(buf, "[");
        strcat(buf, r ? r : "");
        strcat(buf, "] ");
        strcat(buf, c ? c : "");
        strcat(buf, "\n");
        (*env)->ReleaseStringUTFChars(env, role, r);
        (*env)->ReleaseStringUTFChars(env, content, c);
        (*env)->DeleteLocalRef(env, role);
        (*env)->DeleteLocalRef(env, content);
    }
    return (*env)->NewStringUTF(env, buf);
}

EXPORT JNIEXPORT jint JNICALL
Java_com_agent_aios_LlamaBridge_nativeInfer(
    JNIEnv *env, jobject thiz, jstring prompt, jint max_tokens) {
    g_n_past += (max_tokens > 0 ? max_tokens / 4 : 1);
    if (g_n_past > g_n_ctx) g_n_past = g_n_ctx;
    return 0;
}

EXPORT JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeReleaseModel(
    JNIEnv *env, jobject thiz) {
    g_model_loaded = 0;
    g_n_past = 0;
    g_loaded_path[0] = '\0';
}

EXPORT JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeResetContext(
    JNIEnv *env, jobject thiz) {
    g_n_past = 0;
}

EXPORT JNIEXPORT jboolean JNICALL
Java_com_agent_aios_LlamaBridge_nativeIsModelLoaded(
    JNIEnv *env, jobject thiz) {
    return g_model_loaded ? JNI_TRUE : JNI_FALSE;
}

EXPORT JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetModelInfo(
    JNIEnv *env, jobject thiz) {
    if (!g_model_loaded) return (*env)->NewStringUTF(env, "No model loaded");
    char info[512];
    snprintf(info, sizeof(info), "Stub model: %s (n_ctx=%d)", g_loaded_path, g_n_ctx);
    return (*env)->NewStringUTF(env, info);
}

EXPORT JNIEXPORT jstring JNICALL
Java_com_agent_aios_LlamaBridge_nativeGetContextUsage(
    JNIEnv *env, jobject thiz) {
    char usage[64];
    snprintf(usage, sizeof(usage), "%d/%d", g_n_past, g_n_ctx);
    return (*env)->NewStringUTF(env, usage);
}

EXPORT JNIEXPORT void JNICALL
Java_com_agent_aios_LlamaBridge_nativeSetSamplingParams(
    JNIEnv *env, jobject thiz, jfloat temperature, jint top_k, jfloat top_p, jfloat repeat_penalty) {
    g_temperature = temperature;
    g_top_k = top_k;
    g_top_p = top_p;
    g_repeat_penalty = repeat_penalty;
}
