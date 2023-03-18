
# version 1.3

set(BETTER_CMAKE_VERSION_MAJOR 1)
set(BETTER_CMAKE_VERSION_MINOR 3)
set(BETTER_CMAKE_VERSION "${BETTER_CMAKE_VERSION_MAJOR}.${BETTER_CMAKE_VERSION_MINOR}")
set(ROOT     "${CMAKE_CURRENT_SOURCE_DIR}")
set(ROOT_BIN "${CMAKE_CURRENT_SOURCE_DIR}")

message(VERBOSE "better-cmake v${BETTER_CMAKE_VERSION} from ${ROOT}")

# by default color output is only generated for Make for some reason
add_compile_options (-fdiagnostics-color=always)

# versions
cmake_policy(SET CMP0048 NEW)

# basic functionality
macro(increment VAR)
    MATH(EXPR ${VAR} "${${VAR}}+1")
endmacro()

macro(decrement VAR)
    MATH(EXPR ${VAR} "${${VAR}}-1")
endmacro()

macro(set_default VAR DEFAULT)
    if (NOT DEFINED ${VAR})
        set(${VAR} ${DEFAULT})
    endif()
endmacro()

macro(set_export VAR)
    if (DEFINED ${VAR})
        set(${VAR} ${${VAR}} PARENT_SCOPE)
    endif()
endmacro()

# etc
macro(project_author NAME)
    set(_OPTIONS)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS EMAIL)

    cmake_parse_arguments(PROJECT_AUTHOR "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})

    set(PROJECT_AUTHOR "${NAME}")
    set(${PROJECT_NAME}_AUTHOR "${NAME}")

    if (DEFINED PROJECT_AUTHOR_EMAIL)
        set(PROJECT_EMAIL ${PROJECT_AUTHOR_EMAIL})
        set(${PROJECT_NAME}_EMAIL ${PROJECT_AUTHOR_EMAIL})
    endif()
endmacro()

macro(find_sources OUT_VAR SRC_DIR)
    file(GLOB_RECURSE ${OUT_VAR} "${SRC_DIR}/*.c" "${SRC_DIR}/*.cpp")
endmacro()

macro(find_headers OUT_VAR SRC_DIR)
    file(GLOB_RECURSE ${OUT_VAR} "${SRC_DIR}/*.h" "${SRC_DIR}/*.hpp")
endmacro()

macro(exit_if_included)
    if (NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
        return()
    endif()
endmacro()

# install_library: set install targets for the given target library.
# usage: install_library(TARGET <target> HEADERS <headers>)
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

# install_executable: set install targets for the given target executable.
# usage: install_executable(TARGET <target>)
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

macro(export_library_variables NAME)
    set_export(${NAME}_VERSION)
    set_export(${NAME}_VERSION_MAJOR)
    set_export(${NAME}_VERSION_MINOR)
    set_export(${NAME}_VERSION_PATCH)
    set_export(${NAME}_SOURCES_DIR)
    set_export(${NAME}_LIBRARIES)
    set_export(${NAME}_SOURCES)
    set_export(${NAME}_INCLUDE_DIRECTORIES)
    set_export(${NAME}_HEADERS)
endmacro()

macro(_unversion_variable NAME VNAME VAR)
    set("${NAME}${VAR}" "${${VNAME}${VAR}}")
endmacro()

macro(unversion_library_variables NAME VNAME)
    set(${NAME}_TARGET ${VNAME})
    _unversion_variable(${NAME} ${VNAME} _VERSION)
    _unversion_variable(${NAME} ${VNAME} _VERSION_MAJOR)
    _unversion_variable(${NAME} ${VNAME} _VERSION_MINOR)
    _unversion_variable(${NAME} ${VNAME} _VERSION_PATCH)
    _unversion_variable(${NAME} ${VNAME} _SOURCES_DIR)
    _unversion_variable(${NAME} ${VNAME} _LIBRARIES)
    _unversion_variable(${NAME} ${VNAME} _SOURCES)
    _unversion_variable(${NAME} ${VNAME} _INCLUDE_DIRECTORIES)
    _unversion_variable(${NAME} ${VNAME} _HEADERS)
endmacro()

# split_version_string: splits the given VERSION string into
# MAJOR, MINOR and PATCH out variables.
# MINOR and PATCH are optional.
macro(split_version_string VERSION OUT_MAJOR OUT_MINOR OUT_PATCH)
    string(REPLACE "." ";" _VERSION_LIST "${VERSION}")
    list(LENGTH _VERSION_LIST _LIST_LEN)

    list(GET _VERSION_LIST 0 ${OUT_MAJOR})

    if (_LIST_LEN GREATER 1)
        list(GET _VERSION_LIST 1 ${OUT_MINOR})

        if (_LIST_LEN GREATER 2)
            list(GET _VERSION_LIST 2 ${OUT_PATCH})
        else()
            set(${OUT_PATCH} 0)
        endif()
    else()
        set(${OUT_MINOR} 0)
        set(${OUT_PATCH} 0)
    endif()

    unset(_VERSION_LIST)
endmacro()

# compare_versions: sets OUT_VAR to -1 if V1 is less than V2
#                                    0 if V1 is equal to V2
#                                    1 if V1 is greater than V2
macro(compare_versions OUT_VAR V1 V2)
    split_version_string("${V1}" V1_MAJOR V1_MINOR V1_PATCH)
    split_version_string("${V2}" V2_MAJOR V2_MINOR V2_PATCH)

    if (V1_MAJOR LESS V2_MAJOR)
        set(${OUT_VAR} -1)
    elseif (V1_MAJOR GREATER V2_MAJOR)
        set(${OUT_VAR} 1)
    else()
        if (V1_MINOR LESS V2_MINOR)
            set(${OUT_VAR} -1)
        elseif (V1_MINOR GREATER V2_MINOR)
            set(${OUT_VAR} 1)
        else()
            if (V1_PATCH LESS V2_PATCH)
                set(${OUT_VAR} -1)
            elseif (V1_PATCH GREATER V2_PATCH)
                set(${OUT_VAR} 1)
            else()
                set(${OUT_VAR} 0)
            endif()
        endif()
    endif()
endmacro()

# generate_target_header: generates a C(++) header file containing
# macros about the target, the target version and project author
# at the given path.
macro(generate_target_header NAME VNAME OUT_PATH)
    if (NOT DEFINED "${VNAME}_VERSION")
        message(FATAL_ERROR "generate_target_header: missing ${VNAME}_VERSION")
    endif()

    set(_HEADER "// this file was generated by better-cmake\n")
    set(_HEADER "${_HEADER}// ${NAME} v${${VNAME}_VERSION}\n\n")

    set(_HEADER "${_HEADER}#define ${NAME}_NAME \"${NAME}\"\n")

    if(DEFINED PROJECT_AUTHOR) 
        set(_HEADER "${_HEADER}#define ${NAME}_AUTHOR \"${PROJECT_AUTHOR}\"\n")
    endif()

    if(DEFINED PROJECT_AUTHOR_EMAIL) 
        set(_HEADER "${_HEADER}#define ${NAME}_AUTHOR_EMAIL \"${PROJECT_AUTHOR_EMAIL}\"\n")
    endif()

    set(_HEADER "${_HEADER}#define ${NAME}_VERSION \"${${VNAME}_VERSION}\"\n")
    set(_HEADER "${_HEADER}#define ${NAME}_VERSION_MAJOR ${${VNAME}_VERSION_MAJOR}\n")
    set(_HEADER "${_HEADER}#define ${NAME}_VERSION_MINOR ${${VNAME}_VERSION_MINOR}\n")
    set(_HEADER "${_HEADER}#define ${NAME}_VERSION_PATCH ${${VNAME}_VERSION_PATCH}\n")

    file(WRITE "${OUT_PATH}" "${_HEADER}")

    unset(_HEADER)
endmacro()

# target_cpp_warnings: enables C(++) compiler warnings
macro(target_cpp_warnings TARGET)
    set(_OPTIONS ALL EXTRA PEDANTIC)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS)

    cmake_parse_arguments(TARGET_CPP_WARNINGS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (TARGET_CPP_WARNINGS_ALL)
        target_compile_options(${TARGET} PRIVATE -Wall)
    endif()

    if (TARGET_CPP_WARNINGS_EXTRA)
        target_compile_options(${TARGET} PRIVATE -Wextra)
    endif()

    if (TARGET_CPP_WARNINGS_PEDANTIC)
        target_compile_options(${TARGET} PRIVATE -Wpedantic)
    endif()
endmacro()

# target_cpp_version: sets the C++ version of the target
macro(target_cpp_version OUT_VAR TARGET VERSION)
    set_property(TARGET "${TARGET}" PROPERTY CXX_STANDARD "${VERSION}")
    set("${OUT_VAR}" "${VERSION}")
endmacro()

macro(get_version_name OUT_VAR NAME VERSION)
    set(${OUT_VAR} "${NAME}-${VERSION}")
endmacro()

# this effectively makes ARGN a list within a string
macro(list_pack OUT_VAR)
    string(REPLACE ";" "\;" ${OUT_VAR} "${ARGN}") 
endmacro()

# parses arguments by delimiter into a list of lists and writes the
# list of lists to OUT_VAR.
# example:
# parse_arguments_by_delimiter(OUT LIB
#                                  LIB a b c
#                                  LIB d e f)
# foreach (ARGS ${OUT})
#   message("${ARGS}")
# endforeach()
#
# prints: a b c
#         d e f
macro(parse_arguments_by_delimiter OUT_VAR DELIM)
    set(INDEX 0)
    set(_ARGN ${ARGN}) # huh
    list(SUBLIST _ARGN 1 -1 _ARGN)

    while (INDEX GREATER -1)
        list(FIND _ARGN "${DELIM}" INDEX)

        if (INDEX GREATER -1)
            list(SUBLIST _ARGN 0 ${INDEX} TMP)
            list_pack(TMP ${TMP})
            list(APPEND ${OUT_VAR} "${TMP}")

            increment(INDEX)
            list(SUBLIST _ARGN ${INDEX} -1 _ARGN)
        endif()
    endwhile()

    if (_ARGN)
        list(SUBLIST _ARGN 0 -1 TMP)
        list_pack(TMP ${TMP})
        list(APPEND ${OUT_VAR} "${TMP}")
    endif()
endmacro()

macro(include_subdirectory PATH)
    if (NOT "${PATH}" IN_LIST INCLUDED_DIRS)
        list(APPEND INCLUDED_DIRS "${PATH}")
        add_subdirectory("${PATH}")
    endif()
endmacro()

# add_external_dependency: add an external dependency from a directory.
# the dependency should also be created with better-cmake.
# example:
#   add_lib(myLib ...)
#   add_external_dependency(${myLib_TARGET} shl 0.6.0 ext/shl)
macro(add_external_dependency TARGET EXTNAME EXTVERSION EXTPATH)
    set(_OPTIONS INCLUDE LINK)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS)

    cmake_parse_arguments(_ADD_LIB_EXT "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})

    if (NOT IS_DIRECTORY "${EXTPATH}")
        message(FATAL_ERROR "add_external_dependency: path ${EXTPATH} of external dependency ${EXTNAME} does not exist.")
    endif()

    split_version_string("${EXTVERSION}" _EXTMAJOR _EXTMINOR _EXTPATCH)
    get_version_name(_EXTNAME "${EXTNAME}" "${_EXTMAJOR}.${_EXTMINOR}.${_EXTPATCH}")

    include_subdirectory("${EXTPATH}")

    if (NOT TARGET "${_EXTNAME}")
        message(FATAL_ERROR "add_external_dependency: external dependency ${EXTNAME} version ${EXTVERSION} not found after including path ${EXTPATH}.")
    endif()

    if (_ADD_LIB_EXT_INCLUDE)
        if (NOT DEFINED "${_EXTNAME}_SOURCES_DIR")
            message(FATAL_ERROR "add_external_dependency: external dependency ${EXTNAME} did not define required variable ${_EXTNAME}_SOURCES_DIR needed for include paths.")
        endif()

        include_directories("${TARGET}" PRIVATE "${${_EXTNAME}_SOURCES_DIR}")
        list(APPEND "${TARGET}_INCLUDE_DIRECTORIES" "${${_EXTNAME}_SOURCES_DIR}")
    endif()

    if (_ADD_LIB_EXT_LINK)
        list(APPEND "${TARGET}_LIBRARIES" "${_EXTNAME}")
    endif()
endmacro()

macro(_add_lib_exts TARGET)
    parse_arguments_by_delimiter(_GROUPS LIB ${ARGN})

    foreach (ARGS ${_GROUPS})
        add_external_dependency(${TARGET} ${ARGS})
    endforeach()
endmacro()

macro(add_lib NAME LINKAGE)
    set(_OPTIONS PIE)
    set(_SINGLE_VAL_ARGS
        VERSION                 # version of the target
        SOURCES_DIR             # top directory of all source files, if "src" folder is present, can be omitted
        GENERATE_TARGET_HEADER  # path to target header file
        CPP_VERSION             # defaults to 20 if omitted
        )
    set(_MULTI_VAL_ARGS
        CPP_WARNINGS            # ALL, EXTRA, PEDANTIC
        TESTS                   # tests or directories of tests
        SOURCES                 # extra sources, optional
        INCLUDE_DIRS            # extra include directories, optional
        LIBRARIES               # libraries to link
        EXT                     # external dependencies
        )

    cmake_parse_arguments(ADD_LIB "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (NOT DEFINED ADD_LIB_VERSION)
        set(ADD_LIB_VERSION 0.0.0)
    endif()

    split_version_string(${ADD_LIB_VERSION} _MAJOR _MINOR _PATCH)
    get_version_name(_NAME "${NAME}" "${_MAJOR}.${_MINOR}.${_PATCH}")

    if (TARGET "${_NAME}")
        message(STATUS "better-cmake: found existing target ${NAME} version ${ADD_LIB_VERSION}, skipping duplicate.")
    else()
        # different version, add it

        # set versions
        set("${_NAME}_VERSION" "${_MAJOR}.${_MINOR}.${_PATCH}")
        set("${_NAME}_VERSION_MAJOR" "${_MAJOR}")
        set("${_NAME}_VERSION_MINOR" "${_MINOR}")
        set("${_NAME}_VERSION_PATCH" "${_PATCH}")

        add_library("${_NAME}" ${LINKAGE})
    
        if (NOT DEFINED ADD_LIB_SOURCES_DIR)
            if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/")
                message(VERBOSE "better-cmake: using default source directory ${CMAKE_CURRENT_SOURCE_DIR}/src/")
                set(${_NAME}_SOURCES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/")
            else()
                message(FATAL_ERROR "better-cmake: add_lib requires parameter SOURCES_DIR")
            endif()
        else()
            set(${_NAME}_SOURCES_DIR "${ADD_LIB_SOURCES_DIR}")
        endif()

        if (DEFINED ADD_LIB_GENERATE_TARGET_HEADER)
            generate_target_header("${NAME}" "${_NAME}" "${ADD_LIB_GENERATE_TARGET_HEADER}")
        endif()

        find_sources("${_NAME}_SOURCES" "${${_NAME}_SOURCES_DIR}")
        find_headers("${_NAME}_HEADERS" "${${_NAME}_SOURCES_DIR}")

        target_sources(${_NAME} PRIVATE ${${_NAME}_HEADERS} ${${_NAME}_SOURCES} ${ADD_LIB_SOURCES})

        if (NOT DEFINED ADD_LIB_CPP_VERSION)
            set(ADD_LIB_CPP_VERSION 20)
        endif()

        target_cpp_version("${_NAME}_CPP_VERSION" "${_NAME}" ${ADD_LIB_CPP_VERSION})

        if (DEFINED ADD_LIB_CPP_WARNINGS)
            target_cpp_warnings("${_NAME}" ${ADD_LIB_CPP_WARNINGS})
        endif()

        if (DEFINED ADD_LIB_INCLUDE_DIRS)
            list(APPEND "${_NAME}_INCLUDE_DIRECTORIES" ${ADD_LIB_LIBRARIES})
        endif()

        if (DEFINED ADD_LIB_LIBRARIES)
            list(APPEND "${_NAME}_LIBRARIES" ${ADD_LIB_LIBRARIES})
        endif()

        if (ADD_LIB_PIE)
            set_property(TARGET "${_NAME}" PROPERTY POSITION_INDEPENDENT_CODE ON)
        endif()

        if (DEFINED ADD_LIB_EXT)
            _add_lib_exts("${_NAME}" ${ADD_LIB_EXT})
        endif()

        target_include_directories(${_NAME} PRIVATE "${${_NAME}_SOURCES_DIR}" "${${_NAME}_INCLUDE_DIRECTORIES}")

        if (DEFINED "${_NAME}_LIBRARIES")
            target_link_libraries("${_NAME}" PRIVATE ${${_NAME}_LIBRARIES})
        endif()

        if (NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
            export_library_variables("${_NAME}")
        else()
            unversion_library_variables("${NAME}" "${_NAME}")

            install_library(TARGET "${_NAME}" HEADERS ${${_NAME}_HEADERS})

            if (DEFINED ADD_LIB_TESTS)
                find_package(t1 QUIET)

                if (t1_FOUND)
                    foreach (_TEST ${ADD_LIB_TESTS})
                        if (IS_DIRECTORY "${_TEST}")
                            add_test_directory("${_TEST}"
                                INCLUDE_DIRS "${${_NAME}_SOURCES_DIR}" ${${_NAME}_INCLUDE_DIRECTORIES}
                                LIBRARIES ${_NAME} ${${_NAME}_LIBRARIES}
                                CPP_VERSION ${${_NAME}_CPP_VERSION}
                                CPP_WARNINGS ${ADD_LIB_CPP_WARNINGS}
                                )
                        else()
                            add_test("${_TEST}"
                                CPP_VERSION ${${_NAME}_CPP_VERSION}
                                CPP_WARNINGS ${ADD_LIB_CPP_WARNINGS}
                                INCLUDE_DIRS "${${_NAME}_SOURCES_DIR}" ${${_NAME}_INCLUDE_DIRECTORIES}
                                LIBRARIES ${_NAME} ${${_NAME}_LIBRARIES})
                        endif()
                    endforeach()

                    register_tests()
                endif()
            endif()
        endif()
    endif()
endmacro()
