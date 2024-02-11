
# version 2.4
# version 2.4: w64devkit / GCC Windows support
# version 2.3: compiler and linker flags
# version 2.2: better MSVC support
# version 2:   some Windows support

set(BETTER_CMAKE_VERSION_MAJOR 2)
set(BETTER_CMAKE_VERSION_MINOR 4)
set(BETTER_CMAKE_VERSION "${BETTER_CMAKE_VERSION_MAJOR}.${BETTER_CMAKE_VERSION_MINOR}")
set(ROOT     "${CMAKE_CURRENT_SOURCE_DIR}")
set(ROOT_BIN "${CMAKE_CURRENT_BINARY_DIR}")

message(VERBOSE "better-cmake v${BETTER_CMAKE_VERSION} from ${ROOT}, using CMake version ${CMAKE_VERSION}")

# defaults
set(better_DEFAULT_CXX_STANDARD 20)

set(CMAKE_CXX_FLAGS "" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_DEBUG "" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_RELEASE "-DNDEBUG" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_DEBUG "" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "" CACHE STRING "" FORCE)
set(CMAKE_C_COMPILER_WORKS 1)
set(CMAKE_CXX_COMPILER_WORKS 1)

# build type, SOMEHOW if you don't specify CMAKE_BUILD_TYPE, you get
# neither Debug nor Release. amazing work CMake.
# this sets build type to Debug if not specified.
if (DEFINED Build)
    set(CMAKE_BUILD_TYPE "${Build}" CACHE STRING "" FORCE)
    set(Build "${Build}" CACHE STRING "the build type" FORCE)
elseif (NOT CMAKE_BUILD_TYPE)
    if (NOT DEFINED Build) 
        set(Build Debug CACHE STRING "the build type" FORCE)
    endif()

    set(CMAKE_BUILD_TYPE "${Build}" CACHE STRING "" FORCE)
endif()

# preferred compiler, is handled at the bottom
if (DEFINED Compiler)
    set(Compiler "${Compiler}" CACHE STRING "the preferred compiler" FORCE)
endif()

if (DEFINED Tests)
    set(Tests "${Tests}" CACHE STRING "whether or not to build tests" FORCE)
endif()

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

macro(set_cache VAR VALUE)
    set(${VAR} ${VALUE} CACHE STRING "" FORCE)
endmacro()

macro(set_export VAR)
    if (DEFINED ${VAR})
        set(${VAR} ${${VAR}} PARENT_SCOPE)
    endif()
endmacro()



# platform vars
if (WIN32)
    set_cache(Windows 1)
    set_cache(Linux 0)
    set_cache(Mac 0)
    set_cache(Platform "Windows")
elseif (APPLE)
    set_cache(Windows 0)
    set_cache(Linux 0)
    set_cache(Mac 1)
    set_cache(Platform "Mac")
elseif (UNIX)
    set_cache(Windows 0)
    set_cache(Linux 1)
    set_cache(Mac 0)
    set_cache(Platform "Linux")
else()
    # huh??
    set_cache(Windows 0)
    set_cache(Linux 0)
    set_cache(Mac 0)
endif()



# versions
cmake_policy(SET CMP0048 NEW)

find_program(git_PROGRAM git)

# some functions
macro(get_git_submodule_checkout_commit OUT_VAR PATH)
    execute_process(COMMAND "${git_PROGRAM}" submodule status --cached "${PATH}"
                    OUTPUT_VARIABLE _git_result
                    WORKING_DIRECTORY "${ROOT}") 

    string(REGEX MATCH ".([a-z0-9]+)" _ "${_git_result}")
    set(${OUT_VAR} "${CMAKE_MATCH_1}")
endmacro()

macro(get_git_submodule_status OUT_VAR PATH)
    execute_process(COMMAND "${git_PROGRAM}" submodule status --cached "${PATH}"
                    OUTPUT_VARIABLE _git_result
                    WORKING_DIRECTORY "${ROOT}") 

    string(REGEX MATCH "(.)" _ "${_git_result}")
    set(${OUT_VAR} "${CMAKE_MATCH_1}")
endmacro()

macro(git_submodule_update PATH)
    set(_OPTIONS INIT)
    set(_SINGLE_VAL_ARGS WORKING_DIRECTORY)
    set(_MULTI_VAL_ARGS)

    cmake_parse_arguments(GSU "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})

    if (GSU_INIT)
        set(GSU_INIT "--init")
    endif()

    if (NOT GSU_WORKING_DIRECTORY)
        set(GSU_WORKING_DIRECTORY "${ROOT}")
    endif()

    execute_process(COMMAND "${git_PROGRAM}" submodule update "${GSU_INIT}" "${PATH}"
        WORKING_DIRECTORY "${GSU_WORKING_DIRECTORY}") 
endmacro()

# gets the deepest common path among all arguments, e.g.
# get_deepest_common_parent_path(DIR "/home/user/testfile.txt"
#                                    "/home/user/directory"
#                                    "/home/user/dev/git/better-cmake")
# message("${DIR}")
#
# results in:
# /home/user
#
macro(get_deepest_common_parent_path OUT_VAR)
    set(_PARENT "${ARGV1}")
    
    foreach (_PATH ${ARGN})
        set(_START "")

        if (IS_DIRECTORY "${_PATH}")
            set(_START "${_PATH}")
        else()
            cmake_path(GET _PATH PARENT_PATH _START)
        endif()

        set(_END FALSE)
        while (NOT _END)
            cmake_path(IS_PREFIX _PARENT "${_START}" _IS_PARENT)

            if (NOT _IS_PARENT)
                cmake_path(GET _PARENT PARENT_PATH _TMP)

                # we test this to see if we're at the root.
                # this would fail on different roots otherwise
                if (_TMP STREQUAL _PARENT)
                    set(_END TRUE)
                else()
                    set(_PARENT "${_TMP}")
                endif()
            else()
                set(_END TRUE)
            endif()
        endwhile()
    endforeach()

    set(${OUT_VAR} "${_PARENT}")
endmacro()

# used internally
macro(_copy_files_base DO_TARGET TARGET_VAR)
    set(_OPTIONS)
    set(_SINGLE_VAL_ARGS DESTINATION BASE)
    set(_MULTI_VAL_ARGS FILES)

    cmake_parse_arguments(COPY_FILES_BASE "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})

    if (NOT DEFINED COPY_FILES_BASE_FILES)
        message(FATAL_ERROR "copy_files_target: missing FILES")
    endif()

    if (NOT DEFINED COPY_FILES_BASE_DESTINATION)
        message(FATAL_ERROR "copy_files_target: missing DESTINATION")
    endif()

    if (NOT DEFINED COPY_FILES_BASE_BASE)
        get_deepest_common_parent_path(COPY_FILES_BASE_BASE ${COPY_FILES_BASE_FILES} "${COPY_FILES_BASE_DESTINATION}")
    endif()

    file(MAKE_DIRECTORY "${DEST_DIR}")

    foreach(_FILE ${COPY_FILES_BASE_FILES})
        cmake_path(RELATIVE_PATH _FILE BASE_DIRECTORY "${COPY_FILES_BASE_BASE}" OUTPUT_VARIABLE _REL_FILE)
        set(_OUT_FILE "${COPY_FILES_BASE_DESTINATION}/${_REL_FILE}")
        cmake_path(GET _OUT_FILE PARENT_PATH _PARENT)

        file(MAKE_DIRECTORY "${_PARENT}")
        message(DEBUG "copying file ${_FILE}")
        
        if (${DO_TARGET})
            add_custom_command(
                OUTPUT "${_OUT_FILE}"
                COMMAND ${CMAKE_COMMAND} "-E" "copy" "${_FILE}" "${_OUT_FILE}"
                DEPENDS "${_FILE}")
        else()
            configure_file("${_FILE}" "${_OUT_FILE}" COPYONLY)
        endif()

        list(APPEND ${TARGET_VAR} "${_OUT_FILE}")
    endforeach()
endmacro()

# copy_files: copies the input files FILES to DESTINATION
# (relative to base BASE, default is deepest common path among all input files and
# destination) at configure time, and overwrites them if source files are
# newer.
macro(copy_files)
    _copy_files_base(FALSE _ ${ARGN})
endmacro()

# copy_files_target: copies the input files FILES to DESTINATION
# (relative to base BASE, default is deepest common path among all input files and
# destination) as a target, and writes the targets to TARGET_VAR.
macro(copy_files_target TARGET_VAR)
    _copy_files_base(TRUE ${TARGET_VAR} ${ARGN})
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

macro(find_t1)
    set(t1_FOUND FALSE)
    unset(t1_BASE_DIR)

    if (CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR AND DEFINED Tests)
        if (EXISTS "${CMAKE_SOURCE_DIR}/ext/t1" AND
            NOT EXISTS "${CMAKE_SOURCE_DIR}/ext/t1/cmake/t1Config.cmake")
            execute_process(COMMAND "${git_PROGRAM}" submodule update --init "${CMAKE_SOURCE_DIR}/ext/t1"
                            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}") 
        endif()

        find_package(t1 QUIET PATHS "${CMAKE_SOURCE_DIR}/ext/t1/cmake" NO_DEFAULT_PATH)

        if (t1_FOUND)
            set(t1_BASE_DIR "${CMAKE_SOURCE_DIR}/ext/t1")
        else()
            if (EXISTS "${Tests}" AND IS_DIRECTORY "${Tests}")
                find_package(t1 QUIET PATHS "${Tests}" NO_DEFAULT_PATH)
            endif()

            if (t1_FOUND)
                set(t1_BASE_DIR "${Tests}")
            else()
                find_package(t1 QUIET)
                unset(t1_BASE_DIR)
            endif()
        endif()

        if (DEFINED t1_BASE_DIR)
            set(t1_SOURCE_DIR "${t1_BASE_DIR}/src")
        endif()
    endif()
endmacro()

# install_library: set install targets for the given target library.
# usage: install_library(TARGET <target> HEADERS <headers> SOURCES_DIR <dir>)
# prefer to use SOURCES_DIR, not HEADERS
macro(install_library)
    set(_OPTIONS)
    set(_SINGLE_VAL_ARGS TARGET)
    set(_MULTI_VAL_ARGS HEADERS SOURCES_DIR)

    cmake_parse_arguments(INSTALL_LIBRARY "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})

    if (NOT DEFINED INSTALL_LIBRARY_TARGET)
        message(FATAL_ERROR "install_library: missing TARGET")
    endif()

    if (DEFINED INSTALL_LIBRARY_HEADERS)
        install(FILES ${INSTALL_LIBRARY_HEADERS}
                DESTINATION "include/${INSTALL_LIBRARY_TARGET}/${PROJECT_NAME}")
    endif()

    if (DEFINED INSTALL_LIBRARY_SOURCES_DIR)
        install(DIRECTORY "${INSTALL_LIBRARY_SOURCES_DIR}/"
                DESTINATION "include/${INSTALL_LIBRARY_TARGET}"
                FILES_MATCHING REGEX ".*\\.(h|hpp)"
        )
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
    set(_SINGLE_VAL_ARGS TARGET NAME)
    set(_MULTI_VAL_ARGS)

    cmake_parse_arguments(INSTALL_EXECUTABLE "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})

    if (NOT DEFINED INSTALL_EXECUTABLE_TARGET)
        message(FATAL_ERROR "install_executable: missing TARGET")
    endif()

    if (DEFINED INSTALL_EXECUTABLE_NAME)
        if (Windows)
            add_custom_command(TARGET "${INSTALL_EXECUTABLE_TARGET}" POST_BUILD
                COMMAND "${CMAKE_COMMAND}" -E copy
                "${CMAKE_CURRENT_BINARY_DIR}/${INSTALL_EXECUTABLE_TARGET}.exe"
                "${CMAKE_CURRENT_BINARY_DIR}/${INSTALL_EXECUTABLE_NAME}.exe")

            install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/${INSTALL_EXECUTABLE_NAME}.exe" DESTINATION bin)
        else()
            add_custom_command(TARGET "${INSTALL_EXECUTABLE_TARGET}" POST_BUILD
                COMMAND "${CMAKE_COMMAND}" -E copy
                "${CMAKE_CURRENT_BINARY_DIR}/${INSTALL_EXECUTABLE_TARGET}"
                "${CMAKE_CURRENT_BINARY_DIR}/${INSTALL_EXECUTABLE_NAME}")

            install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/${INSTALL_EXECUTABLE_NAME}" DESTINATION bin)
        endif()
    endif()

    install(TARGETS "${INSTALL_EXECUTABLE_TARGET}" DESTINATION bin)
endmacro()

macro(export_target_variables NAME)
    set_export(${NAME}_TARGET)
    set_export(${NAME}_VERSION)
    set_export(${NAME}_VERSION_MAJOR)
    set_export(${NAME}_VERSION_MINOR)
    set_export(${NAME}_VERSION_PATCH)
    set_export(${NAME}_SOURCES_DIR)
    set_export(${NAME}_LIBRARIES)
    set_export(${NAME}_SOURCES)
    set_export(${NAME}_INCLUDE_DIRS)
    set(${NAME}_INCLUDE_DIRECTORIES ${${NAME}_INCLUDE_DIRS})
    set_export(${NAME}_INCLUDE_DIRECTORIES)
    set_export(${NAME}_COMPILE_FLAGS)
    set_export(${NAME}_LINK_FLAGS)
    set_export(${NAME}_LINK_DIRS)
    set_export(${NAME}_HEADERS)
    set_export(${NAME}_ROOT)
endmacro()

macro(_unversion_variable NAME VNAME VAR)
    set("${NAME}${VAR}" "${${VNAME}${VAR}}")
endmacro()

macro(unversion_target_variables NAME VNAME)
    set(${NAME}_TARGET ${VNAME})
    _unversion_variable(${NAME} ${VNAME} _VERSION)
    _unversion_variable(${NAME} ${VNAME} _VERSION_MAJOR)
    _unversion_variable(${NAME} ${VNAME} _VERSION_MINOR)
    _unversion_variable(${NAME} ${VNAME} _VERSION_PATCH)
    _unversion_variable(${NAME} ${VNAME} _SOURCES_DIR)
    _unversion_variable(${NAME} ${VNAME} _LIBRARIES)
    _unversion_variable(${NAME} ${VNAME} _SOURCES)
    _unversion_variable(${NAME} ${VNAME} _INCLUDE_DIRS)
    set(${NAME}_INCLUDE_DIRECTORIES ${${VNAME}_INCLUDE_DIRS})
    _unversion_variable(${NAME} ${VNAME} _LINK_DIRS)
    _unversion_variable(${NAME} ${VNAME} _HEADERS)
    _unversion_variable(${NAME} ${VNAME} _ROOT)
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

macro(sanitize_variable NAME_VAR VAL)
    string(REGEX REPLACE "[/.-]" "_" ${NAME_VAR} ${VAL})
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

    sanitize_variable(SAFENAME "${NAME}")

    set(_HEADER "${_HEADER}#define ${SAFENAME}_NAME \"${NAME}\"\n")

    if(DEFINED PROJECT_AUTHOR) 
        set(_HEADER "${_HEADER}#define ${SAFENAME}_AUTHOR \"${PROJECT_AUTHOR}\"\n")
    endif()

    if(DEFINED PROJECT_AUTHOR_EMAIL) 
        set(_HEADER "${_HEADER}#define ${SAFENAME}_AUTHOR_EMAIL \"${PROJECT_AUTHOR_EMAIL}\"\n")
    endif()

    set(_HEADER "${_HEADER}#define ${SAFENAME}_VERSION \"${${VNAME}_VERSION}\"\n")
    set(_HEADER "${_HEADER}#define ${SAFENAME}_VERSION_MAJOR ${${VNAME}_VERSION_MAJOR}\n")
    set(_HEADER "${_HEADER}#define ${SAFENAME}_VERSION_MINOR ${${VNAME}_VERSION_MINOR}\n")
    set(_HEADER "${_HEADER}#define ${SAFENAME}_VERSION_PATCH ${${VNAME}_VERSION_PATCH}\n")

    file(WRITE "${OUT_PATH}" "${_HEADER}")

    unset(_HEADER)
endmacro()

# get_cpp_warnings: get a list of cpp warnings from ARGN
macro(get_cpp_warnings OUT_VAR)
    set(_OPTIONS ALL EXTRA PEDANTIC SANE FATAL)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(TARGET_CPP_WARNINGS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (TARGET_CPP_WARNINGS_ALL)
        if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
            list(APPEND ${OUT_VAR} -Wall)
        elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "CLANG")
            list(APPEND ${OUT_VAR} -Wall)
        elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
            list(APPEND ${OUT_VAR} "/Wall")
        endif()
    endif()

    if (TARGET_CPP_WARNINGS_EXTRA)
        if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
            list(APPEND ${OUT_VAR} -Wextra)
        elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "CLANG")
            list(APPEND ${OUT_VAR} -Wextra)
        endif()
    endif()

    if (TARGET_CPP_WARNINGS_PEDANTIC)
        if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
            list(APPEND ${OUT_VAR} -Wpedantic)
        elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "CLANG")
            list(APPEND ${OUT_VAR} -Wpedantic)
        endif()
    endif()

    if (TARGET_CPP_WARNINGS_SANE)
        if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
            list(APPEND ${OUT_VAR} -Wno-sign-compare -Wno-unused-but-set-variable -Wno-multichar)
        elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
            list(APPEND ${OUT_VAR} -Wno-sign-compare -Wno-unused-but-set-variable -Wno-multichar -Wno-missing-braces)
        elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
            # Suppressed warnings:
            list(APPEND ${OUT_VAR}
                "/wd4100" # C4100: unused parameter
                "/wd4003" # C4003: "incorrect" macro parameters
                "/wd4018" # C4018: signed/unsigned comparison
                "/wd4130" # C4130: logical operation on string constant
                "/wd4146" # C4146: unary minus on unsigned type, this is intentional
                "/wd4365" # C4365: conversion from signed to unsigned
                "/wd4388" # C4388: signed/unsigned comparison
                "/wd4389" # C4389: signed/unsigned comparison
                "/wd4514" # C4514: unreferenced inline function
                "/wd4577" # C4577: noexcept with exception handling disabled
                "/wd4668" # C4668: not defined as a preprocessor macro, replacing with '0'
                "/wd4710" # C4710: function not inlined
                "/wd4711" # C4711: automatic inline expansion
                "/wd4820" # C4820: added padding at end of struct
                "/wd5039" # C5039: extern C exceptions
                "/wd5045" # C5045: spectre
                "/wd5246" # C5246: initialization of subobjects should be wrapped in braces
                "/wd5262" # C5262: implicit case fall-through
            )
        endif()
    endif()

    if (TARGET_CPP_WARNINGS_FATAL)
        if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
            list(APPEND ${OUT_VAR} -Wfatal-errors)
        elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
            list(APPEND ${OUT_VAR} "/WX")
        endif()
    endif()

    if (DEFINED "TARGET_CPP_WARNINGS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND ${OUT_VAR} ${TARGET_CPP_WARNINGS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()

    if (DEFINED TARGET_CPP_WARNINGS_UNPARSED_ARGUMENTS)
        list(APPEND ${OUT_VAR} ${TARGET_CPP_WARNINGS_UNPARSED_ARGUMENTS})
    endif()
endmacro()

# target_cpp_version: sets the C++ version of the target
macro(target_cpp_version OUT_VAR TARGET VERSION)
    set_property(TARGET "${TARGET}" PROPERTY CXX_STANDARD "${VERSION}")
    set("${OUT_VAR}" "${VERSION}")
endmacro()

macro(get_version_name OUT_VAR NAME MAJOR MINOR PATCH)
    set(_TMP "")

    if ("${PATCH}" EQUAL 0)
        if ("${MINOR}" EQUAL 0)
            if (NOT "${MAJOR}" EQUAL 0)
                set(_TMP "-${MAJOR}")
            endif()
        else()
            set(_TMP "-${MAJOR}.${MINOR}")
        endif()
    else()
        set(_TMP "-${MAJOR}.${MINOR}.${PATCH}")
    endif()

    set(_TMP "${NAME}${_TMP}")
    set(${OUT_VAR} "${_TMP}")
    unset(_TMP)
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
    set(${OUT_VAR} "")
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
    set(_OPTIONS INCLUDE LINK GIT_SUBMODULE)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS)

    cmake_parse_arguments(_ADD_LIB_EXT "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})

    if (NOT IS_DIRECTORY "${EXTPATH}")
        message(FATAL_ERROR "add_external_dependency: path ${EXTPATH} of external dependency ${EXTNAME} does not exist.")
    endif()

    split_version_string("${EXTVERSION}" _EXTMAJOR _EXTMINOR _EXTPATCH)
    get_version_name(_EXTNAME "${EXTNAME}" "${_EXTMAJOR}" "${_EXTMINOR}" "${_EXTPATCH}")

    if (NOT TARGET "${_EXTNAME}")
        # target is not already included

        if (NOT EXISTS "${EXTPATH}/CMakeLists.txt")
            # target directory is probably empty.
            # see if its a git submodule and initialize it, then include it,
            # fail otherwise.
            
            if (_ADD_LIB_EXT_GIT_SUBMODULE)
                if (NOT git_PROGRAM)
                    message(FATAL_ERROR "add_external_dependency: external dependency ${EXTNAME} is an uninitialized git submodule and requires git to be installed. Alternatively initialize the dependency manually.")
                endif()

                git_submodule_update("${EXTPATH}" INIT)
            else()
                message(FATAL_ERROR "add_external_dependency: path ${EXTPATH} of external dependency ${EXTNAME} does not contain a CMakeLists.txt file.")
            endif()
        endif()

        include_subdirectory("${EXTPATH}")
    endif()

    if (NOT TARGET "${_EXTNAME}")
        message(FATAL_ERROR "add_external_dependency: external dependency ${EXTNAME} version ${EXTVERSION} not found after including path ${EXTPATH}.")
    endif()

    if (_ADD_LIB_EXT_INCLUDE)
        if (NOT DEFINED "${_EXTNAME}_SOURCES_DIR")
            message(FATAL_ERROR "add_external_dependency: external dependency ${EXTNAME} did not define required variable ${_EXTNAME}_SOURCES_DIR needed for include paths.")
        endif()

        target_include_directories("${TARGET}" PRIVATE "${${_EXTNAME}_SOURCES_DIR}")
        list(APPEND "${TARGET}_INCLUDE_DIRS" "${${_EXTNAME}_SOURCES_DIR}")
    endif()

    if (_ADD_LIB_EXT_LINK)
        list(APPEND "${TARGET}_LIBRARIES" "${_EXTNAME}")
    endif()
endmacro()

macro(_add_target_ext TARGET)
    parse_arguments_by_delimiter(_GROUPS LIB ${ARGN})

    foreach (ARGS ${_GROUPS})
        add_external_dependency(${TARGET} ${ARGS})
    endforeach()
endmacro()

# add_git_submodule: add a git submodule dependency.
# the dependency doesn't have to be better-cmake, but adding the same submodule
# multiple times with different commits will probably cause CMake to fail, as
# CMake can't deal with targets having the same name. Pathetic.
# example:
#   add_git_submodule(${myLib_TARGET} glm "${ROOT}/ext/glm" INCLUDE "${ROOT}/ext/glm")
macro(add_git_submodule TARGET MODNAME MODPATH)
    set(_OPTIONS)
    set(_SINGLE_VAL_ARGS CMAKELISTS_DIR)
    set(_MULTI_VAL_ARGS INCLUDE)

    cmake_parse_arguments(_ADD_GIT_SUBMODULE "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})

    if (NOT IS_DIRECTORY "${MODPATH}")
        message(FATAL_ERROR "add_git_submodule: git submodule path ${MODPATH} does not exist.")
    endif()

    get_git_submodule_checkout_commit(_COMMIT "${MODPATH}")
    # git status of "-" means the submodule is uninitialized
    get_git_submodule_status(_GIT_STATUS "${MODPATH}")

    if (${MODNAME}_COMMIT)
        if (NOT ${MODNAME}_COMMIT STREQUAL _COMMIT)
            message(WARNING "add_git_submodule: conflicting submodule ${MODNAME} commits ${_COMMIT} (from this repo) and ${${MODNAME}_COMMIT}. Attempting to continue.")
            
            if (_GIT_STATUS STREQUAL "-")
                git_submodule_update("${MODPATH}" INIT)
            endif()
        endif()
    else()
        if (_GIT_STATUS STREQUAL "-")
            git_submodule_update("${MODPATH}" INIT)
            set(${MODNAME}_COMMIT "${_COMMIT}")

            if (NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
                set_export(${MODNAME}_COMMIT)
            endif()
        else()
            message(VERBOSE "add_git_submodule: submodule ${MODNAME} already loaded")
        endif()
    endif()

    if (_ADD_GIT_SUBMODULE_INCLUDE)
        target_include_directories("${TARGET}" PRIVATE ${_ADD_GIT_SUBMODULE_INCLUDE})
        list(APPEND "${TARGET}_INCLUDE_DIRS" ${_ADD_GIT_SUBMODULE_INCLUDE})
    endif()

    if (_ADD_GIT_SUBMODULE_CMAKELISTS_DIR)
        include_subdirectory("${_ADD_GIT_SUBMODULE_CMAKELISTS_DIR}")
    endif()
endmacro()

macro(_add_target_submodules TARGET)
    parse_arguments_by_delimiter(_GROUPS MODULE ${ARGN})

    foreach (ARGS ${_GROUPS})
        add_git_submodule(${TARGET} ${ARGS})
    endforeach()
endmacro()

# add_target_libraries: add libraries to link for a given target.
# supports platform-specific library selection with @,
# example:
#   add_target_libraries(${myLib_TARGET}
#                        vulkan
#                        @Linux pthread zlib
#                        @Windows kernel32 zlib)
#
# links vulkan on all platforms, pthread and zlib on Linux and zlib on Windows.
macro(add_target_libraries TARGET)
    set(_OPTIONS)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @Linux @Windows @Mac)

    cmake_parse_arguments(_ADD_TARGET_LIBRARIES "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (DEFINED _ADD_TARGET_LIBRARIES_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_LIBRARIES" ${_ADD_TARGET_LIBRARIES_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_LIBRARIES_\@${Platform}")
        list(APPEND "${TARGET}_LIBRARIES" ${_ADD_TARGET_LIBRARIES_\@${Platform}})
    endif()
endmacro()

# add_target_compile_flags: add compiler flags to the given target.
# use "Default" to set default flags.
# supports compiler-specific flags with @, e.g.:
#
#   add_target_compile_flags(${myLib_TARGET}
#                            @GNU -O0
#                            @MSVC /Zi)
#
macro(add_target_compile_flags TARGET)
    set(_OPTIONS Default)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(_ADD_TARGET_COMPILE_FLAGS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_COMPILE_FLAGS_Default)
        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "-fno-exceptions")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "-fno-rtti")
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            # TODO
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
            # cl.exe compiler flags
            # https://learn.microsoft.com/en-us/cpp/build/reference/compiler-options-listed-alphabetically?view=msvc-170

            # complete debugging information
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/Zi")

            # real preprocessor
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/Zc:preprocessor")

            # undocumented option to generate "enhanced debugging information for optimized code"
            # https://learn.microsoft.com/en-us/cpp/build/reference/zo-enhance-optimized-debugging?view=msvc-170
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/d2Zi+")

            # packaged functions
            # https://learn.microsoft.com/en-us/cpp/build/reference/gy-enable-function-level-linking?view=msvc-170
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/Gy")

            # Eliminate duplicate strings
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/GF")

            # Disable RTTI
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/GR-")

            # Disable exceptions?
            # https://learn.microsoft.com/en-us/cpp/build/reference/eh-exception-handling-model?view=msvc-170
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/EHs-")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/EHa-")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/EHc-")

            # no copyright notice
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/nologo")

            # Full file paths in diagnostics text
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/FC")

            # Deprecated? No minimal build?
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/Gm-")

            # Diagnostics format
            # https://learn.microsoft.com/en-us/cpp/build/reference/diagnostics-compiler-diagnostic-options?view=msvc-170
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/diagnostics:column")

            # Floating point options
            # https://learn.microsoft.com/en-us/cpp/build/reference/fp-specify-floating-point-behavior?view=msvc-170
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/fp:fast")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/fp:except-")
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_COMPILE_FLAGS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_COMPILE_FLAGS" ${_ADD_TARGET_COMPILE_FLAGS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_COMPILE_FLAGS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND "${TARGET}_COMPILE_FLAGS" ${_ADD_TARGET_COMPILE_FLAGS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()
endmacro()

# add_target_compile_flags_debug: add compiler flags to the given target when
# building a debug build.
# use "Default" to set default flags.
macro(add_target_compile_flags_debug TARGET)
    set(_OPTIONS Default)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(_ADD_TARGET_COMPILE_FLAGS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_COMPILE_FLAGS_Default)
        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "-g")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "-O0")
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            # TODO
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
            # No optimization
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/Od")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/MDd")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/Zi")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/Ob0")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/RTC1")
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_COMPILE_FLAGS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_COMPILE_FLAGS" ${_ADD_TARGET_COMPILE_FLAGS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_COMPILE_FLAGS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND "${TARGET}_COMPILE_FLAGS" ${_ADD_TARGET_COMPILE_FLAGS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()
endmacro()

# add_target_compile_flags_release: add compiler flags to the given target when
# building a release build.
# use "Default" to set default flags.
macro(add_target_compile_flags_release TARGET)
    set(_OPTIONS Default)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(_ADD_TARGET_COMPILE_FLAGS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_COMPILE_FLAGS_Default)
        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "-O3")
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            # TODO
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
            # Optimization
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/Oi")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/Oxb2")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/O2")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/DNDBUG")
            list(APPEND "${TARGET}_COMPILE_FLAGS" "/MD")
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_COMPILE_FLAGS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_COMPILE_FLAGS" ${_ADD_TARGET_COMPILE_FLAGS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_COMPILE_FLAGS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND "${TARGET}_COMPILE_FLAGS" ${_ADD_TARGET_COMPILE_FLAGS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()
endmacro()

# add_target_compile_definitions: add compiler definitions to the given target.
# use "Default" to set default definitions.
# supports platform-specific definitions with @, e.g.:
#
#   add_target_compile_definitions(${myLib_TARGET}
#                                  @Windows -DUNICODE=1)
#
macro(add_target_compile_definitions TARGET)
    set(_OPTIONS Default)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @Linux @Windows @Mac)

    cmake_parse_arguments(_ADD_TARGET_COMPILE_DEFINITIONS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_COMPILE_DEFINITIONS_Default)
        if (WIN32)
            # UNICODE to make macro Win32 functions use the W overload
            list(APPEND "${TARGET}_COMPILE_DEFINITIONS" "-DUNICODE=1")
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_COMPILE_DEFINITIONS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_COMPILE_DEFINITIONS" ${_ADD_TARGET_COMPILE_DEFINITIONS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_COMPILE_DEFINITIONS_\@${Platform}")
        list(APPEND "${TARGET}_COMPILE_DEFINITIONS" ${_ADD_TARGET_COMPILE_DEFINITIONS_\@${Platform}})
    endif()
endmacro()

# add_target_compile_definitions_debug: add compiler definitions to the given target when
# building a debug build.
# use "Default" to set default definitions.
macro(add_target_compile_definitions_debug TARGET)
    set(_OPTIONS Default)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(_ADD_TARGET_COMPILE_DEFINITIONS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_COMPILE_DEFINITIONS_Default)
        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_COMPILE_DEFINITIONS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_COMPILE_DEFINITIONS" ${_ADD_TARGET_COMPILE_DEFINITIONS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_COMPILE_DEFINITIONS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND "${TARGET}_COMPILE_DEFINITIONS" ${_ADD_TARGET_COMPILE_DEFINITIONS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()
endmacro()

# add_target_compile_definitions_release: add compiler definitions to the given target when
# building a release build.
# use "Default" to set default definitions.
macro(add_target_compile_definitions_release TARGET)
    set(_OPTIONS Default)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(_ADD_TARGET_COMPILE_DEFINITIONS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_COMPILE_DEFINITIONS_Default)
        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_COMPILE_DEFINITIONS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_COMPILE_DEFINITIONS" ${_ADD_TARGET_COMPILE_DEFINITIONS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_COMPILE_DEFINITIONS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND "${TARGET}_COMPILE_DEFINITIONS" ${_ADD_TARGET_COMPILE_DEFINITIONS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()
endmacro()

# add_target_link_flags: add linker flags to the given target.
# use "Default" to set default flags.
# supports compiler-specific flags with @, e.g.:
#
#   add_target_link_flags(${myLib_TARGET}
#                            @MSVC /incremental:no)
#
macro(add_target_link_flags TARGET)
    set(_OPTIONS Default)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(_ADD_TARGET_LINK_FLAGS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_LINK_FLAGS_Default)
        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            # TODO
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            # TODO
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
            # doesn't create an incremental build
            # https://learn.microsoft.com/en-us/cpp/build/reference/incremental-link-incrementally?view=msvc-170
            list(APPEND "${TARGET}_LINK_FLAGS" "/incremental:no")

            # removes unused definitions
            # https://learn.microsoft.com/en-us/cpp/build/reference/opt-optimizations?view=msvc-170
            list(APPEND "${TARGET}_LINK_FLAGS" "/opt:ref")
            list(APPEND "${TARGET}_LINK_FLAGS" "/machine:x64")

            # let's not generate a manifest file
            # https://learn.microsoft.com/en-us/cpp/build/reference/manifest-create-side-by-side-assembly-manifest?view=msvc-170
            list(APPEND "${TARGET}_LINK_FLAGS" "/manifest:no")
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_LINK_FLAGS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_LINK_FLAGS" ${_ADD_TARGET_LINK_FLAGS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_LINK_FLAGS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND "${TARGET}_LINK_FLAGS" ${_ADD_TARGET_LINK_FLAGS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()
endmacro()

# add_target_link_flags_debug: add linker debug flags to the given target.
# use "Default" to set default flags.
macro(add_target_link_flags_debug TARGET)
    set(_OPTIONS Default)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(_ADD_TARGET_LINK_FLAGS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_LINK_FLAGS_Default)
        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            # nothing
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            # nothing
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
            list(APPEND "${TARGET}_LINK_FLAGS" "/debug")
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_LINK_FLAGS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_LINK_FLAGS" ${_ADD_TARGET_LINK_FLAGS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_LINK_FLAGS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND "${TARGET}_LINK_FLAGS" ${_ADD_TARGET_LINK_FLAGS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()
endmacro()

# add_target_link_flags_release: add linker release flags to the given target.
# use "Default" to set default flags.
macro(add_target_link_flags_release TARGET)
    set(_OPTIONS Default)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(_ADD_TARGET_LINK_FLAGS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_LINK_FLAGS_Default)
        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            # nothing
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            # nothing
        elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
            # nothing
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_LINK_FLAGS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_LINK_FLAGS" ${_ADD_TARGET_LINK_FLAGS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_LINK_FLAGS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND "${TARGET}_LINK_FLAGS" ${_ADD_TARGET_LINK_FLAGS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()
endmacro()

# add_target_tests_compile_flags: add compiler flags to the tests of the given target
# use "Inherit" to set the same flags as the target.
# supports compiler-specific flags with @, e.g.:
#
#   add_target_tests_compile_flags(${myLib_TARGET} Inherit @MSVC /Zi)
#
macro(add_target_tests_compile_flags TARGET)
    set(_OPTIONS Inherit)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(_ADD_TARGET_TESTS_COMPILE_FLAGS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_TESTS_COMPILE_FLAGS_Inherit)
        if (DEFINED "${TARGET}_COMPILE_FLAGS")
            list(APPEND "${TARGET}_TESTS_COMPILE_FLAGS" ${${TARGET}_COMPILE_FLAGS})
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_TESTS_COMPILE_FLAGS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_TESTS_COMPILE_FLAGS" ${_ADD_TARGET_TESTS_COMPILE_FLAGS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_TESTS_COMPILE_FLAGS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND "${TARGET}_TESTS_COMPILE_FLAGS" ${_ADD_TARGET_TESTS_COMPILE_FLAGS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()
endmacro()

# add_target_tests_link_flags: add linker flags to the tests of the given target.
# use "Inherit" to set the same flags as target.
# supports compiler-specific flags with @, e.g.:
#
#   add_target_tests_link_flags(${myLib_TARGET} Inherit @MSVC /incremental:no)
#
macro(add_target_tests_link_flags TARGET)
    set(_OPTIONS Inherit)
    set(_SINGLE_VAL_ARGS)
    set(_MULTI_VAL_ARGS @GNU @Clang @MSVC)

    cmake_parse_arguments(_ADD_TARGET_TESTS_LINK_FLAGS "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (_ADD_TARGET_TESTS_LINK_FLAGS_Inherit)
        if (DEFINED "${TARGET}_LINK_FLAGS")
            list(APPEND "${TARGET}_TESTS_LINK_FLAGS" ${${TARGET}_LINK_FLAGS})
        endif()
    endif()
    
    if (DEFINED _ADD_TARGET_TESTS_LINK_FLAGS_UNPARSED_ARGUMENTS)
        list(APPEND "${TARGET}_TESTS_LINK_FLAGS" ${_ADD_TARGET_TESTS_LINK_FLAGS_UNPARSED_ARGUMENTS})
    endif()

    if (DEFINED "_ADD_TARGET_TESTS_LINK_FLAGS_\@${CMAKE_CXX_COMPILER_ID}")
        list(APPEND "${TARGET}_TESTS_LINK_FLAGS" ${_ADD_TARGET_TESTS_LINK_FLAGS_\@${CMAKE_CXX_COMPILER_ID}})
    endif()
endmacro()

macro(_add_target NAME)
    set(_OPTIONS)
    set(_SINGLE_VAL_ARGS
        VERSION                 # version of the target
        SOURCES_DIR             # top directory of all source files, if "src" folder is present, can be omitted
        GENERATE_TARGET_HEADER  # path to target header file
        CPP_VERSION             # defaults to 17 if omitted
        )
    set(_MULTI_VAL_ARGS
        CPP_WARNINGS            # ALL, EXTRA, PEDANTIC
        SOURCES                 # extra sources, optional
        INCLUDE_DIRS            # extra include directories, optional
        COMPILE_FLAGS           # compiler flags
        COMPILE_FLAGS_DEBUG     # debug compiler flags
        COMPILE_FLAGS_RELEASE   # release compiler flags
        COMPILE_DEFINITIONS           # definitions
        COMPILE_DEFINITIONS_DEBUG     # debug definitions
        COMPILE_DEFINITIONS_RELEASE   # release definitions
        LINK_FLAGS              # linker flags
        LINK_FLAGS_DEBUG        # debug linker flags
        LINK_FLAGS_RELEASE      # release linker flags
        LINK_DIRS               # extra directories to look at when linking, optional
        LIBRARIES               # libraries to link
        EXT                     # better-cmake external dependencies
        SUBMODULES              # git external dependencies
        TESTS                   # t1 tests
        TESTS_COMPILE_FLAGS     # t1 test compiler flags
        TESTS_COMPILE_DEFINITIONS # t1 test compiler definitions
        TESTS_LINK_FLAGS        # t1 test linker flags
        )

    cmake_parse_arguments(_ADD_TARGET "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (NOT DEFINED _ADD_TARGET_VERSION)
        set(_ADD_TARGET_VERSION 0.0.0)
    endif()

    # variables
    split_version_string(${_ADD_TARGET_VERSION} _MAJOR _MINOR _PATCH)
    get_version_name(_NAME "${NAME}" "${_MAJOR}" "${_MINOR}" "${_PATCH}")

    # set versions
    set("${_NAME}_VERSION" "${_MAJOR}.${_MINOR}.${_PATCH}")
    set("${_NAME}_VERSION_MAJOR" "${_MAJOR}")
    set("${_NAME}_VERSION_MINOR" "${_MINOR}")
    set("${_NAME}_VERSION_PATCH" "${_PATCH}")

    set("${_NAME}_ROOT" "${CMAKE_CURRENT_SOURCE_DIR}")

    if (NOT DEFINED _ADD_TARGET_SOURCES_DIR)
        if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/")
            message(VERBOSE "better-cmake: using default source directory ${CMAKE_CURRENT_SOURCE_DIR}/src/")
            set(${_NAME}_SOURCES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/")
        else()
            message(FATAL_ERROR "better-cmake: add_lib/add_exe requires parameter SOURCES_DIR")
        endif()
    else()
        set(${_NAME}_SOURCES_DIR "${_ADD_TARGET_SOURCES_DIR}")
    endif()

    if (DEFINED _ADD_TARGET_GENERATE_TARGET_HEADER)
        generate_target_header("${NAME}" "${_NAME}" "${_ADD_TARGET_GENERATE_TARGET_HEADER}")
    endif()

    find_sources("${_NAME}_SOURCES" "${${_NAME}_SOURCES_DIR}")
    find_headers("${_NAME}_HEADERS" "${${_NAME}_SOURCES_DIR}")

    target_sources(${_NAME} PRIVATE ${${_NAME}_HEADERS} ${${_NAME}_SOURCES} ${_ADD_TARGET_SOURCES})

    if (NOT DEFINED _ADD_TARGET_CPP_VERSION)
        set(_ADD_TARGET_CPP_VERSION ${better_DEFAULT_CXX_STANDARD})
    endif()

    target_cpp_version("${_NAME}_CPP_VERSION" "${_NAME}" ${_ADD_TARGET_CPP_VERSION})
    set("${_NAME}_CPP_WARNINGS" "")

    if (DEFINED _ADD_TARGET_CPP_WARNINGS)
        get_cpp_warnings("${_NAME}_CPP_WARNINGS" ${_ADD_TARGET_CPP_WARNINGS})
    endif()

    if (${_NAME}_CPP_WARNINGS)
        target_compile_options("${_NAME}" PRIVATE ${${_NAME}_CPP_WARNINGS})
    endif()

    if (DEFINED _ADD_TARGET_INCLUDE_DIRS)
        list(APPEND "${_NAME}_INCLUDE_DIRS" ${_ADD_TARGET_INCLUDE_DIRS})
    endif()

    # Compile flags
    if (DEFINED _ADD_TARGET_COMPILE_FLAGS)
        add_target_compile_flags("${_NAME}" ${_ADD_TARGET_COMPILE_FLAGS})
    else()
        add_target_compile_flags("${_NAME}" Default)
    endif()

    if (CMAKE_BUILD_TYPE STREQUAL "Debug")
        if (DEFINED _ADD_TARGET_COMPILE_FLAGS_DEBUG)
            add_target_compile_flags_debug("${_NAME}" ${_ADD_TARGET_COMPILE_FLAGS_DEBUG})
        else()
            add_target_compile_flags_debug("${_NAME}" Default)
        endif()
    elseif (CMAKE_BUILD_TYPE STREQUAL "Release")
        if (DEFINED _ADD_TARGET_COMPILE_FLAGS_RELEASE)
            add_target_compile_flags_release("${_NAME}" ${_ADD_TARGET_COMPILE_FLAGS_RELEASE})
        else()
            add_target_compile_flags_release("${_NAME}" Default)
        endif()
    endif()

    if (DEFINED _ADD_TARGET_TESTS_COMPILE_FLAGS)
        add_target_tests_compile_flags("${_NAME}" ${_ADD_TARGET_TESTS_COMPILE_FLAGS})
    else()
        add_target_tests_compile_flags("${_NAME}" Inherit)
    endif()

    # definitions
    if (DEFINED _ADD_TARGET_COMPILE_DEFINITIONS)
        add_target_compile_definitions("${_NAME}" ${_ADD_TARGET_COMPILE_DEFINITIONS})
    else()
        add_target_compile_definitions("${_NAME}" Default)
    endif()

    if (CMAKE_BUILD_TYPE STREQUAL "Debug")
        if (DEFINED _ADD_TARGET_COMPILE_DEFINITIONS_DEBUG)
            add_target_compile_definitions_debug("${_NAME}" ${_ADD_TARGET_COMPILE_DEFINITIONS_DEBUG})
        else()
            add_target_compile_definitions_debug("${_NAME}" Default)
        endif()
    elseif (CMAKE_BUILD_TYPE STREQUAL "Release")
        if (DEFINED _ADD_TARGET_COMPILE_DEFINITIONS_RELEASE)
            add_target_compile_definitions_release("${_NAME}" ${_ADD_TARGET_COMPILE_DEFINITIONS_RELEASE})
        else()
            add_target_compile_definitions_release("${_NAME}" Default)
        endif()
    endif()

    if (DEFINED _ADD_TARGET_TESTS_COMPILE_DEFINITIONS)
        add_target_tests_compile_flags("${_NAME}" ${_ADD_TARGET_TESTS_COMPILE_DEFINITIONS})
    else()
        add_target_tests_compile_flags("${_NAME}" ${${_NAME}_COMPILE_DEFINITIONS})
    endif()

    # Link flags
    if (DEFINED _ADD_TARGET_LINK_FLAGS)
        add_target_link_flags("${_NAME}" ${_ADD_TARGET_LINK_FLAGS})
    else()
        add_target_link_flags("${_NAME}" Default)
    endif()

    if (CMAKE_BUILD_TYPE STREQUAL "Debug")
        if (DEFINED _ADD_TARGET_LINK_FLAGS_DEBUG)
            add_target_link_flags_debug("${_NAME}" ${_ADD_TARGET_LINK_FLAGS_DEBUG})
        else()
            add_target_link_flags_debug("${_NAME}" Default)
        endif()
    elseif (CMAKE_BUILD_TYPE STREQUAL "Release")
        if (DEFINED _ADD_TARGET_LINK_FLAGS_RELEASE)
            add_target_link_flags_release("${_NAME}" ${_ADD_TARGET_LINK_FLAGS_RELEASE})
        else()
            add_target_link_flags_release("${_NAME}" Default)
        endif()
    endif()

    if (DEFINED _ADD_TARGET_TESTS_LINK_FLAGS)
        add_target_tests_link_flags("${_NAME}" ${_ADD_TARGET_TESTS_LINK_FLAGS})
    else()
        add_target_tests_link_flags("${_NAME}" Inherit)
    endif()

    if (DEFINED _ADD_TARGET_LINK_DIRS)
        list(APPEND "${_NAME}_LINK_DIRS" ${_ADD_TARGET_LINK_DIRS})
    endif()

    if (DEFINED _ADD_TARGET_LIBRARIES)
        add_target_libraries("${_NAME}" ${_ADD_TARGET_LIBRARIES})
    endif()

    if (DEFINED _ADD_TARGET_EXT)
        _add_target_ext("${_NAME}" ${_ADD_TARGET_EXT})
    endif()

    if (DEFINED _ADD_TARGET_SUBMODULES)
        _add_target_submodules("${_NAME}" ${_ADD_TARGET_SUBMODULES})
    endif()

    target_include_directories(${_NAME} PRIVATE "${${_NAME}_SOURCES_DIR}" ${${_NAME}_INCLUDE_DIRS})

    if (DEFINED "${_NAME}_COMPILE_FLAGS")
        target_compile_options("${_NAME}" PRIVATE ${${_NAME}_COMPILE_FLAGS})
    endif()

    if (DEFINED "${_NAME}_COMPILE_DEFINITIONS")
        target_compile_definitions("${_NAME}" PRIVATE ${${_NAME}_COMPILE_DEFINITIONS})
    endif()

    if (DEFINED "${_NAME}_LINK_FLAGS")
        target_link_options("${_NAME}" PRIVATE ${${_NAME}_LINK_FLAGS})
    endif()

    if (DEFINED "${_NAME}_LINK_DIRS")
        target_link_directories(${_NAME} PRIVATE ${${_NAME}_LINK_DIRS})
    endif()

    if (DEFINED "${_NAME}_LIBRARIES")
        target_link_libraries("${_NAME}" PRIVATE ${${_NAME}_LIBRARIES})
    endif()

    # platform-specific settings
    # by default color output is only generated for Make for some reason
    if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        target_compile_options("${_NAME}" PRIVATE -fdiagnostics-color=always)
    elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        target_compile_options("${_NAME}" PRIVATE -fcolor-diagnostics)
    endif()
endmacro()

macro(add_lib NAME LINKAGE)
    set(_OPTIONS PIE)
    set(_SINGLE_VAL_ARGS
        VERSION                 # version of the target
        SOURCES_DIR             # top directory of all source files, if "src" folder is present, can be omitted
        GENERATE_TARGET_HEADER  # path to target header file
        CPP_VERSION             # defaults to 17 if omitted
        )
    set(_MULTI_VAL_ARGS
        CPP_WARNINGS            # ALL, EXTRA, PEDANTIC
        SOURCES                 # extra sources, optional
        INCLUDE_DIRS            # extra include directories, optional
        COMPILE_FLAGS           # compiler flags
        COMPILE_FLAGS_DEBUG     # debug compiler flags
        COMPILE_FLAGS_RELEASE   # release compiler flags
        COMPILE_DEFINITIONS           # definitions
        COMPILE_DEFINITIONS_DEBUG     # debug definitions
        COMPILE_DEFINITIONS_RELEASE   # release definitions
        LINK_FLAGS              # linker flags
        LINK_FLAGS_DEBUG        # debug linker flags
        LINK_FLAGS_RELEASE      # release linker flags
        LINK_DIRS               # extra directories to look at when linking, optional
        LIBRARIES               # libraries to link
        EXT                     # better-cmake external dependencies
        SUBMODULES              # git external dependencies
        TESTS                   # t1 tests or directories of tests
        TESTS_COMPILE_FLAGS     # t1 test compiler flags
        TESTS_COMPILE_DEFINITIONS # t1 test compiler definitions
        TESTS_LINK_FLAGS        # t1 test linker flags
        )

    cmake_parse_arguments(ADD_LIB "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (NOT DEFINED ADD_LIB_VERSION)
        set(ADD_LIB_VERSION 0.0.0)
    endif()

    split_version_string(${ADD_LIB_VERSION} _MAJOR _MINOR _PATCH)
    get_version_name(_NAME "${NAME}" "${_MAJOR}" "${_MINOR}" "${_PATCH}")

    if (TARGET "${_NAME}")
        message(STATUS "better-cmake: found existing target ${NAME} version ${ADD_LIB_VERSION}, skipping duplicate.")
    else()
        # different version, add it

        add_library("${_NAME}" ${LINKAGE})

        if (ADD_LIB_PIE)
            set_property(TARGET "${_NAME}" PROPERTY POSITION_INDEPENDENT_CODE ON)
        endif()

        _add_target("${NAME}" ${ARGN})

        if (NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
            export_target_variables("${_NAME}")
        else()
            unversion_target_variables("${NAME}" "${_NAME}")

            install_library(TARGET "${_NAME}" SOURCES_DIR "${${_NAME}_SOURCES_DIR}")

            if (DEFINED ADD_LIB_TESTS)
                find_t1()

                if (t1_FOUND)
                    foreach (_TEST ${ADD_LIB_TESTS})
                        if (IS_DIRECTORY "${_TEST}")
                            add_test_directory("${_TEST}"
                                INCLUDE_DIRS "${${_NAME}_SOURCES_DIR}" ${${_NAME}_INCLUDE_DIRS} "${t1_SOURCE_DIR}"
                                COMPILE_FLAGS ${${_NAME}_TESTS_COMPILE_FLAGS}
                                LINK_FLAGS ${${_NAME}_TESTS_LINK_FLAGS}
                                LIBRARIES ${_NAME} ${${_NAME}_LIBRARIES}
                                CPP_VERSION ${${_NAME}_CPP_VERSION}
                                CPP_WARNINGS ${${_NAME}_CPP_WARNINGS}
                                )
                        else()
                            add_t1_test("${_TEST}"
                                INCLUDE_DIRS "${${_NAME}_SOURCES_DIR}" ${${_NAME}_INCLUDE_DIRS} "${t1_SOURCE_DIR}"
                                COMPILE_FLAGS ${${_NAME}_TESTS_COMPILE_FLAGS}
                                LINK_FLAGS ${${_NAME}_TESTS_LINK_FLAGS}
                                LIBRARIES ${_NAME} ${${_NAME}_LIBRARIES}
                                CPP_VERSION ${${_NAME}_CPP_VERSION}
                                CPP_WARNINGS ${${_NAME}_CPP_WARNINGS}
                                )
                        endif()
                    endforeach()

                    register_tests()
                endif()
            endif()
        endif()
    endif()
endmacro()

macro(add_exe NAME)
    set(_OPTIONS)
    set(_SINGLE_VAL_ARGS
        VERSION                 # version of the target
        SOURCES_DIR             # top directory of all source files, if "src" folder is present, can be omitted
        GENERATE_TARGET_HEADER  # path to target header file
        CPP_VERSION             # defaults to 17 if omitted
        WINDOWS_SUBSYSTEM       # Windows subsystem, defaults to "console".
                                # https://learn.microsoft.com/en-us/cpp/build/reference/subsystem-specify-subsystem?view=msvc-170
                                # Note: because CMake is a huge pile of shit, you can only choose "console" or "windows".
        )
    set(_MULTI_VAL_ARGS
        CPP_WARNINGS            # ALL, EXTRA, PEDANTIC
        SOURCES                 # extra sources, optional
        INCLUDE_DIRS            # extra include directories, optional
        COMPILE_FLAGS           # compiler flags
        COMPILE_FLAGS_DEBUG     # debug compiler flags
        COMPILE_FLAGS_RELEASE   # release compiler flags
        COMPILE_DEFINITIONS           # definitions
        COMPILE_DEFINITIONS_DEBUG     # debug definitions
        COMPILE_DEFINITIONS_RELEASE   # release definitions
        LINK_FLAGS              # linker flags
        LINK_FLAGS_DEBUG        # debug linker flags
        LINK_FLAGS_RELEASE      # release linker flags
        LINK_DIRS               # extra directories to look at when linking, optional
        LIBRARIES               # libraries to link
        EXT                     # better-cmake external dependencies
        SUBMODULES              # git external dependencies
        TESTS                   # t1 tests or directories of tests
        TESTS_COMPILE_FLAGS     # t1 test compiler flags
        TESTS_COMPILE_DEFINITIONS # t1 test compiler definitions
        TESTS_LINK_FLAGS        # t1 test linker flags
        )

    cmake_parse_arguments(ADD_EXE "${_OPTIONS}" "${_SINGLE_VAL_ARGS}" "${_MULTI_VAL_ARGS}" ${ARGN})
    
    if (NOT DEFINED ADD_EXE_VERSION)
        set(ADD_EXE_VERSION 0.0.0)
    endif()

    split_version_string(${ADD_EXE_VERSION} _MAJOR _MINOR _PATCH)
    get_version_name(_NAME "${NAME}" "${_MAJOR}" "${_MINOR}" "${_PATCH}")

    if (TARGET "${_NAME}")
        message(STATUS "better-cmake: found existing target ${NAME} version ${ADD_EXE_VERSION}, skipping duplicate.")
    else()
        # different version, add it

        add_executable("${_NAME}")

        _add_target("${NAME}" ${ARGN})

        if (Windows)
            if (DEFINED ADD_EXE_WINDOWS_SUBSYSTEM)
                string(TOLOWER "${ADD_EXE_WINDOWS_SUBSYSTEM}" _SUBSYSTEM)
                if (_SUBSYSTEM STREQUAL "windows")
                    set_property(TARGET "${_NAME}" PROPERTY WIN32_EXECUTABLE TRUE)
                endif()
            endif()
        endif()

        if (NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
            export_target_variables("${_NAME}")
        else()
            unversion_target_variables("${NAME}" "${_NAME}")

            install_executable(TARGET "${_NAME}" NAME "${NAME}")

            if (DEFINED ADD_EXE_TESTS)
                find_t1()

                if (t1_FOUND)
                    foreach (_TEST ${ADD_EXE_TESTS})
                        if (IS_DIRECTORY "${_TEST}")
                            add_test_directory("${_TEST}"
                                INCLUDE_DIRS "${${_NAME}_SOURCES_DIR}" ${${_NAME}_INCLUDE_DIRS} "${t1_SOURCE_DIR}"
                                LIBRARIES ${${_NAME}_LIBRARIES}
                                COMPILE_FLAGS ${${_NAME}_TESTS_COMPILE_FLAGS}
                                LINK_FLAGS ${${_NAME}_TESTS_LINK_FLAGS}
                                CPP_VERSION ${${_NAME}_CPP_VERSION}
                                CPP_WARNINGS ${${_NAME}_CPP_WARNINGS}
                                )
                        else()
                            add_t1_test("${_TEST}"
                                INCLUDE_DIRS "${${_NAME}_SOURCES_DIR}" ${${_NAME}_INCLUDE_DIRS} "${t1_SOURCE_DIR}"
                                LIBRARIES ${${_NAME}_LIBRARIES}
                                COMPILE_FLAGS ${${_NAME}_TESTS_COMPILE_FLAGS}
                                LINK_FLAGS ${${_NAME}_TESTS_LINK_FLAGS}
                                CPP_VERSION ${${_NAME}_CPP_VERSION}
                                CPP_WARNINGS ${${_NAME}_CPP_WARNINGS}
                                )
                        endif()
                    endforeach()

                    register_tests()
                endif()
            endif()
        endif()
    endif()
endmacro()

# =======
# WINDOWS
# =======
macro(set_up_msvc_environment)
    set_cache(Compiler "MSVC")
    # time to set "developer prompt" variables manually

    # VSINSTALLDIR is the directory Visual Studio is installed in.
    # If not set (it probably won't be unless you start a Developer Prompt
    # or run vcvarsall.bat), we try to find the latest version.
    if (NOT DEFINED ENV{VSINSTALLDIR})
        set(_vs_search_path "C:/Program Files/Microsoft Visual Studio")
        file(GLOB _vs_versions "${_vs_search_path}/*/*")

        if (NOT _vs_versions)
            message(FATAL_ERROR "Could not set VSINSTALLDIR: no Visual Studio installation found in ${_vs_search_path}.\nSet environment variable VSINSTALLDIR if Visual Studio is installed elsewhere.")
        endif()

        list(SORT _vs_versions COMPARE NATURAL ORDER DESCENDING)
        list(GET _vs_versions 0 _vs_current_version)
        set(ENV{VSINSTALLDIR} "${_vs_current_version}")
    endif()

    message(VERBOSE "VSINSTALLDIR: $ENV{VSINSTALLDIR}")

    # VSINSTALLDIR: MSVC installation directory.
    if (NOT DEFINED ENV{VCINSTALLDIR})
        if (NOT IS_DIRECTORY "$ENV{VSINSTALLDIR}/VC")
            message(FATAL_ERROR "Could not set VCINSTALLDIR: Visual Studio is installed but no VC installation found in $ENV{VSINSTALLDIR}/VC. Run Visual Studio and install VC.")
        endif()

        set(ENV{VCINSTALLDIR} "$ENV{VSINSTALLDIR}/VC")
    endif()

    message(VERBOSE "VCINSTALLDIR: $ENV{VCINSTALLDIR}")

    # VS170COMNTOOLS: Common7/Tools
    if (NOT DEFINED ENV{VS170COMNTOOLS})
        if (NOT IS_DIRECTORY "$ENV{VSINSTALLDIR}/Common7/Tools")
            message(FATAL_ERROR "Could not set VS170COMNTOOLS: Visual Studio is installed but no Common7/Tools directory was found in installation found at $ENV{VSINSTALLDIR}/Common7/Tools.")
        endif()

        set(ENV{VS170COMNTOOLS} "$ENV{VSINSTALLDIR}/Common7/Tools")
    endif()

    message(VERBOSE "VS170COMNTOOLS: $ENV{VS170COMNTOOLS}")

    # VCToolsInstallDir: The versioned directory where MSVC tools like cl.exe (compiler)
    # and other tools are installed in.
    if (NOT DEFINED ENV{VCToolsInstallDir})
        file(GLOB _vc_versions "$ENV{VCINSTALLDIR}/Tools/MSVC/*")

        if (NOT _vc_versions)
            message(FATAL_ERROR "No MSVC tools found in $ENV{VCINSTALLDIR}/Tools/MSVC/. Check your MSVC installation.")
        endif()

        list(SORT _vc_versions COMPARE NATURAL ORDER DESCENDING)
        list(GET _vc_versions 0 _vc_current_version)
        set(ENV{VCToolsInstallDir} "${_vc_current_version}")
    endif()

    message(VERBOSE "VCToolsInstallDir $ENV{VCToolsInstallDir}")

    # VCToolsVersion: version of the MSVC tools.
    if (NOT DEFINED ENV{VCToolsVersion})
        get_filename_component(_vc_version "$ENV{VCToolsInstallDir}" NAME)
        set(ENV{VCToolsVersion} "${_vc_version}")
    endif()

    message(VERBOSE "VCToolsVersion $ENV{VCToolsVersion}")

    # VCToolsRedistDir: The versioned directory where MSVC tools like cl.exe (compiler)
    # and other tools are installed in.
    if (NOT DEFINED ENV{VCToolsRedistDir})
        file(GLOB _vc_versions "$ENV{VCINSTALLDIR}/Redist/MSVC/[0-9]*")

        if (NOT _vc_versions)
            message(FATAL_ERROR "No MSVC redistributables found in $ENV{VCINSTALLDIR}/Redist/MSVC/. Check your MSVC installation.")
        endif()

        list(SORT _vc_versions COMPARE NATURAL ORDER DESCENDING)
        list(GET _vc_versions 0 _vc_current_version)
        set(ENV{VCToolsRedistDir} "${_vc_current_version}")
    endif()

    message(VERBOSE "VCToolsRedistDir $ENV{VCToolsRedistDir}")

    #Windows SDK
    # WindowsSdkDir: the root path of the Windows SDK.
    if (NOT DEFINED ENV{WindowsSdkDir})
        set(_winsdk_search_path "C:/Program Files (x86)/Windows Kits")
        file(GLOB _winsdk_versions "${_winsdk_search_path}/[0-9]*")

        if (NOT _winsdk_versions)
            message(FATAL_ERROR "Could not set WindowsSdkDir: no Windows Kits installation found in ${_winsdk_search_path}.\nSet environment variable WindowsSdkDir if installation path is elsewhere.")
        endif()

        list(SORT _winsdk_versions COMPARE NATURAL ORDER DESCENDING)
        list(GET _winsdk_versions 0 _winsdk_current_version)
        set(ENV{WindowsSdkDir} "${_winsdk_current_version}")
    endif()

    message(VERBOSE "WindowsSdkDir $ENV{WindowsSdkDir}")

    set_default(ENV{WindowsSdkBinPath} "$ENV{WindowsSdkDir}/bin")

    message(VERBOSE "WindowsSdkBinPath $ENV{WindowsSdkBinPath}")

    # WindowsSdkVerBinPath: specific version of the Windows SDK binaries.
    if (NOT DEFINED ENV{WindowsSdkVerBinPath})
        file(GLOB _winsdk_verbins "$ENV{WindowsSdkBinPath}/[0-9]*")

        if (NOT _winsdk_verbins)
            message(FATAL_ERROR "Could not set WindowsSdkBinPath: no Windows SDK versions found in $ENV{WindowsSdkBinPath}.\nCheck your Windows SDK installation.")
        endif()

        list(SORT _winsdk_verbins COMPARE NATURAL ORDER DESCENDING)
        list(GET _winsdk_verbins 0 _winsdk_bin_current_version)
        set(ENV{WindowsSdkVerBinPath} "${_winsdk_bin_current_version}")
    endif()

    message(VERBOSE "WindowsSdkVerBinPath $ENV{WindowsSdkVerBinPath}")

    # WindowsSDKVersion: the version of the Windows SDK
    if (NOT DEFINED ENV{WindowsSDKVersion})
        get_filename_component(_winsdk_version "$ENV{WindowsSdkVerBinPath}" NAME)
        set_default(ENV{UCRTVersion} "${_winsdk_version}")
        set(ENV{WindowsSDKVersion} "${_winsdk_version}/")
    endif()

    message(VERBOSE "WindowsSDKVersion $ENV{WindowsSDKVersion}")

    set_default(ENV{WindowsSDKLibVersion} "$ENV{WindowsSDKVersion}")
    message(VERBOSE "WindowsSDKLibVersion $ENV{WindowsSDKLibVersion}")

    set_default(ENV{UniversalCRTSdkDir} "$ENV{WindowsSdkDir}")

    

    # include, link, path, ...
    # (EXTERNAL_)INCLUDE: include paths
    set(_INCLUDE "")
    # Standard Library
    list(APPEND _INCLUDE "$ENV{VCToolsInstallDir}/include")

    # ATL (COM objects)
    if (IS_DIRECTORY "$ENV{VCToolsInstallDir}/atlmfc/include")
        list(APPEND _INCLUDE "$ENV{VCToolsInstallDir}/atlmfc/include")
    endif()

    # VS Auxiliary libs
    if (IS_DIRECTORY "$ENV{VCINSTALLDIR}/Auxiliary/VS/include")
        list(APPEND _INCLUDE "$ENV{VCINSTALLDIR}/Auxiliary/VS/include")
    endif()

    # Windows kits universal CRT, winrt, um, ...
    if (IS_DIRECTORY "$ENV{WindowsSdkDir}/include/$ENV{WindowsSDKVersion}")
        file(GLOB _includes "$ENV{WindowsSdkDir}/include/$ENV{WindowsSDKVersion}/*")
        list(APPEND _INCLUDE ${_includes})
    endif()

    set(ENV{EXTERNAL_INCLUDE} "${_INCLUDE};$ENV{EXTERNAL_INCLUDE}")
    message(VERBOSE "EXTERNAL_INCLUDE $ENV{EXTERNAL_INCLUDE}")

    set(ENV{INCLUDE} "${_INCLUDE};$ENV{INCLUDE}")

    include_directories($ENV{INCLUDE})
    message(VERBOSE "INCLUDE $ENV{INCLUDE}")


    # LIB: Library linking paths
    set(_LIB "")
    # Standard Library
    list(APPEND _LIB "$ENV{VCToolsInstallDir}/lib/x64")

    # ATL (COM objects)
    if (IS_DIRECTORY "$ENV{VCToolsInstallDir}/atlmfc/lib/x64")
        list(APPEND _LIB "$ENV{VCToolsInstallDir}/atlmfc/lib/x64")
    endif()

    # Windows kits universal CRT, um, ...
    if (IS_DIRECTORY "$ENV{WindowsSdkDir}/lib/$ENV{WindowsSDKVersion}/ucrt/x64")
        list(APPEND _LIB "$ENV{WindowsSdkDir}/lib/$ENV{WindowsSDKVersion}/ucrt/x64")
    endif()

    if (IS_DIRECTORY "$ENV{WindowsSdkDir}/lib/$ENV{WindowsSDKVersion}/um/x64")
        list(APPEND _LIB "$ENV{WindowsSdkDir}/lib/$ENV{WindowsSDKVersion}/um/x64")
    endif()

    set(ENV{LIB} "${_LIB};$ENV{LIB}")
    message(VERBOSE "LIB $ENV{LIB}")
    link_directories($ENV{LIB})


    # LIBPATH: yes
    set(_LIBPATH "")
    # Standard Library
    list(APPEND _LIBPATH "$ENV{VCToolsInstallDir}/lib/x64")
    
    # ATL (COM objects)
    if (IS_DIRECTORY "$ENV{VCToolsInstallDir}/atlmfc/lib/x64")
        list(APPEND _LIBPATH "$ENV{VCToolsInstallDir}/atlmfc/lib/x64")
    endif()

    # x86 references...?
    if (IS_DIRECTORY "$ENV{VCToolsInstallDir}/lib/x86/store/references")
        list(APPEND _LIBPATH "$ENV{VCToolsInstallDir}/lib/x86/store/references")
    endif()

    if (IS_DIRECTORY "$ENV{WindowsSdkDir}/References/$ENV{WindowsSDKVersion}")
        list(APPEND _LIBPATH "$ENV{WindowsSdkDir}/References/$ENV{WindowsSDKVersion}")
    endif()

    # PATH: search path
    set(_PATH "")
    list(APPEND _PATH "$ENV{VCToolsInstallDir}/bin/HostX64/x64")
    list(APPEND _PATH "$ENV{WindowsSdkVerBinPath}/x64")
    list(APPEND _PATH "$ENV{WindowsSdkBinPath}/x64")

    if (IS_DIRECTORY "$ENV{VSINSTALLDIR}/MSBuild/Current/Bin/amd64")
        list(APPEND _PATH "$ENV{VSINSTALLDIR}/MSBuild/Current/Bin/amd64")
    endif()

    if (IS_DIRECTORY "$ENV{VSINSTALLDIR}/VC/Tools/Llvm/x64/bin")
        list(APPEND _PATH "$ENV{VSINSTALLDIR}/VC/Tools/Llvm/x64/bin")
    endif()

    set(ENV{__VSCMD_PREINIT_PATH} "$ENV{PATH}")
    set(ENV{PATH} "${_PATH};$ENV{PATH}")

    message(VERBOSE "PATH $ENV{PATH}")

    # etc
    set_default(ENV{VSCMD_ARG_app_plat} Desktop)
    set_default(ENV{VSCMD_ARG_HOST_ARCH} x64)
    set_default(ENV{VSCMD_ARG_TGT_ARCH} x64)
    set_default(ENV{Platform} x64) # not to be confused with CMake variable Platform
    set_default(ENV{is_x64_arch} true)

    message(VERBOSE "VSCMD_ARG_app_plat $ENV{VSCMD_ARG_app_plat}")
    message(VERBOSE "VSCMD_ARG_HOST_ARCH $ENV{VSCMD_ARG_HOST_ARCH}")
    message(VERBOSE "VSCMD_ARG_TGT_ARCH $ENV{VSCMD_ARG_TGT_ARCH}")
    message(VERBOSE "Platform $ENV{Platform}")
    message(VERBOSE "is_x64_arch $ENV{is_x64_arch}")
endmacro()

if (Windows)
    message(VERBOSE "Checking for Windows compiler...")
    message(VERBOSE "Preferred Compiler: ${Compiler}")

    if ("${CMAKE_C_COMPILER}" MATCHES ".*[cC][lL](.exe)?$")
        message(VERBOSE "CMAKE_C_COMPILER: ${CMAKE_C_COMPILER} (matches cl.exe)")
    else()
        message(VERBOSE "CMAKE_C_COMPILER: ${CMAKE_C_COMPILER} (not cl.exe)")
    endif()

    if ("${CMAKE_CXX_COMPILER}" MATCHES ".*[cC][lL](.exe)?$")
        message(VERBOSE "CMAKE_CXX_COMPILER: ${CMAKE_CXX_COMPILER} (matches cl.exe)")
    else()
        message(VERBOSE "CMAKE_CXX_COMPILER: ${CMAKE_CXX_COMPILER} (not cl.exe)")
    endif()

    if (DEFINED Compiler AND Compiler STREQUAL "MSVC")
        message(VERBOSE "Preferred compiler set to MSVC. Setting up environment...")
        set_up_msvc_environment()
    elseif (NOT DEFINED Compiler AND (NOT DEFINED CMAKE_C_COMPILER OR NOT DEFINED CMAKE_CXX_COMPILER))
        message(VERBOSE "No compiler or preferred compiler set, using MSVC. Setting up environment...")
        set_up_msvc_environment()
    elseif ("${CMAKE_C_COMPILER}" MATCHES ".*[cC][lL](.exe)?$" OR "${CMAKE_CXX_COMPILER}" MATCHES ".*[cC][lL](.exe)?$")
        message(VERBOSE "Detected cl.exe, using MSVC. Setting up environment...")
        set_up_msvc_environment()
    elseif (Compiler STREQUAL "GNU")
        message(VERBOSE "Preferred compiler set to GNU")
        set_cache(Compiler "GNU")

        set_default(CMAKE_C_COMPILER gcc)
        set_default(CMAKE_CXX_COMPILER g++)
        set_default(CMAKE_C_LINK_EXECUTABLE ld)
        set_default(CMAKE_CXX_LINK_EXECUTABLE ld)
    elseif (Compiler STREQUAL "Clang")
        message(VERBOSE "Preferred compiler set to Clang")
        set_cache(Compiler "Clang")

        set_default(CMAKE_C_COMPILER clang)
        set_default(CMAKE_CXX_COMPILER clang++)
        set_default(CMAKE_C_LINK_EXECUTABLE ld)
        set_default(CMAKE_CXX_LINK_EXECUTABLE ld)
    endif()


    # we're dangerous
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS=1)
    add_compile_definitions(WIN32_LEAN_AND_MEAN=1)

    # Clear standard libraries, set the ones you want with LIBRARIES @Windows <libs>
    # in add_exe(...).
    set_cache(CMAKE_C_STANDARD_LIBRARIES   "")
    set_cache(CMAKE_CXX_STANDARD_LIBRARIES "")

    if (Compiler STREQUAL "MSVC")
        if (Build STREQUAL "Debug")
            # Debug libraries. If these are missing, MSVC will try to compile debug
            # builds but fail because debug symbols are missing.
            # These are not needed in release builds.
            set_cache(CMAKE_C_STANDARD_LIBRARIES   "kernel32.lib vcruntimed.lib ucrtd.lib")
            set_cache(CMAKE_CXX_STANDARD_LIBRARIES "kernel32.lib vcruntimed.lib ucrtd.lib")
        endif()
    endif()
else()
    # Not windows, check preferred compiler
    if (Compiler STREQUAL "GNU"
            OR (NOT DEFINED Compiler AND (NOT DEFINED CMAKE_C_COMPILER OR NOT DEFINED CMAKE_CXX_COMPILER))
        OR CMAKE_C_COMPILER MATCHES "g?cc")
        set_cache(Compiler "GNU")

        set_default(CMAKE_C_COMPILER gcc)
        set_default(CMAKE_CXX_COMPILER g++)
    elseif (Compiler STREQUAL "Clang")
        set_cache(Compiler "Clang")

        set_default(CMAKE_C_COMPILER clang)
        set_default(CMAKE_CXX_COMPILER clang++)
    endif()
endif()
