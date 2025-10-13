#Universal SDL3
Introducing my universal SDL3 project, with the sheer intention on allowing others to build cross-platform applications without the headache of dealing with multiple platforms.

The base of this project is Alpine Linux, particularly, its edge branch. This is so I can work with a lot of the graphics libraries, which tend to be a lot more "experimental", and hence, requires me to use edge.

So far, this SDL3 project has the following support (but not limited to):
- OpenGL
- Vulkan
- SDL3
- SDL3_image
- SDL3_ttf
- Sqlite3 
- FFMPEG

Currently, the goal is to get JUCE ported over and working, and then if it is satisfactory enough for a gen Dockerfile, I'll be submitting it to the Alpine Linux repository.

I cannot ensure that the libraries have full functionality, so please report to me any particular issues you may find if you decide to use this repo. 