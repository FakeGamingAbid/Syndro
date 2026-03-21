# Linux Desktop CMake configuration
# This file is required for Flutter Linux desktop support
cmake_minimum_required(VERSION 3.13)
project(moonplex LANGUAGES CXX)

set(BINARY_NAME "moonplex")
set(APPLICATION_ID "com.moonplex.app")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(flutter)

set(FLUTTER_LIBRARY "${FLUTTER_MANAGED_DIR}/libflutter_linux_gtk.so")

add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
)

apply_standard_settings(${BINARY_NAME})

target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK3)

add_dependencies(${BINARY_NAME} flutter_assemble)
