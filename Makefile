
# This is a GNU Makefile. This should work on most Un*x systems, Windows
# undoubtedly needs some work.

# IMPORTANT: On Debian/Ubuntu, the octave library path seems to be missing
# from the ld.so config, so if the octave module fails to load, you will have
# to set LD_LIBRARY_PATH explicitly, e.g.:

# export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/octave/6.4.0

# Package name and version number:
dist = lua-octave-$(version)
version = 1.0
rev = 1

# This has been set up so that it will work with luarocks or without it.
# With luarocks: `sudo luarocks make` to build and install, `sudo luarocks
# remove luaoctave` to remove the `luaoctave` rock from your system.
# Without luarocks: `make && sudo make install` to build and install, `sudo
# make uninstall` to remove the `octave.so` module from your system.

# Where to install compiled (C) modules.
installdir = $(shell pkg-config --variable INSTALL_CMOD lua)
# Where to install source (Lua) modules.
installdir_l = $(shell pkg-config --variable INSTALL_LMOD lua)

distfiles = COPYING README.md Makefile luaoct-$(version)-$(rev).rockspec embed.cc embed.h examples/*

# You may have to adjust these to the appropriate values for your system if
# you're installing without luarocks.
LIBFLAG ?= -shared
CFLAGS ?= -O2 -fPIC
INST_LIBDIR ?= $(installdir)

# The mkoctfile to use. Adjust this as needed if it's named differently, isn't
# in the standard PATH or if you have multiple Octave installations on your
# system.
mkoctfile = mkoctfile

# Try to guess the Octave version number. We're only interested in the
# major/minor version here, to cope with the C/C++ API breakage in Octave 3.8+.
octversion = $(shell $(mkoctfile) --version 2>&1 | sed -e 's/^mkoctfile, version \([0-9.]*\).*/\1/' | sed -e 's/\([0-9]*\)[.]\([0-9]*\).*/\1 \2/')
octversionflag = -DOCTAVE_MAJOR=$(word 1,$(octversion)) -DOCTAVE_MINOR=$(word 2,$(octversion))

# Add the -rpath flag so that the dynamic linker finds liboctave.so etc. when
# Pure loads the module. NOTE: This doesn't seem to be needed any more.
RLD_FLAG=$(shell $(mkoctfile) -p RLD_FLAG)

# Octave 5.1+ doesn't automatically include these linker options any more.
OCT_FLAGS=-L$(shell $(mkoctfile) -p OCTLIBDIR) $(shell $(mkoctfile) -p LIBOCTINTERP) $(shell $(mkoctfile) -p LIBOCTAVE)

all: octave.so
octave.so: embed.cc embed.h
	rm -f $@
	$(mkoctfile) -v $(octversionflag) -o $@ $< $(shell pkg-config --cflags --libs lua) $(RLD_FLAG) $(OCT_FLAGS) -Wl,--no-as-needed
	if test -f $@.oct; then mv $@.oct $@; fi

clean:
	rm -f octave.so

# Note that only the compiled C module is installed, so you'll have to copy
# the examples and documentation files manually if you want to keep those.

install: octave.so
	mkdir -p $(DESTDIR)$(INST_LIBDIR)
	cp octave.so $(DESTDIR)$(INST_LIBDIR)

uninstall:
	rm -f $(DESTDIR)$(INST_LIBDIR)/octave.so

# Roll a distribution tarball.

dist:
	rm -rf $(dist)
	mkdir $(dist) && mkdir $(dist)/examples
	for x in $(distfiles); do ln -sf $$PWD/$$x $(dist)/$$x; done
	rm -f $(dist).tar.gz
	tar cfzh $(dist).tar.gz $(dist)
	rm -rf $(dist)

distcheck: dist
	tar xfz $(dist).tar.gz
	cd $(dist) && make && make install DESTDIR=./BUILD
	rm -rf $(dist)
