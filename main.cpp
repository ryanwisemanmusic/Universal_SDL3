#include "main.hpp"
#include <iostream>
#include <cstdlib>
#include <SDL3/SDL.h>
#include <SDL3/SDL_vulkan.h>

using namespace std;

int main(int argc, char* argv[]) 
{

    /*
For Docker, make sure you have:
# Minimal Plasma Desktop
sudo apk add plasma-desktop

# KDE Workspace and core components
sudo apk add plasma-workspace
sudo apk add plasma-framework
sudo apk add kwin
sudo apk add kscreen
sudo apk add ksysguard

# Display Manager (SDDM - recommended for KDE)
sudo apk add sddm
sudo apk add sddm-kcm

# KDE Applications and Utilities
sudo apk add dolphin         # File manager
sudo apk add konsole         # Terminal
sudo apk add kate            # Text editor
sudo apk add spectacle       # Screenshot tool
sudo apk add systemsettings  # System settings

# KDE Core Libraries
sudo apk add kio
sudo apk add kconfig
sudo apk add kcoreaddons
sudo apk add kservice
sudo apk add solid
sudo apk add kglobalaccel

# X11 Session Management
sudo apk add plasma-desktop-x11
sudo apk add xdg-utils

# Themes and Look-and-Feel
sudo apk add breeze
sudo apk add breeze-icons
sudo apk add oxygen-icons

# Optional but Recommended
sudo apk add ark             # Archive tool
sudo apk add gwenview        # Image viewer
sudo apk add okular          # Document viewer
sudo apk add kcalc           # Calculator
    */
    system("startplasma-x11 &");
    SDL_Delay(2000);
    SDL_Window *window;
    bool done = false;
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
    
    return 0;
}