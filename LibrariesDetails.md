# Stage: base deps (Alpine version)
- Pre-Fetching Of Alpine Start Libraries:
llvm16-dev, llvm16-libs, clang16

- LLVM Path details:
ENV PATH=/usr/lib/llvm16/bin:${PATH}
ENV LLVM_CONFIG=/usr/lib/llvm16/bin/llvm-config
ENV LD_LIBRARY_PATH=/usr/lib/llvm16/lib:/usr/local/lib:/usr/lib

- Apline Start Libraries
bash, ca-certificates, git, build-base, linux-headers, musl-dev
cmake, ninja, pkgconf, python3, py3-pip

- Third-Party Start Libraries:
libpcap-dev, readline-dev, openssl-dev, bzip2-dev                           (SQLite3)
vulkan-headers, vulkan-loader, vulkan-tools, freetype-dev, fontconfig-dev   (VulkanSDK)
libxcomposite-dev, libxinerama-dev, libxi-dev, libxcursor-dev               (X11)
libxrandr-dev, libxshmfence-dev, libxxf86vm-dev                             (X11)
alsa-lib-dev, pulseaudio-dev                                                (Audio - Generic)
bsd-compat-headers, xf86-video-fbdev, xf86-video-dummy                      (Misc - Generic)
glslang, net-tools, iproute2                                                (Misc - Generic)

- Glibc details (specific requirements listed):
APK (Library): glibc                                                        (Version: 2.35-r1)
APK (Library): glibc-bin                                                    (Version: 2.35-r1)
APK (Library): glibc-dev                                                    (Version: 2.35-r1)
    Wrapper details about glibc (paths used for location of it's ldconfig):
/usr/glibc-compat/sbin/ldconfig 
/usr/glibc-compat/sbin/ldconfig.real

# Stage: build core libraries
- Build Dependencies:
m4, bison, flex, zlib-dev, expat-dev, ncurses-dev, libx11-dev

- Third-Party Build Libraries:
xf86driproto, xf86vidmodeproto, glproto, dri2proto, libxext-dev             (X11)
libxrender-dev, libxfixes-dev, libxdamage-dev, libxcb-dev                   (X11)
autoconf, automake, libtool, util-macros, pkgconf-dev, xorg-util-macros     (xorg-server)
libpciaccess-dev, libepoxy-dev, pixman-dev, xkeyboard-config                (xorg-server)
xkbcomp, libxkbfile-dev, libxfont2-dev                                      (xorg-server)

- PCIACCESS Build-From-Source Details:
Directory Created         : /usr/local/bin
CFLAGS (Location)         : /usr/lib/llvm16/include
CXXFLAGS (Locaion)        : /usr/lib/llvm16/include
LDFLAGS (Location)        : /usr/lib/llvm16/lib
PKG_CONFIG_PATH (Location): /usr/local/lib/pkgconfig

- XORG-SERVER-DEV Build-From-Source Details:

- Additional Third-Party Build Libraries:
wayland-dev, wayland-protocols, python3-dev, py3-setuptools,                (General - Wayland)
jpeg-dev, libpng-dev, libxkbcommon-dev                                      (General APKs)
tiff-dev, libwebp-dev, libavif-dev                                          (SDL3_Image)
libpcap-dev,  v4l-utils-dev                                                 (General - Media)
strace, file, tree                                                          (Debug)

- Python Dependency Details
APK: meson                                                                  (Version: 1.4.0)
APK: mako                                                                   (Version 1.3.3)

- SPIRV-Tools Build-From-Source Details:

- shaderc Build-From-Source Details:

- Additional Third-Party Build Libraries:


