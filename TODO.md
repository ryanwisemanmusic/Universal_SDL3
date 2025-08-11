Things to integrate (immediate):
- SDL_VulkanRenderer
- sys library. Networking is important for attempting to run the DOOM source code
- wine (yes, do that but git clone with debug on)
- DIRECTX renderer

When we have this all done, we need to make sure this runs native via Obj-C
Since Imo, this will be faster

Things to integrate (soon):
High Priorty:

- clang
- SDL3_Image
- lld
- SDL3_mixer
- SDL3_ttf
- FFMPEG
- JUCE
- SQLite
- GLM 

Medium Priority:
- util/types.h
- perl
- PortAudio
- binutils
- autoconf
- automake
- libtool
- ImGui 

Low Priority (for OS Project):
- QEMU (this is for userspace kernel, and hence, will be passed into X11)
- Abort kernel process of killall w/ Ubuntu fallback using GRUB 
