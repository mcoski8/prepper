cmake_minimum_required(VERSION 3.22.1)
project("tantivy_jni")

# Add the Tantivy JNI wrapper
add_library(tantivy_jni SHARED
    tantivy_jni.cpp
)

# Find required libraries
find_library(log-lib log)

# Include directories
include_directories(include)

# Link libraries
target_link_libraries(tantivy_jni
    ${log-lib}
    ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libtantivy_mobile.so
)