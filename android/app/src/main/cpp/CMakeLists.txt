cmake_minimum_required(VERSION 3.18.1)
project(pc_emulator_native)

add_library(pc_emulator_native SHARED native_bridge.cpp)

find_library(log-lib log)
target_link_libraries(pc_emulator_native ${log-lib})