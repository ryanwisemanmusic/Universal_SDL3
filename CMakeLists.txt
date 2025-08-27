cmake_minimum_required(VERSION 3.10)
project(simplehttpserver)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Generate compile_commands.json for IntelliSense (ONLY ADDITION)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

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
