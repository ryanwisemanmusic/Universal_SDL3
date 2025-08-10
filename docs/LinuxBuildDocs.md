Docker has some fun functionality that is often used less for graphics over
the demand it causes, especially if you need significant overhead to make things
work. Keep in mind, you are containerizing Linux and then Docker creates the
Wine translation layer. And so when you attempt to work with third-party libraries,
it means that there are a lot of dependencies that aren't included in the APK's
you clone and install.

And so with that, there is a whole list of things we need to fetch.

Alipine is tiny, which, while we can use Ubuntu, the amount of things
we fetch is just often not in areas we need. And so you take a 5MB image,
and then basically recreate Linux for our build process. Because the overhead
you get will take about 5-10 minutes in terms of the amount of stuff you need.


Later note to contextualize with a further update on why I fetch what
I fetch:
When it comes to the buildtime, the lack of communication between Docker
and X11 is this library needed at buildtime:
- llvm16-dev llvm16-libs 

Now, this was the needed graphics library that was causing a lack of
communication between Docker and X11. Sure, while we have some problems
of some drivers going all fucky-wucky, for now, the code compiles and runs

So, we still have some issues to cleanup on this