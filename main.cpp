#include <iostream>
#include <vector>
#include <SDL3/SDL.h>
#include <SDL3/SDL_audio.h>
#include <SDL3/SDL_main.h>
#include <SDL3/SDL_opengl.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_surface.h>
#include <SDL3/SDL_video.h>
#include <SDL3/SDL_vulkan.h>
#include <SDL3_image/SDL_image.h>
#include <SDL3_ttf/SDL_ttf.h>
#include <vulkan/vulkan.h>
#include <sqlite3.h>

extern "C" 
{
    #include <libavcodec/avcodec.h>
    #include <libavformat/avformat.h>
    #include <libswscale/swscale.h>
}

using namespace std;

bool tryVulkan() 
{
    SDL_Window* window = 
    SDL_CreateWindow(
        "Vulkan Test", 
        640, 
        480, 
        SDL_WINDOW_VULKAN);

    VkInstance instance = VK_NULL_HANDLE;
    VkSurfaceKHR surface = VK_NULL_HANDLE;

    VkApplicationInfo appInfo = {};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Vulkan Test";
    appInfo.apiVersion = VK_API_VERSION_1_0;

    uint32_t extensionCount = 0;
    const char* const* extensions = SDL_Vulkan_GetInstanceExtensions(&extensionCount);

    VkInstanceCreateInfo createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;
    createInfo.enabledExtensionCount = extensionCount;
    createInfo.ppEnabledExtensionNames = extensions;

    vkCreateInstance(&createInfo, nullptr, &instance);
    SDL_Vulkan_CreateSurface(window, instance, nullptr, &surface);
    
    bool done = false;
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
        SDL_Delay(16);
    }
    
    vkDestroySurfaceKHR(instance, surface, nullptr);
    vkDestroyInstance(instance, nullptr);
    SDL_DestroyWindow(window);

    return true;
}

void runOpenGL() 
{
    SDL_Window *window = SDL_CreateWindow
    (
        "OpenGL Window", 
        640, 
        480, 
        SDL_WINDOW_OPENGL
    );

    SDL_GLContext gl_context = SDL_GL_CreateContext(window);
    SDL_GL_SetSwapInterval(1);

    bool done = false;
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

        glClearColor(0.2f, 0.3f, 0.8f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glBegin(GL_TRIANGLES);
        glColor3f(1.0f, 0.0f, 0.0f);
        glVertex2f(-0.6f, -0.6f);
        glColor3f(0.0f, 1.0f, 0.0f);
        glVertex2f(0.6f, -0.6f);
        glColor3f(0.0f, 0.0f, 1.0f);
        glVertex2f(0.0f, 0.6f);
        glEnd();

        SDL_GL_SwapWindow(window);
        SDL_Delay(16);
    }

    SDL_GL_DestroyContext(gl_context);
    SDL_DestroyWindow(window);
}

int main() 
{
    SDL_Init(SDL_INIT_VIDEO);
    
    //tryVulkan();
    runOpenGL();

    SDL_Quit();
    return 0;
}