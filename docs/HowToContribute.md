So far, this build supports standard SDL3 library functionality. However,
if you log check this, you'll find that there are a lot of problems under the hood.

We have OpenGL windowing supported, but I am unsure if our renderer will cause problems.

There are a few areas in which you can contribute to the build. The first
is dealing with older SDL2 libraries. Currently, the libraries with SDL3
support are as the following:
- SDL3 (vanilla) - this is a given
- SDL_image

Any code to better the linking of SDL3 extern libraries:
- SDL3_mixer
- SDL3_ttf

Here are libraries that cause a fundamental problem to the build:
- SDL3_gfx
- SDL_sound

If you want to contribute, what I personally need is a port of the two
incompatible libraries to SDL3. Whether this is your own fork that meets
the very specific requirements, or you contributing to the creation of SDL3,
these external libraries need support for full integration to happen.

While I will do all I can to try to support these libraries, depending on
what is required, this may not be possible without additional contributions.

Keep in mind, this is just part of a larger LinuxOS build I'm intending on
writing for a potential embedded software project, and I will use pure
OpenGL/Vulkan if required. So contributions like this guarentee that we
see real world application of SDL3 from an OS perspective.

Here is what I'm not seeking:
I do not want you to be contributing to main.cpp. I'm only using this
as a means to intialization. Keep in mind, most of this work is backend.



