#Universal SDL3
Introducing my universal SDL3 project, with the sheer intention on allowing others to build cross-platform applications without the headache of dealing with multiple platforms. Currently, this has been tested on my ARM based Mac, and works, so results may vary.

The base of this project is Alpine Linux, particularly, its edge branch. This is so I can work with a lot of the graphics libraries, which tend to be a lot more "experimental".

So far, this SDL3 project has the following support (but not limited to):
- OpenGL
- Vulkan
- SDL3

Here are things that are added, but not fully tested:
- SDL3_image
- SDL3_ttf
- Sqlite3 
- FFMPEG

As a note, the attached package you will find (that you can pull the Docker image) is an EARLY alpha version. Once again, this is EARLY ALPHA. 

For example, while SDL3_ttf works (supposedly the library links without problem; supposedly), I have yet to work out a valid way of binding text to a screen yet where SDL3_ttf is happy about it. Stuff like this is where the project right now struggles.

A good note, currently, if you are going to create an SDL3 renderer, you must use: 'gpu' under the name of the renderer. This was the only renderer that worked for me, and hence, these issues is why I am being VERY cautious on this working. There is a problem where if you choose 0, you end up with a problem where MESA isn't bound to the x11 shim, and so you render NOTHING.

Currently, I am so busy with school; so please understand it is one person working on this project!
