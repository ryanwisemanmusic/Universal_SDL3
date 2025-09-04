Alright, if you want to do anything symlink related, you must understand that ln -sf IS NOT YOUR FRIEND, at
least not without certain bounds.

So here is an example of very bad and good code that will help you understand what you can and cannot do

BAD CODE:
# DO NOT DO THIS:
ln -sf /lilyspark/usr/local/lib/python/site-packages /lilyspark/usr/lib/python3*/site-packages

GOOD CODE:
# Symlink each package individually to preserve all packages
for pkg in mako markupsafe mesonbuild; do
    ln -sf /lilyspark/usr/local/lib/python/site-packages/$pkg /lilyspark/usr/lib/python3*/site-packages/$pkg
done

This ensures that you symlink to each package, rather than attempting to link to the entire folder.
And I note this because it is very easy to do a simple ln -sf, or any other symlink approach, without
keeping this in mind.

This is the issue that caused problems with our app's binary early on, per this Substack article I wrote:
https://ryanwiseman.substack.com/p/the-warning-your-compiler-never-tells

