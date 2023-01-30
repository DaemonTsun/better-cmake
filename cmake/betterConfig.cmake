
# version 1.0

# by default color output is only generated for Make for some reason
add_compile_options (-fdiagnostics-color=always)

# versions
cmake_policy(SET CMP0048 NEW)

macro(get_version_target OUT_VAR NAME)
    set(${OUT_VAR} "${NAME}-${PROJECT_VERSION}")
endmacro()

macro(find_sources OUT_VAR SRC_DIR)
    file(GLOB_RECURSE ${OUT_VAR} "${SRC_DIR}/*.c" "${SRC_DIR}/*.cpp")
endmacro()

macro(find_headers OUT_VAR SRC_DIR)
    file(GLOB_RECURSE ${OUT_VAR} "${SRC_DIR}/*.h" "${SRC_DIR}/*.hpp")
endmacro()

macro(install_library)
    set(_OPTIONS)
    set(_SINGLE_VAL_ARGS TARGET)
    set(_MULTI_VAL_ARGS HEADERS)

    cmake_parse_arguments(INSTALL_LIBRARY "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})

    if (NOT DEFINED INSTALL_LIBRARY_TARGET)
        message(FATAL_ERROR "install_library: missing TARGET")
    endif()

    if (DEFINED INSTALL_LIBRARY_HEADERS)
        install(FILES ${INSTALL_LIBRARY_HEADERS} DESTINATION "include/${INSTALL_LIBRARY_TARGET}/${PROJECT_NAME}")
    endif()

    install(TARGETS "${INSTALL_LIBRARY_TARGET}"
            RUNTIME DESTINATION "bin"
            LIBRARY DESTINATION "lib"
            ARCHIVE DESTINATION "lib/${INSTALL_LIBRARY_TARGET}")
endmacro()

macro(install_executable)
    set(_OPTIONS)
    set(_SINGLE_VAL_ARGS TARGET)
    set(_MULTI_VAL_ARGS)

    cmake_parse_arguments(INSTALL_EXECUTABLE "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})

    if (NOT DEFINED INSTALL_EXECUTABLE_TARGET)
        message(FATAL_ERROR "install_executable: missing TARGET")
    endif()

    install(TARGETS "${INSTALL_EXECUTABLE_TARGET}" DESTINATION bin)
endmacro()
