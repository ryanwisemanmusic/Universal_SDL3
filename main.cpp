#include "main.hpp"
#include <iostream>
#include <cstdlib>
#include <SDL3/SDL.h>
#include <SDL3/SDL_vulkan.h>
#include <unistd.h>

using namespace std;

int main(int argc, char* argv[]) 
{
    //system("Xephyr :1 -screen 640x480 &");
    //sleep(1);
    //system("DISPLAY=:1 startplasma-x11 &");

    //SDL_Delay(4000);
    SDL_Window *window;
    bool done = false;
    //setenv("DISPLAY", ":1", 1);
    SDL_Init(SDL_INIT_VIDEO);

    window = SDL_CreateWindow(
        "An SDL3 window",
        640,
        480,
        0
        //Other valid flags:
        //SDL_WINDOW_VULKAN
        //SDL_WINDOW_OPENGL
    );

    if (window == NULL) 
    {
        SDL_LogError(SDL_LOG_CATEGORY_ERROR, "Could not create window: %s\n", SDL_GetError());
        return 1;
    }

    while (!done) 
    {
        SDL_Event event;

        while (SDL_PollEvent(&event)) 
        {
            if (event.type == SDL_EVENT_QUIT) 
            {
                done = true;
            }
        }

    }

    SDL_DestroyWindow(window);

    SDL_Quit();

    //system("pkill Xephyr");
    
    return 0;
}
