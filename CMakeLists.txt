cmake_minimum_required(VERSION 3.10)
project(simplehttpserver)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Generate compile_commands.json for IntelliSense (ONLY ADDITION)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

#
#
#

# ===============================
# Apache FOP (Build Requirements)
# ===============================
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

# ==========================
# JACK2 (Build Requirements)
# ==========================
# JACK2 Paths
find_path(JACK2_INSTALL_DIR
    NAMES bin usr/bin
    PATHS
        /lilyspark/opt/lib/audio/jack2
    NO_DEFAULT_PATH
)

find_path(JACK2_INCLUDE_DIR
    NAMES jack/jack.h
    PATHS
        /lilyspark/opt/lib/audio/jack2/usr/include
        /lilyspark/opt/lib/audio/jack2/include
        /usr/include
        /usr/local/include
    NO_DEFAULT_PATH
)

# JACK2 library
find_library(JACK2_LIBRARY
    NAMES jack libjack jack2 libjack2
    PATHS
        /lilyspark/opt/lib/audio/jack2/usr/lib
        /lilyspark/opt/lib/audio/jack2/lib
        /usr/lib
        /usr/local/lib
    NO_DEFAULT_PATH
)

# JACK2 executable
find_program(JACK2_JACKD
    NAMES jackd
    PATHS
        /lilyspark/opt/lib/audio/jack2/bin
        /lilyspark/opt/lib/audio/jack2/usr/bin
        /usr/bin
        /usr/local/bin
    NO_DEFAULT_PATH
)

find_program(JACK2_JACK_CONNECT
    NAMES jack_connect
    PATHS
        /lilyspark/opt/lib/audio/jack2/bin
        /lilyspark/opt/lib/audio/jack2/usr/bin
        /usr/bin
        /usr/local/bin
    NO_DEFAULT_PATH
)

file(GLOB FOP_JARS "/lilyspark/opt/lib/java/fop/lib/*.jar")

# ======================
# PlutoSVG (Build Requirements)
# ======================
find_path(PLUTOSVG_INCLUDE_DIR
    NAMES plutosvg.h
    PATHS /lilyspark/opt/lib/graphics/usr/include
    NO_DEFAULT_PATH
)

find_library(PLUTOSVG_LIBRARY
    NAMES plutosvg
    PATHS /lilyspark/opt/lib/graphics/usr/lib
    NO_DEFAULT_PATH
)

file(GLOB PLUTOSVG_FILES "/lilyspark/opt/lib/graphics/usr/lib/*plutosvg*")

# ======================
# pciaccess (Build Requirements)
# ======================
find_path(PCIACCESS_INCLUDE_DIR
    NAMES pciaccess.h
    PATHS /lilyspark/opt/lib/sys/usr/include
    NO_DEFAULT_PATH
)

find_library(PCIACCESS_LIBRARY
    NAMES pciaccess
    PATHS /lilyspark/opt/lib/sys/usr/lib
    NO_DEFAULT_PATH
)

file(GLOB PCIACCESS_PKGCONFIG "/lilyspark/opt/lib/sys/usr/lib/pkgconfig/pciaccess.pc")

# ===========================
# libdrm (Build Requirements)
# ===========================
find_path(LIBDRM_INCLUDE_DIR
    NAMES drm.h
    PATHS /lilyspark/opt/lib/sys/usr/include
    NO_DEFAULT_PATH
)

find_library(LIBDRM_LIBRARY
    NAMES drm
    PATHS /lilyspark/opt/lib/sys/usr/lib
    NO_DEFAULT_PATH
)

file(GLOB LIBDRM_PKGCONFIG "/lilyspark/opt/lib/sys/usr/lib/pkgconfig/libdrm.pc")

# =============================
# libepoxy (Build Requirements)
# =============================
find_path(LIBEPOXY_INCLUDE_DIR
    NAMES epoxy/gl.h
    PATHS /lilyspark/opt/lib/sys/usr/include
    NO_DEFAULT_PATH
)

find_library(LIBEPOXY_LIBRARY
    NAMES epoxy
    PATHS /lilyspark/opt/lib/sys/usr/lib
    NO_DEFAULT_PATH
)

file(GLOB LIBEPOXY_PKGCONFIG "/lilyspark/opt/lib/sys/usr/lib/pkgconfig/epoxy.pc")

# ==========================================
# SDL3 Image Dependency (Build Requirements)
# ==========================================
find_library(LIBTIFF_LIBRARY
    NAMES tiff
    PATHS /lilyspark/opt/lib/sdl3/lib
    NO_DEFAULT_PATH
)
find_library(LIBWEBP_LIBRARY
    NAMES webp
    PATHS /lilyspark/opt/lib/sdl3/lib
    NO_DEFAULT_PATH
)
find_library(LIBAVIF_LIBRARY
    NAMES avif
    PATHS /lilyspark/opt/lib/sdl3/lib
    NO_DEFAULT_PATH
)

find_path(LIBTIFF_INCLUDE_DIR
    NAMES tiffio.h
    PATHS /lilyspark/opt/lib/sdl3/include
    NO_DEFAULT_PATH
)
find_path(LIBWEBP_INCLUDE_DIR
    NAMES webp/encode.h
    PATHS /lilyspark/opt/lib/sdl3/include
    NO_DEFAULT_PATH
)
find_path(LIBAVIF_INCLUDE_DIR
    NAMES avif/avif.h
    PATHS /lilyspark/opt/lib/sdl3/include
    NO_DEFAULT_PATH
)

# ================================================
# Python Package Dependencies (Build Requirements)
# ================================================
find_path(PYTHON_MESONBUILD_DIR
    NAMES mesonbuild
    PATHS /lilyspark/opt/lib/python/site-packages
    NO_DEFAULT_PATH
)
find_path(PYTHON_MAKO_DIR
    NAMES mako
    PATHS /lilyspark/opt/lib/python/site-packages
    NO_DEFAULT_PATH
)
find_path(PYTHON_MARKUPSAFE_DIR
    NAMES MarkupSafe
    PATHS /lilyspark/opt/lib/python/site-packages
    NO_DEFAULT_PATH
)

# ================================
# SPIRV-Tools (Build Requirements)
# ================================
find_path(SPIRV_HEADERS_DIR
    NAMES spirv.h
    PATHS /lilyspark/opt/lib/graphics/include/spirv-tools
    NO_DEFAULT_PATH
)
find_library(SPIRV_TOOLS_LIB
    NAMES SPIRV-Tools
    PATHS /lilyspark/opt/lib/graphics/lib
    NO_DEFAULT_PATH
)
find_program(SPIRV_TOOLS_BIN
    NAMES spirv-as spirv-opt
    PATHS /lilyspark/opt/lib/graphics/bin
    NO_DEFAULT_PATH
)

# ============================
# Shaderc (Build Requirements)
# ============================
find_path(SHADERC_INCLUDE_DIR
    NAMES shaderc/shaderc.h
    PATHS /lilyspark/opt/lib/graphics/include
    NO_DEFAULT_PATH
)
find_library(SHADERC_LIB
    NAMES shaderc
    PATHS /lilyspark/opt/lib/graphics/lib
    NO_DEFAULT_PATH
)
find_program(SHADERC_BIN
    NAMES shaderc
    PATHS /lilyspark/opt/lib/graphics/bin
    NO_DEFAULT_PATH
)

# ===========================
# libgbm (Build Requirements)
# ===========================
find_path(LIBGBM_INCLUDE_DIR
    NAMES gbm.h
    PATHS /lilyspark/opt/lib/sys/include
    NO_DEFAULT_PATH
)
find_library(LIBGBM_LIB
    NAMES gbm
    PATHS /lilyspark/opt/lib/sys/lib
    NO_DEFAULT_PATH
)

# ===========================================
# GStreamer Plugins Base (Build Requirements)
# ===========================================
find_path(GST_BASE_INCLUDE_DIR
    NAMES gst/gst.h
    PATHS /lilyspark/opt/lib/media/include
    NO_DEFAULT_PATH
)
find_library(GST_BASE_LIB
    NAMES gstreamer-1.0
    PATHS /lilyspark/opt/lib/media/lib
    NO_DEFAULT_PATH
)
find_program(GST_BIN
    NAMES gst-launch-1.0 gst-inspect-1.0
    PATHS /lilyspark/opt/lib/media/bin
    NO_DEFAULT_PATH
)

# ================================
# xorg-server (Build Requirements)
# ================================
find_path(XORG_INCLUDE_DIR
    NAMES X.h
    PATHS /lilyspark/usr/x11/include
    NO_DEFAULT_PATH
)
find_library(XORG_LIB
    NAMES xserver
    PATHS /lilyspark/usr/x11
    NO_DEFAULT_PATH
)
find_program(XORG_BIN
    NAMES Xorg Xvfb Xnest Xephyr
    PATHS /lilyspark/usr/x11
    NO_DEFAULT_PATH
)

# ========================================
# MESA Core Libraries (Build Requirements)
# ========================================
find_path(MESA_INCLUDE_DIR
    NAMES mesa_glu.h
    PATHS /lilyspark/opt/lib/driver/include /lilyspark/usr/include
    NO_DEFAULT_PATH
)
find_library(MESA_LIB
    NAMES GL swrast osmesa
    PATHS /lilyspark/opt/lib/driver /lilyspark/usr/lib
    NO_DEFAULT_PATH
)

# ========================
# GBM (Build Requirements)
# ========================
find_path(GBM_INCLUDE_DIR
    NAMES gbm.h
    PATHS /lilyspark/opt/lib/driver/include
    NO_DEFAULT_PATH
)
find_library(GBM_LIB
    NAMES gbm
    PATHS /lilyspark/opt/lib/driver/lib
    NO_DEFAULT_PATH
)

# ========================
# EGL (Build Requirements)
# ========================
find_path(EGL_INCLUDE_DIR
    NAMES EGL/egl.h
    PATHS /lilyspark/opt/lib/driver/include
    NO_DEFAULT_PATH
)
find_library(EGL_LIB
    NAMES EGL
    PATHS /lilyspark/opt/lib/driver/lib
    NO_DEFAULT_PATH
)

# =========================
# GLES (Build Requirements)
# =========================
find_path(GLES_INCLUDE_DIR
    NAMES GLES2/gl2.h
    PATHS /lilyspark/opt/lib/driver/include
    NO_DEFAULT_PATH
)
find_library(GLES_LIB
    NAMES GLESv1_CM GLESv2
    PATHS /lilyspark/opt/lib/driver/lib
    NO_DEFAULT_PATH
)

# ==============================
# SDL3 Core (Build Requirements)
# ==============================
find_path(SDL3_INCLUDE_DIR
    NAMES SDL3.h
    PATHS /lilyspark/opt/lib/sdl3/usr/media/include
    NO_DEFAULT_PATH
)
find_library(SDL3_LIB
    NAMES SDL3
    PATHS /lilyspark/opt/lib/sdl3/usr/media/lib
    NO_DEFAULT_PATH
)

# ===============================
# SDL3_image (Build Requirements)
# ===============================
find_path(SDL3_IMAGE_INCLUDE_DIR
    NAMES SDL_image.h
    PATHS /lilyspark/opt/lib/sdl3/usr/media/include
    NO_DEFAULT_PATH
)
find_library(SDL3_IMAGE_LIB
    NAMES SDL3_image
    PATHS /lilyspark/opt/lib/sdl3/usr/media/lib
    NO_DEFAULT_PATH
)

# ===============================
# SDL3_mixer (Build Requirements)
# ===============================
find_path(SDL3_MIXER_INCLUDE_DIR
    NAMES SDL_mixer.h
    PATHS /lilyspark/opt/lib/sdl3/usr/media/include
    NO_DEFAULT_PATH
)
find_library(SDL3_MIXER_LIB
    NAMES SDL3_mixer
    PATHS /lilyspark/opt/lib/sdl3/usr/media/lib
    NO_DEFAULT_PATH
)

# =============================
# SDL3_ttf (Build Requirements)
# =============================
find_path(SDL3_TTF_INCLUDE_DIR
    NAMES SDL_ttf.h
    PATHS /lilyspark/opt/lib/sdl3/usr/media/include
    NO_DEFAULT_PATH
)
find_library(SDL3_TTF_LIB
    NAMES SDL3_ttf
    PATHS /lilyspark/opt/lib/sdl3/usr/media/lib
    NO_DEFAULT_PATH
)

# ===================================
# Vulkan-Headers (Build Requirements)
# ===================================
find_path(VULKAN_HEADERS_INCLUDE_DIR
    NAMES vulkan/vulkan.h
    PATHS /lilyspark/opt/lib/vulkan/include
    NO_DEFAULT_PATH
)

# ==================================
# Vulkan-Loader (Build Requirements)
# ==================================
find_library(VULKAN_LOADER_LIB
    NAMES vulkan
    PATHS /lilyspark/opt/lib/vulkan/lib
    NO_DEFAULT_PATH
)

# ============================
# glmark2 (Build Requirements)
# ============================
find_program(GLMARK2_BIN
    NAMES glmark2
    PATHS /lilyspark/opt/lib/graphics/bin
    NO_DEFAULT_PATH
)

# ============================
# SQLite3 (Build Requirements)
# ============================
find_path(SQLITE3_INCLUDE_DIR
    NAMES sqlite3.h
    PATHS /lilyspark/opt/lib/database/include
    NO_DEFAULT_PATH
)
find_library(SQLITE3_LIB
    NAMES sqlite3
    PATHS /lilyspark/opt/lib/database/lib
    NO_DEFAULT_PATH
)

#
#
#
# ============
# Falback code
# ============
#
#
#

# ===========================
# Apache FOP (Fallback Logic)
# ===========================
if(JAVA_EXECUTABLE AND FOP_JARS)
    execute_process(
        COMMAND ${JAVA_EXECUTABLE} -cp "/lilyspark/opt/lib/java/fop/lib/*" org.apache.fop.cli.Main -version
        RESULT_VARIABLE FOP_TEST_RESULT
        OUTPUT_VARIABLE FOP_VERSION_OUTPUT
        ERROR_QUIET
    )
endif()

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

# ===========================
# JACK2 (Fallback Logic)
# ===========================
# Create fallback status based on what was found
if(JACK2_INCLUDE_DIR AND JACK2_LIBRARY AND JACK2_JACKD AND JACK2_TEST_RESULT EQUAL 0)
    set(JACK2_FOUND TRUE)
    message(STATUS "✓ JACK2 Audio found and functional")
    message(STATUS "  Headers: ${JACK2_INCLUDE_DIR}")
    message(STATUS "  Library: ${JACK2_LIBRARY}")
    message(STATUS "  JACKD: ${JACK2_JACKD}")
    message(STATUS "  Version: ${JACK2_VERSION_OUTPUT}")
    add_compile_definitions(HAVE_JACK2=1)
    add_compile_definitions(JACK2_JACKD_PATH="${JACK2_JACKD}")
    
elseif(JACK2_INCLUDE_DIR AND JACK2_LIBRARY)
    set(JACK2_FOUND PARTIAL)
    message(WARNING "⚠ JACK2 headers and library found but daemon issues")
    message(STATUS "  Headers: ${JACK2_INCLUDE_DIR}")
    message(STATUS "  Library: ${JACK2_LIBRARY}")
    add_compile_definitions(HAVE_JACK2_LIB=1)
    
elseif(JACK2_INCLUDE_DIR)
    set(JACK2_FOUND HEADERS_ONLY)
    message(STATUS "ℹ JACK2 headers found but library missing")
    message(STATUS "  Headers: ${JACK2_INCLUDE_DIR}")
    add_compile_definitions(HAVE_JACK2_HEADERS=1)
    
elseif(JACK2_JACKD)
    set(JACK2_FOUND DAEMON_ONLY)
    message(STATUS "ℹ JACK2 daemon found but no development files")
    message(STATUS "  JACKD: ${JACK2_JACKD}")
    add_compile_definitions(HAVE_JACK2_DAEMON=1)
    add_compile_definitions(JACK2_JACKD_PATH="${JACK2_JACKD}")
    
else()
    set(JACK2_FOUND FALSE)
    message(STATUS "ℹ JACK2 not found - building without audio server support")
    add_compile_definitions(HAVE_JACK2=0)
endif()

# ======================
# PlutoSVG (Fallback Logic)
# ======================
if(PLUTOSVG_INCLUDE_DIR AND PLUTOSVG_LIBRARY)
    set(PLUTOSVG_FOUND TRUE)
    message(STATUS "✓ PlutoSVG found and usable")
    message(STATUS "  Headers: ${PLUTOSVG_INCLUDE_DIR}")
    message(STATUS "  Library: ${PLUTOSVG_LIBRARY}")
    add_compile_definitions(HAVE_PLUTOSVG=1)
elseif(PLUTOSVG_INCLUDE_DIR)
    set(PLUTOSVG_FOUND HEADERS_ONLY)
    message(WARNING "⚠ PlutoSVG headers found but library missing")
    message(STATUS "  Headers: ${PLUTOSVG_INCLUDE_DIR}")
    add_compile_definitions(HAVE_PLUTOSVG_HEADERS=1)
else()
    set(PLUTOSVG_FOUND FALSE)
    message(STATUS "ℹ PlutoSVG not found - building without graphics support")
    add_compile_definitions(HAVE_PLUTOSVG=0)
endif()

# ======================
# pciaccess (Fallback Logic)
# ======================
if(PCIACCESS_INCLUDE_DIR AND PCIACCESS_LIBRARY)
    set(PCIACCESS_FOUND TRUE)
    message(STATUS "✓ pciaccess found and usable")
    message(STATUS "  Headers: ${PCIACCESS_INCLUDE_DIR}")
    message(STATUS "  Library: ${PCIACCESS_LIBRARY}")
    add_compile_definitions(HAVE_PCIACCESS=1)
elseif(PCIACCESS_INCLUDE_DIR)
    set(PCIACCESS_FOUND HEADERS_ONLY)
    message(WARNING "⚠ pciaccess headers found but library missing")
    message(STATUS "  Headers: ${PCIACCESS_INCLUDE_DIR}")
    add_compile_definitions(HAVE_PCIACCESS_HEADERS=1)
else()
    set(PCIACCESS_FOUND FALSE)
    message(STATUS "ℹ pciaccess not found - building without PCI support")
    add_compile_definitions(HAVE_PCIACCESS=0)
endif()

# ===========================
# libdrm (Fallback Logic)
# ===========================
if(LIBDRM_INCLUDE_DIR AND LIBDRM_LIBRARY)
    set(LIBDRM_FOUND TRUE)
    message(STATUS "✓ libdrm found and usable")
    message(STATUS "  Headers: ${LIBDRM_INCLUDE_DIR}")
    message(STATUS "  Library: ${LIBDRM_LIBRARY}")
    add_compile_definitions(HAVE_LIBDRM=1)
elseif(LIBDRM_INCLUDE_DIR)
    set(LIBDRM_FOUND HEADERS_ONLY)
    message(WARNING "⚠ libdrm headers found but library missing")
    message(STATUS "  Headers: ${LIBDRM_INCLUDE_DIR}")
    add_compile_definitions(HAVE_LIBDRM_HEADERS=1)
else()
    set(LIBDRM_FOUND FALSE)
    message(STATUS "ℹ libdrm not found - building without DRM support")
    add_compile_definitions(HAVE_LIBDRM=0)
endif()

# =============================
# libepoxy (Fallback Logic)
# =============================
if(LIBEPOXY_INCLUDE_DIR AND LIBEPOXY_LIBRARY)
    set(LIBEPOXY_FOUND TRUE)
    message(STATUS "✓ libepoxy found and usable")
    message(STATUS "  Headers: ${LIBEPOXY_INCLUDE_DIR}")
    message(STATUS "  Library: ${LIBEPOXY_LIBRARY}")
    add_compile_definitions(HAVE_LIBEPOXY=1)
elseif(LIBEPOXY_INCLUDE_DIR)
    set(LIBEPOXY_FOUND HEADERS_ONLY)
    message(WARNING "⚠ libepoxy headers found but library missing")
    message(STATUS "  Headers: ${LIBEPOXY_INCLUDE_DIR}")
    add_compile_definitions(HAVE_LIBEPOXY_HEADERS=1)
else()
    set(LIBEPOXY_FOUND FALSE)
    message(STATUS "ℹ libepoxy not found - building without OpenGL support")
    add_compile_definitions(HAVE_LIBEPOXY=0)
endif()

# ==========================================
# SDL3 Image Dependency (Fallback Logic)
# ==========================================
if(LIBTIFF_LIBRARY AND LIBTIFF_INCLUDE_DIR AND
   LIBWEBP_LIBRARY AND LIBWEBP_INCLUDE_DIR AND
   LIBAVIF_LIBRARY AND LIBAVIF_INCLUDE_DIR)
    set(SDL3_IMAGE_FOUND TRUE)
    message(STATUS "✓ SDL3 Image libraries found and usable")
    add_compile_definitions(HAVE_SDL3_IMAGE=1)
else()
    set(SDL3_IMAGE_FOUND FALSE)
    message(WARNING "⚠ Some SDL3 image dependencies missing")
    add_compile_definitions(HAVE_SDL3_IMAGE=0)
endif()

# ================================================
# Python Package Dependencies (Fallback Logic)
# ================================================
if(PYTHON_MESONBUILD_DIR AND PYTHON_MAKO_DIR AND PYTHON_MARKUPSAFE_DIR)
    set(PYTHON_PACKAGES_FOUND TRUE)
    message(STATUS "✓ Python packages (mesonbuild, mako, MarkupSafe) found")
    add_compile_definitions(HAVE_PYTHON_PACKAGES=1)
else()
    set(PYTHON_PACKAGES_FOUND FALSE)
    message(WARNING "⚠ Some Python packages missing in custom filesystem")
    add_compile_definitions(HAVE_PYTHON_PACKAGES=0)
endif()

# ================================
# SPIRV-Tools (Fallback Logic)
# ================================
if(SPIRV_HEADERS_DIR AND SPIRV_TOOLS_LIB AND SPIRV_TOOLS_BIN)
    set(SPIRV_TOOLS_FOUND TRUE)
    message(STATUS "✓ SPIRV-Tools headers, libraries, and binaries found")
    add_compile_definitions(HAVE_SPIRV_TOOLS=1)
else()
    set(SPIRV_TOOLS_FOUND FALSE)
    message(WARNING "⚠ SPIRV-Tools components missing")
    add_compile_definitions(HAVE_SPIRV_TOOLS=0)
endif()

# ============================
# Shaderc (Fallback Logic)
# ============================
if(SHADERC_INCLUDE_DIR AND SHADERC_LIB AND SHADERC_BIN)
    set(SHADERC_FOUND TRUE)
    message(STATUS "✓ Shaderc headers, library, and binary found")
    add_compile_definitions(HAVE_SHADERC=1)
else()
    set(SHADERC_FOUND FALSE)
    message(WARNING "⚠ Shaderc components missing")
    add_compile_definitions(HAVE_SHADERC=0)
endif()

# ===========================
# libgbm (Fallback Logic)
# ===========================
if(LIBGBM_INCLUDE_DIR AND LIBGBM_LIB)
    set(LIBGBM_FOUND TRUE)
    message(STATUS "✓ libgbm headers and library found")
    add_compile_definitions(HAVE_LIBGBM=1)
else()
    set(LIBGBM_FOUND FALSE)
    message(WARNING "⚠ libgbm components missing")
    add_compile_definitions(HAVE_LIBGBM=0)
endif()

# ===========================================
# GStreamer Plugins Base (Fallback Logic)
# ===========================================
if(GST_BASE_INCLUDE_DIR AND GST_BASE_LIB AND GST_BIN)
    set(GST_BASE_FOUND TRUE)
    message(STATUS "✓ GStreamer Base headers, library, and binaries found")
    add_compile_definitions(HAVE_GST_BASE=1)
else()
    set(GST_BASE_FOUND FALSE)
    message(WARNING "⚠ GStreamer Base components missing")
    add_compile_definitions(HAVE_GST_BASE=0)
endif()

# ================================
# xorg-server (Fallback Logic)
# ================================
if(XORG_INCLUDE_DIR AND XORG_LIB AND XORG_BIN)
    set(XORG_FOUND TRUE)
    message(STATUS "✓ xorg-server headers, libraries, and binaries found")
    add_compile_definitions(HAVE_XORG=1)
else()
    set(XORG_FOUND FALSE)
    message(WARNING "⚠ xorg-server components missing")
    add_compile_definitions(HAVE_XORG=0)
endif()

# ====================================
# MESA Core Libraries (Fallback Logic)
# ====================================
if(MESA_INCLUDE_DIR AND MESA_LIB)
    set(MESA_FOUND TRUE)
    message(STATUS "✓ Mesa headers and libraries found")
    add_compile_definitions(HAVE_MESA=1)
else()
    set(MESA_FOUND FALSE)
    message(WARNING "⚠ Mesa components missing")
    add_compile_definitions(HAVE_MESA=0)
endif()

# ========================
# GBM (Fallback Logic)
# ========================
if(GBM_INCLUDE_DIR AND GBM_LIB)
    set(GBM_FOUND TRUE)
    message(STATUS "✓ GBM headers and library found")
    add_compile_definitions(HAVE_GBM=1)
else()
    set(GBM_FOUND FALSE)
    message(WARNING "⚠ GBM components missing")
    add_compile_definitions(HAVE_GBM=0)
endif()

# ========================
# EGL (Fallback Logic)
# ========================
if(EGL_INCLUDE_DIR AND EGL_LIB)
    set(EGL_FOUND TRUE)
    message(STATUS "✓ EGL headers and library found")
    add_compile_definitions(HAVE_EGL=1)
else()
    set(EGL_FOUND FALSE)
    message(WARNING "⚠ EGL components missing")
    add_compile_definitions(HAVE_EGL=0)
endif()

# =========================
# GLES (Fallback Logic)
# =========================
if(GLES_INCLUDE_DIR AND GLES_LIB)
    set(GLES_FOUND TRUE)
    message(STATUS "✓ GLES headers and libraries found")
    add_compile_definitions(HAVE_GLES=1)
else()
    set(GLES_FOUND FALSE)
    message(WARNING "⚠ GLES components missing")
    add_compile_definitions(HAVE_GLES=0)
endif()

# ==============================
# SDL3 Core (Fallback Logic)
# ==============================
if(SDL3_INCLUDE_DIR AND SDL3_LIB)
    set(SDL3_FOUND TRUE)
    message(STATUS "✓ SDL3 headers and library found")
    add_compile_definitions(HAVE_SDL3=1)
else()
    set(SDL3_FOUND FALSE)
    message(WARNING "⚠ SDL3 not found")
    add_compile_definitions(HAVE_SDL3=0)
endif()

# ===============================
# SDL3_image (Fallback Logic)
# ===============================
if(SDL3_IMAGE_INCLUDE_DIR AND SDL3_IMAGE_LIB)
    set(SDL3_IMAGE_FOUND TRUE)
    message(STATUS "✓ SDL3_image headers and library found")
    add_compile_definitions(HAVE_SDL3_IMAGE=1)
else()
    set(SDL3_IMAGE_FOUND FALSE)
    message(WARNING "⚠ SDL3_image not found")
    add_compile_definitions(HAVE_SDL3_IMAGE=0)
endif()

# ===============================
# SDL3_mixer (Fallback Logic)
# ===============================
if(SDL3_MIXER_INCLUDE_DIR AND SDL3_MIXER_LIB)
    set(SDL3_MIXER_FOUND TRUE)
    message(STATUS "✓ SDL3_mixer headers and library found")
    add_compile_definitions(HAVE_SDL3_MIXER=1)
else()
    set(SDL3_MIXER_FOUND FALSE)
    message(WARNING "⚠ SDL3_mixer not found")
    add_compile_definitions(HAVE_SDL3_MIXER=0)
endif()

# =============================
# SDL3_ttf (Fallback Logic)
# =============================
if(SDL3_TTF_INCLUDE_DIR AND SDL3_TTF_LIB)
    set(SDL3_TTF_FOUND TRUE)
    message(STATUS "✓ SDL3_ttf headers and library found")
    add_compile_definitions(HAVE_SDL3_TTF=1)
else()
    set(SDL3_TTF_FOUND FALSE)
    message(WARNING "⚠ SDL3_ttf not found")
    add_compile_definitions(HAVE_SDL3_TTF=0)
endif()

# ===================================
# Vulkan-Headers (Fallback Logic)
# ===================================
if(VULKAN_HEADERS_INCLUDE_DIR)
    set(VULKAN_HEADERS_FOUND TRUE)
    message(STATUS "✓ Vulkan-Headers found")
    add_compile_definitions(HAVE_VULKAN_HEADERS=1)
else()
    set(VULKAN_HEADERS_FOUND FALSE)
    message(WARNING "⚠ Vulkan-Headers not found")
    add_compile_definitions(HAVE_VULKAN_HEADERS=0)
endif()

# ==================================
# Vulkan-Loader (Fallback Logic)
# ==================================
if(VULKAN_LOADER_LIB)
    set(VULKAN_LOADER_FOUND TRUE)
    message(STATUS "✓ Vulkan-Loader found")
    add_compile_definitions(HAVE_VULKAN_LOADER=1)
else()
    set(VULKAN_LOADER_FOUND FALSE)
    message(WARNING "⚠ Vulkan-Loader not found")
    add_compile_definitions(HAVE_VULKAN_LOADER=0)
endif()

# ============================
# glmark2 (Fallback Logic)
# ============================
if(GLMARK2_BIN)
    set(GLMARK2_FOUND TRUE)
    message(STATUS "✓ glmark2 binary found")
    add_compile_definitions(HAVE_GLMARK2=1)
else()
    set(GLMARK2_FOUND FALSE)
    message(WARNING "⚠ glmark2 not found")
    add_compile_definitions(HAVE_GLMARK2=0)
endif()

# ============================
# SQLite3 (Fallback Logic)
# ============================
if(SQLITE3_INCLUDE_DIR AND SQLITE3_LIB)
    set(SQLITE3_FOUND TRUE)
    message(STATUS "✓ SQLite3 found")
    add_compile_definitions(HAVE_SQLITE3=1)
else()
    set(SQLITE3_FOUND FALSE)
    message(WARNING "⚠ SQLite3 not found")
    add_compile_definitions(HAVE_SQLITE3=0)
endif()


# ==============================================
# Executable created here (DO NOT FUCKING TOUCH)
# ==============================================
add_executable(simplehttpserver
    main.cpp
)

#
#
#
# ===============
# ENV For Runtime
# ===============
#
#
#

# ============================
# Apache FOP (ENV For Runtime)
# ============================
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

# =======================
# JACK2 (ENV For Runtime)
# =======================
# Conditional linking based on what was found
if(JACK2_FOUND STREQUAL "TRUE")
    # Full JACK2 support
    target_include_directories(simplehttpserver PRIVATE ${JACK2_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${JACK2_LIBRARY})
    message(STATUS "✓ Linking with full JACK2 audio support")
    
elseif(JACK2_FOUND STREQUAL "PARTIAL")
    # Headers and library only - no daemon
    target_include_directories(simplehttpserver PRIVATE ${JACK2_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${JACK2_LIBRARY})
    message(STATUS "⚠ Building with JACK2 library (daemon may not work)")
    
elseif(JACK2_FOUND STREQUAL "HEADERS_ONLY")
    # Headers only - no linking
    target_include_directories(simplehttpserver PRIVATE ${JACK2_INCLUDE_DIR})
    message(STATUS "ℹ Building with JACK2 headers only (no library linking)")
    
else()
    # No JACK2 - pure fallback mode
    message(STATUS "ℹ Building without JACK2 (audio fallback mode)")
endif()

# Update the feature summary section
message(STATUS "=== BUILD CONFIGURATION SUMMARY ===")
message(STATUS "Apache FOP Support: ${FOP_FOUND}")
message(STATUS "JACK2 Audio Support: ${JACK2_FOUND}")
if(JACK2_FOUND STREQUAL "TRUE" OR JACK2_FOUND STREQUAL "PARTIAL")
    message(STATUS "  Include Dir: ${JACK2_INCLUDE_DIR}")
    message(STATUS "  Library: ${JACK2_LIBRARY}")
endif()
if(JACK2_JACKD)
    message(STATUS "  JACKD Daemon: ${JACK2_JACKD}")
endif()
if(JACK2_CONNECT)
    message(STATUS "  Jack Connect: ${JACK2_JACK_CONNECT}")
endif()
message(STATUS "===================================")

# ======================
# PlutoSVG (ENV For Runtime)
# ======================
if(PLUTOSVG_FOUND STREQUAL "TRUE")
    target_include_directories(simplehttpserver PRIVATE ${PLUTOSVG_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${PLUTOSVG_LIBRARY})
    message(STATUS "✓ Linking PlutoSVG library")
elseif(PLUTOSVG_FOUND STREQUAL "HEADERS_ONLY")
    target_include_directories(simplehttpserver PRIVATE ${PLUTOSVG_INCLUDE_DIR})
    message(STATUS "ℹ Using PlutoSVG headers only (no linking)")
endif()

# ======================
# pciaccess (ENV For Runtime)
# ======================
if(PCIACCESS_FOUND STREQUAL "TRUE")
    target_include_directories(simplehttpserver PRIVATE ${PCIACCESS_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${PCIACCESS_LIBRARY})
    message(STATUS "✓ Linking pciaccess library")
elseif(PCIACCESS_FOUND STREQUAL "HEADERS_ONLY")
    target_include_directories(simplehttpserver PRIVATE ${PCIACCESS_INCLUDE_DIR})
    message(STATUS "ℹ Using pciaccess headers only (no linking)")
endif()

# ========================
# libdrm (ENV For Runtime)
# ========================
if(LIBDRM_FOUND STREQUAL "TRUE")
    target_include_directories(simplehttpserver PRIVATE ${LIBDRM_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${LIBDRM_LIBRARY})
    message(STATUS "✓ Linking libdrm library")
elseif(LIBDRM_FOUND STREQUAL "HEADERS_ONLY")
    target_include_directories(simplehttpserver PRIVATE ${LIBDRM_INCLUDE_DIR})
    message(STATUS "ℹ Using libdrm headers only (no linking)")
endif()

# =============================
# libepoxy (ENV For Runtime)
# =============================
if(LIBEPOXY_FOUND STREQUAL "TRUE")
    target_include_directories(simplehttpserver PRIVATE ${LIBEPOXY_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${LIBEPOXY_LIBRARY})
    message(STATUS "✓ Linking libepoxy library")
elseif(LIBEPOXY_FOUND STREQUAL "HEADERS_ONLY")
    target_include_directories(simplehttpserver PRIVATE ${LIBEPOXY_INCLUDE_DIR})
    message(STATUS "ℹ Using libepoxy headers only (no linking)")
endif()

# ==========================================
# SDL3 Image Dependency (ENV For Runtime)
# ==========================================
if(SDL3_IMAGE_FOUND)
    target_include_directories(simplehttpserver PRIVATE
        ${LIBTIFF_INCLUDE_DIR}
        ${LIBWEBP_INCLUDE_DIR}
        ${LIBAVIF_INCLUDE_DIR}
    )
    target_link_libraries(simplehttpserver PRIVATE
        ${LIBTIFF_LIBRARY}
        ${LIBWEBP_LIBRARY}
        ${LIBAVIF_LIBRARY}
    )
    message(STATUS "✓ Linking SDL3 image libraries")
endif()

# ================================================
# Python Package Dependencies (ENV For Runtime)
# ================================================
if(PYTHON_PACKAGES_FOUND)
    target_include_directories(simplehttpserver PRIVATE
        ${PYTHON_MESONBUILD_DIR}
        ${PYTHON_MAKO_DIR}
        ${PYTHON_MARKUPSAFE_DIR}
    )
    message(STATUS "✓ Python packages included in build")
endif()

# ================================
# SPIRV-Tools (ENV For Runtime)
# ================================
if(SPIRV_TOOLS_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${SPIRV_HEADERS_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${SPIRV_TOOLS_LIB})
    message(STATUS "✓ Linking SPIRV-Tools")
endif()

# ============================
# Shaderc (ENV For Runtime)
# ============================
if(SHADERC_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${SHADERC_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${SHADERC_LIB})
    message(STATUS "✓ Linking Shaderc")
endif()

# ===========================
# libgbm (ENV For Runtime)
# ===========================
if(LIBGBM_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${LIBGBM_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${LIBGBM_LIB})
    message(STATUS "✓ Linking libgbm")
endif()

# ===========================================
# GStreamer Plugins Base (ENV For Runtime)
# ===========================================
if(GST_BASE_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${GST_BASE_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${GST_BASE_LIB})
    message(STATUS "✓ Linking GStreamer Base")
endif()

# ================================
# xorg-server (ENV For Runtime)
# ================================
if(XORG_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${XORG_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${XORG_LIB})
    message(STATUS "✓ Linking xorg-server")
endif()

# ====================================
# MESA Core Libraries (ENV For Runtime)
# ====================================
if(MESA_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${MESA_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${MESA_LIB})
endif()

# ========================
# GBM (ENV For Runtime)
# ========================
if(GBM_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${GBM_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${GBM_LIB})
endif()

# ========================
# EGL (ENV For Runtime)
# ========================
if(EGL_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${EGL_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${EGL_LIB})
endif()

# =========================
# GLES (ENV For Runtime)
# =========================
if(GLES_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${GLES_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${GLES_LIB})
endif()

# ==============================
# SDL3 Core (ENV For Runtime)
# ==============================
if(SDL3_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${SDL3_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${SDL3_LIB})
endif()

# ===============================
# SDL3_image (ENV For Runtime)
# ===============================
if(SDL3_IMAGE_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${SDL3_IMAGE_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${SDL3_IMAGE_LIB})
endif()

# ===============================
# SDL3_mixer (ENV For Runtime)
# ===============================
if(SDL3_MIXER_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${SDL3_MIXER_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${SDL3_MIXER_LIB})
endif()

# =============================
# SDL3_ttf (ENV For Runtime)
# =============================
if(SDL3_TTF_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${SDL3_TTF_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${SDL3_TTF_LIB})
endif()

# ===================================
# Vulkan-Headers (ENV For Runtime)
# ===================================
if(VULKAN_HEADERS_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${VULKAN_HEADERS_INCLUDE_DIR})
endif()

# ==================================
# Vulkan-Loader (ENV For Runtime)
# ==================================
if(VULKAN_LOADER_FOUND)
    target_link_libraries(simplehttpserver PRIVATE ${VULKAN_LOADER_LIB})
endif()

# ============================
# SQLite3 (ENV For Runtime)
# ============================
if(SQLITE3_FOUND)
    target_include_directories(simplehttpserver PRIVATE ${SQLITE3_INCLUDE_DIR})
    target_link_libraries(simplehttpserver PRIVATE ${SQLITE3_LIB})
endif()

#
#
#
#
#
#

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
