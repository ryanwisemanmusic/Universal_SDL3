Hello! This SDL3 Universal build is coming along well!!!!

So my TODO list is centered around seeing if I can get my first project
in SDL3, to work inside of this container!!!

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