In order to move this project to a great state, there are a few important
things to tackle.

- Handle any missing libraries, suppress what is not needed for the context of the build
- Shell script wrappers that handle definition discrepancies between libraries
- CMake file fixed so all external libraries are recognized
- OpenGL fixed, renderer flag working in SDL3. 
- VulkanSDK fixed, renderer flag working in SDL3.
- Versioning of each library handled, for consistency, wrapped in a .json file about dependencies




To handle the stuff above, let's document where in the debugger I've been, and where I need to head next:
- Completed: JACK2 handling (Dockerfile)
    Some notes:
        JACK2 is missing from being recognized in my CMake file. 
        There also are some library discrepancies where definitions need to be shell script wrapped.


- Incomplete: FOP
    - #200 3.015 === RUNNING SUID/SGID SCANNER ON FOP INSTALLATION ===
    - #200 3.015 /bin/sh: /usr/local/bin/sgid_suid_scanner.sh: not found

        The only issue here is that you just need to make sure to copy and run chmod the script, and FOP will load the scanner.
        We also have it not appear in our CMake file. Java is found, but FOP is not

- Incomplete: LibDRM
    - MESON fails (probably because its path is different than where it points to)





After this, will be one of the foundational parts about making my fork of Alpine
- Write a desktop implementation of Alpine Linux.
- Add virtualization via Hypervisor/QEMU and the ability to communicate with the foundational hardware
- Add TheLilySpark C Project so I can still do systems prodding on Linux, see if we can skip virtualizing.

Implementing AtaraxiaSDK:
- Part of the test to make sure that graphics are advanced enough on the backend, so we need to add more and more layers and see what breaks
- We want the backend to work for us, not the other way around, so we need system compliance so that anything that is more Mac exclusive   
  translates in a Linux environment and becomes the standard.
- Our biggest test will be making sure that our first game translates, including passing Obj-C toolbaring stuff into Swift if needbe

Finalization for the SDL3 Project
- At the end, we essentially want the kernel to do two basic things:
    - custom code to launch the SDL3 build of AtaraxiaSDK
    - custom code to launch the desktop version of Alpine Linux.

Now we are wanting to do this primarily because it helps tackle a future
project significantly. I don't have much of an interest per-se with doing
kernel development, it is more to do with a: does this work at all????

