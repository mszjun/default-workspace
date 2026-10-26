cmake_minimum_required(VERSION 3.25)
project(toolchain_smoke LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(smoke main.cpp)

if(MSVC)
  target_compile_options(smoke PRIVATE /W4 /permissive- /Zc:__cplusplus /utf-8)
else()
  target_compile_options(smoke PRIVATE -Wall -Wextra -Wpedantic)
endif()
