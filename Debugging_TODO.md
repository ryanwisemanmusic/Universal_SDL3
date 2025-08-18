
libdrm problems:
#67 7.054 ninja: subcommand failed
#67 7.054 INFO: autodetecting backend as ninja
#67 7.054 INFO: calculating backend command to run: /usr/bin/ninja -C /build/libdrm/builddir -j 12 -v
#67 7.142 ninja: entering directory '/build/libdrm/builddir'
#67 7.165 [1/13] Compiling C object intel/libdrm_intel.so.1.125.0.p/intel_bufmgr.c.o
#67 7.165 [2/13] Compiling C object libdrm.so.2.125.0.p/xf86drm.c.o
#67 7.165 ninja: job failed: clang-16 -Iintel/libdrm_intel.so.1.125.0.p -Iintel -I../intel -I. -I.. -I../include/drm -I/usr/local/include -I/usr/lib/llvm16/include -fvisibility=hidden -fcolor-diagnostics -D_FILE_OFFSET_BITS=64 -Wall -Winvalid-pch -std=c11 -O3 -include /build/libdrm/builddir/config.h -march=armv8-a -Wno-deprecated-declarations -fPIC -pthread -Wsign-compare -Werror=undef -Werror=implicit-function-declaration -Wpointer-arith -Wwrite-strings -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wnested-externs -Wpacked -Wswitch-enum -Wmissing-format-attribute -Wstrict-aliasing=2 -Winit-self -Winline -Wshadow -Wdeclaration-after-statement -Wold-style-definition -Wno-unused-parameter -Wno-attributes -Wno-long-long -Wno-missing-field-initializers -MD -MQ intel/libdrm_intel.so.1.125.0.p/intel_bufmgr.c.o -MF intel/libdrm_intel.so.1.125.0.p/intel_bufmgr.c.o.d -o intel/libdrm_intel.so.1.125.0.p/intel_bufmgr.c.o -c ../intel/intel_bufmgr.c
#67 7.494 ../intel/intel_bufmgr.c:36:10: fatal error: 'pciaccess.h' file not found

#67 7.498 === PKG-CONFIG COMPREHENSIVE TESTING ===
#67 7.498 Testing pkg-config with PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib/llvm16/lib/pkgconfig:/usr/lib/pkgconfig
#67 7.498 Available packages containing 'drm':
#67 7.505 Testing libdrm specifically:
#67 7.510 ✗ libdrm package not found in pkg-config

xorg-server related rpoblems:
#68 5.939 === CONFIGURING XORG-SERVER WITH LLVM16 EXPLICIT PATHS ===
#68 5.965 autoreconf: export WARNINGS=
#68 5.966 autoreconf: Entering directory '.'
#68 5.967 autoreconf: configure.ac: not using Gettext
#68 6.971 autoreconf: running: aclocal --force -I m4
#68 7.374 configure.ac:52: error: must install font-util 1.1 or later before running autoconf/autogen
#68 7.374 configure.ac:52: the top level
#68 7.374 autom4te: error: /usr/bin/m4 failed with exit status: 1
#68 7.376 aclocal: error: /usr/bin/autom4te failed with exit status: 1
#68 7.380 autoreconf: error: aclocal failed with exit status: 1