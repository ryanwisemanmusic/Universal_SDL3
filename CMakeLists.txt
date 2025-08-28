cmake_minimum_required(VERSION 3.10)
project(simplehttpserver)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Generate compile_commands.json for IntelliSense (ONLY ADDITION)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ===========
# Apache FOP
# ===========
find_program(JAVA_EXECUTABLE java)

#Search FOP Location
find_path(FOP_INSTALL_DIR
    NAMES bin/fop launchers/fop
    PATHS
        /lilyspark/opt/lib/java/fop
    NO_DEFAULT_PATH
)
message(STATUS "Success in locating FOP path")

find_file(FOP_LAUNCHER
    NAMES fop fop.sh
    PATHS
        /lilyspark/opt/lib/java/fop/bin
        /lilyspark/opt/lib/java/fop/launchers
    NO_DEFAULT_PATH
)
message(STATUS "Success in locating FOP file")

file(GLOB FOP_JARS "/lilyspark/opt/lib/java/fop/lib/*.jar")

# Attempt to execute the Java executable related to FOP 
if(JAVA_EXECUTABLE AND FOP_JARS)
    execute_process(
        COMMAND ${JAVA_EXECUTABLE} -cp "/lilyspark/opt/lib/java/fop/lib/*" org.apache.fop.cli.Main -version
        RESULT_VARIABLE FOP_TEST_RESULT
        OUTPUT_VARIABLE FOP_VERSION_OUTPUT
        ERROR_QUIET
    )
endif()

# Fallback for FOP incase it cannot be located
if(JAVA_EXECUTABLE AND FOP_LAUNCHER AND FOP_JARS AND FOP_TEST_RESULT EQUAL 0)
    set(FOP_FOUND TRUE)
    message(STATUS "✓ Apache FOP found and functional")
    message(STATUS "  Java: ${JAVA_EXECUTABLE}")
    message(STATUS "  Launcher: ${FOP_LAUNCHER}")
    message(STATUS "  JAR count: ${CMAKE_MATCH_COUNT}")
    message(STATUS "  Version: ${FOP_VERSION_OUTPUT}")
    add_compile_definitions(HAVE_APACHE_FOP=1)
    add_compile_definitions(FOP_CLASSPATH="/lilyspark/opt/lib/java/fop/lib/*")
    add_compile_definitions(FOP_LAUNCHER="${FOP_LAUNCHER}")
    
elseif(JAVA_EXECUTABLE AND FOP_JARS)
    set(FOP_FOUND PARTIAL)
    message(WARNING "⚠ Apache FOP JARs found but launcher/functionality issues")
    message(STATUS "  Java: ${JAVA_EXECUTABLE}")
    message(STATUS "  JAR count: ${CMAKE_MATCH_COUNT}")
    add_compile_definitions(HAVE_APACHE_FOP_JARS=1)
    add_compile_definitions(FOP_CLASSPATH="/lilyspark/opt/lib/java/fop/lib/*")
    
elseif(JAVA_EXECUTABLE)
    set(FOP_FOUND JAVA_ONLY)
    message(STATUS "ℹ Java found but Apache FOP missing - limited PDF support")
    add_compile_definitions(HAVE_JAVA_ONLY=1)
    
else()
    set(FOP_FOUND FALSE)
    message(STATUS "ℹ Apache FOP and/or Java not found - building without PDF support")
    add_compile_definitions(HAVE_APACHE_FOP=0)
endif()

# -------------------------------
# JACK2 Audio Support
# -------------------------------
message(STATUS "Checking for JACK2 audio support...")

# Search for pre-built JACK2
find_path(JACK2_INSTALL_DIR
    NAMES bin/jackd lib/libjack.so lib/libjack.so.0
    PATHS
        /lilyspark/opt/lib/audio/jack2
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_program(JACKD_EXECUTABLE jackd
    PATHS
        /lilyspark/opt/lib/audio/jack2/bin
        /usr/bin
        /usr/local/bin
    NO_DEFAULT_PATH
)

find_library(JACK_LIBRARY
    NAMES jack
    PATHS
        /lilyspark/opt/lib/audio/jack2/usr/lib
        /lilyspark/opt/lib/audio/jack2/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(JACK2_BUILD_FROM_SOURCE FALSE)
set(JACK2_FOUND FALSE)

if(JACKD_EXECUTABLE AND JACK_LIBRARY)
    set(JACK2_FOUND TRUE)
    message(STATUS "✓ JACK2 found (pre-built)")
    message(STATUS "  jackd: ${JACKD_EXECUTABLE}")
    message(STATUS "  library: ${JACK_LIBRARY}")
    
else()
    message(STATUS "ℹ JACK2 not found as pre-built - checking if we can build from source")
    
    # Check for build dependencies
    find_program(GIT_EXECUTABLE git)
    find_program(WAF_EXECUTABLE waf)
    find_program(MAKE_EXECUTABLE make)
    find_program(AUTOCONF_EXECUTABLE autoconf)
    find_program(AUTOMAKE_EXECUTABLE automake)
    
    if(GIT_EXECUTABLE AND (WAF_EXECUTABLE OR (MAKE_EXECUTABLE AND AUTOCONF_EXECUTABLE)))
        set(JACK2_BUILD_FROM_SOURCE TRUE)
        set(JACK2_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ JACK2 build dependencies found - will build from source")
        message(STATUS "  git: ${GIT_EXECUTABLE}")
        if(WAF_EXECUTABLE)
            message(STATUS "  waf: ${WAF_EXECUTABLE}")
        else()
            message(STATUS "  make: ${MAKE_EXECUTABLE}")
            message(STATUS "  autoconf: ${AUTOCONF_EXECUTABLE}")
        endif()
    else()
        set(JACK2_FOUND FALSE)
        message(STATUS "ℹ JACK2 not available and cannot build from source")
        if(NOT GIT_EXECUTABLE)
            message(STATUS "  Missing: git")
        endif()
        if(NOT WAF_EXECUTABLE AND NOT (MAKE_EXECUTABLE AND AUTOCONF_EXECUTABLE))
            message(STATUS "  Missing: build system (waf or autotools)")
        endif()
    endif()
endif()

# Set compile definitions based on JACK2 availability
if(JACK2_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_JACK2=1)
    add_compile_definitions(JACKD_EXECUTABLE="${JACKD_EXECUTABLE}")
    
elseif(JACK2_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_JACK2_SOURCE=1)
    add_compile_definitions(BUILD_JACK2_FROM_SOURCE=1)
    
    # Custom command to build JACK2 from source
    set(JACK2_SOURCE_DIR ${CMAKE_BINARY_DIR}/jack2-source)
    set(JACK2_INSTALL_PREFIX ${CMAKE_BINARY_DIR}/jack2-install)
    
    add_custom_command(
        OUTPUT ${JACK2_INSTALL_PREFIX}/bin/jackd
        COMMAND rm -rf ${JACK2_SOURCE_DIR}
        COMMAND git clone --depth=1 https://github.com/jackaudio/jack2.git ${JACK2_SOURCE_DIR}
        COMMAND cd ${JACK2_SOURCE_DIR} && if [ -x ./waf ]; then
            ./waf configure --prefix=${JACK2_INSTALL_PREFIX} --libdir=${JACK2_INSTALL_PREFIX}/lib &&
            ./waf build &&
            ./waf install;
        else
            ./configure --prefix=${JACK2_INSTALL_PREFIX} --libdir=${JACK2_INSTALL_PREFIX}/lib &&
            make -j$(nproc) &&
            make install;
        fi
        COMMENT "Building JACK2 from source"
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
    
    add_custom_target(jack2_build ALL DEPENDS ${JACK2_INSTALL_PREFIX}/bin/jackd)
    
else()
    add_compile_definitions(HAVE_JACK2=0)
    message(STATUS "ℹ Building without JACK2 audio support")
endif()


# -------------------------------
# PlutoSVG Graphics Support
# -------------------------------
message(STATUS "Checking for PlutoSVG graphics support...")

# Search for pre-built PlutoSVG
find_path(PLUTOSVG_INSTALL_DIR
    NAMES include/plutosvg.h lib/libplutosvg.so lib/libplutosvg.a
    PATHS
        /lilyspark/opt/lib/graphics
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(PLUTOSVG_LIBRARY
    NAMES plutosvg
    PATHS
        /lilyspark/opt/lib/graphics/usr/lib
        /lilyspark/opt/lib/graphics/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(PLUTOSVG_BUILD_FROM_SOURCE FALSE)
set(PLUTOSVG_FOUND FALSE)

if(PLUTOSVG_LIBRARY AND PLUTOSVG_INSTALL_DIR)
    set(PLUTOSVG_FOUND TRUE)
    message(STATUS "✓ PlutoSVG found (pre-built)")
    message(STATUS "  library: ${PLUTOSVG_LIBRARY}")
    message(STATUS "  install dir: ${PLUTOSVG_INSTALL_DIR}")
    
else()
    message(STATUS "ℹ PlutoSVG not found as pre-built - checking if we can build from source")
    
    # Check for build dependencies
    find_program(MESON_EXECUTABLE meson)
    find_program(NINJA_EXECUTABLE ninja)
    
    if(MESON_EXECUTABLE AND NINJA_EXECUTABLE)
        set(PLUTOSVG_BUILD_FROM_SOURCE TRUE)
        set(PLUTOSVG_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ PlutoSVG build dependencies found - will build from source")
        message(STATUS "  meson: ${MESON_EXECUTABLE}")
        message(STATUS "  ninja: ${NINJA_EXECUTABLE}")
        
    else()
        set(PLUTOSVG_FOUND FALSE)
        message(STATUS "ℹ PlutoSVG not available and cannot build from source")
        if(NOT MESON_EXECUTABLE)
            message(STATUS "  Missing: meson")
        endif()
        if(NOT NINJA_EXECUTABLE)
            message(STATUS "  Missing: ninja")
        endif()
    endif()
endif()

# Set compile definitions based on PlutoSVG availability
if(PLUTOSVG_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_PLUTOSVG=1)
    
elseif(PLUTOSVG_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_PLUTOSVG_SOURCE=1)
    add_compile_definitions(BUILD_PLUTOSVG_FROM_SOURCE=1)
    
    # Use ExternalProject for more reliable source building
    include(ExternalProject)
    
    set(PLUTOSVG_PREFIX ${CMAKE_BINARY_DIR}/plutosvg-install)
    
    ExternalProject_Add(plutosvg_build
        PREFIX ${PLUTOSVG_PREFIX}
        GIT_REPOSITORY https://github.com/sammycage/plutosvg.git
        GIT_SHALLOW 1
        GIT_PROGRESS 1
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        BUILD_IN_SOURCE 1
        BUILD_BYPRODUCTS ${PLUTOSVG_PREFIX}/lib/libplutosvg.so
    )
    
    # Add custom steps for the actual build process
    ExternalProject_Add_Step(plutosvg_build build_plutosvg
        COMMAND find . -type f -path "*/subprojects/*/meson.build" -exec sed -i "s/gnu11,c11/gnu11/g; s/gnu17,c17/gnu17/g" {} \\; || true
        COMMAND ${MESON_EXECUTABLE} setup builddir --prefix=${PLUTOSVG_PREFIX} -Dc_std=gnu11
        COMMAND ${NINJA_EXECUTABLE} -C builddir
        COMMAND ${NINJA_EXECUTABLE} -C builddir install
        DEPENDEES download update
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMENT "Building and installing PlutoSVG"
    )
    
else()
    add_compile_definitions(HAVE_PLUTOSVG=0)
    message(STATUS "ℹ Building without PlutoSVG graphics support")
endif()

# -------------------------------
# Simple Hello World executable
# -------------------------------
add_executable(simplehttpserver
    /lilyspark/app/src/main.cpp
)


# Add environment variables as compile definitions for runtime use
if(FOP_FOUND STREQUAL "TRUE" OR FOP_FOUND STREQUAL "PARTIAL")
    target_compile_definitions(simplehttpserver PRIVATE
        JAVA_EXECUTABLE="${JAVA_EXECUTABLE}"
    )
endif()

# Optional: Create a feature summary
message(STATUS "=== BUILD CONFIGURATION SUMMARY ===")
message(STATUS "Apache FOP Support: ${FOP_FOUND}")
if(JAVA_EXECUTABLE)
    message(STATUS "  Java Runtime: ${JAVA_EXECUTABLE}")
endif()
if(FOP_LAUNCHER)
    message(STATUS "  FOP Launcher: ${FOP_LAUNCHER}")
endif()
if(FOP_JARS)
    list(LENGTH FOP_JARS JAR_COUNT)
    message(STATUS "  FOP JARs Found: ${JAR_COUNT}")
endif()
message(STATUS "===================================")

# Link against JACK2 if available
if(JACK2_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${JACK_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        /lilyspark/opt/lib/audio/jack2/usr/include
        /usr/include
        /usr/local/include
    )
    
elseif(JACK2_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_dependencies(simplehttpserver jack2_build)
    target_link_libraries(simplehttpserver PRIVATE ${JACK2_INSTALL_PREFIX}/lib/libjack.so)
    target_include_directories(simplehttpserver PRIVATE ${JACK2_INSTALL_PREFIX}/include)
endif()

# Update configuration summary with JACK2 status
message(STATUS "JACK2 Audio Support: ${JACK2_FOUND}")
if(JACK2_FOUND STREQUAL "TRUE")
    message(STATUS "  jackd: ${JACKD_EXECUTABLE}")
    message(STATUS "  library: ${JACK_LIBRARY}")
elseif(JACK2_FOUND STREQUAL "SOURCE_AVAILABLE")
    message(STATUS "  Build: From source during compilation")
endif()

# Link against PlutoSVG if available
if(PLUTOSVG_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${PLUTOSVG_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        ${PLUTOSVG_INSTALL_DIR}/include
        /usr/include
        /usr/local/include
    )
    
elseif(PLUTOSVG_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_dependencies(simplehttpserver plutosvg_build)
    
    # Add the include and library directories from the built PlutoSVG
    target_include_directories(simplehttpserver PRIVATE
        ${PLUTOSVG_PREFIX}/include
    )
    
    target_link_directories(simplehttpserver PRIVATE
        ${PLUTOSVG_PREFIX}/lib
    )
    
    target_link_libraries(simplehttpserver PRIVATE plutosvg)
endif()

# Update configuration summary with PlutoSVG status
message(STATUS "PlutoSVG Graphics Support: ${PLUTOSVG_FOUND}")
if(PLUTOSVG_FOUND STREQUAL "TRUE")
    message(STATUS "  library: ${PLUTOSVG_LIBRARY}")
elseif(PLUTOSVG_FOUND STREQUAL "SOURCE_AVAILABLE")
    message(STATUS "  Build: From source during compilation")
endif()

# No external dependencies needed for Hello World
target_compile_definitions(simplehttpserver PRIVATE
    HELLO_WORLD_BUILD=1
)

# Installation
install(TARGETS simplehttpserver
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib/static
)
