cmake_minimum_required(VERSION 3.10)
project(simplehttpserver)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Generate compile_commands.json for IntelliSense (ONLY ADDITION)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ===========
# Apache FOP - BULLETPROOF VERSION
# ===========
message(STATUS "Starting FOP detection (safe mode)...")

# Safe Java detection with multiple fallbacks
set(JAVA_EXECUTABLE "NOTFOUND")
find_program(JAVA_EXECUTABLE_TMP java)
if(JAVA_EXECUTABLE_TMP)
    set(JAVA_EXECUTABLE ${JAVA_EXECUTABLE_TMP})
    message(STATUS "Java executable found: ${JAVA_EXECUTABLE}")
else()
    message(STATUS "Java not found in PATH")
endif()

# Safe FOP directory check
set(FOP_BASE_DIR "/lilyspark/opt/lib/java/fop")
set(FOP_INSTALL_DIR "NOTFOUND")
set(FOP_LAUNCHER "NOTFOUND")
set(FOP_JARS "")
set(FOP_JAR_COUNT 0)
set(FOP_CLASSPATH "")

# Check if FOP directory exists - with multiple safety checks
if(EXISTS ${FOP_BASE_DIR} AND IS_DIRECTORY ${FOP_BASE_DIR})
    set(FOP_INSTALL_DIR ${FOP_BASE_DIR})
    message(STATUS "✓ FOP directory found: ${FOP_INSTALL_DIR}")
    
    # Safe launcher detection
    foreach(LAUNCHER_PATH 
        "${FOP_BASE_DIR}/bin/fop"
        "${FOP_BASE_DIR}/bin/fop.sh" 
        "${FOP_BASE_DIR}/launchers/fop"
    )
        if(EXISTS ${LAUNCHER_PATH} AND NOT FOP_LAUNCHER)
            set(FOP_LAUNCHER ${LAUNCHER_PATH})
        endif()
    endforeach()
    
    # Safe JAR detection with error suppression
    if(EXISTS "${FOP_BASE_DIR}/lib")
        file(GLOB FOP_JARS_TMP "${FOP_BASE_DIR}/lib/*.jar")
        if(FOP_JARS_TMP)
            set(FOP_JARS ${FOP_JARS_TMP})
            list(LENGTH FOP_JARS FOP_JAR_COUNT)
            # Safe classpath creation
            if(FOP_JAR_COUNT GREATER 0)
                list(JOIN FOP_JARS ":" FOP_CLASSPATH)
            endif()
        endif()
    endif()
endif()

message(STATUS "FOP install dir: ${FOP_INSTALL_DIR}")
message(STATUS "FOP launcher: ${FOP_LAUNCHER}")
message(STATUS "FOP JARs found: ${FOP_JAR_COUNT}")

# SUPER SAFE FOP testing - no Java execution that could fail
set(FOP_FOUND "FALSE")
set(FOP_VERSION "unknown")

if(JAVA_EXECUTABLE AND JAVA_EXECUTABLE STREQUAL "NOTFOUND")
    message(STATUS "Java not available for FOP testing")
elseif(FOP_JAR_COUNT GREATER 0)
    # Method 1: Simple existence check without execution
    set(FOP_FOUND "PARTIAL")
    message(STATUS "✓ FOP JARs found - assuming partial functionality")
    
    # Method 2: Try to extract version from filename (safe)
    if(FOP_JARS)
        list(GET FOP_JARS 0 FIRST_JAR)
        get_filename_component(JAR_NAME ${FIRST_JAR} NAME)
        if(JAR_NAME MATCHES "fop.*([0-9]+\\.[0-9]+\\.[0-9]+)")
            set(FOP_VERSION ${CMAKE_MATCH_1})
            set(FOP_FOUND "TRUE")
            message(STATUS "✓ FOP version detected from filename: ${FOP_VERSION}")
        endif()
    endif()
elseif(JAVA_EXECUTABLE AND NOT JAVA_EXECUTABLE STREQUAL "NOTFOUND")
    set(FOP_FOUND "JAVA_ONLY")
    message(STATUS "ℹ Java available but no FOP found")
else()
    set(FOP_FOUND "FALSE")
    message(STATUS "ℹ No Java or FOP available")
endif()

# SAFEST POSSIBLE compile definitions - no complex operations
if(FOP_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_APACHE_FOP=1)
    message(STATUS "✓ Building with full FOP support")
elseif(FOP_FOUND STREQUAL "PARTIAL")
    add_compile_definitions(HAVE_APACHE_FOP_JARS=1)
    message(STATUS "⚠ Building with partial FOP support (JARs only)")
elseif(FOP_FOUND STREQUAL "JAVA_ONLY")
    add_compile_definitions(HAVE_JAVA_ONLY=1)
    message(STATUS "⚠ Building with Java only (no FOP)")
else()
    add_compile_definitions(HAVE_APACHE_FOP=0)
    message(STATUS "ℹ Building without PDF support")
endif()

# Safe conditional definitions
if(FOP_CLASSPATH AND NOT FOP_CLASSPATH STREQUAL "")
    add_compile_definitions(FOP_CLASSPATH="${FOP_CLASSPATH}")
endif()
if(FOP_LAUNCHER AND NOT FOP_LAUNCHER STREQUAL "NOTFOUND")
    add_compile_definitions(FOP_LAUNCHER="${FOP_LAUNCHER}")
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
# libpciaccess Hardware Support
# -------------------------------
message(STATUS "Checking for libpciaccess hardware support...")

# Search for pre-built libpciaccess
find_path(PCACCESS_INSTALL_DIR
    NAMES include/pciaccess.h lib/libpciaccess.so lib/libpciaccess.a
    PATHS
        /lilyspark/opt/lib/sys/usr
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(PCACCESS_LIBRARY
    NAMES pciaccess
    PATHS
        /lilyspark/opt/lib/sys/usr/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(PCACCESS_BUILD_FROM_SOURCE FALSE)
set(PCACCESS_FOUND FALSE)

if(PCACCESS_LIBRARY AND PCACCESS_INSTALL_DIR)
    set(PCACCESS_FOUND TRUE)
    message(STATUS "✓ libpciaccess found (pre-built)")
    message(STATUS "  library: ${PCACCESS_LIBRARY}")
    message(STATUS "  install dir: ${PCACCESS_INSTALL_DIR}")
    
else()
    message(STATUS "ℹ libpciaccess not found as pre-built - checking if we can build from source")
    
    # Check for build dependencies
    find_program(MESON_EXECUTABLE meson)
    find_program(NINJA_EXECUTABLE ninja)
    find_program(GIT_EXECUTABLE git)
    
    if(MESON_EXECUTABLE AND NINJA_EXECUTABLE AND GIT_EXECUTABLE)
        set(PCACCESS_BUILD_FROM_SOURCE TRUE)
        set(PCACCESS_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ libpciaccess build dependencies found - will build from source")
        message(STATUS "  meson: ${MESON_EXECUTABLE}")
        message(STATUS "  ninja: ${NINJA_EXECUTABLE}")
        message(STATUS "  git: ${GIT_EXECUTABLE}")
        
    else()
        set(PCACCESS_FOUND FALSE)
        message(STATUS "ℹ libpciaccess not available and cannot build from source")
        if(NOT MESON_EXECUTABLE)
            message(STATUS "  Missing: meson")
        endif()
        if(NOT NINJA_EXECUTABLE)
            message(STATUS "  Missing: ninja")
        endif()
        if(NOT GIT_EXECUTABLE)
            message(STATUS "  Missing: git")
        endif()
    endif()
endif()

# Set compile definitions based on libpciaccess availability
if(PCACCESS_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_PCIACCESS=1)
    
elseif(PCACCESS_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_PCIACCESS_SOURCE=1)
    add_compile_definitions(BUILD_PCIACCESS_FROM_SOURCE=1)
    
    # Use ExternalProject for libpciaccess source building
    include(ExternalProject)
    
    set(PCACCESS_PREFIX ${CMAKE_BINARY_DIR}/pciaccess-install)
    
    ExternalProject_Add(pciaccess_build
        PREFIX ${PCACCESS_PREFIX}
        GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libpciaccess.git
        GIT_SHALLOW 1
        GIT_PROGRESS 1
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS ${PCACCESS_PREFIX}/lib/libpciaccess.so
    )
    
    # Add custom steps for the actual build process
    ExternalProject_Add_Step(pciaccess_build build_pciaccess
        COMMAND export PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/sys" &&
            export PKG_CONFIG_PATH="/lilyspark/opt/lib/sys/usr/lib/pkgconfig" &&
            ${MESON_EXECUTABLE} setup builddir --prefix=${PCACCESS_PREFIX}
        COMMAND ${NINJA_EXECUTABLE} -C builddir
        COMMAND ${NINJA_EXECUTABLE} -C builddir install
        DEPENDEES download update
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMENT "Building and installing libpciaccess"
    )
    
else()
    add_compile_definitions(HAVE_PCIACCESS=0)
    message(STATUS "ℹ Building without libpciaccess hardware support")
endif()

# -------------------------------
# libdrm Graphics Support
# -------------------------------
message(STATUS "Checking for libdrm graphics support...")

# Search for pre-built libdrm
find_path(LIBDRM_INSTALL_DIR
    NAMES include/libdrm/drm.h lib/libdrm.so lib/libdrm.a
    PATHS
        /lilyspark/opt/lib/sys/usr
        #Check for discrepancies here if this fails, but we'll fallback if not correct anyways
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(LIBDRM_LIBRARY
    NAMES drm
    PATHS
        /lilyspark/opt/lib/sys/usr/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(LIBDRM_BUILD_FROM_SOURCE FALSE)
set(LIBDRM_FOUND FALSE)

if(LIBDRM_LIBRARY AND LIBDRM_INSTALL_DIR)
    set(LIBDRM_FOUND TRUE)
    message(STATUS "✓ libdrm found (pre-built)")
    message(STATUS "  library: ${LIBDRM_LIBRARY}")
    message(STATUS "  install dir: ${LIBDRM_INSTALL_DIR}")
    
else()
    message(STATUS "ℹ libdrm not found as pre-built - checking if we can build from source")
    
    # Check for build dependencies
    find_program(MESON_EXECUTABLE meson)
    find_program(NINJA_EXECUTABLE ninja)
    find_program(CURL_EXECUTABLE curl)
    find_program(TAR_EXECUTABLE tar)
    find_program(CLANG_16_EXECUTABLE NAMES clang-16 PATHS /lilyspark/opt/lib/sys/compiler/bin NO_DEFAULT_PATH)
    find_program(CLANGXX_16_EXECUTABLE NAMES clang++-16 PATHS /lilyspark/opt/lib/sys/compiler/bin NO_DEFAULT_PATH)
    
    if(MESON_EXECUTABLE AND NINJA_EXECUTABLE AND CURL_EXECUTABLE AND TAR_EXECUTABLE AND CLANG_16_EXECUTABLE AND CLANGXX_16_EXECUTABLE)
        set(LIBDRM_BUILD_FROM_SOURCE TRUE)
        set(LIBDRM_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ libdrm build dependencies found - will build from source")
        message(STATUS "  meson: ${MESON_EXECUTABLE}")
        message(STATUS "  ninja: ${NINJA_EXECUTABLE}")
        message(STATUS "  clang-16: ${CLANG_16_EXECUTABLE}")
        message(STATUS "  clang++-16: ${CLANGXX_16_EXECUTABLE}")
        
    else()
        set(LIBDRM_FOUND FALSE)
        message(STATUS "ℹ libdrm not available and cannot build from source")
        if(NOT MESON_EXECUTABLE)
            message(STATUS "  Missing: meson")
        endif()
        if(NOT NINJA_EXECUTABLE)
            message(STATUS "  Missing: ninja")
        endif()
        if(NOT CLANG_16_EXECUTABLE)
            message(STATUS "  Missing: clang-16")
        endif()
    endif()
endif()

# Set compile definitions based on libdrm availability
if(LIBDRM_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_LIBDRM=1)
    
elseif(LIBDRM_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_LIBDRM_SOURCE=1)
    add_compile_definitions(BUILD_LIBDRM_FROM_SOURCE=1)
    
    # Use ExternalProject for libdrm source building
    include(ExternalProject)
    
    set(LIBDRM_PREFIX ${CMAKE_BINARY_DIR}/libdrm-install)
    set(LIBDRM_VER 2.4.125)
    set(LIBDRM_URL "https://dri.freedesktop.org/libdrm/libdrm-${LIBDRM_VER}.tar.xz")
    
    ExternalProject_Add(libdrm_build
        PREFIX ${LIBDRM_PREFIX}
        URL ${LIBDRM_URL}
        DOWNLOAD_DIR ${CMAKE_BINARY_DIR}/downloads
        DOWNLOAD_NAME libdrm-${LIBDRM_VER}.tar.xz
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS ${LIBDRM_PREFIX}/lib/libdrm.so
    )
    
    # Add custom steps for the actual build process
    ExternalProject_Add_Step(libdrm_build build_libdrm
        COMMAND ${CMAKE_COMMAND} -E make_directory ${LIBDRM_PREFIX}
        COMMAND tar -xf libdrm-${LIBDRM_VER}.tar.xz --strip-components=1
        COMMAND export PATH="/lilyspark/opt/lib/sys/compiler/bin:$PATH" &&
            export CC=/lilyspark/opt/lib/sys/compiler/bin/clang-16 &&
            export CXX=/lilyspark/opt/lib/sys/compiler/bin/clang++-16 &&
            export PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/sys" &&
            export PKG_CONFIG_PATH="/lilyspark/opt/lib/sys/usr/lib/pkgconfig:/lilyspark/opt/lib/sys/compiler/lib/pkgconfig" &&
            export CFLAGS="--sysroot=/lilyspark/opt/lib/sys -I/lilyspark/opt/lib/sys/usr/include -I/lilyspark/opt/lib/sys/compiler/include -march=armv8-a" &&
            export CXXFLAGS="$CFLAGS" &&
            export LDFLAGS="--sysroot=/lilyspark/opt/lib/sys -L/lilyspark/opt/lib/sys/usr/lib -L/lilyspark/opt/lib/sys/compiler/lib" &&
            ${MESON_EXECUTABLE} setup builddir
                --prefix=${LIBDRM_PREFIX}
                --libdir=lib
                -Dtests=false
                -Dudev=true
                -Dvalgrind=disabled
        COMMAND ${NINJA_EXECUTABLE} -C builddir
        COMMAND ${NINJA_EXECUTABLE} -C builddir install
        DEPENDEES download
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMENT "Building and installing libdrm with LLVM16 toolchain"
    )
    
else()
    add_compile_definitions(HAVE_LIBDRM=0)
    message(STATUS "ℹ Building without libdrm graphics support")
endif()

# -------------------------------
# libepoxy Graphics Support
# -------------------------------
message(STATUS "Checking for libepoxy graphics support...")

# Search for pre-built libepoxy
find_path(EPOXY_INSTALL_DIR
    NAMES include/epoxy/gl.h lib/libepoxy.so lib/libepoxy.a
    PATHS
        /lilyspark/opt/lib/sys/usr
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(EPOXY_LIBRARY
    NAMES epoxy
    PATHS
        /lilyspark/opt/lib/sys/usr/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(EPOXY_BUILD_FROM_SOURCE FALSE)
set(EPOXY_FOUND FALSE)

if(EPOXY_LIBRARY AND EPOXY_INSTALL_DIR)
    set(EPOXY_FOUND TRUE)
    message(STATUS "✓ libepoxy found (pre-built)")
    message(STATUS "  library: ${EPOXY_LIBRARY}")
    message(STATUS "  install dir: ${EPOXY_INSTALL_DIR}")
    
else()
    message(STATUS "ℹ libepoxy not found as pre-built - checking if we can build from source")
    
    # Check for build dependencies
    find_program(MESON_EXECUTABLE meson)
    find_program(NINJA_EXECUTABLE ninja)
    find_program(GIT_EXECUTABLE git)
    find_program(CLANG_16_EXECUTABLE NAMES clang-16 PATHS /lilyspark/opt/lib/sys/compiler/bin NO_DEFAULT_PATH)
    find_program(CLANGXX_16_EXECUTABLE NAMES clang++-16 PATHS /lilyspark/opt/lib/sys/compiler/bin NO_DEFAULT_PATH)
    find_program(LLVM_CONFIG_EXECUTABLE NAMES llvm-config PATHS /lilyspark/opt/lib/sys/compiler/bin NO_DEFAULT_PATH)
    
    if(MESON_EXECUTABLE AND NINJA_EXECUTABLE AND GIT_EXECUTABLE AND CLANG_16_EXECUTABLE AND CLANGXX_16_EXECUTABLE)
        set(EPOXY_BUILD_FROM_SOURCE TRUE)
        set(EPOXY_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ libepoxy build dependencies found - will build from source with LLVM16")
        message(STATUS "  meson: ${MESON_EXECUTABLE}")
        message(STATUS "  ninja: ${NINJA_EXECUTABLE}")
        message(STATUS "  clang-16: ${CLANG_16_EXECUTABLE}")
        message(STATUS "  clang++-16: ${CLANGXX_16_EXECUTABLE}")
        
    else()
        set(EPOXY_FOUND FALSE)
        message(STATUS "ℹ libepoxy not available and cannot build from source")
        if(NOT MESON_EXECUTABLE)
            message(STATUS "  Missing: meson")
        endif()
        if(NOT NINJA_EXECUTABLE)
            message(STATUS "  Missing: ninja")
        endif()
        if(NOT CLANG_16_EXECUTABLE)
            message(STATUS "  Missing: clang-16")
        endif()
    endif()
endif()

# Set compile definitions based on libepoxy availability
if(EPOXY_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_EPOXY=1)
    
elseif(EPOXY_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_EPOXY_SOURCE=1)
    add_compile_definitions(BUILD_EPOXY_FROM_SOURCE=1)
    
    # Use ExternalProject for libepoxy source building
    include(ExternalProject)
    
    set(EPOXY_PREFIX ${CMAKE_BINARY_DIR}/epoxy-install)
    
    ExternalProject_Add(epoxy_build
        PREFIX ${EPOXY_PREFIX}
        GIT_REPOSITORY https://github.com/anholt/libepoxy.git
        GIT_TAG 1.5.10
        GIT_SHALLOW 1
        GIT_PROGRESS 1
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS ${EPOXY_PREFIX}/lib/libepoxy.so
    )
    
    # Add custom steps for the actual build process
    ExternalProject_Add_Step(epoxy_build build_epoxy
        COMMAND export CC=/lilyspark/opt/lib/sys/compiler/bin/clang-16 &&
            export CXX=/lilyspark/opt/lib/sys/compiler/bin/clang++-16 &&
            export LLVM_CONFIG=/lilyspark/opt/lib/sys/compiler/bin/llvm-config &&
            export CFLAGS="-I/lilyspark/opt/lib/sys/compiler/include -I/lilyspark/opt/lib/sys/glibc/include -march=armv8-a" &&
            export CXXFLAGS="-I/lilyspark/opt/lib/sys/compiler/include -I/lilyspark/opt/lib/sys/glibc/include -march=armv8-a" &&
            export LDFLAGS="-L/lilyspark/opt/lib/sys/compiler/lib -L/lilyspark/opt/lib/sys/glibc/lib -Wl,-rpath,/lilyspark/opt/lib/sys/compiler/lib:/lilyspark/opt/lib/sys/glibc/lib" &&
            export PKG_CONFIG_PATH="/lilyspark/opt/lib/sys/usr/lib/pkgconfig:/lilyspark/opt/lib/sys/compiler/lib/pkgconfig" &&
            ${MESON_EXECUTABLE} setup builddir
                --prefix=${EPOXY_PREFIX}
                --libdir=lib
                --buildtype=release
                -Dglx=yes
                -Degl=yes
                -Dx11=true
                -Dwayland=false
                -Dtests=false
        COMMAND ${NINJA_EXECUTABLE} -C builddir -j${CMAKE_BUILD_PARALLEL_LEVEL}
        COMMAND ${NINJA_EXECUTABLE} -C builddir install
        DEPENDEES download update
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMENT "Building and installing libepoxy with LLVM16 toolchain"
    )
    
    # Add step to create symlinks
    ExternalProject_Add_Step(epoxy_build create_symlinks
        COMMAND cd ${EPOXY_PREFIX}/lib &&
            sh -c "for lib in \\$$(ls libepoxy*.so.*.* 2>/dev/null); do \
                soname=\\$$(echo \"\\$$lib\" | sed 's/\\(.*\\.so\\.[0-9]*\\).*/\\1/'); \
                basename=\\$$(echo \"\\$$lib\" | sed 's/\\(.*\\.so\\).*/\\1/'); \
                ln -sf \"\\$$lib\" \"\\$$soname\"; \
                ln -sf \"\\$$soname\" \"\\$$basename\"; \
            done"
        DEPENDEES install
        COMMENT "Creating libepoxy symlinks"
    )
    
else()
    add_compile_definitions(HAVE_EPOXY=0)
    message(STATUS "ℹ Building without libepoxy graphics support")
endif()

# -------------------------------
# SDL3 Image Dependencies Support
# -------------------------------
message(STATUS "Checking for SDL3 Image dependencies support...")

# Search for image libraries in all possible locations
set(SEARCH_PATHS
    /lilyspark/opt/lib/sdl3/lib
    /usr/lib
    /usr/local/lib
)

find_library(TIFF_LIBRARY NAMES tiff PATHS ${SEARCH_PATHS})
find_library(WEBP_LIBRARY NAMES webp PATHS ${SEARCH_PATHS})
find_library(AVIF_LIBRARY NAMES avif PATHS ${SEARCH_PATHS})

# Check what we found
set(HAVE_TIFF FALSE)
set(HAVE_WEBP FALSE)
set(HAVE_AVIF FALSE)

if(TIFF_LIBRARY)
    set(HAVE_TIFF TRUE)
    message(STATUS "✓ libtiff found: ${TIFF_LIBRARY}")
else()
    message(STATUS "ℹ libtiff not found")
endif()

if(WEBP_LIBRARY)
    set(HAVE_WEBP TRUE)
    message(STATUS "✓ libwebp found: ${WEBP_LIBRARY}")
else()
    message(STATUS "ℹ libwebp not found")
endif()

if(AVIF_LIBRARY)
    set(HAVE_AVIF TRUE)
    message(STATUS "✓ libavif found: ${AVIF_LIBRARY}")
else()
    message(STATUS "ℹ libavif not found")
endif()

# Set compile definitions based on what we found
if(HAVE_TIFF)
    add_compile_definitions(HAVE_TIFF=1)
else()
    add_compile_definitions(HAVE_TIFF=0)
endif()

if(HAVE_WEBP)
    add_compile_definitions(HAVE_WEBP=1)
else()
    add_compile_definitions(HAVE_WEBP=0)
endif()

if(HAVE_AVIF)
    add_compile_definitions(HAVE_AVIF=1)
else()
    add_compile_definitions(HAVE_AVIF=0)
endif()

# -------------------------------
# Python Dependencies Support
# -------------------------------
message(STATUS "Checking for Python dependencies...")

# Check for each Python package
set(PYTHON_PACKAGES mesonbuild mako MarkupSafe)
set(HAVE_PYTHON_DEPS FALSE)

foreach(pkg IN LISTS PYTHON_PACKAGES)
    # Check if package exists in custom filesystem
    if(EXISTS /lilyspark/opt/lib/python/site-packages/${pkg})
        set(HAVE_${pkg} TRUE)
        message(STATUS "✓ ${pkg} found in custom filesystem")
        
    else()
        # Check if package exists in system Python
        execute_process(
            COMMAND find /usr/lib/python3.*/site-packages /usr/lib/python*/site-packages -type d -name "${pkg}"
            OUTPUT_VARIABLE ${pkg}_FIND_RESULT
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        
        if(${pkg}_FIND_RESULT)
            set(HAVE_${pkg} TRUE)
            message(STATUS "✓ ${pkg} found in system: ${${pkg}_FIND_RESULT}")
        else()
            set(HAVE_${pkg} FALSE)
            message(STATUS "ℹ ${pkg} not found")
        endif()
    endif()
    
    # Set compile definitions for each package
    if(HAVE_${pkg})
        add_compile_definitions(HAVE_${pkg}=1)
    else()
        add_compile_definitions(HAVE_${pkg}=0)
    endif()
endforeach()

# Check if we have all required packages
if(HAVE_mesonbuild AND HAVE_mako AND HAVE_MarkupSafe)
    set(HAVE_PYTHON_DEPS TRUE)
    message(STATUS "✓ All Python dependencies available")
else()
    set(HAVE_PYTHON_DEPS FALSE)
    message(STATUS "ℹ Some Python dependencies missing")
endif()

# -------------------------------
# SPIRV-Tools Support
# -------------------------------
message(STATUS "Checking for SPIRV-Tools support...")

# Search for pre-built SPIRV-Tools
find_path(SPIRV_TOOLS_INSTALL_DIR
    NAMES include/spirv-tools/libspirv.h lib/libSPIRV-Tools.so lib/libSPIRV-Tools.a
    PATHS
        /lilyspark/opt/lib/graphics
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(SPIRV_TOOLS_LIBRARY
    NAMES SPIRV-Tools
    PATHS
        /lilyspark/opt/lib/graphics/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

find_program(SPIRV_TOOLS_BINARY
    NAMES spirv-val spirv-opt
    PATHS
        /lilyspark/opt/lib/graphics/bin
        /usr/bin
        /usr/local/bin
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(SPIRV_TOOLS_BUILD_FROM_SOURCE FALSE)
set(SPIRV_TOOLS_FOUND FALSE)

if(SPIRV_TOOLS_LIBRARY AND SPIRV_TOOLS_BINARY AND SPIRV_TOOLS_INSTALL_DIR)
    set(SPIRV_TOOLS_FOUND TRUE)
    message(STATUS "✓ SPIRV-Tools found (pre-built)")
    message(STATUS "  library: ${SPIRV_TOOLS_LIBRARY}")
    message(STATUS "  binary: ${SPIRV_TOOLS_BINARY}")
    message(STATUS "  install dir: ${SPIRV_TOOLS_INSTALL_DIR}")
    
else()
    message(STATUS "ℹ SPIRV-Tools not found as pre-built - checking if we can build from source")
    
    # Check for build dependencies
    find_program(GIT_EXECUTABLE git)
    find_program(CMAKE_EXECUTABLE cmake)
    find_program(MAKE_EXECUTABLE make)
    find_program(CLANG_16_EXECUTABLE NAMES clang-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    find_program(CLANGXX_16_EXECUTABLE NAMES clang++-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    find_program(LLVM_CONFIG_EXECUTABLE NAMES llvm-config PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    
    if(GIT_EXECUTABLE AND CMAKE_EXECUTABLE AND MAKE_EXECUTABLE AND CLANG_16_EXECUTABLE AND CLANGXX_16_EXECUTABLE)
        set(SPIRV_TOOLS_BUILD_FROM_SOURCE TRUE)
        set(SPIRV_TOOLS_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ SPIRV-Tools build dependencies found - will build from source with LLVM16")
        message(STATUS "  git: ${GIT_EXECUTABLE}")
        message(STATUS "  cmake: ${CMAKE_EXECUTABLE}")
        message(STATUS "  clang-16: ${CLANG_16_EXECUTABLE}")
        message(STATUS "  clang++-16: ${CLANGXX_16_EXECUTABLE}")
        
    else()
        set(SPIRV_TOOLS_FOUND FALSE)
        message(STATUS "ℹ SPIRV-Tools not available and cannot build from source")
        if(NOT GIT_EXECUTABLE)
            message(STATUS "  Missing: git")
        endif()
        if(NOT CMAKE_EXECUTABLE)
            message(STATUS "  Missing: cmake")
        endif()
        if(NOT CLANG_16_EXECUTABLE)
            message(STATUS "  Missing: clang-16")
        endif()
    endif()
endif()

# Set compile definitions based on SPIRV-Tools availability
if(SPIRV_TOOLS_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_SPIRV_TOOLS=1)
    
elseif(SPIRV_TOOLS_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_SPIRV_TOOLS_SOURCE=1)
    add_compile_definitions(BUILD_SPIRV_TOOLS_FROM_SOURCE=1)
    
    # Use ExternalProject for SPIRV-Tools source building
    include(ExternalProject)
    
    set(SPIRV_TOOLS_PREFIX ${CMAKE_BINARY_DIR}/spirv-tools-install)
    
    ExternalProject_Add(spirv_tools_build
        PREFIX ${SPIRV_TOOLS_PREFIX}
        GIT_REPOSITORY https://github.com/KhronosGroup/SPIRV-Tools.git
        GIT_SHALLOW 1
        GIT_PROGRESS 1
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS ${SPIRV_TOOLS_PREFIX}/lib/libSPIRV-Tools.so
    )
    
    # Add custom steps for the actual build process
    ExternalProject_Add_Step(spirv_tools_build clone_headers
        COMMAND ${GIT_EXECUTABLE} clone --depth=1 https://github.com/KhronosGroup/SPIRV-Headers.git external/spirv-headers
        COMMENT "Cloning SPIRV-Headers dependency"
        WORKING_DIRECTORY <SOURCE_DIR>
        DEPENDEES download
    )
    
    ExternalProject_Add_Step(spirv_tools_build build_spirv_tools
        COMMAND ${CMAKE_COMMAND} -E make_directory build
        COMMAND cd build &&
            ${CMAKE_EXECUTABLE} ..
                -DCMAKE_BUILD_TYPE=Release
                -DCMAKE_INSTALL_PREFIX=${SPIRV_TOOLS_PREFIX}
                -DCMAKE_C_COMPILER=${CLANG_16_EXECUTABLE}
                -DCMAKE_CXX_COMPILER=${CLANGXX_16_EXECUTABLE}
                -DLLVM_CONFIG_EXECUTABLE=${LLVM_CONFIG_EXECUTABLE}
                -DCMAKE_C_FLAGS="-I/lilyspark/compiler/include -march=armv8-a"
                -DCMAKE_CXX_FLAGS="-I/lilyspark/compiler/include -march=armv8-a"
                -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -Wl,-rpath,/lilyspark/compiler/lib"
        COMMAND cd build && ${MAKE_EXECUTABLE} -j${CMAKE_BUILD_PARALLEL_LEVEL}
        COMMAND cd build && ${MAKE_EXECUTABLE} install
        DEPENDEES clone_headers
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMENT "Building and installing SPIRV-Tools with LLVM16"
    )
    
    # Add step to create symlinks
    ExternalProject_Add_Step(spirv_tools_build create_symlinks
        COMMAND cd ${SPIRV_TOOLS_PREFIX}/lib &&
            sh -c "for lib in \\$$(ls libSPIRV-Tools*.so.* 2>/dev/null); do \
                soname=\\$$(echo \"\\$$lib\" | sed 's/\\(.*\\.so\\.[0-9]*\\).*/\\1/'); \
                basename=\\$$(echo \"\\$$lib\" | sed 's/\\(.*\\.so\\).*/\\1/'); \
                ln -sf \"\\$$lib\" \"\\$$soname\"; \
                ln -sf \"\\$$soname\" \"\\$$basename\"; \
            done"
        DEPENDEES build_spirv_tools
        COMMENT "Creating SPIRV-Tools symlinks"
    )
    
else()
    add_compile_definitions(HAVE_SPIRV_TOOLS=0)
    message(STATUS "ℹ Building without SPIRV-Tools support")
endif()

# -------------------------------
# Shaderc Support
# -------------------------------
message(STATUS "Checking for Shaderc support...")

# Search for pre-built Shaderc
find_path(SHADERC_INSTALL_DIR
    NAMES include/shaderc/shaderc.h lib/libshaderc.so lib/libshaderc.a
    PATHS
        /lilyspark/opt/lib/graphics
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(SHADERC_LIBRARY
    NAMES shaderc
    PATHS
        /lilyspark/opt/lib/graphics/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

find_program(SHADERC_BINARY
    NAMES shaderc
    PATHS
        /lilyspark/opt/lib/graphics/bin
        /usr/bin
        /usr/local/bin
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(SHADERC_BUILD_FROM_SOURCE FALSE)
set(SHADERC_FOUND FALSE)

if(SHADERC_LIBRARY AND SHADERC_BINARY AND SHADERC_INSTALL_DIR)
    set(SHADERC_FOUND TRUE)
    message(STATUS "✓ Shaderc found (pre-built)")
    message(STATUS "  library: ${SHADERC_LIBRARY}")
    message(STATUS "  binary: ${SHADERC_BINARY}")
    message(STATUS "  install dir: ${SHADERC_INSTALL_DIR}")
    
else()
    message(STATUS "ℹ Shaderc not found as pre-built - checking if we can build from source")
    
    # Check for build dependencies
    find_program(GIT_EXECUTABLE git)
    find_program(CMAKE_EXECUTABLE cmake)
    find_program(MAKE_EXECUTABLE make)
    find_program(CLANG_16_EXECUTABLE NAMES clang-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    find_program(CLANGXX_16_EXECUTABLE NAMES clang++-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    
    # Check for SPIRV-Tools dependency (required for Shaderc)
    find_library(SPIRV_TOOLS_LIB NAMES SPIRV-Tools PATHS /lilyspark/opt/lib/graphics/lib NO_DEFAULT_PATH)
    find_path(SPIRV_HEADERS_DIR NAMES spirv.h PATHS /lilyspark/opt/lib/graphics/include NO_DEFAULT_PATH)
    
    if(GIT_EXECUTABLE AND CMAKE_EXECUTABLE AND MAKE_EXECUTABLE AND 
       CLANG_16_EXECUTABLE AND CLANGXX_16_EXECUTABLE AND
       SPIRV_TOOLS_LIB AND SPIRV_HEADERS_DIR)
        set(SHADERC_BUILD_FROM_SOURCE TRUE)
        set(SHADERC_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ Shaderc build dependencies found - will build from source with LLVM16")
        message(STATUS "  git: ${GIT_EXECUTABLE}")
        message(STATUS "  cmake: ${CMAKE_EXECUTABLE}")
        message(STATUS "  clang-16: ${CLANG_16_EXECUTABLE}")
        message(STATUS "  SPIRV-Tools: ${SPIRV_TOOLS_LIB}")
        
    else()
        set(SHADERC_FOUND FALSE)
        message(STATUS "ℹ Shaderc not available and cannot build from source")
        if(NOT GIT_EXECUTABLE)
            message(STATUS "  Missing: git")
        endif()
        if(NOT CMAKE_EXECUTABLE)
            message(STATUS "  Missing: cmake")
        endif()
        if(NOT CLANG_16_EXECUTABLE)
            message(STATUS "  Missing: clang-16")
        endif()
        if(NOT SPIRV_TOOLS_LIB)
            message(STATUS "  Missing: SPIRV-Tools (required dependency)")
        endif()
    endif()
endif()

# Set compile definitions based on Shaderc availability
if(SHADERC_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_SHADERC=1)
    
elseif(SHADERC_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_SHADERC_SOURCE=1)
    add_compile_definitions(BUILD_SHADERC_FROM_SOURCE=1)
    
    # Use ExternalProject for Shaderc source building
    include(ExternalProject)
    
    set(SHADERC_PREFIX ${CMAKE_BINARY_DIR}/shaderc-install)
    
    ExternalProject_Add(shaderc_build
        PREFIX ${SHADERC_PREFIX}
        GIT_REPOSITORY https://github.com/google/shaderc.git
        GIT_SHALLOW 1
        GIT_PROGRESS 1
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS ${SHADERC_PREFIX}/lib/libshaderc.so
    )
    
    # Add custom steps for the actual build process
    ExternalProject_Add_Step(shaderc_build build_shaderc
        COMMAND ${CMAKE_COMMAND} -E make_directory build
        COMMAND cd build &&
            export PATH="/lilyspark/compiler/bin:$$PATH" &&
            export CC=${CLANG_16_EXECUTABLE} &&
            export CXX=${CLANGXX_16_EXECUTABLE} &&
            export PKG_CONFIG_SYSROOT_DIR="/lilyspark" &&
            export PKG_CONFIG_PATH="/lilyspark/opt/lib/graphics/lib/pkgconfig:/lilyspark/usr/lib/pkgconfig:/lilyspark/compiler/lib/pkgconfig" &&
            export CFLAGS="--sysroot=/lilyspark -I/lilyspark/opt/lib/graphics/include -I/lilyspark/usr/include -I/lilyspark/compiler/include -march=armv8-a" &&
            export CXXFLAGS="$$CFLAGS" &&
            export LDFLAGS="--sysroot=/lilyspark -L/lilyspark/opt/lib/graphics/lib -L/lilyspark/usr/lib -L/lilyspark/compiler/lib" &&
            ${CMAKE_EXECUTABLE} ..
                -DCMAKE_BUILD_TYPE=Release
                -DCMAKE_INSTALL_PREFIX=${SHADERC_PREFIX}
                -DCMAKE_C_COMPILER=$${CC}
                -DCMAKE_CXX_COMPILER=$${CXX}
                -DCMAKE_PREFIX_PATH="/lilyspark/opt/lib/graphics:/lilyspark/usr:/lilyspark/compiler"
                -DCMAKE_INCLUDE_PATH="/lilyspark/opt/lib/graphics/include:/lilyspark/usr/include:/lilyspark/compiler/include"
                -DCMAKE_LIBRARY_PATH="/lilyspark/opt/lib/graphics/lib:/lilyspark/usr/lib:/lilyspark/compiler/lib"
                -DCMAKE_INSTALL_RPATH="/lilyspark/opt/lib/graphics/lib:/lilyspark/usr/lib:/lilyspark/compiler/lib"
                -DSPIRV-Tools_ROOT="/lilyspark/opt/lib/graphics"
                -DSPIRV-Headers_ROOT="/lilyspark/opt/lib/graphics"
                -DCMAKE_C_FLAGS="$${CFLAGS}"
                -DCMAKE_CXX_FLAGS="$${CXXFLAGS}"
                -DCMAKE_EXE_LINKER_FLAGS="$${LDFLAGS}"
                -DCMAKE_SHARED_LINKER_FLAGS="$${LDFLAGS}"
                -DSHADERC_SKIP_TESTS=ON
                -DSHADERC_SKIP_EXAMPLES=ON
        COMMAND cd build && ${MAKE_EXECUTABLE} -j${CMAKE_BUILD_PARALLEL_LEVEL}
        COMMAND cd build && ${MAKE_EXECUTABLE} install
        DEPENDEES download
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMENT "Building and installing Shaderc with LLVM16"
    )
    
    # Add step to create symlinks
    ExternalProject_Add_Step(shaderc_build create_symlinks
        COMMAND cd ${SHADERC_PREFIX}/lib &&
            sh -c "for lib in \\$$(ls libshaderc*.so.* 2>/dev/null); do \
                soname=\\$$(echo \"\\$$lib\" | sed 's/\\(.*\\.so\\.[0-9]*\\).*/\\1/'); \
                basename=\\$$(echo \"\\$$lib\" | sed 's/\\(.*\\.so\\).*/\\1/'); \
                ln -sf \"\\$$lib\" \"\\$$soname\"; \
                ln -sf \"\\$$soname\" \"\\$$basename\"; \
            done"
        DEPENDEES build_shaderc
        COMMENT "Creating Shaderc symlinks"
    )
    
else()
    add_compile_definitions(HAVE_SHADERC=0)
    message(STATUS "ℹ Building without Shaderc support")
endif()

# -------------------------------
# libgbm Support
# -------------------------------
message(STATUS "Checking for libgbm support...")

# Search for pre-built libgbm
find_path(GBM_INSTALL_DIR
    NAMES include/gbm.h lib/libgbm.so lib/libgbm.a
    PATHS
        /lilyspark/opt/lib/sys
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(GBM_LIBRARY
    NAMES gbm
    PATHS
        /lilyspark/opt/lib/sys/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(GBM_BUILD_FROM_SOURCE FALSE)
set(GBM_FOUND FALSE)

if(GBM_LIBRARY AND GBM_INSTALL_DIR)
    set(GBM_FOUND TRUE)
    message(STATUS "✓ libgbm found (pre-built)")
    message(STATUS "  library: ${GBM_LIBRARY}")
    message(STATUS "  install dir: ${GBM_INSTALL_DIR}")
    
else()
    message(STATUS "ℹ libgbm not found as pre-built - checking if we can build from source")
    
    # Check for build dependencies
    find_program(GIT_EXECUTABLE git)
    find_program(AUTOGEN_EXECUTABLE autogen.sh)
    find_program(CONFIGURE_EXECUTABLE configure)
    find_program(MAKE_EXECUTABLE make)
    find_program(CLANG_16_EXECUTABLE NAMES clang-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    find_program(CLANGXX_16_EXECUTABLE NAMES clang++-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    
    # Check for libdrm dependency
    find_library(DRM_LIB NAMES drm PATHS /lilyspark/opt/lib/sys/lib NO_DEFAULT_PATH)
    
    if(GIT_EXECUTABLE AND AUTOGEN_EXECUTABLE AND CONFIGURE_EXECUTABLE AND 
       MAKE_EXECUTABLE AND CLANG_16_EXECUTABLE AND CLANGXX_16_EXECUTABLE AND DRM_LIB)
        set(GBM_BUILD_FROM_SOURCE TRUE)
        set(GBM_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ libgbm build dependencies found - will build from source with autotools")
        message(STATUS "  git: ${GIT_EXECUTABLE}")
        message(STATUS "  autogen: ${AUTOGEN_EXECUTABLE}")
        message(STATUS "  clang-16: ${CLANG_16_EXECUTABLE}")
        message(STATUS "  libdrm: ${DRM_LIB}")
        
    else()
        set(GBM_FOUND FALSE)
        message(STATUS "ℹ libgbm not available and cannot build from source")
        if(NOT GIT_EXECUTABLE)
            message(STATUS "  Missing: git")
        endif()
        if(NOT AUTOGEN_EXECUTABLE)
            message(STATUS "  Missing: autogen.sh")
        endif()
        if(NOT CLANG_16_EXECUTABLE)
            message(STATUS "  Missing: clang-16")
        endif()
        if(NOT DRM_LIB)
            message(STATUS "  Missing: libdrm (required dependency)")
        endif()
    endif()
endif()

# Set compile definitions based on libgbm availability
if(GBM_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_GBM=1)
    
elseif(GBM_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_GBM_SOURCE=1)
    add_compile_definitions(BUILD_GBM_FROM_SOURCE=1)
    
    # Use ExternalProject for libgbm source building
    include(ExternalProject)
    
    set(GBM_PREFIX ${CMAKE_BINARY_DIR}/gbm-install)
    
    ExternalProject_Add(gbm_build
        PREFIX ${GBM_PREFIX}
        GIT_REPOSITORY https://github.com/robclark/libgbm.git
        GIT_SHALLOW 1
        GIT_PROGRESS 1
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS ${GBM_PREFIX}/lib/libgbm.so
    )
    
    # Add custom steps for the actual build process
    ExternalProject_Add_Step(gbm_build build_gbm
        COMMAND ./autogen.sh --prefix=${GBM_PREFIX}
        COMMAND export PKG_CONFIG_SYSROOT_DIR="/lilyspark" &&
            export PKG_CONFIG_PATH="/lilyspark/opt/lib/sys/lib/pkgconfig:/lilyspark/opt/lib/sys/share/pkgconfig" &&
            ./configure
                --prefix=${GBM_PREFIX}
                CC=${CLANG_16_EXECUTABLE}
                CXX=${CLANGXX_16_EXECUTABLE}
                CFLAGS="--sysroot=/lilyspark -I/lilyspark/opt/lib/sys/include -I/lilyspark/compiler/include -march=armv8-a"
                CXXFLAGS="--sysroot=/lilyspark -I/lilyspark/opt/lib/sys/include -I/lilyspark/compiler/include -march=armv8-a"
                LDFLAGS="--sysroot=/lilyspark -L/lilyspark/opt/lib/sys/lib -L/lilyspark/compiler/lib"
        COMMAND ${MAKE_EXECUTABLE} -j${CMAKE_BUILD_PARALLEL_LEVEL}
        COMMAND ${MAKE_EXECUTABLE} install
        DEPENDEES download
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMENT "Building and installing libgbm with autotools"
    )
    
       # Add step to create symlinks
    ExternalProject_Add_Step(gbm_build create_symlinks
        COMMAND cd ${GBM_PREFIX}/lib &&
            sh -c "for lib in \\$$(ls libgbm.so.* 2>/dev/null); do \
                soname=\\$$(echo \"\\$$lib\" | sed 's/\\(.*\\.so\\.[0-9]*\\).*/\\1/'); \
                basename=\\$$(echo \"\\$$lib\" | sed 's/\\(.*\\.so\\).*/\\1/'); \
                ln -sf \"\\$$lib\" \"\\$$soname\"; \
                ln -sf \"\\$$soname\" \"\\$$basename\"; \
            done"
        DEPENDEES build_gbm
        COMMENT "Creating libgbm symlinks"
    )
    
else()
    add_compile_definitions(HAVE_GBM=0)
    message(STATUS "ℹ Building without libgbm support")
endif()

# -------------------------------
# GStreamer and Xorg Support
# -------------------------------
message(STATUS "Checking for GStreamer and Xorg support...")

# Search for pre-built GStreamer
find_path(GSTREAMER_INSTALL_DIR
    NAMES include/gstreamer-1.0/gst/gst.h lib/libgstreamer-1.0.so
    PATHS
        /lilyspark/opt/lib/media
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(GSTREAMER_LIBRARY
    NAMES gstreamer-1.0
    PATHS
        /lilyspark/opt/lib/media/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Search for pre-built Xorg
find_path(XORG_INSTALL_DIR
    NAMES x11/Xlib.h lib/libX11.so
    PATHS
        /lilyspark/usr/x11
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(X11_LIBRARY
    NAMES X11
    PATHS
        /lilyspark/usr/x11
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(GSTREAMER_BUILD_FROM_SOURCE FALSE)
set(GSTREAMER_FOUND FALSE)
set(XORG_BUILD_FROM_SOURCE FALSE)
set(XORG_FOUND FALSE)

# Check for GStreamer
if(GSTREAMER_LIBRARY AND GSTREAMER_INSTALL_DIR)
    set(GSTREAMER_FOUND TRUE)
    message(STATUS "✓ GStreamer found (pre-built)")
    message(STATUS "  library: ${GSTREAMER_LIBRARY}")
    
else()
    message(STATUS "ℹ GStreamer not found as pre-built - checking build dependencies")
    
    # Check for build dependencies
    find_program(WGET_EXECUTABLE wget)
    find_program(TAR_EXECUTABLE tar)
    find_program(CONFIGURE_EXECUTABLE configure)
    find_program(MAKE_EXECUTABLE make)
    find_program(CLANG_16_EXECUTABLE NAMES clang-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    find_program(CLANGXX_16_EXECUTABLE NAMES clang++-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    find_program(LLVM_CONFIG_EXECUTABLE NAMES llvm-config PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    find_program(PKG_CONFIG_EXECUTABLE pkg-config)
    
    if(WGET_EXECUTABLE AND TAR_EXECUTABLE AND CONFIGURE_EXECUTABLE AND 
       MAKE_EXECUTABLE AND CLANG_16_EXECUTABLE AND CLANGXX_16_EXECUTABLE AND PKG_CONFIG_EXECUTABLE)
        set(GSTREAMER_BUILD_FROM_SOURCE TRUE)
        set(GSTREAMER_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ GStreamer build dependencies found - will build from source")
        message(STATUS "  clang-16: ${CLANG_16_EXECUTABLE}")
        
    else()
        set(GSTREAMER_FOUND FALSE)
        message(STATUS "ℹ GStreamer not available and cannot build from source")
        if(NOT CLANG_16_EXECUTABLE)
            message(STATUS "  Missing: clang-16")
        endif()
    endif()
endif()

# Check for Xorg
if(X11_LIBRARY AND XORG_INSTALL_DIR)
    set(XORG_FOUND TRUE)
    message(STATUS "✓ Xorg found (pre-built)")
    message(STATUS "  library: ${X11_LIBRARY}")
    
else()
    message(STATUS "ℹ Xorg not found as pre-built - checking build dependencies")
    
    # Check for build dependencies
    find_program(GIT_EXECUTABLE git)
    find_program(AUTORECONF_EXECUTABLE autoreconf)
    find_program(CLANG_16_EXECUTABLE NAMES clang-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    
    if(GIT_EXECUTABLE AND AUTORECONF_EXECUTABLE AND CLANG_16_EXECUTABLE)
        set(XORG_BUILD_FROM_SOURCE TRUE)
        set(XORG_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ Xorg build dependencies found - will build from source")
        message(STATUS "  git: ${GIT_EXECUTABLE}")
        message(STATUS "  clang-16: ${CLANG_16_EXECUTABLE}")
        
    else()
        set(XORG_FOUND FALSE)
        message(STATUS "ℹ Xorg not available and cannot build from source")
        if(NOT CLANG_16_EXECUTABLE)
            message(STATUS "  Missing: clang-16")
        endif()
    endif()
endif()

# Set compile definitions
if(GSTREAMER_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_GSTREAMER=1)
elseif(GSTREAMER_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_GSTREAMER_SOURCE=1)
    add_compile_definitions(BUILD_GSTREAMER_FROM_SOURCE=1)
else()
    add_compile_definitions(HAVE_GSTREAMER=0)
endif()

if(XORG_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_XORG=1)
elseif(XORG_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_XORG_SOURCE=1)
    add_compile_definitions(BUILD_XORG_FROM_SOURCE=1)
else()
    add_compile_definitions(HAVE_XORG=0)
endif()

# -------------------------------
# MESA Support
# -------------------------------
message(STATUS "Checking for MESA support...")

# Search for pre-built MESA components
find_path(MESA_INSTALL_DIR
    NAMES lib/libGL.so lib/libEGL.so lib/libgbm.so lib/libvulkan_swrast.so
    PATHS
        /lilyspark/opt/lib/driver
        /lilyspark/usr
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(GL_LIBRARY
    NAMES GL
    PATHS
        /lilyspark/opt/lib/driver
        /lilyspark/usr/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

find_library(EGL_LIBRARY
    NAMES EGL
    PATHS
        /lilyspark/opt/lib/driver
        /lilyspark/usr/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

find_library(GBM_LIBRARY
    NAMES gbm
    PATHS
        /lilyspark/opt/lib/driver
        /lilyspark/usr/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

find_library(VULKAN_SWRAST_LIBRARY
    NAMES vulkan_swrast
    PATHS
        /lilyspark/opt/lib/driver
        /lilyspark/usr/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(MESA_BUILD_FROM_SOURCE FALSE)
set(MESA_FOUND FALSE)

if(GL_LIBRARY AND EGL_LIBRARY AND GBM_LIBRARY AND VULKAN_SWRAST_LIBRARY)
    set(MESA_FOUND TRUE)
    message(STATUS "✓ MESA found (pre-built)")
    message(STATUS "  OpenGL: ${GL_LIBRARY}")
    message(STATUS "  EGL: ${EGL_LIBRARY}")
    message(STATUS "  GBM: ${GBM_LIBRARY}")
    message(STATUS "  Vulkan: ${VULKAN_SWRAST_LIBRARY}")
    
else()
    message(STATUS "ℹ MESA not found as pre-built - checking if we can build from source")
    
    # Check for build dependencies
    find_program(GIT_EXECUTABLE git)
    find_program(MESON_EXECUTABLE meson)
    find_program(NINJA_EXECUTABLE ninja)
    find_program(CLANG_16_EXECUTABLE NAMES clang-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    find_program(CLANGXX_16_EXECUTABLE NAMES clang++-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    find_program(LLVM_CONFIG_EXECUTABLE NAMES llvm-config PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    
    # Check for required dependencies
    find_library(DRM_LIB NAMES drm PATHS /lilyspark/opt/lib/sys/lib NO_DEFAULT_PATH)
    find_library(WAYLAND_LIB NAMES wayland-client PATHS /usr/lib /usr/local/lib)
    
    if(GIT_EXECUTABLE AND MESON_EXECUTABLE AND NINJA_EXECUTABLE AND 
       CLANG_16_EXECUTABLE AND CLANGXX_16_EXECUTABLE AND LLVM_CONFIG_EXECUTABLE AND
       DRM_LIB AND WAYLAND_LIB)
        set(MESA_BUILD_FROM_SOURCE TRUE)
        set(MESA_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ MESA build dependencies found - will build from source with LLVM16")
        message(STATUS "  meson: ${MESON_EXECUTABLE}")
        message(STATUS "  ninja: ${NINJA_EXECUTABLE}")
        message(STATUS "  clang-16: ${CLANG_16_EXECUTABLE}")
        message(STATUS "  libdrm: ${DRM_LIB}")
        message(STATUS "  wayland: ${WAYLAND_LIB}")
        
    else()
        set(MESA_FOUND FALSE)
        message(STATUS "ℹ MESA not available and cannot build from source")
        if(NOT MESON_EXECUTABLE)
            message(STATUS "  Missing: meson")
        endif()
        if(NOT NINJA_EXECUTABLE)
            message(STATUS "  Missing: ninja")
        endif()
        if(NOT CLANG_16_EXECUTABLE)
            message(STATUS "  Missing: clang-16")
        endif()
        if(NOT DRM_LIB)
            message(STATUS "  Missing: libdrm (required)")
        endif()
    endif()
endif()

# Set compile definitions based on MESA availability
if(MESA_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_MESA=1)
    add_compile_definitions(HAVE_OPENGL=1)
    add_compile_definitions(HAVE_EGL=1)
    add_compile_definitions(HAVE_GBM=1)
    add_compile_definitions(HAVE_VULKAN=1)
    
elseif(MESA_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_MESA_SOURCE=1)
    add_compile_definitions(BUILD_MESA_FROM_SOURCE=1)
    
    # Use ExternalProject for MESA source building
    include(ExternalProject)
    
    set(MESA_PREFIX ${CMAKE_BINARY_DIR}/mesa-install)
    
    ExternalProject_Add(mesa_build
        PREFIX ${MESA_PREFIX}
        GIT_REPOSITORY https://gitlab.freedesktop.org/mesa/mesa.git
        GIT_TAG mesa-24.0.3
        GIT_SHALLOW 1
        GIT_PROGRESS 1
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS 
            ${MESA_PREFIX}/lib/libGL.so
            ${MESA_PREFIX}/lib/libEGL.so
            ${MESA_PREFIX}/lib/libgbm.so
            ${MESA_PREFIX}/lib/libvulkan_swrast.so
    )
    
    # Add custom steps for the actual build process
    ExternalProject_Add_Step(mesa_build build_mesa
        COMMAND export PATH="/lilyspark/compiler/bin:$$PATH" &&
            export CC=${CLANG_16_EXECUTABLE} &&
            export CXX=${CLANGXX_16_EXECUTABLE} &&
            export LLVM_CONFIG=${LLVM_CONFIG_EXECUTABLE} &&
            export PKG_CONFIG_SYSROOT_DIR="/lilyspark" &&
            export PKG_CONFIG_PATH="/lilyspark/usr/lib/pkgconfig:/lilyspark/compiler/lib/pkgconfig" &&
            export CFLAGS="--sysroot=/lilyspark -I/lilyspark/usr/include -I/lilyspark/compiler/include -march=armv8-a" &&
            export CXXFLAGS="$$CFLAGS" &&
            export LDFLAGS="--sysroot=/lilyspark -L/lilyspark/usr/lib -L/lilyspark/compiler/lib" &&
            ${MESON_EXECUTABLE} setup builddir
                --prefix=${MESA_PREFIX}
                -Dglx=disabled
                -Ddri3=disabled
                -Degl=enabled
                -Dgbm=enabled
                -Dplatforms=wayland
                -Dglvnd=false
                -Dosmesa=true
                -Dgallium-drivers=swrast,kmsro,zink
                -Dvulkan-drivers=swrast
                -Dbuildtype=debugoptimized
                --fatal-meson-warnings
                --wrap-mode=nodownload
                -Dllvm=enabled
        COMMAND ${NINJA_EXECUTABLE} -C builddir -v
        COMMAND ${NINJA_EXECUTABLE} -C builddir install
        DEPENDEES download
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMENT "Building and installing MESA with LLVM16"
    )
    
    # Add step to create Vulkan ICD configuration
    ExternalProject_Add_Step(mesa_build create_vulkan_icd
        COMMAND ${CMAKE_COMMAND} -E make_directory ${MESA_PREFIX}/share/vulkan/icd.d
        COMMAND echo '{"file_format_version":"1.0.0","ICD":{"library_path":"libvulkan_swrast.so","api_version":"1.3.0"}}' > ${MESA_PREFIX}/share/vulkan/icd.d/swrast_icd.arm64.json
        DEPENDEES build_mesa
        COMMENT "Creating Vulkan ICD configuration"
    )
    
else()
    add_compile_definitions(HAVE_MESA=0)
    add_compile_definitions(HAVE_OPENGL=0)
    add_compile_definitions(HAVE_EGL=0)
    add_compile_definitions(HAVE_GBM=0)
    add_compile_definitions(HAVE_VULKAN=0)
    message(STATUS "ℹ Building without MESA graphics support")
endif()

# -------------------------------
# GBM (MESA) Support
# -------------------------------
message(STATUS "Checking for GBM (MESA) support...")

# Search for pre-built GBM from MESA
find_path(GBM_MESA_INSTALL_DIR
    NAMES include/gbm.h lib/libgbm.so
    PATHS
        /lilyspark/opt/lib/driver
        /usr
        /usr/local
    NO_DEFAULT_PATH
)

find_library(GBM_MESA_LIBRARY
    NAMES gbm
    PATHS
        /lilyspark/opt/lib/driver/usr/lib
        /lilyspark/opt/lib/driver/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Check if we need to build from source
set(GBM_MESA_BUILD_FROM_SOURCE FALSE)
set(GBM_MESA_FOUND FALSE)

if(GBM_MESA_LIBRARY AND GBM_MESA_INSTALL_DIR)
    set(GBM_MESA_FOUND TRUE)
    message(STATUS "✓ GBM (MESA) found (pre-built)")
    message(STATUS "  library: ${GBM_MESA_LIBRARY}")
    message(STATUS "  install dir: ${GBM_MESA_INSTALL_DIR}")
    
else()
    message(STATUS "ℹ GBM (MESA) not found as pre-built - checking if we can build from source")
    
    # Check for build dependencies
    find_program(GIT_EXECUTABLE git)
    find_program(MESON_EXECUTABLE meson)
    find_program(NINJA_EXECUTABLE ninja)
    find_program(CLANG_16_EXECUTABLE NAMES clang-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    find_program(CLANGXX_16_EXECUTABLE NAMES clang++-16 PATHS /lilyspark/compiler/bin NO_DEFAULT_PATH)
    
    # Check for libdrm dependency
    find_library(DRM_LIB NAMES drm PATHS /lilyspark/opt/lib/sys/lib NO_DEFAULT_PATH)
    
    if(GIT_EXECUTABLE AND MESON_EXECUTABLE AND NINJA_EXECUTABLE AND 
       CLANG_16_EXECUTABLE AND CLANGXX_16_EXECUTABLE AND DRM_LIB)
        set(GBM_MESA_BUILD_FROM_SOURCE TRUE)
        set(GBM_MESA_FOUND SOURCE_AVAILABLE)
        message(STATUS "✓ GBM (MESA) build dependencies found - will build from source")
        message(STATUS "  git: ${GIT_EXECUTABLE}")
        message(STATUS "  meson: ${MESON_EXECUTABLE}")
        message(STATUS "  clang-16: ${CLANG_16_EXECUTABLE}")
        message(STATUS "  libdrm: ${DRM_LIB}")
        
    else()
        set(GBM_MESA_FOUND FALSE)
        message(STATUS "ℹ GBM (MESA) not available and cannot build from source")
        if(NOT GIT_EXECUTABLE)
            message(STATUS "  Missing: git")
        endif()
        if(NOT MESON_EXECUTABLE)
            message(STATUS "  Missing: meson")
        endif()
        if(NOT CLANG_16_EXECUTABLE)
            message(STATUS "  Missing: clang-16")
        endif()
        if(NOT DRM_LIB)
            message(STATUS "  Missing: libdrm (required dependency)")
        endif()
    endif()
endif()

# Set compile definitions based on GBM (MESA) availability
if(GBM_MESA_FOUND STREQUAL "TRUE")
    add_compile_definitions(HAVE_GBM_MESA=1)
    
elseif(GBM_MESA_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_compile_definitions(HAVE_GBM_MESA_SOURCE=1)
    add_compile_definitions(BUILD_GBM_MESA_FROM_SOURCE=1)
    
    # Use ExternalProject for GBM (MESA) source building
    include(ExternalProject)
    
    set(GBM_MESA_PREFIX ${CMAKE_BINARY_DIR}/gbm-mesa-install)
    
    ExternalProject_Add(gbm_mesa_build
        PREFIX ${GBM_MESA_PREFIX}
        GIT_REPOSITORY https://gitlab.freedesktop.org/mesa/mesa.git
        GIT_SHALLOW 1
        GIT_PROGRESS 1
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS ${GBM_MESA_PREFIX}/lib/libgbm.so
    )
    
    # Add custom steps for the actual build process
    ExternalProject_Add_Step(gbm_mesa_build build_gbm_mesa
        COMMAND export PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/driver" &&
            export PKG_CONFIG_PATH="/lilyspark/opt/lib/driver/usr/lib/pkgconfig" &&
            ${MESON_EXECUTABLE} setup builddir
                --prefix=${GBM_MESA_PREFIX}
                -Dgbm=enabled
                -Ddri-drivers=
                -Dgallium-drivers=
                -Degl=disabled
                -Dgles1=disabled
                -Dgles2=disabled
                -Dopengl=disabled
        COMMAND ${NINJA_EXECUTABLE} -C builddir -v
        COMMAND ${NINJA_EXECUTABLE} -C builddir install
        DEPENDEES download
        WORKING_DIRECTORY <SOURCE_DIR>
        COMMENT "Building and installing GBM from MESA source"
    )
    
else()
    add_compile_definitions(HAVE_GBM_MESA=0)
    message(STATUS "ℹ Building without GBM (MESA) support")
endif()

# -------------------------------
# EGL (MESA) Support
# -------------------------------
message(STATUS "Checking for EGL (MESA) support...")

# Search for EGL in all possible locations
set(EGL_SEARCH_PATHS
    /lilyspark/opt/lib/driver
    /lilyspark/opt/lib/driver/usr/lib
    /lilyspark/opt/lib/driver/lib
    /usr/lib
    /usr/local/lib
)

find_library(EGL_LIBRARY
    NAMES EGL
    PATHS ${EGL_SEARCH_PATHS}
    NO_DEFAULT_PATH
)

find_path(EGL_INCLUDE_DIR
    NAMES EGL/egl.h
    PATHS
        /lilyspark/opt/lib/driver/include
        /lilyspark/opt/lib/driver/usr/include
        /usr/include
        /usr/local/include
    NO_DEFAULT_PATH
)

# Simple detection without complex source building
set(EGL_FOUND FALSE)

if(EGL_LIBRARY AND EGL_INCLUDE_DIR)
    set(EGL_FOUND TRUE)
    message(STATUS "✓ EGL found")
    message(STATUS "  library: ${EGL_LIBRARY}")
    message(STATUS "  include: ${EGL_INCLUDE_DIR}")
    
    # Set compile definitions
    add_compile_definitions(HAVE_EGL=1)
    
else()
    set(EGL_FOUND FALSE)
    message(STATUS "ℹ EGL not found")
    
    # Set compile definitions for missing EGL
    add_compile_definitions(HAVE_EGL=0)
    
    # Provide helpful information about what's missing
    if(NOT EGL_LIBRARY)
        message(STATUS "  Missing: libEGL.so library")
        # Check common locations to help user
        foreach(path IN LISTS EGL_SEARCH_PATHS)
            if(EXISTS ${path})
                message(STATUS "  Checked: ${path}")
            endif()
        endforeach()
    endif()
    
    if(NOT EGL_INCLUDE_DIR)
        message(STATUS "  Missing: EGL headers")
    endif()
endif()

# -------------------------------
# GLES Support
# -------------------------------
message(STATUS "Checking for GLES support...")

# Search for GLES in all possible locations
set(GLES_SEARCH_PATHS
    /lilyspark/opt/lib/driver
    /lilyspark/opt/lib/driver/usr/lib
    /lilyspark/opt/lib/driver/lib
    /usr/lib
    /usr/local/lib
)

# Look for both GLESv1 and GLESv2 libraries
find_library(GLES1_LIBRARY
    NAMES GLESv1_CM
    PATHS ${GLES_SEARCH_PATHS}
    NO_DEFAULT_PATH
)

find_library(GLES2_LIBRARY
    NAMES GLESv2
    PATHS ${GLES_SEARCH_PATHS}
    NO_DEFAULT_PATH
)

find_path(GLES_INCLUDE_DIR
    NAMES GLES/gl.h GLES2/gl2.h
    PATHS
        /lilyspark/opt/lib/driver/include
        /lilyspark/opt/lib/driver/usr/include
        /usr/include
        /usr/local/include
    NO_DEFAULT_PATH
)

# Simple detection
set(GLES1_FOUND FALSE)
set(GLES2_FOUND FALSE)
set(GLES_FOUND FALSE)

if(GLES1_LIBRARY OR GLES2_LIBRARY)
    if(GLES1_LIBRARY)
        set(GLES1_FOUND TRUE)
        message(STATUS "✓ GLESv1 found: ${GLES1_LIBRARY}")
        add_compile_definitions(HAVE_GLES1=1)
    else()
        message(STATUS "ℹ GLESv1 not found")
        add_compile_definitions(HAVE_GLES1=0)
    endif()
    
    if(GLES2_LIBRARY)
        set(GLES2_FOUND TRUE)
        message(STATUS "✓ GLESv2 found: ${GLES2_LIBRARY}")
        add_compile_definitions(HAVE_GLES2=1)
    else()
        message(STATUS "ℹ GLESv2 not found")
        add_compile_definitions(HAVE_GLES2=0)
    endif()
    
    if(GLES_INCLUDE_DIR)
        message(STATUS "✓ GLES headers found: ${GLES_INCLUDE_DIR}")
    else()
        message(STATUS "ℹ GLES headers not found")
    endif()
    
    set(GLES_FOUND TRUE)
    
else()
    set(GLES_FOUND FALSE)
    message(STATUS "ℹ GLES not found")
    
    # Set compile definitions for missing GLES
    add_compile_definitions(HAVE_GLES1=0)
    add_compile_definitions(HAVE_GLES2=0)
    
    # Provide helpful information
    message(STATUS "  Missing: GLES libraries")
    foreach(path IN LISTS GLES_SEARCH_PATHS)
        if(EXISTS ${path})
            message(STATUS "  Checked: ${path}")
        endif()
    endforeach()
endif()

# -------------------------------
# SDL3 Support
# -------------------------------
message(STATUS "Checking for SDL3 support...")

# Search for SDL3 in primary location first
find_library(SDL3_LIBRARY
    NAMES SDL3
    PATHS /lilyspark/opt/lib/sdl3/usr/media/lib
    NO_DEFAULT_PATH
)

find_path(SDL3_INCLUDE_DIR
    NAMES SDL3/SDL.h
    PATHS /lilyspark/opt/lib/sdl3/usr/media/include
    NO_DEFAULT_PATH
)

# Simple detection - don't set compile definitions yet
set(SDL3_FOUND FALSE)

if(SDL3_LIBRARY AND SDL3_INCLUDE_DIR)
    set(SDL3_FOUND TRUE)
    message(STATUS "✓ SDL3 found")
    message(STATUS "  library: ${SDL3_LIBRARY}")
    message(STATUS "  include: ${SDL3_INCLUDE_DIR}")
else()
    set(SDL3_FOUND FALSE)
    message(STATUS "ℹ SDL3 not found in expected location")
    
    # Additional fallback search
    find_library(SDL3_LIBRARY_FALLBACK NAMES SDL3 PATHS /usr/lib /usr/local/lib)
    find_path(SDL3_INCLUDE_DIR_FALLBACK NAMES SDL3/SDL.h PATHS /usr/include /usr/local/include)
    
    if(SDL3_LIBRARY_FALLBACK AND SDL3_INCLUDE_DIR_FALLBACK)
        set(SDL3_LIBRARY ${SDL3_LIBRARY_FALLBACK})
        set(SDL3_INCLUDE_DIR ${SDL3_INCLUDE_DIR_FALLBACK})
        set(SDL3_FOUND TRUE)
        message(STATUS "✓ SDL3 found in system locations")
        message(STATUS "  library: ${SDL3_LIBRARY}")
        message(STATUS "  include: ${SDL3_INCLUDE_DIR}")
    else()
        message(STATUS "ℹ SDL3 not available anywhere")
    endif()
endif()

# -------------------------------
# SDL3_image Support
# -------------------------------
message(STATUS "Checking for SDL3_image support...")

# Search for SDL3_image in primary location first
find_library(SDL3_IMAGE_LIBRARY
    NAMES SDL3_image
    PATHS /lilyspark/opt/lib/sdl3/usr/media/lib
    NO_DEFAULT_PATH
)

find_path(SDL3_IMAGE_INCLUDE_DIR
    NAMES SDL3_image/SDL_image.h
    PATHS /lilyspark/opt/lib/sdl3/usr/media/include
    NO_DEFAULT_PATH
)

# Simple detection - don't set compile definitions yet
set(SDL3_IMAGE_FOUND FALSE)

if(SDL3_IMAGE_LIBRARY AND SDL3_IMAGE_INCLUDE_DIR)
    set(SDL3_IMAGE_FOUND TRUE)
    message(STATUS "✓ SDL3_image found")
    message(STATUS "  library: ${SDL3_IMAGE_LIBRARY}")
    message(STATUS "  include: ${SDL3_IMAGE_INCLUDE_DIR}")
else()
    set(SDL3_IMAGE_FOUND FALSE)
    message(STATUS "ℹ SDL3_image not found in expected location")
    
    # Additional fallback search
    find_library(SDL3_IMAGE_LIBRARY_FALLBACK NAMES SDL3_image PATHS /usr/lib /usr/local/lib)
    find_path(SDL3_IMAGE_INCLUDE_DIR_FALLBACK NAMES SDL3_image/SDL_image.h PATHS /usr/include /usr/local/include)
    
    if(SDL3_IMAGE_LIBRARY_FALLBACK AND SDL3_IMAGE_INCLUDE_DIR_FALLBACK)
        set(SDL3_IMAGE_LIBRARY ${SDL3_IMAGE_LIBRARY_FALLBACK})
        set(SDL3_IMAGE_INCLUDE_DIR ${SDL3_IMAGE_INCLUDE_DIR_FALLBACK})
        set(SDL3_IMAGE_FOUND TRUE)
        message(STATUS "✓ SDL3_image found in system locations")
        message(STATUS "  library: ${SDL3_IMAGE_LIBRARY}")
        message(STATUS "  include: ${SDL3_IMAGE_INCLUDE_DIR}")
    else()
        message(STATUS "ℹ SDL3_image not available anywhere")
    endif()
endif()

# -------------------------------
# SDL3_mixer Support
# -------------------------------
message(STATUS "Checking for SDL3_mixer support...")

# Search for SDL3_mixer in primary location first
find_library(SDL3_MIXER_LIBRARY
    NAMES SDL3_mixer
    PATHS /lilyspark/opt/lib/sdl3/usr/media/lib
    NO_DEFAULT_PATH
)

find_path(SDL3_MIXER_INCLUDE_DIR
    NAMES SDL3_mixer/SDL_mixer.h
    PATHS /lilyspark/opt/lib/sdl3/usr/media/include
    NO_DEFAULT_PATH
)

# Simple detection - don't set compile definitions yet
set(SDL3_MIXER_FOUND FALSE)

if(SDL3_MIXER_LIBRARY AND SDL3_MIXER_INCLUDE_DIR)
    set(SDL3_MIXER_FOUND TRUE)
    message(STATUS "✓ SDL3_mixer found")
    message(STATUS "  library: ${SDL3_MIXER_LIBRARY}")
    message(STATUS "  include: ${SDL3_MIXER_INCLUDE_DIR}")
else()
    set(SDL3_MIXER_FOUND FALSE)
    message(STATUS "ℹ SDL3_mixer not found in expected location")
    
    # Additional fallback search
    find_library(SDL3_MIXER_LIBRARY_FALLBACK NAMES SDL3_mixer PATHS /usr/lib /usr/local/lib)
    find_path(SDL3_MIXER_INCLUDE_DIR_FALLBACK NAMES SDL3_mixer/SDL_mixer.h PATHS /usr/include /usr/local/include)
    
    if(SDL3_MIXER_LIBRARY_FALLBACK AND SDL3_MIXER_INCLUDE_DIR_FALLBACK)
        set(SDL3_MIXER_LIBRARY ${SDL3_MIXER_LIBRARY_FALLBACK})
        set(SDL3_MIXER_INCLUDE_DIR ${SDL3_MIXER_INCLUDE_DIR_FALLBACK})
        set(SDL3_MIXER_FOUND TRUE)
        message(STATUS "✓ SDL3_mixer found in system locations")
        message(STATUS "  library: ${SDL3_MIXER_LIBRARY}")
        message(STATUS "  include: ${SDL3_MIXER_INCLUDE_DIR}")
    else()
        message(STATUS "ℹ SDL3_mixer not available anywhere")
    endif()
endif()

# -------------------------------
# SDL3_ttf Support
# -------------------------------
message(STATUS "Checking for SDL3_ttf support...")

# Search for SDL3_ttf in primary location first
find_library(SDL3_TTF_LIBRARY
    NAMES SDL3_ttf
    PATHS /lilyspark/opt/lib/sdl3/usr/media/lib
    NO_DEFAULT_PATH
)

find_path(SDL3_TTF_INCLUDE_DIR
    NAMES SDL3_ttf/SDL_ttf.h
    PATHS /lilyspark/opt/lib/sdl3/usr/media/include
    NO_DEFAULT_PATH
)

# Simple detection - don't set compile definitions yet
set(SDL3_TTF_FOUND FALSE)

if(SDL3_TTF_LIBRARY AND SDL3_TTF_INCLUDE_DIR)
    set(SDL3_TTF_FOUND TRUE)
    message(STATUS "✓ SDL3_ttf found")
    message(STATUS "  library: ${SDL3_TTF_LIBRARY}")
    message(STATUS "  include: ${SDL3_TTF_INCLUDE_DIR}")
else()
    set(SDL3_TTF_FOUND FALSE)
    message(STATUS "ℹ SDL3_ttf not found in expected location")
    
    # Additional fallback search
    find_library(SDL3_TTF_LIBRARY_FALLBACK NAMES SDL3_ttf PATHS /usr/lib /usr/local/lib)
    find_path(SDL3_TTF_INCLUDE_DIR_FALLBACK NAMES SDL3_ttf/SDL_ttf.h PATHS /usr/include /usr/local/include)
    
    if(SDL3_TTF_LIBRARY_FALLBACK AND SDL3_TTF_INCLUDE_DIR_FALLBACK)
        set(SDL3_TTF_LIBRARY ${SDL3_TTF_LIBRARY_FALLBACK})
        set(SDL3_TTF_INCLUDE_DIR ${SDL3_TTF_INCLUDE_DIR_FALLBACK})
        set(SDL3_TTF_FOUND TRUE)
        message(STATUS "✓ SDL3_ttf found in system locations")
        message(STATUS "  library: ${SDL3_TTF_LIBRARY}")
        message(STATUS "  include: ${SDL3_TTF_INCLUDE_DIR}")
    else()
        message(STATUS "ℹ SDL3_ttf not available anywhere")
    endif()
endif()

# -------------------------------
# Vulkan Support
# -------------------------------
message(STATUS "Checking for Vulkan support...")

# Search for Vulkan headers
find_path(VULKAN_HEADERS_DIR
    NAMES vulkan/vulkan.h
    PATHS
        /lilyspark/opt/lib/vulkan/include
        /usr/include
        /usr/local/include
    NO_DEFAULT_PATH
)

# Search for Vulkan loader library
find_library(VULKAN_LIBRARY
    NAMES vulkan
    PATHS
        /lilyspark/opt/lib/vulkan/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Simple detection
set(VULKAN_HEADERS_FOUND FALSE)
set(VULKAN_LOADER_FOUND FALSE)
set(VULKAN_FOUND FALSE)

if(VULKAN_HEADERS_DIR)
    set(VULKAN_HEADERS_FOUND TRUE)
    message(STATUS "✓ Vulkan headers found: ${VULKAN_HEADERS_DIR}")
else()
    message(STATUS "ℹ Vulkan headers not found")
endif()

if(VULKAN_LIBRARY)
    set(VULKAN_LOADER_FOUND TRUE)
    message(STATUS "✓ Vulkan loader found: ${VULKAN_LIBRARY}")
else()
    message(STATUS "ℹ Vulkan loader not found")
endif()

if(VULKAN_HEADERS_FOUND AND VULKAN_LOADER_FOUND)
    set(VULKAN_FOUND TRUE)
    message(STATUS "✓ Complete Vulkan support available")
else()
    set(VULKAN_FOUND FALSE)
    message(STATUS "ℹ Incomplete or missing Vulkan support")
endif()

# -------------------------------
# glmark2 Support
# -------------------------------
message(STATUS "Checking for glmark2 support...")

# Search for glmark2 binary
find_program(GLMARK2_EXECUTABLE
    NAMES glmark2
    PATHS
        /lilyspark/opt/lib/graphics/bin
        /usr/bin
        /usr/local/bin
    NO_DEFAULT_PATH
)

# Simple detection
set(GLMARK2_FOUND FALSE)

if(GLMARK2_EXECUTABLE)
    set(GLMARK2_FOUND TRUE)
    message(STATUS "✓ glmark2 found: ${GLMARK2_EXECUTABLE}")
    
    # Set compile definition
    add_compile_definitions(HAVE_GLMARK2=1)
    
else()
    set(GLMARK2_FOUND FALSE)
    message(STATUS "ℹ glmark2 not found")
    
    # Set compile definition for missing glmark2
    add_compile_definitions(HAVE_GLMARK2=0)
    
    # Provide helpful information about what's missing
    message(STATUS "  Missing: glmark2 benchmark tool")
    message(STATUS "  Checked locations:")
    message(STATUS "    - /lilyspark/opt/lib/graphics/bin")
    message(STATUS "    - /usr/bin") 
    message(STATUS "    - /usr/local/bin")
endif()

# -------------------------------
# SQLite3 Support
# -------------------------------
message(STATUS "Checking for SQLite3 support...")

# Search for SQLite3 in primary location first
find_path(SQLITE3_INCLUDE_DIR
    NAMES sqlite3.h
    PATHS
        /lilyspark/opt/lib/database/include
        /usr/include
        /usr/local/include
    NO_DEFAULT_PATH
)

find_library(SQLITE3_LIBRARY
    NAMES sqlite3
    PATHS
        /lilyspark/opt/lib/database/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# Simple detection
set(SQLITE3_FOUND FALSE)

if(SQLITE3_LIBRARY AND SQLITE3_INCLUDE_DIR)
    set(SQLITE3_FOUND TRUE)
    message(STATUS "✓ SQLite3 found")
    message(STATUS "  library: ${SQLITE3_LIBRARY}")
    message(STATUS "  include: ${SQLITE3_INCLUDE_DIR}")
    
    # Set compile definitions
    add_compile_definitions(HAVE_SQLITE3=1)
    add_compile_definitions(SQLITE_ENABLE_COLUMN_METADATA=1)
    add_compile_definitions(SQLITE_ENABLE_FTS3=1)
    add_compile_definitions(SQLITE_ENABLE_FTS4=1)
    add_compile_definitions(SQLITE_ENABLE_FTS5=1)
    add_compile_definitions(SQLITE_ENABLE_JSON1=1)
    add_compile_definitions(SQLITE_ENABLE_RTREE=1)
    add_compile_definitions(SQLITE_ENABLE_DBSTAT_VTAB=1)
    add_compile_definitions(SQLITE_SECURE_DELETE=1)
    add_compile_definitions(SQLITE_USE_URI=1)
    add_compile_definitions(SQLITE_ENABLE_UNLOCK_NOTIFY=1)
    add_compile_definitions(SQLITE_ENABLE_ZLIB=1)
    
else()
    set(SQLITE3_FOUND FALSE)
    message(STATUS "ℹ SQLite3 not found in expected location")
    
    # Additional fallback search
    find_library(SQLITE3_LIBRARY_FALLBACK NAMES sqlite3 PATHS /usr/lib /usr/local/lib)
    find_path(SQLITE3_INCLUDE_DIR_FALLBACK NAMES sqlite3.h PATHS /usr/include /usr/local/include)
    
    if(SQLITE3_LIBRARY_FALLBACK AND SQLITE3_INCLUDE_DIR_FALLBACK)
        set(SQLITE3_LIBRARY ${SQLITE3_LIBRARY_FALLBACK})
        set(SQLITE3_INCLUDE_DIR ${SQLITE3_INCLUDE_DIR_FALLBACK})
        set(SQLITE3_FOUND TRUE)
        message(STATUS "✓ SQLite3 found in system locations")
        message(STATUS "  library: ${SQLITE3_LIBRARY}")
        message(STATUS "  include: ${SQLITE3_INCLUDE_DIR}")
        
        # Set basic compile definition for system SQLite3
        add_compile_definitions(HAVE_SQLITE3=1)
        
    else()
        message(STATUS "ℹ SQLite3 not available anywhere")
        add_compile_definitions(HAVE_SQLITE3=0)
    endif()
endif()

# I swear to god if you touch this code below, I hate you if you do this
# and then fuck the codebase up. You are worthless for the dev of this project
# if you touch this, please for fucks sake DO NOT touch this.
# 
# If you are unaware of what this does, since this is so important, let it
# be the one time I tell you why you are unqualified to touch this.
# 
# This manages both Docker's executable source code as well as CMake's.
# There are two requirements you dumb fuck, do not think one can live
# and the other can die. Do you like debugging? Yes, fucking keep it.
# Do you like the code compiling????? Yes, ABSOLUTELY FUCKING KEEP IT!!!!

# We essentially have two different schemas we must include, and so, these
# sections will continously grow in due time.

if(EXISTS /lilyspark/app/src/main.cpp)
    add_executable(simplehttpserver
        /lilyspark/app/src/main.cpp
    )
    message(STATUS "Using Docker source path: /lilyspark/app/src/main.cpp")
elseif(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp)
    add_executable(simplehttpserver
        main.cpp
    )
    message(STATUS "Using CMake specific path: main.cpp")
else()
    message(WARNING "main.cpp not found in any current searched paths")
    file(WRITE ${CMAKE_BINARY_DIR}/placeholder_main.cpp "int main() { return 0; }")
    add_executable(simplehttpserver
        ${CMAKE_BINARY_DIR}/placeholder_main.cpp
    )
endif()

#
#
# So yeah listen to me when I tell you to not FUCKING TOUCH THE ABOVE CODE
#
#

# Safe dependency tracking - cannot fail
if(FOP_FOUND STREQUAL "TRUE" OR FOP_FOUND STREQUAL "PARTIAL")
    message(STATUS "Creating FOP version info...")
    
    # Create simple version file without complex commands
    file(WRITE ${CMAKE_BINARY_DIR}/fop_version.json
        "{\n"
        "  \"type\": \"apache-fop\",\n"
        "  \"version\": \"${FOP_VERSION}\",\n"
        "  \"status\": \"${FOP_FOUND}\",\n"
        "  \"jar_count\": ${FOP_JAR_COUNT}\n"
        "}\n"
    )
    message(STATUS "FOP info saved to fop_version.json")
    
    # Safe Java definition
    if(JAVA_EXECUTABLE AND NOT JAVA_EXECUTABLE STREQUAL "NOTFOUND")
        add_compile_definitions(JAVA_EXECUTABLE="${JAVA_EXECUTABLE}")
    endif()
endif()

# Final summary (cannot fail)
message(STATUS "=== FINAL FOP STATUS ===")
message(STATUS "Status: ${FOP_FOUND}")
message(STATUS "Version: ${FOP_VERSION}")
message(STATUS "JARs: ${FOP_JAR_COUNT}")
message(STATUS "Java: ${JAVA_EXECUTABLE}")
message(STATUS "=========================")


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

# Link against libpciaccess if available
if(PCACCESS_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${PCACCESS_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        ${PCACCESS_INSTALL_DIR}/include
        /usr/include
        /usr/local/include
    )
    
elseif(PCACCESS_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_dependencies(simplehttpserver pciaccess_build)
    
    # Add the include and library directories from the built libpciaccess
    target_include_directories(simplehttpserver PRIVATE
        ${PCACCESS_PREFIX}/include
    )
    
    target_link_directories(simplehttpserver PRIVATE
        ${PCACCESS_PREFIX}/lib
    )
    
    target_link_libraries(simplehttpserver PRIVATE pciaccess)
endif()

# Update configuration summary with libpciaccess status
message(STATUS "libpciaccess Hardware Support: ${PCACCESS_FOUND}")
if(PCACCESS_FOUND STREQUAL "TRUE")
    message(STATUS "  library: ${PCACCESS_LIBRARY}")
elseif(PCACCESS_FOUND STREQUAL "SOURCE_AVAILABLE")
    message(STATUS "  Build: From source during compilation")
endif()

# Link against libdrm if available
if(LIBDRM_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${LIBDRM_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        ${LIBDRM_INSTALL_DIR}/include
        ${LIBDRM_INSTALL_DIR}/include/libdrm
        /usr/include
        /usr/local/include
    )
    
elseif(LIBDRM_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_dependencies(simplehttpserver libdrm_build)
    
    # Add the include and library directories from the built libdrm
    target_include_directories(simplehttpserver PRIVATE
        ${LIBDRM_PREFIX}/include
        ${LIBDRM_PREFIX}/include/libdrm
    )
    
    target_link_directories(simplehttpserver PRIVATE
        ${LIBDRM_PREFIX}/lib
    )
    
    target_link_libraries(simplehttpserver PRIVATE drm)
endif()

# Update configuration summary with libdrm status
message(STATUS "libdrm Graphics Support: ${LIBDRM_FOUND}")
if(LIBDRM_FOUND STREQUAL "TRUE")
    message(STATUS "  library: ${LIBDRM_LIBRARY}")
elseif(LIBDRM_FOUND STREQUAL "SOURCE_AVAILABLE")
    message(STATUS "  Build: From source during compilation with LLVM16")
endif()

# Link against libepoxy if available
if(EPOXY_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${EPOXY_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        ${EPOXY_INSTALL_DIR}/include
        ${EPOXY_INSTALL_DIR}/include/epoxy
        /usr/include
        /usr/local/include
    )
    
elseif(EPOXY_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_dependencies(simplehttpserver epoxy_build)
    
    # Add the include and library directories from the built libepoxy
    target_include_directories(simplehttpserver PRIVATE
        ${EPOXY_PREFIX}/include
        ${EPOXY_PREFIX}/include/epoxy
    )
    
    target_link_directories(simplehttpserver PRIVATE
        ${EPOXY_PREFIX}/lib
    )
    
    target_link_libraries(simplehttpserver PRIVATE epoxy)
endif()

# Update configuration summary with libepoxy status
message(STATUS "libepoxy Graphics Support: ${EPOXY_FOUND}")
if(EPOXY_FOUND STREQUAL "TRUE")
    message(STATUS "  library: ${EPOXY_LIBRARY}")
elseif(EPOXY_FOUND STREQUAL "SOURCE_AVAILABLE")
    message(STATUS "  Build: From source during compilation with LLVM16")
endif()

# Link against available image libraries
if(HAVE_TIFF)
    target_link_libraries(simplehttpserver PRIVATE ${TIFF_LIBRARY})
    # Add include directories for tiff
    if(EXISTS /lilyspark/opt/lib/sdl3/include)
        target_include_directories(simplehttpserver PRIVATE /lilyspark/opt/lib/sdl3/include)
    elseif(EXISTS /usr/include)
        target_include_directories(simplehttpserver PRIVATE /usr/include)
    endif()
endif()

if(HAVE_WEBP)
    target_link_libraries(simplehttpserver PRIVATE ${WEBP_LIBRARY})
    # Add include directories for webp
    if(EXISTS /lilyspark/opt/lib/sdl3/include)
        target_include_directories(simplehttpserver PRIVATE /lilyspark/opt/lib/sdl3/include)
    elseif(EXISTS /usr/include)
        target_include_directories(simplehttpserver PRIVATE /usr/include)
    endif()
endif()

if(HAVE_AVIF)
    target_link_libraries(simplehttpserver PRIVATE ${AVIF_LIBRARY})
    # Add include directories for avif
    if(EXISTS /lilyspark/opt/lib/sdl3/include)
        target_include_directories(simplehttpserver PRIVATE /lilyspark/opt/lib/sdl3/include)
    elseif(EXISTS /usr/include)
        target_include_directories(simplehttpserver PRIVATE /usr/include)
    endif()
endif()

# Add a simple verification message (no file operations)
add_custom_command(TARGET simplehttpserver POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "=== IMAGE LIBRARY SUMMARY ==="
    COMMAND ${CMAKE_COMMAND} -E echo "libtiff: ${HAVE_TIFF}"
    COMMAND ${CMAKE_COMMAND} -E echo "libwebp: ${HAVE_WEBP}"
    COMMAND ${CMAKE_COMMAND} -E echo "libavif: ${HAVE_AVIF}"
    COMMENT "Image library availability summary"
)

# Update configuration summary
message(STATUS "=== IMAGE LIBRARY SUMMARY ===")
message(STATUS "libtiff: ${HAVE_TIFF}")
if(HAVE_TIFF)
    message(STATUS "  path: ${TIFF_LIBRARY}")
endif()
message(STATUS "libwebp: ${HAVE_WEBP}")
if(HAVE_WEBP)
    message(STATUS "  path: ${WEBP_LIBRARY}")
endif()
message(STATUS "libavif: ${HAVE_AVIF}")
if(HAVE_AVIF)
    message(STATUS "  path: ${AVIF_LIBRARY}")
endif()

# Add verification step for Python packages
add_custom_command(TARGET simplehttpserver POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "=== PYTHON PACKAGE VERIFICATION ==="
    COMMAND ${CMAKE_COMMAND} -E echo "mesonbuild: $<IF:$<BOOL:${HAVE_mesonbuild}>,Available,Missing>"
    COMMAND ${CMAKE_COMMAND} -E echo "mako: $<IF:$<BOOL:${HAVE_mako}>,Available,Missing>"
    COMMAND ${CMAKE_COMMAND} -E echo "MarkupSafe: $<IF:$<BOOL:${HAVE_MarkupSafe}>,Available,Missing>"
    COMMENT "Python package availability summary"
)

# Update configuration summary
message(STATUS "=== PYTHON DEPENDENCY SUMMARY ===")
message(STATUS "mesonbuild: ${HAVE_mesonbuild}")
if(HAVE_mesonbuild AND mesonbuild_FIND_RESULT)
    message(STATUS "  location: ${mesonbuild_FIND_RESULT}")
endif()

message(STATUS "mako: ${HAVE_mako}")
if(HAVE_mako AND mako_FIND_RESULT)
    message(STATUS "  location: ${mako_FIND_RESULT}")
endif()

message(STATUS "MarkupSafe: ${HAVE_MarkupSafe}")
if(HAVE_MarkupSafe AND MarkupSafe_FIND_RESULT)
    message(STATUS "  location: ${MarkupSafe_FIND_RESULT}")
endif()

message(STATUS "All dependencies available: ${HAVE_PYTHON_DEPS}")

# Link against SPIRV-Tools if available
if(SPIRV_TOOLS_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${SPIRV_TOOLS_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        ${SPIRV_TOOLS_INSTALL_DIR}/include
        /usr/include
        /usr/local/include
    )
    
elseif(SPIRV_TOOLS_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_dependencies(simplehttpserver spirv_tools_build)
    
    # Add the include and library directories from the built SPIRV-Tools
    target_include_directories(simplehttpserver PRIVATE
        ${SPIRV_TOOLS_PREFIX}/include
    )
    
    target_link_directories(simplehttpserver PRIVATE
        ${SPIRV_TOOLS_PREFIX}/lib
    )
    
    target_link_libraries(simplehttpserver PRIVATE SPIRV-Tools)
endif()

# Add verification step
if(SPIRV_TOOLS_FOUND STREQUAL "TRUE" OR SPIRV_TOOLS_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== SPIRV-TOOLS VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "Library: $<IF:$<BOOL:${SPIRV_TOOLS_FOUND}>,Available,Missing>"
        COMMENT "SPIRV-Tools availability verification"
    )
endif()

# Update configuration summary with SPIRV-Tools status
message(STATUS "SPIRV-Tools Support: ${SPIRV_TOOLS_FOUND}")
if(SPIRV_TOOLS_FOUND STREQUAL "TRUE")
    message(STATUS "  library: ${SPIRV_TOOLS_LIBRARY}")
    message(STATUS "  binary: ${SPIRV_TOOLS_BINARY}")
elseif(SPIRV_TOOLS_FOUND STREQUAL "SOURCE_AVAILABLE")
    message(STATUS "  Build: From source during compilation with LLVM16")
endif()

# Link against Shaderc if available
if(SHADERC_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${SHADERC_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        ${SHADERC_INSTALL_DIR}/include
        /usr/include
        /usr/local/include
    )
    
elseif(SHADERC_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_dependencies(simplehttpserver shaderc_build)
    
    # Add the include and library directories from the built Shaderc
    target_include_directories(simplehttpserver PRIVATE
        ${SHADERC_PREFIX}/include
    )
    
    target_link_directories(simplehttpserver PRIVATE
        ${SHADERC_PREFIX}/lib
    )
    
    target_link_libraries(simplehttpserver PRIVATE shaderc)
endif()

# Add verification step
if(SHADERC_FOUND STREQUAL "TRUE" OR SHADERC_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== SHADERC VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "Library: $<IF:$<BOOL:${SHADERC_FOUND}>,Available,Missing>"
        COMMENT "Shaderc availability verification"
    )
endif()

# Update configuration summary with Shaderc status
message(STATUS "Shaderc Support: ${SHADERC_FOUND}")
if(SHADERC_FOUND STREQUAL "TRUE")
    message(STATUS "  library: ${SHADERC_LIBRARY}")
    message(STATUS "  binary: ${SHADERC_BINARY}")
elseif(SHADERC_FOUND STREQUAL "SOURCE_AVAILABLE")
    message(STATUS "  Build: From source during compilation with LLVM16")
    message(STATUS "  Depends on: SPIRV-Tools")
endif()

# Link against libgbm if available
if(GBM_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${GBM_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        ${GBM_INSTALL_DIR}/include
        /usr/include
        /usr/local/include
    )
    
elseif(GBM_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_dependencies(simplehttpserver gbm_build)
    
    # Add the include and library directories from the built libgbm
    target_include_directories(simplehttpserver PRIVATE
        ${GBM_PREFIX}/include
    )
    
    target_link_directories(simplehttpserver PRIVATE
        ${GBM_PREFIX}/lib
    )
    
    target_link_libraries(simplehttpserver PRIVATE gbm)
endif()

# Add verification step
if(GBM_FOUND STREQUAL "TRUE" OR GBM_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== LIBGBM VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "Library: $<IF:$<BOOL:${GBM_FOUND}>,Available,Missing>"
        COMMENT "libgbm availability verification"
    )
endif()

# Update configuration summary with libgbm status
message(STATUS "libgbm Support: ${GBM_FOUND}")
if(GBM_FOUND STREQUAL "TRUE")
    message(STATUS "  library: ${GBM_LIBRARY}")
elseif(GBM_FOUND STREQUAL "SOURCE_AVAILABLE")
    message(STATUS "  Build: From source during compilation with autotools")
    message(STATUS "  Depends on: libdrm")
endif()

# Link against GStreamer if available
if(GSTREAMER_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${GSTREAMER_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        ${GSTREAMER_INSTALL_DIR}/include
        /usr/include
        /usr/local/include
    )
endif()

# Link against Xorg if available
if(XORG_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${X11_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        ${XORG_INSTALL_DIR}/include
        /usr/include
        /usr/local/include
    )
endif()

# Note: For source builds, we would typically add custom targets here,
# but given the complexity of building GStreamer and Xorg from source,
# it's better to rely on pre-built versions or handle the source builds
# separately in your build environment.

# Add verification steps
add_custom_command(TARGET simplehttpserver POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "=== MEDIA LIBRARY SUMMARY ==="
    COMMAND ${CMAKE_COMMAND} -E echo "GStreamer: $<IF:$<BOOL:${GSTREAMER_FOUND}>,Available,Missing>"
    COMMAND ${CMAKE_COMMAND} -E echo "Xorg: $<IF:$<BOOL:${XORG_FOUND}>,Available,Missing>"
    COMMENT "Media library availability summary"
)

# Update configuration summary
message(STATUS "=== MEDIA LIBRARY SUMMARY ===")
message(STATUS "GStreamer Support: ${GSTREAMER_FOUND}")
if(GSTREAMER_FOUND STREQUAL "TRUE")
    message(STATUS "  library: ${GSTREAMER_LIBRARY}")
endif()

message(STATUS "Xorg Support: ${XORG_FOUND}")
if(XORG_FOUND STREQUAL "TRUE")
    message(STATUS "  library: ${X11_LIBRARY}")
endif()

# Link against MESA components if available
if(MESA_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE
        ${GL_LIBRARY}
        ${EGL_LIBRARY}
        ${GBM_LIBRARY}
        ${VULKAN_SWRAST_LIBRARY}
    )
    target_include_directories(simplehttpserver PRIVATE
        ${MESA_INSTALL_DIR}/include
        /usr/include
        /usr/local/include
    )
    
elseif(MESA_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_dependencies(simplehttpserver mesa_build)
    
    # Add the include and library directories from the built MESA
    target_include_directories(simplehttpserver PRIVATE
        ${MESA_PREFIX}/include
    )
    
    target_link_directories(simplehttpserver PRIVATE
        ${MESA_PREFIX}/lib
    )
    
    target_link_libraries(simplehttpserver PRIVATE
        GL
        EGL
        gbm
        vulkan_swrast
    )
endif()

# Add verification step
if(MESA_FOUND STREQUAL "TRUE" OR MESA_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== MESA VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "OpenGL: $<IF:$<BOOL:${GL_LIBRARY}>,Available,Missing>"
        COMMAND ${CMAKE_COMMAND} -E echo "EGL: $<IF:$<BOOL:${EGL_LIBRARY}>,Available,Missing>"
        COMMAND ${CMAKE_COMMAND} -E echo "GBM: $<IF:$<BOOL:${GBM_LIBRARY}>,Available,Missing>"
        COMMAND ${CMAKE_COMMAND} -E echo "Vulkan: $<IF:$<BOOL:${VULKAN_SWRAST_LIBRARY}>,Available,Missing>"
        COMMENT "MESA components availability verification"
    )
endif()

# Update configuration summary with MESA status
message(STATUS "=== MESA GRAPHICS SUMMARY ===")
message(STATUS "MESA Support: ${MESA_FOUND}")
if(MESA_FOUND STREQUAL "TRUE")
    message(STATUS "  OpenGL: ${GL_LIBRARY}")
    message(STATUS "  EGL: ${EGL_LIBRARY}")
    message(STATUS "  GBM: ${GBM_LIBRARY}")
    message(STATUS "  Vulkan: ${VULKAN_SWRAST_LIBRARY}")
elseif(MESA_FOUND STREQUAL "SOURCE_AVAILABLE")
    message(STATUS "  Build: From source during compilation with LLVM16")
    message(STATUS "  Drivers: swrast, kmsro, zink")
    message(STATUS "  Platforms: wayland")
    message(STATUS "  Features: EGL, GBM, Vulkan SWRAST")
endif()

# Link against GBM (MESA) if available
if(GBM_MESA_FOUND STREQUAL "TRUE")
    target_link_libraries(simplehttpserver PRIVATE ${GBM_MESA_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE
        ${GBM_MESA_INSTALL_DIR}/include
        /usr/include
        /usr/local/include
    )
    
elseif(GBM_MESA_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_dependencies(simplehttpserver gbm_mesa_build)
    
    # Add the include and library directories from the built GBM (MESA)
    target_include_directories(simplehttpserver PRIVATE
        ${GBM_MESA_PREFIX}/include
    )
    
    target_link_directories(simplehttpserver PRIVATE
        ${GBM_MESA_PREFIX}/lib
    )
    
    target_link_libraries(simplehttpserver PRIVATE gbm)
endif()

# Add verification step
if(GBM_MESA_FOUND STREQUAL "TRUE" OR GBM_MESA_FOUND STREQUAL "SOURCE_AVAILABLE")
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== GBM (MESA) VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "Library: $<IF:$<BOOL:${GBM_MESA_FOUND}>,Available,Missing>"
        COMMENT "GBM (MESA) availability verification"
    )
endif()

# Update configuration summary with GBM (MESA) status
message(STATUS "GBM (MESA) Support: ${GBM_MESA_FOUND}")
if(GBM_MESA_FOUND STREQUAL "TRUE")
    message(STATUS "  library: ${GBM_MESA_LIBRARY}")
elseif(GBM_MESA_FOUND STREQUAL "SOURCE_AVAILABLE")
    message(STATUS "  Build: From MESA source during compilation")
    message(STATUS "  Features: GBM only (other components disabled)")
endif()

# Link against EGL if available
if(EGL_FOUND)
    target_link_libraries(simplehttpserver PRIVATE ${EGL_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE ${EGL_INCLUDE_DIR})
    
    # Add verification step
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== EGL VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "EGL: Available (${EGL_LIBRARY})"
        COMMENT "EGL availability verification"
    )
else()
    # Add message for missing EGL
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== EGL VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "EGL: Not available - building without EGL support"
        COMMENT "EGL not available"
    )
endif()

# Update configuration summary
message(STATUS "EGL Support: ${EGL_FOUND}")
if(EGL_FOUND)
    message(STATUS "  library: ${EGL_LIBRARY}")
    message(STATUS "  headers: ${EGL_INCLUDE_DIR}")
else()
    message(STATUS "  status: Building without EGL support")
endif()

# Link against GLES if available
if(GLES_FOUND)
    if(GLES1_FOUND)
        target_link_libraries(simplehttpserver PRIVATE ${GLES1_LIBRARY})
    endif()
    
    if(GLES2_FOUND)
        target_link_libraries(simplehttpserver PRIVATE ${GLES2_LIBRARY})
    endif()
    
    if(GLES_INCLUDE_DIR)
        target_include_directories(simplehttpserver PRIVATE ${GLES_INCLUDE_DIR})
    endif()
    
    # Add verification step
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== GLES VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "GLESv1: $<IF:$<BOOL:${GLES1_FOUND}>,Available,Missing>"
        COMMAND ${CMAKE_COMMAND} -E echo "GLESv2: $<IF:$<BOOL:${GLES2_FOUND}>,Available,Missing>"
        COMMENT "GLES availability verification"
    )
else()
    # Add message for missing GLES
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== GLES VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "GLES: Not available - building without GLES support"
        COMMENT "GLES not available"
    )
endif()

# Update configuration summary
message(STATUS "GLES Support: ${GLES_FOUND}")
if(GLES1_FOUND)
    message(STATUS "  GLESv1: ${GLES1_LIBRARY}")
endif()
if(GLES2_FOUND)
    message(STATUS "  GLESv2: ${GLES2_LIBRARY}")
endif()
if(GLES_INCLUDE_DIR)
    message(STATUS "  headers: ${GLES_INCLUDE_DIR}")
endif()
if(NOT GLES_FOUND)
    message(STATUS "  status: Building without GLES support")
endif()

# Set compile definitions based on SDL3 availability
if(SDL3_FOUND)
    target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL3=1)
    
    # Link against SDL3
    target_link_libraries(simplehttpserver PRIVATE ${SDL3_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE ${SDL3_INCLUDE_DIR})
    
    # Add verification step
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== SDL3 VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "SDL3: Available"
        COMMENT "SDL3 available"
    )
else()
    target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL3=0)
    
    # Check for SDL2 as fallback (simpler approach)
    find_library(SDL2_LIBRARY NAMES SDL2)
    if(SDL2_LIBRARY)
        message(STATUS "Using SDL2 as fallback")
        target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL2=1)
        target_link_libraries(simplehttpserver PRIVATE ${SDL2_LIBRARY})
        
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== SDL VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "SDL3: Not available, using SDL2 fallback"
            COMMENT "SDL fallback"
        )
    else()
        target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL2=0)
        
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== SDL VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "SDL: Not available"
            COMMENT "No SDL available"
        )
    endif()
endif()

# Update configuration summary (simple version)
message(STATUS "SDL3 Support: ${SDL3_FOUND}")
if(SDL3_FOUND)
    message(STATUS "  library: ${SDL3_LIBRARY}")
endif()

# Set compile definitions based on SDL3_image availability
if(SDL3_IMAGE_FOUND)
    target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL3_IMAGE=1)
    
    # Link against SDL3_image
    target_link_libraries(simplehttpserver PRIVATE ${SDL3_IMAGE_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE ${SDL3_IMAGE_INCLUDE_DIR})
    
    # Add verification step
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== SDL3_image VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "SDL3_image: Available"
        COMMENT "SDL3_image available"
    )
else()
    target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL3_IMAGE=0)
    
    # Check for SDL2_image as fallback
    find_library(SDL2_IMAGE_LIBRARY NAMES SDL2_image)
    if(SDL2_IMAGE_LIBRARY)
        message(STATUS "Using SDL2_image as fallback")
        target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL2_IMAGE=1)
        target_link_libraries(simplehttpserver PRIVATE ${SDL2_IMAGE_LIBRARY})
        
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== SDL_image VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "SDL3_image: Not available, using SDL2_image fallback"
            COMMENT "SDL_image fallback"
        )
    else()
        target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL2_IMAGE=0)
        
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== SDL_image VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "SDL_image: Not available"
            COMMENT "No SDL_image available"
        )
    endif()
endif()

# Update configuration summary
message(STATUS "SDL3_image Support: ${SDL3_IMAGE_FOUND}")
if(SDL3_IMAGE_FOUND)
    message(STATUS "  library: ${SDL3_IMAGE_LIBRARY}")
endif()

# Set compile definitions based on SDL3_mixer availability
if(SDL3_MIXER_FOUND)
    target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL3_MIXER=1)
    
    # Link against SDL3_mixer
    target_link_libraries(simplehttpserver PRIVATE ${SDL3_MIXER_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE ${SDL3_MIXER_INCLUDE_DIR})
    
    # Add verification step
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== SDL3_mixer VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "SDL3_mixer: Available"
        COMMENT "SDL3_mixer available"
    )
else()
    target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL3_MIXER=0)
    
    # Check for SDL2_mixer as fallback
    find_library(SDL2_MIXER_LIBRARY NAMES SDL2_mixer)
    if(SDL2_MIXER_LIBRARY)
        message(STATUS "Using SDL2_mixer as fallback")
        target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL2_MIXER=1)
        target_link_libraries(simplehttpserver PRIVATE ${SDL2_MIXER_LIBRARY})
        
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== SDL_mixer VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "SDL3_mixer: Not available, using SDL2_mixer fallback"
            COMMENT "SDL_mixer fallback"
        )
    else()
        target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL2_MIXER=0)
        
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== SDL_mixer VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "SDL_mixer: Not available"
            COMMENT "No SDL_mixer available"
        )
    endif()
endif()

# Update configuration summary
message(STATUS "SDL3_mixer Support: ${SDL3_MIXER_FOUND}")
if(SDL3_MIXER_FOUND)
    message(STATUS "  library: ${SDL3_MIXER_LIBRARY}")
endif()

# Set compile definitions based on SDL3_ttf availability
if(SDL3_TTF_FOUND)
    target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL3_TTF=1)
    
    # Link against SDL3_ttf
    target_link_libraries(simplehttpserver PRIVATE ${SDL3_TTF_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE ${SDL3_TTF_INCLUDE_DIR})
    
    # Add verification step
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== SDL3_ttf VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "SDL3_ttf: Available"
        COMMENT "SDL3_ttf available"
    )
else()
    target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL3_TTF=0)
    
    # Check for SDL2_ttf as fallback
    find_library(SDL2_TTF_LIBRARY NAMES SDL2_ttf)
    if(SDL2_TTF_LIBRARY)
        message(STATUS "Using SDL2_ttf as fallback")
        target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL2_TTF=1)
        target_link_libraries(simplehttpserver PRIVATE ${SDL2_TTF_LIBRARY})
        
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== SDL_ttf VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "SDL3_ttf: Not available, using SDL2_ttf fallback"
            COMMENT "SDL_ttf fallback"
        )
    else()
        target_compile_definitions(simplehttpserver PRIVATE HAVE_SDL2_TTF=0)
        
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== SDL_ttf VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "SDL_ttf: Not available"
            COMMENT "No SDL_ttf available"
        )
    endif()
endif()

# Update configuration summary
message(STATUS "SDL3_ttf Support: ${SDL3_TTF_FOUND}")
if(SDL3_TTF_FOUND)
    message(STATUS "  library: ${SDL3_TTF_LIBRARY}")
endif()

# Set compile definitions based on Vulkan availability
if(VULKAN_FOUND)
    target_compile_definitions(simplehttpserver PRIVATE HAVE_VULKAN=1)
    
    # Link against Vulkan
    target_link_libraries(simplehttpserver PRIVATE ${VULKAN_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE ${VULKAN_HEADERS_DIR})
    
    # Add verification step
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== VULKAN VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "Vulkan: Complete support available"
        COMMAND ${CMAKE_COMMAND} -E echo "  headers: ${VULKAN_HEADERS_DIR}"
        COMMAND ${CMAKE_COMMAND} -E echo "  loader: ${VULKAN_LIBRARY}"
        COMMENT "Vulkan availability verification"
    )
    
else()
    target_compile_definitions(simplehttpserver PRIVATE HAVE_VULKAN=0)
    
    # Check for partial components
    if(VULKAN_HEADERS_FOUND AND NOT VULKAN_LOADER_FOUND)
        message(STATUS "Vulkan headers available but loader missing")
        target_include_directories(simplehttpserver PRIVATE ${VULKAN_HEADERS_DIR})
        
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== VULKAN VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "Vulkan: Headers available but loader missing"
            COMMENT "Partial Vulkan support"
        )
        
    elseif(VULKAN_LOADER_FOUND AND NOT VULKAN_HEADERS_FOUND)
        message(STATUS "Vulkan loader available but headers missing")
        target_link_libraries(simplehttpserver PRIVATE ${VULKAN_LIBRARY})
        
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== VULKAN VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "Vulkan: Loader available but headers missing"
            COMMENT "Partial Vulkan support"
        )
        
    else()
        add_custom_command(TARGET simplehttpserver POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "=== VULKAN VERIFICATION ==="
            COMMAND ${CMAKE_COMMAND} -E echo "Vulkan: Not available"
            COMMENT "No Vulkan support"
        )
    endif()
endif()

# Update configuration summary
message(STATUS "=== VULKAN SUPPORT SUMMARY ===")
message(STATUS "Vulkan Support: ${VULKAN_FOUND}")
if(VULKAN_HEADERS_FOUND)
    message(STATUS "  headers: ${VULKAN_HEADERS_DIR}")
endif()
if(VULKAN_LOADER_FOUND)
    message(STATUS "  loader: ${VULKAN_LIBRARY}")
endif()
if(NOT VULKAN_FOUND)
    message(STATUS "  status: Building without Vulkan support")
endif()

# Add verification step for glmark2
if(GLMARK2_FOUND)
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== GLMARK2 VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "glmark2: Available (${GLMARK2_EXECUTABLE})"
        COMMENT "glmark2 availability verification"
    )
else()
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== GLMARK2 VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "glmark2: Not available - OpenGL benchmarking tool missing"
        COMMENT "glmark2 not available"
    )
endif()

# Update configuration summary
message(STATUS "glmark2 Support: ${GLMARK2_FOUND}")
if(GLMARK2_FOUND)
    message(STATUS "  executable: ${GLMARK2_EXECUTABLE}")
else()
    message(STATUS "  status: OpenGL benchmarking tool not available")
endif()

# Link against SQLite3 if available
if(SQLITE3_FOUND)
    target_link_libraries(simplehttpserver PRIVATE ${SQLITE3_LIBRARY})
    target_include_directories(simplehttpserver PRIVATE ${SQLITE3_INCLUDE_DIR})
    
    # Add verification step
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== SQLITE3 VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "SQLite3: Available"
        COMMAND ${CMAKE_COMMAND} -E echo "  library: ${SQLITE3_LIBRARY}"
        COMMENT "SQLite3 availability verification"
    )
else()
    add_custom_command(TARGET simplehttpserver POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "=== SQLITE3 VERIFICATION ==="
        COMMAND ${CMAKE_COMMAND} -E echo "SQLite3: Not available - database support disabled"
        COMMENT "SQLite3 not available"
    )
endif()

# Update configuration summary
message(STATUS "=== SQLITE3 SUPPORT SUMMARY ===")
message(STATUS "SQLite3 Support: ${SQLITE3_FOUND}")
if(SQLITE3_FOUND)
    message(STATUS "  library: ${SQLITE3_LIBRARY}")
    message(STATUS "  headers: ${SQLITE3_INCLUDE_DIR}")
    
    # Show which features are available (only for custom build)
    if(SQLITE3_LIBRARY MATCHES "/lilyspark/opt/lib/database/")
        message(STATUS "  features: Column Metadata, FTS3/4/5, JSON1, RTree, DBSTAT, Secure Delete, URI, Unlock Notify, ZLIB")
    endif()
else()
    message(STATUS "  status: Building without database support")
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
