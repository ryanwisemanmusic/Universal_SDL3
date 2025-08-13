Alpine (3.18) can teach us quite a lot about compiler versioning, and
how you need to be extremely careful when attempting to build your libraries

LLVM has multiple versions that we are watching out for. Alpine commonly uses
16 for a lot, but there are a few APK's that you must force to use 16.

Here are the ones that required LLVM V16 explicitly:
- shaderc
- xorg-server-dev
- gst
