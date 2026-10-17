# rb2 desktop build: Windows build of the recompiled game on the stock ReXGlue SDK.
#
# Windows (native):  tools/desktop/build_windows.ps1   (see WINDOWS.md)
# Windows (cross, from Linux): tools/desktop/build_windows.sh (maintainer's layout)

cmake_minimum_required(VERSION 3.25)
project(rb2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(../config/generated/rexglue.cmake)

set(RB2_REXGLUE_HOST_EXECUTABLE "" CACHE FILEPATH
    "Native rexglue executable used for codegen while cross-compiling")
if(CMAKE_CROSSCOMPILING)
    if(NOT RB2_REXGLUE_HOST_EXECUTABLE OR NOT EXISTS "${RB2_REXGLUE_HOST_EXECUTABLE}")
        message(FATAL_ERROR "Cross-compiling requires -DRB2_REXGLUE_HOST_EXECUTABLE=/path/to/native/rexglue")
    endif()
    set_target_properties(rex::rexglue PROPERTIES
        IMPORTED_LOCATION "${RB2_REXGLUE_HOST_EXECUTABLE}"
        IMPORTED_LOCATION_RELEASE "${RB2_REXGLUE_HOST_EXECUTABLE}"
        IMPORTED_LOCATION_RELWITHDEBINFO "${RB2_REXGLUE_HOST_EXECUTABLE}")
endif()

set(RB2_SOURCES main.cpp)
if(WIN32)
    list(APPEND RB2_SOURCES win_math_compat.cpp)
    add_executable(rb2 WIN32 ${RB2_SOURCES})
else()
    add_executable(rb2 ${RB2_SOURCES})
endif()

# GPU_PLUGINS xenos copies the renderer plugin (rexgpu-xenos.dll) next to rb2.exe; without it the game
# starts and draws nothing.
rexglue_setup_target(rb2 GPU_PLUGINS xenos)
target_include_directories(rb2 PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../../src
    # main.cpp includes "generated/default/rb2_init.h"; codegen writes to desktop/generated/default.
    # An include path instead of a desktop/game/generated symlink (symlinks need admin on Windows).
    ${CMAKE_CURRENT_SOURCE_DIR}/..)
