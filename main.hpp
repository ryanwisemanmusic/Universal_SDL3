//==================================================
// Foundational Headers - General System Headers
//==================================================

//So standard headers are recognized. So long as it is C/C++ library, it
//should be loaded.
#include <assert.h>
#include <ctype.h>
#include <fcntl.h>
#include <iostream>
#include <math.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

//==================================================
// Foundational Headers - Networking Headers
//==================================================


/*
Alright, some interesting notes. Apparently even though sys is a default
library, I still need to package include??? Curious if there are a bunch
of system headers that aren't automatically included so I've commented out
anything that is contained within a system program.

Weird af that Apline Linux doesn't like automatically build with sys
networking from the start because isn't that like foundational and a 
critical problem if someone were to build a kernel with Alpine but
never substantiated sys
*/
//#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
//#include <netinet/in.h>
#include <signal.h>
//#include <sys/ioctl.h>
//#include <sys/filio.h>
//#include <sys/time.h>
//#include <sys/types.h>
//#include <sys/socket.h>
//#include <sys/stat.h>

//==================================================
// Foundational Headers - SDL (General)
//==================================================
#include <SDL3/SDL.h>
#include <SDL3/SDL_events.h>

//==================================================
// Foundational Headers - SDL (Audio/Video)
//==================================================
#include <SDL3/SDL_audio.h>
#include <SDL3/SDL_video.h>

//==================================================
// Foundational Headers - SDL (Core/Code Structure)
//==================================================
#include <SDL3/SDL_begin_code.h>
#include <SDL3/SDL_close_code.h>
#include <SDL3/SDL_process.h>
#include <SDL3/SDL_revision.h>
#include <SDL3/SDL_stdinc.h>

//==================================================
// Foundational Headers - SDL (Clipboard & Licensing)
//==================================================
#include <SDL3/SDL_clipboard.h>
#include <SDL3/SDL_copying.h>

//==================================================
// Foundational Headers - SDL (Renderer Backends)
//==================================================
#include <SDL3/SDL_egl.h>
#include <SDL3/SDL_gpu.h>
#include <SDL3/SDL_opengl.h>
#include <SDL3/SDL_metal.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_vulkan.h>

//==================================================
// Foundational Headers - SDL (Rendering Helpers)
//==================================================
#include <SDL3/SDL_blendmode.h>
#include <SDL3/SDL_camera.h>
#include <SDL3/SDL_pixels.h>
#include <SDL3/SDL_rect.h>
#include <SDL3/SDL_surface.h>

//==================================================
// Foundational Headers - SDL (OpenGL Extra Support)
//==================================================
#include <SDL3/SDL_opengles.h>
#include <SDL3/SDL_opengles2.h>
#include <SDL3/SDL_opengles2_gl2.h>
#include <SDL3/SDL_opengles2_gl2ext.h>
#include <SDL3/SDL_opengles2_gl2platform.h>
#include <SDL3/SDL_opengles2_khrplatform.h>
#include <SDL3/SDL_opengl_glext.h>

//==================================================
// Foundational Headers - SDL (System & Info)
//==================================================
#include <SDL3/SDL_assert.h>
#include <SDL3/SDL_cpuinfo.h>
#include <SDL3/SDL_hints.h>
#include <SDL3/SDL_error.h>
#include <SDL3/SDL_locale.h>
#include <SDL3/SDL_log.h>
#include <SDL3/SDL_messagebox.h>
#include <SDL3/SDL_properties.h>
#include <SDL3/SDL_system.h>
#include <SDL3/SDL_version.h>

//==================================================
// Foundational Headers - SDL (File & I/O)
//==================================================
#include <SDL3/SDL_asyncio.h>
#include <SDL3/SDL_filesystem.h>
#include <SDL3/SDL_iostream.h>
#include <SDL3/SDL_storage.h>

//==================================================
// Foundational Headers - SDL (Input Devices)
//==================================================
#include <SDL3/SDL_gamepad.h>
#include <SDL3/SDL_guid.h>
#include <SDL3/SDL_haptic.h>
#include <SDL3/SDL_hidapi.h>
#include <SDL3/SDL_joystick.h>
#include <SDL3/SDL_keyboard.h>
#include <SDL3/SDL_keycode.h>
#include <SDL3/SDL_mouse.h>
#include <SDL3/SDL_pen.h>
#include <SDL3/SDL_scancode.h>
#include <SDL3/SDL_touch.h>

//==================================================
// Foundational Headers - SDL (Hardware Access)
//==================================================
#include <SDL3/SDL_bits.h>
#include <SDL3/SDL_intrin.h>
#include <SDL3/SDL_power.h>
#include <SDL3/SDL_sensor.h>

//==================================================
// Foundational Headers - SDL (Platform Specific)
//==================================================
#include <SDL3/SDL_platform.h>
#include <SDL3/SDL_platform_defines.h>

//==================================================
// Foundational Headers - SDL (Testing)
//==================================================
#include <SDL3/SDL_test.h>
#include <SDL3/SDL_test_assert.h>
#include <SDL3/SDL_test_common.h>
#include <SDL3/SDL_test_compare.h>
#include <SDL3/SDL_test_crc32.h>
#include <SDL3/SDL_test_font.h>
#include <SDL3/SDL_test_fuzzer.h>
#include <SDL3/SDL_test_harness.h>
#include <SDL3/SDL_test_log.h>
#include <SDL3/SDL_test_md5.h>
#include <SDL3/SDL_test_memory.h>

//==================================================
// Foundational Headers - SDL (Threading)
//==================================================
#include <SDL3/SDL_atomic.h>
#include <SDL3/SDL_mutex.h>
#include <SDL3/SDL_thread.h>

//==================================================
// Foundational Headers - SDL (Timing)
//==================================================
#include <SDL3/SDL_time.h>
#include <SDL3/SDL_timer.h>

//==================================================
// Additional SDL Headers (Misc/Utilities)
//==================================================
#include <SDL3/SDL_dialog.h>
#include <SDL3/SDL_endian.h>
#include <SDL3/SDL_init.h>
#include <SDL3/SDL_loadso.h>
#include <SDL3/SDL_misc.h>
#include <SDL3/SDL_oldnames.h>
#include <SDL3/SDL_tray.h>

//==================================================
// Foundational Headers - OpenGL
//==================================================
#include <GL/gl.h>
#include <GL/glext.h>
#include <GL/glcorearb.h>
#include <GL/glx.h>
#include <GL/glxmd.h>
#include <GL/glxtokens.h>





/*
Double check these headers with relationship to your build. 
Do I think these are needed, no, but, you need to handle:
- #include <GL/glxint.h>
- #include <GL/glxproto.h>
*/