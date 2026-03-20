option(BUILD_ETHERNET_INTERFACE "Build ethernet interface support" OFF)
option(BUILD_WLAN_INTERFACE "Build wlan interface support" ON)

set(COMPONENT_SRC "")
set(MICROROS_COMPONENT_INCLUDE_DIRS "network_interfaces" "include" "include/include")

if(BUILD_ETHERNET_INTERFACE)
    list(APPEND COMPONENT_SRC "network_interfaces/uros_ethernet_netif.c")
endif()

if(BUILD_WLAN_INTERFACE)
    list(APPEND COMPONENT_SRC "network_interfaces/uros_wlan_netif.c")
endif()

# Ensure include directories exist before idf_component_register checks them
file(MAKE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/include/include")

file(GLOB microros_generated_include_dirs LIST_DIRECTORIES true
     "${CMAKE_CURRENT_LIST_DIR}/include/include/*")
foreach(microros_generated_include_dir ${microros_generated_include_dirs})
    if(IS_DIRECTORY ${microros_generated_include_dir})
        get_filename_component(microros_generated_include_name ${microros_generated_include_dir} NAME)
        list(APPEND MICROROS_COMPONENT_INCLUDE_DIRS "include/include/${microros_generated_include_name}")
    endif()
endforeach()

idf_component_register(SRCS ${COMPONENT_SRC}
                       INCLUDE_DIRS ${MICROROS_COMPONENT_INCLUDE_DIRS}
                       REQUIRES nvs_flash esp_wifi esp_eth lwip)

if(CMAKE_GENERATOR STREQUAL "Unix Makefiles")
set(submake "make")
else()
set(submake "make")
endif()

if (${IDF_VERSION_MAJOR} EQUAL 5)
    set(CMAKE_C_STANDARD 17)
else()
    set(CMAKE_C_STANDARD 11)
endif()

set(APP_COLCON_META "${PROJECT_DIR}/app-colcon.meta")
if(NOT EXISTS "${APP_COLCON_META}")
set(APP_COLCON_META "")
endif()

set(EXTRA_ROS_PACKAGES "${PROJECT_DIR}/extra_ros_packages")
if(NOT EXISTS "${EXTRA_ROS_PACKAGES}")
set(EXTRA_ROS_PACKAGES "${COMPONENT_DIR}/extra_packages")
endif()

if(${CONFIG_MICRO_ROS_ESP_EMBEDDEDRTPS_MIDDLEWARE})
message(STATUS "Using embeddedRTPS middleware")
set(MIDDLEWARE "embeddedrtps")
else()
message(STATUS "Using Micro XRCE-DDS middleware")
set(MIDDLEWARE "microxrcedds")
endif()

# Create a list of packages to get includes
idf_build_get_property(PACKAGES BUILD_COMPONENTS)

# Add includes for each package
foreach(package ${PACKAGES})
    idf_component_get_property(${package}_dir ${package} COMPONENT_DIR)
    idf_component_get_property(${package}_includes ${package} INCLUDE_DIRS)
    list(TRANSFORM ${package}_includes PREPEND " -I${${package}_dir}/")
    string(REPLACE ";" "" ${package}_includes_string "${${package}_includes}")
endforeach()

# Workaround for https://github.com/ros2/rosidl/pull/739
string(APPEND IDF_INCLUDES "-I${COMPONENT_DIR}/include_override")

# Create a string with all packages with a for loop
foreach(package ${PACKAGES})
    string(APPEND IDF_INCLUDES "${${package}_includes_string}")
endforeach()

# ESP-IDF 6.x injects esp_libc platform wrapper headers into component includes.
# Those wrappers rely on the normal IDF build's libc header ordering, but the
# standalone micro-ROS colcon toolchain does not reproduce that environment.
# Excluding platform_include here avoids rcutils pulling the wrapper layer and
# then resolving into an incompatible libc header set.
string(REPLACE " -I${IDF_PATH}/components/esp_libc/platform_include" "" IDF_INCLUDES "${IDF_INCLUDES}")

# Prefer the SDK's generated sdkconfig.h from the active IDF build.
set(MICROROS_SDKCONFIG_DIR "${CMAKE_BINARY_DIR}/config")
if(NOT EXISTS "${MICROROS_SDKCONFIG_DIR}/sdkconfig.h")
    set(MICROROS_SDKCONFIG_DIR "")
endif()

# Check if pre-built libmicroros.a exists — skip source build if so
if(EXISTS "${COMPONENT_DIR}/libmicroros.a" AND EXISTS "${COMPONENT_DIR}/include/include")
    message(STATUS "Using pre-built libmicroros.a, skipping micro-ROS build")
    set(libmicroros_ret 0)
else()
    message(STATUS "Building libmicroros from source (this may take a while)...")
    # --- Dynamic toolchain version fix ---
    # Some IDF-bundled xtensa-esp-elf versions have linker bugs.
    # Auto-detect the version from CMAKE_C_COMPILER and replace if buggy.
    set(_BUGGY_VERSIONS "esp-14.2.0_20241119;esp-14.2.0_20251107")
    string(REGEX MATCH "xtensa-esp-elf/([^/]+)/" _tc_match "${CMAKE_C_COMPILER}")
    if(_tc_match)
        set(_current_tc_ver "${CMAKE_MATCH_1}")
        list(FIND _BUGGY_VERSIONS "${_current_tc_ver}" _buggy_idx)
        if(NOT _buggy_idx EQUAL -1)
            # Scan ~/.espressif/tools/xtensa-esp-elf/ for a non-buggy replacement
            file(GLOB _tc_candidates "$ENV{HOME}/.espressif/tools/xtensa-esp-elf/*/xtensa-esp-elf/bin/xtensa-esp32s3-elf-gcc")
            set(_best_replacement "")
            foreach(_cand ${_tc_candidates})
                string(REGEX MATCH "xtensa-esp-elf/([^/]+)/" _cand_match "${_cand}")
                if(_cand_match)
                    set(_cand_ver "${CMAKE_MATCH_1}")
                    list(FIND _BUGGY_VERSIONS "${_cand_ver}" _cand_buggy)
                    if(_cand_buggy EQUAL -1)
                        # Pick the lexicographically greatest (newest) version
                        if("${_cand_ver}" STRGREATER "${_best_replacement}")
                            set(_best_replacement "${_cand_ver}")
                        endif()
                    endif()
                endif()
            endforeach()
            if(_best_replacement)
                message(STATUS "micro-ROS: replacing buggy toolchain ${_current_tc_ver} -> ${_best_replacement}")
                string(REPLACE "${_current_tc_ver}" "${_best_replacement}" CMAKE_C_COMPILER "${CMAKE_C_COMPILER}")
                string(REPLACE "${_current_tc_ver}" "${_best_replacement}" CMAKE_CXX_COMPILER "${CMAKE_CXX_COMPILER}")
                string(REPLACE "${_current_tc_ver}" "${_best_replacement}" CMAKE_AR "${CMAKE_AR}")
                string(REPLACE "${_current_tc_ver}" "${_best_replacement}" CMAKE_STRIP "${CMAKE_STRIP}")
            else()
                message(WARNING "micro-ROS: toolchain ${_current_tc_ver} is buggy but no replacement found")
            endif()
        endif()
    endif()
    # --- End dynamic toolchain version fix ---
    # Remove stale toolchain file to ensure current compiler path is used
    file(REMOVE "${COMPONENT_DIR}/esp32_toolchain.cmake")
    execute_process(
        WORKING_DIRECTORY ${COMPONENT_DIR}
        RESULT_VARIABLE libmicroros_ret
        COMMAND
            ${submake} -j -f libmicroros.mk
                    X_CC=${CMAKE_C_COMPILER}
                    X_AR=${CMAKE_AR}
                    X_STRIP=${CMAKE_STRIP}
                    X_CFLAGS=${CMAKE_C_FLAGS}
                    X_CXX=${CMAKE_CXX_COMPILER}
                    X_CXXFLAGS=${CMAKE_CXX_FLAGS}
                    C_STANDARD=${CMAKE_C_STANDARD}
                    MIDDLEWARE=${MIDDLEWARE}
                    BUILD_DIR=${CMAKE_BINARY_DIR}
                    IDF_INCLUDES=${IDF_INCLUDES}
                    IDF_PATH=${IDF_PATH}
                    IDF_TARGET=${IDF_TARGET}
                    MICROROS_SDKCONFIG_DIR=${MICROROS_SDKCONFIG_DIR}
                    APP_COLCON_META=${APP_COLCON_META}
                    IDF_VERSION_MAJOR=${IDF_VERSION_MAJOR}
                    IDF_VERSION_MINOR=${IDF_VERSION_MINOR}
                    EXTRA_ROS_PACKAGES=${EXTRA_ROS_PACKAGES}
    )
    if(libmicroros_ret AND NOT libmicroros_ret EQUAL 0)
      message(FATAL_ERROR "FAILED: ${libmicroros_ret}")
    endif()
endif()

add_prebuilt_library(libmicroros-prebuilt ""
                     REQUIRES lwip)

add_dependencies(libmicroros-prebuilt libmicroros_project)

set_target_properties(libmicroros-prebuilt PROPERTIES IMPORTED_LOCATION ${COMPONENT_DIR}/libmicroros.a)
target_include_directories(libmicroros-prebuilt INTERFACE ${COMPONENT_DIR}/include)

file(GLOB include_folders LIST_DIRECTORIES true CONFIGURE_DEPENDS ${COMPONENT_DIR}/include/*)
foreach(include_folder ${include_folders})
    if(IS_DIRECTORY ${include_folder})
        get_filename_component(folder_name ${include_folder} NAME)
        target_include_directories(libmicroros-prebuilt INTERFACE ${COMPONENT_DIR}/include/${folder_name})
    endif()
endforeach()

file(GLOB microros_generated_folders LIST_DIRECTORIES true CONFIGURE_DEPENDS
     ${COMPONENT_DIR}/include/include/*)
foreach(microros_generated_folder ${microros_generated_folders})
    if(IS_DIRECTORY ${microros_generated_folder})
        get_filename_component(folder_name ${microros_generated_folder} NAME)
        target_include_directories(libmicroros-prebuilt INTERFACE
                                   ${COMPONENT_DIR}/include/include/${folder_name})
    endif()
endforeach()

add_dependencies(${COMPONENT_LIB} libmicroros-prebuilt)
target_link_libraries(${COMPONENT_LIB} INTERFACE libmicroros-prebuilt)

set_directory_properties( PROPERTIES ADDITIONAL_CLEAN_FILES
    "${COMPONENT_DIR}/include;${COMPONENT_DIR}/micro_ros_dev;${COMPONENT_DIR}/micro_ros_src;${COMPONENT_DIR}/esp32_toolchain.cmake" )

add_custom_target(clean-microros COMMAND ${submake} -f libmicroros.mk clean
                            WORKING_DIRECTORY ${COMPONENT_DIR})
