cmake_minimum_required(VERSION 3.18.1)
project("upscaler" CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Check if pre-built NCNN directory exists for the target ABI
set(NCNN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ncnn/${ANDROID_ABI}/lib/cmake/ncnn")

if(EXISTS "${NCNN_DIR}")
    set(ncnn_DIR "${NCNN_DIR}")
    find_package(ncnn REQUIRED)
    message(STATUS "[Upscaler] Found NCNN at ${ncnn_DIR}")
    set(HAVE_NCNN 1)
    add_definitions(-DHAVE_NCNN=1)
else()
    message(WARNING "[Upscaler] NCNN not found at ${NCNN_DIR}. Compiling in fallback mode.")
    set(HAVE_NCNN 0)
    add_definitions(-DHAVE_NCNN=0)
endif()

add_library(upscaler SHARED
    upscaler_bridge.cpp
)

find_library(log-lib log)
find_library(android-lib android)

if(HAVE_NCNN)
    target_include_directories(upscaler PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/ncnn/${ANDROID_ABI}/include
        ${CMAKE_CURRENT_SOURCE_DIR}/ncnn/${ANDROID_ABI}/include/ncnn
    )
    find_library(vulkan-lib vulkan)
    target_link_libraries(upscaler
        ncnn
        ${vulkan-lib}
        ${log-lib}
        ${android-lib}
    )
else()
    target_link_libraries(upscaler
        ${log-lib}
        ${android-lib}
    )
endif()
