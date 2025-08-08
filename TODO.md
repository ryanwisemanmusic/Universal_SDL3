SO, this is the list of shit that i need to get done with regards to 
SDL3 working with docker.

Here is where we currently need to handle things:
1. OpenGL support

Currrently, Alpine only works via SDL3 getting handled with X11. Any
renderer that uses XQuartz is valid. No flags are allowed in OpenGL,
so that means our environment is not initialized to handle OpenGL

2. Vulkan Renderer support

Yes, we need some Vulkan rendering, just because I can write some Linux
specific usage within this project