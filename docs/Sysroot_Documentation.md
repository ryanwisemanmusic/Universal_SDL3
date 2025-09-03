If you are using LLVM or Clang, or anything in which you need to access a set
of packages that were sysrooted to a location, you must take that sysroot and
apply it to any build from source code that lives in a folder that is NOT
the original place that you applied said sysroot.

So if you installed build-base in location #1, but you have a place that needs
it at #2, you must sysroot populate #1 and #2.