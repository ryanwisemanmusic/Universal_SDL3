Alright, so if you want to not use tarballs as a means of fetching stuff,
and you want to exclusively use git clone, there is a particular standard
we must adhere to. You MUST use a valid hash as means of pulling the version
you want to use or you'll be in a detached head state. This isn't the
biggest problem, you still are valid for checking out in this way.

I just want to save you the debugger code since other things are more
important.

Here is how the standard should look (two different valid contexts):
# LIBEPOXY
echo "=== CLONING LIBEPOXY SOURCE ===" && \
    git clone --depth=1 https://github.com/anholt/libepoxy.git /tmp/libepoxy && \
    cd /tmp/libepoxy && \
    git checkout c84bc9459357a40e46e2fec0408d04fbdde2c973 -b libepoxy-1.5.10 && \
    \

# MESA
git clone --progress https://gitlab.freedesktop.org/mesa/mesa.git || (echo "⚠ mesa not cloned; skipping build commands" && exit 0); \
    if [ -d mesa ]; then cd mesa; else echo "⚠ mesa directory missing; skipping build"; exit 0; fi; \
    \
    git fetch --tags; \
    git checkout -b mesa-24.0.3-branch 67da5a8f08d11b929db3af8b70436065f093fcce || true; \
    /usr/local/bin/check_llvm15.sh "post-mesa-clone" || true; \
    \


MESA has some safety checks just in case you get an issue where MESA moves
from Gitlab to some forbidden place (as in, if the MESA creators decide to do this, I'll hate them)