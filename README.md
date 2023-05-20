# better-cmake
CMake include files to make CMake more bearable.

## How to include

Either copy [betterConfig.cmake](/cmake/betterConfig.cmake) into your project or `git clone/add submodule` this project and add `find_package(better REQUIRED NO_DEFAULT_PATH PATHS path/to/better-cmake/cmake)` to your CMakeLists.txt.

Installing and including from global paths also works.

## Installing (optional)

```sh
$ mkdir bin
$ cd bin
$ cmake path/to/better-cmake
$ sudo make install
```

## Usage

`better-cmake` provides many macros and a few variables, many of which should probably be in CMake by default, but alas, here we are.

### Variables
- `ROOT`: same as `CMAKE_CURRENT_SOURCE_DIR`
- `ROOT_BIN`: same as `CMAKE_CURRENT_BINARY_DIR`

### Macros

- `increment(VAR)`: increases `VAR` by 1
- `decrement(VAR)`: decreases `VAR` by 1
- `set_default(VAR DEFAULT_VALUE)`: if `VAR` is not set, sets it to `DEFAULT_VALUE`
- `set_export(VAR)`: exports `VAR` to the parent scope (e.g. if the current CMake file was added through `add_subdirectory`)
- `get_deepest_common_parent_path(OUT_VAR <PATHS...>)`: finds the deepest common (parent) path among all paths in `PATHS... (ARGN)` and writes it to `OUT_VAR`, e.g.:
```cmake
get_deepest_common_parent_path(DIR "/home/user/testfile.txt"
                                   "/home/user/directory"
                                   "/home/user/dev/git/better-cmake")
# DIR is now /home/user
```
- `copy_files(DESTINATION <dest> FILES <files...> [BASE <base-path>])`: copies all files `files...` to `dest`, relative to base-path, using `configure_file`. Because `configure_file` is used, the files will be copied at "configure" time (i.e. when CMake is run), and files at the destination will be updated when they are modified in at the source.
If `BASE base-path` is omitted, base path will be set to the deepest common parent path of all files and destination, e.g.:
```cmake
copy_files(DESTINATION ./bin FILES ./src/file1.txt ./src/dir/file2.txt)
# files will be copied to: ./bin/src/file1.txt ./bin/src/dir/file2.txt
```
- `copy_files_target(TARGET_VAR DESTINATION <dest> FILES <files...> [BASE <base-path>])`: same thing as `copy_files`, but uses targets instead of `configure_file`, i.e. files are not copied when CMake is run, but when the copied files are needed to be built. All targets for the output files are written as a list to `TARGET_VAR`.
- `install_library(TARGET <target> [HEADERS <headers...>] [SOURCES_DIR <path>])`: installs the target library `TARGET target` to system paths. `HEADERS headers...` is a list of header files to install, although they will be installed only in the root directory of the system path for the target, instead prefer to use the `SOURCES_DIR path` argument and give it the source (or include) path of the library, which will preserve subdirectory structure when installing header files.
- `install_executable(TARGET <target> [NAME <name>])`: installs the target executable `TARGET target` to system paths. Optionally add the `NAME name` argument to create an alias for the executable.
- `split_version_string(VERSION MAJOR MINOR PATCH)`: splits the string argument `VERSION` into its `MAJOR`, `MINOR` and `PATCH` parts. If a part is not contained, it will be 0. Valid version strings have the schema `[MAJOR[.MINOR[.PATCH]]]`.
- `compare_versions(RESULT V1 V2)`: compares version strings `V1` and `V2` and sets `RESULT` to -1 if `V1 < V2`, 0 if `V1 = V2` and 1 if `V1 > V2`.
- `sanitize_variable(VAR OUT)`: replaces `/.-` in `VAR` with `_` and writes the result to `OUT`.

### Targets

```cmake
add_lib(NAME LINKAGE
    [PIE]
    
    [VERSION version]
    [SOURCES_DIR dir]             # top directory of all source files, if "src" folder is present, can be omitted
    [GENERATE_TARGET_HEADER file] # path to target header file
    [CPP_VERSION version]         # defaults to 17 if omitted
        
    [CPP_WARNINGS warnings...]  # ALL, EXTRA, PEDANTIC or normal compiler args
    [TESTS tests...]            # t1 tests or directories of tests
    [SOURCES files...]          # extra sources, optional
    [INCLUDE_DIRS dirs...]      # extra include directories, optional
    [LINK_DIRS dirs...]         # extra directories to look at when linking, optional
    [LIBRARIES libs...]         # libraries to link
    [EXT                        # better-cmake external dependencies
      <LIB name version path [INCLUDE] [LINK] [GIT_SUBMODULE]>...
    ]
)
```

`add_exe` is the same as `add_lib` except theres no `LINKAGE` or `PIE` options.
