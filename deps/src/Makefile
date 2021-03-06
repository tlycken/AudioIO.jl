# Makefile lifted from Clang.jl

all: default

ifeq (exists, $(shell [ -e Make.user ] && echo exists ))
include Make.user
endif

.PHONY: all clean check-env default

#check-env:
#ifndef JULIA_INC
#        $(error Environment variable JULIA_INC is not set.)
#endif

#INC =-I"$(JULIA_INC)"
FLAGS =-Wall -Wno-strict-aliasing -fno-omit-frame-pointer -fPIC
CFLAGS =-g
LIBS =-L/usr/local/lib -lportaudio
LINUX_LIBS =-lrt
LINUX_LDFLAGS =-rdynamic
# add the Homebrew.jl tree to the include dirs in case we used it for
# portaudio and libsndfile
DARWIN_LDFLAGS =-L../../../Homebrew/deps/usr/lib
DARWIN_INC =-I../../../Homebrew/deps/usr/include
TARGETDIR=../usr/lib

OBJS = shim.o

# Figure out OS and architecture
OS = $(shell uname)
ifeq ($(OS), MINGW32_NT-6.1)
  OS=WINNT
endif

# file extensions and platform-specific libs
ifeq ($(OS), WINNT)
  SHLIB_EXT = dll
else ifeq ($(OS), Darwin)
  SHLIB_EXT = dylib
  INC += $(DARWIN_INC)
  LDFLAGS += $(DARWIN_LDFLAGS)
else
  LIBS += $(LINUX_LIBS)
  LDFLAGS += $(LINUX_LDFLAGS)
  SHLIB_EXT = so
  INC += $(LINUX_INC)
endif

TARGET=$(TARGETDIR)/libportaudio_shim.$(SHLIB_EXT)

default: $(TARGET)

%.o: %.c Makefile
	$(CC) $< -fPIC -c -o $@ $(INC) $(CFLAGS) $(FLAGS)

$(TARGET): $(OBJS) Makefile
	mkdir -p $(TARGETDIR)
	$(CC) $(OBJS) -shared -o $@ $(LDFLAGS) $(LIBS)

clean:
	rm -f *.o
	rm -f $(TARGET)
