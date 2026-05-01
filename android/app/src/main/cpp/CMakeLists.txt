cmake_minimum_required(VERSION 3.18.1)
project("aios-native")

set(LLAMA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native/llama.cpp")

set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_LLGUIDANCE OFF CACHE BOOL "" FORCE)
set(LLAMA_OPENSSL OFF CACHE BOOL "" FORCE)

set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
set(GGML_RPC OFF CACHE BOOL "" FORCE)
set(GGML_SYCL OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(GGML_BLAS OFF CACHE BOOL "" FORCE)
set(GGML_LLAMAFILE ON CACHE BOOL "" FORCE)

add_subdirectory(${LLAMA_DIR} llama_cpp_build)

add_library(aios-native SHARED native-lib.cpp)

add_library(aios-crash SHARED crash-handler.cpp)

target_include_directories(aios-native PRIVATE
    ${LLAMA_DIR}/include
    ${LLAMA_DIR}/ggml/include
    ${LLAMA_DIR}/src
)

target_link_libraries(aios-native
    llama
    ggml
    log
)

target_link_libraries(aios-crash
    log
)
