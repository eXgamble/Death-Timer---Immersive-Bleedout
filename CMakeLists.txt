cmake_minimum_required(VERSION 3.21)
project(DeathTimer VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# CommonLibSSE-NG (alandtse ng, git submodule, pinned to v10.0.0). AE only: 1.6.x and 1.7.x.
set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(ENABLE_SKYRIM_SE OFF CACHE BOOL "" FORCE)
set(ENABLE_SKYRIM_AE ON CACHE BOOL "" FORCE)
set(ENABLE_SKYRIM_VR OFF CACHE BOOL "" FORCE)
add_subdirectory(lib/commonlibsse-ng commonlib)

# a plain source add_subdirectory does not define the plugin helper
if(NOT COMMAND add_commonlibsse_plugin)
	include(lib/commonlibsse-ng/cmake/CommonLibSSE.cmake)
endif()

add_commonlibsse_plugin(${PROJECT_NAME}
	NAME "DeathTimer"
	AUTHOR "eXgamble"
	SOURCES src/plugin.cpp src/Hooks.cpp)

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_23)
target_compile_options(${PROJECT_NAME} PRIVATE /Zc:preprocessor /permissive- /EHsc /utf-8 /W4)
target_compile_definitions(${PROJECT_NAME} PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX UNICODE _UNICODE)
target_include_directories(${PROJECT_NAME} PRIVATE src)
target_precompile_headers(${PROJECT_NAME} PRIVATE src/PCH.h)

# Copy the DLL + PDB into a separate MO2 test mod after every build
set(DEPLOY_DIR "C:/Modding/MO2/mods/Death Timer SKSE Test/SKSE/Plugins" CACHE PATH "Where the built DLL is copied")
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E make_directory "${DEPLOY_DIR}"
	COMMAND ${CMAKE_COMMAND} -E copy_if_different "$<TARGET_FILE:${PROJECT_NAME}>" "${DEPLOY_DIR}"
	COMMAND ${CMAKE_COMMAND} -E copy_if_different "$<TARGET_PDB_FILE:${PROJECT_NAME}>" "${DEPLOY_DIR}"
	VERBATIM)
