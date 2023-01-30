cmake_minimum_required(VERSION 3.10)

project(better-cmake)

set(SOURCE_CMAKE_CONFIG_FILE "${CMAKE_SOURCE_DIR}/cmake/betterConfig.cmake")

install(FILES "${SOURCE_CMAKE_CONFIG_FILE}" DESTINATION "share/${PROJECT_NAME}/cmake")
