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

#
#
#
#
#

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

#
#
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
# ==============================================
# Executable created here (DO NOT FUCKING TOUCH)
# ==============================================
add_executable(simplehttpserver
    main.cpp
)
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
