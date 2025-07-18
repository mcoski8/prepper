#include <jni.h>
#include <string>
#include <android/log.h>
#include "include/tantivy_mobile.h"

#define LOG_TAG "TantivyJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" {

JNIEXPORT void JNICALL
Java_com_prepperapp_TantivyBridge_nativeInitLogging(JNIEnv *env, jobject /* this */) {
    tantivy_init_logging();
    LOGI("Tantivy logging initialized");
}

JNIEXPORT jlong JNICALL
Java_com_prepperapp_TantivyBridge_nativeCreateIndex(JNIEnv *env, jobject /* this */, jstring path) {
    const char *nativePath = env->GetStringUTFChars(path, nullptr);
    void *index = tantivy_create_index(nativePath);
    env->ReleaseStringUTFChars(path, nativePath);
    
    if (index == nullptr) {
        LOGE("Failed to create index");
        return 0;
    }
    
    return reinterpret_cast<jlong>(index);
}

JNIEXPORT jlong JNICALL
Java_com_prepperapp_TantivyBridge_nativeOpenIndex(JNIEnv *env, jobject /* this */, jstring path) {
    const char *nativePath = env->GetStringUTFChars(path, nullptr);
    void *index = tantivy_open_index(nativePath);
    env->ReleaseStringUTFChars(path, nativePath);
    
    if (index == nullptr) {
        LOGE("Failed to open index");
        return 0;
    }
    
    return reinterpret_cast<jlong>(index);
}

JNIEXPORT jint JNICALL
Java_com_prepperapp_TantivyBridge_nativeAddDocument(
    JNIEnv *env,
    jobject /* this */,
    jlong indexPtr,
    jstring id,
    jstring title,
    jstring category,
    jint priority,
    jstring summary,
    jstring content
) {
    void *index = reinterpret_cast<void*>(indexPtr);
    
    const char *nativeId = env->GetStringUTFChars(id, nullptr);
    const char *nativeTitle = env->GetStringUTFChars(title, nullptr);
    const char *nativeCategory = env->GetStringUTFChars(category, nullptr);
    const char *nativeSummary = env->GetStringUTFChars(summary, nullptr);
    const char *nativeContent = env->GetStringUTFChars(content, nullptr);
    
    int32_t result = tantivy_add_document(
        index,
        nativeId,
        nativeTitle,
        nativeCategory,
        static_cast<uint64_t>(priority),
        nativeSummary,
        nativeContent
    );
    
    env->ReleaseStringUTFChars(id, nativeId);
    env->ReleaseStringUTFChars(title, nativeTitle);
    env->ReleaseStringUTFChars(category, nativeCategory);
    env->ReleaseStringUTFChars(summary, nativeSummary);
    env->ReleaseStringUTFChars(content, nativeContent);
    
    return result;
}

JNIEXPORT jint JNICALL
Java_com_prepperapp_TantivyBridge_nativeCommit(JNIEnv *env, jobject /* this */, jlong indexPtr) {
    void *index = reinterpret_cast<void*>(indexPtr);
    return tantivy_commit(index);
}

JNIEXPORT jobject JNICALL
Java_com_prepperapp_TantivyBridge_nativeSearch(
    JNIEnv *env,
    jobject /* this */,
    jlong indexPtr,
    jstring query,
    jint limit
) {
    void *index = reinterpret_cast<void*>(indexPtr);
    const char *nativeQuery = env->GetStringUTFChars(query, nullptr);
    
    SearchResults *results = tantivy_search(index, nativeQuery, limit);
    env->ReleaseStringUTFChars(query, nativeQuery);
    
    if (results == nullptr) {
        return nullptr;
    }
    
    // Get class references
    jclass searchResultClass = env->FindClass("com/prepperapp/TantivyBridge$SearchResultNative");
    jclass searchResultsClass = env->FindClass("com/prepperapp/TantivyBridge$SearchResultsNative");
    
    // Create result array
    jobjectArray resultArray = env->NewObjectArray(
        results->count,
        searchResultClass,
        nullptr
    );
    
    // Create SearchResultNative constructor
    jmethodID resultConstructor = env->GetMethodID(
        searchResultClass,
        "<init>",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;IF)V"
    );
    
    // Fill array with results
    for (size_t i = 0; i < results->count; i++) {
        SearchResult &result = results->results[i];
        
        jstring jId = env->NewStringUTF(result.id);
        jstring jTitle = env->NewStringUTF(result.title);
        jstring jCategory = env->NewStringUTF(result.category);
        jstring jSummary = env->NewStringUTF(result.summary);
        
        jobject jResult = env->NewObject(
            searchResultClass,
            resultConstructor,
            jId, jTitle, jCategory, jSummary,
            static_cast<jint>(result.priority),
            result.score
        );
        
        env->SetObjectArrayElement(resultArray, i, jResult);
        
        // Clean up local references
        env->DeleteLocalRef(jId);
        env->DeleteLocalRef(jTitle);
        env->DeleteLocalRef(jCategory);
        env->DeleteLocalRef(jSummary);
        env->DeleteLocalRef(jResult);
    }
    
    // Create SearchResultsNative
    jmethodID resultsConstructor = env->GetMethodID(
        searchResultsClass,
        "<init>",
        "([Lcom/prepperapp/TantivyBridge$SearchResultNative;J)V"
    );
    
    jobject jResults = env->NewObject(
        searchResultsClass,
        resultsConstructor,
        resultArray,
        static_cast<jlong>(results->search_time_ms)
    );
    
    // Free native results
    tantivy_free_search_results(results);
    
    return jResults;
}

JNIEXPORT void JNICALL
Java_com_prepperapp_TantivyBridge_nativeFreeSearchResults(JNIEnv *env, jobject /* this */, jlong resultsPtr) {
    // Not needed - we free immediately after converting to Java objects
}

JNIEXPORT void JNICALL
Java_com_prepperapp_TantivyBridge_nativeFreeIndex(JNIEnv *env, jobject /* this */, jlong indexPtr) {
    void *index = reinterpret_cast<void*>(indexPtr);
    tantivy_free_index(index);
}

JNIEXPORT jobject JNICALL
Java_com_prepperapp_TantivyBridge_nativeGetIndexStats(JNIEnv *env, jobject /* this */, jlong indexPtr) {
    void *index = reinterpret_cast<void*>(indexPtr);
    IndexStats stats = tantivy_get_index_stats(index);
    
    jclass statsClass = env->FindClass("com/prepperapp/TantivyBridge$IndexStats");
    jmethodID constructor = env->GetMethodID(statsClass, "<init>", "(JJ)V");
    
    return env->NewObject(
        statsClass,
        constructor,
        static_cast<jlong>(stats.num_docs),
        static_cast<jlong>(stats.index_size_bytes)
    );
}

} // extern "C"