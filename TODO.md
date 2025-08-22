Alright, here are the things I'll be creating related to shell code
- Shellcode that gets additional data on when a package is missing or not.
- Shelcode to check the components and return whether or not they are found
- Additional shellcode that pulls the source behind said component if possible?
- ldd checker for missing libraries highlighted (dependency walker)
- automatic search suggestion so when file missing, a potential package and relevant paths from other stages
- Check if missing files weren't copied to the build context (they only exist)
- Logger that checks differences between each stage to pinpoint changes
- Logger for ENV Variables and when they are modified/set
- Anything that detects when there is a permission conflict
- Source investigation (into how and why the problem happened)
- Source fetcher: if a component is missing, attempt to locate its source repo
- Dockerfile suggestions, So I stop making my problems worse
- File Triggers, so if file is in stage x, but missing in stage y, we are pinged about it
- Time Travel Debugger: Reconstruct the state of the filesystem at the exact time when a failure occured.




Right now, there are a few libraries we still need to implement. However,
this is very small, given that anything outside of SQLite is FFMPEG:
1. #include <sqlite3.h>
2. #include <libavcodec/avcodec.h>
3. #include <libavformat/avformat.h>
4. #include <libswscale/swscale.h>
5. #include <libswresample/swresample.h>
6. #include <libavutil/channel_layout.h>
7. #include <libswresample/swresample.h>

After these are recognized and the headers create no segfault, I will
be using this project as the testing ground to see just exactly WHAT code
works. There may be some uses of code that fail due to an underlying
dependency missing. And that is what the next part of my TODO comes into
play. 

Here is the link to the repo if you want to check it out!
https://github.com/ryanwisemanmusic/SDL3_Cat_Tac_Toe


Once this gets built, then I will focus my efforts on porting my entire
SDK to it and making sure that code compiles.

Part of the reason for why I am doing this is because hardcoding library
paths has created a specific problem, when homebrew updates said libraries,
it will delete the older ones. And hence, why I wanted to build a 
universally accessible SDL3 build that instantly compiles without tantrum.