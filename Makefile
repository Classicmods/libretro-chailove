DEBUG = 0

ifeq ($(platform),)
	platform = unix
ifeq ($(shell uname -a),)
	platform = win
else ifneq ($(findstring Darwin,$(shell uname -a)),)
	platform = osx
else ifneq ($(findstring MINGW,$(shell uname -a)),)
	platform = win
endif
endif

TARGET_NAME := chaigame

ifeq ($(platform), unix)
	TARGET := $(TARGET_NAME)_libretro.so
	fpic += -fPIC
	SHARED := -shared -Wl,--no-undefined -Wl,--version-script=link.T
	ENDIANNESS_DEFINES := -DLSB_FIRST
	FLAGS += -D__LINUX__ -D__linux
	SDL_PREFIX := unix
# android arm
else ifneq (,$(findstring android,$(platform)))
	TARGET := $(TARGET_NAME)_libretro_android.so
	fpic += -fPIC
	SHARED := -lstdc++ -lstd++fs -llog -lz -shared -Wl,--version-script=link.T -Wl,--no-undefined
	CFLAGS +=  -g -O2
	FLAGS += -DANDROID
# cross Windows
else ifeq ($(platform), wincross64)
	TARGET := $(TARGET_NAME)_libretro.dll
	SHARED := -shared -Wl,--no-undefined -Wl,--version-script=link.T
	LDFLAGS += -static-libgcc -static-libstdc++ -lstd++fs
	ENDIANNESS_DEFINES := -DLSB_FIRST
	FLAGS += -D_WIN64
	EXTRA_LDF := -lwinmm -Wl,--export-all-symbols
	SDL_PREFIX := win
else
	TARGET :=  $(TARGET_NAME)_retro.dll
	SHARED := -shared -Wl,--no-undefined -Wl,--version-script=link.T
	LDFLAGS += -static-libgcc -static-libstdc++  -lstd++fs
	ENDIANNESS_DEFINES := -DLSB_FIRST
	FLAGS += -D_WIN32
	EXTRA_LDF += -lwinmm -Wl,--export-all-symbols
	SDL_PREFIX := win
endif

# MacOSX
ifeq ($(platform), osx)
	FLAGS += -D__APPLE__
endif

OBJECTS := src/libretro.o \
	src/Game.o \
	src/chaigame/audio.o \
	src/chaigame/log.o \
	src/chaigame/graphics.o \
	src/chaigame/keyboard.o \
	src/chaigame/script.o \
	src/chaigame/filesystem.o \
	src/chaigame/image.o \
	src/chaigame/sound.o \
	src/chaigame/math.o \
	src/chaigame/font.o \
	src/chaigame/timer.o \
	src/chaigame/event.o \
	src/chaigame/window.o \
	src/chaigame/mouse.o \
	src/chaigame/system.o \
	src/chaigame/joystick.o \
	src/chaigame/graphics/ImageData.o \
	src/chaigame/graphics/Quad.o \
	src/chaigame/graphics/Image.o \
	src/chaigame/graphics/Font.o \
	src/chaigame/graphics/Point.o \
	src/chaigame/input/Joystick.o \
	src/chaigame/audio/SoundData.o \
	src/chaigame/system/Config.o \
	test/Test.o \
	vendor/physfs/extras/physfsrwops.o \
	vendor/SDL_tty/src/SDL_tty.o \
	vendor/SDL_tty/src/SDL_fnt.o \
	vendor/physfs/src/archiver_dir.o \
	vendor/physfs/src/archiver_grp.o \
	vendor/physfs/src/archiver_hog.o \
	vendor/physfs/src/archiver_iso9660.o \
	vendor/physfs/src/archiver_lzma.o \
	vendor/physfs/src/archiver_mvl.o \
	vendor/physfs/src/archiver_qpak.o \
	vendor/physfs/src/archiver_slb.o \
	vendor/physfs/src/archiver_unpacked.o \
	vendor/physfs/src/archiver_wad.o \
	vendor/physfs/src/archiver_zip.o \
	vendor/physfs/src/physfs_byteorder.o \
	vendor/physfs/src/physfs.o \
	vendor/physfs/src/physfs_unicode.o \
	vendor/physfs/src/platform_macosx.o \
	vendor/physfs/src/platform_posix.o \
	vendor/physfs/src/platform_unix.o \
	vendor/physfs/src/platform_windows.o

# Build all the dependencies, and the core.
all: | dependencies	$(TARGET)

ifeq ($(DEBUG), 0)
   FLAGS += -O3 -ffast-math -fomit-frame-pointer
else
   FLAGS += -O0 -g
endif

LDFLAGS +=  $(fpic) $(SHARED) \
	vendor/SDL_$(platform).a \
	vendor/SDL_gfx_$(platform).a \
	-ldl \
	-lpthread \
	$(EXTRA_LDF)
FLAGS += -I. \
	-Ivendor/sdl-libretro/include \
	-Ivendor/libretro-common/include \
	-Ivendor/chaiscript/include \
	-Ivendor/SDL_tty/include \
	-Ivendor/spdlog/include \
	-Ivendor/sdl-libretro/tests/SDL_ttf-2.0.11/VisualC/external/include \
	-Ivendor/ChaiScript_Extras/include \
	-Ivendor/physfs/src \
	-Ivendor/Snippets \
	-Ivendor/stb

WARNINGS :=

ifeq ($(HAVE_CHAISCRIPT),)
	FLAGS += -D__HAVE_CHAISCRIPT__ -DCHAISCRIPT_NO_THREADS -DCHAISCRIPT_NO_THREADS_WARNING
endif
ifneq ($(HAVE_TESTS),)
	FLAGS += -D__HAVE_TESTS__
endif

FLAGS += -D__LIBRETRO__ $(ENDIANNESS_DEFINES) $(WARNINGS) $(fpic)

CXXFLAGS += $(FLAGS) -fpermissive -std=c++14
CFLAGS += $(FLAGS) -std=gnu99

$(TARGET): $(OBJECTS)
	$(CXX) -o $@ $^ $(LDFLAGS)

%.o: %.cpp
	$(CXX) -c -o $@ $< $(CXXFLAGS)

%.o: %.c
	$(CC) -c -o $@ $< $(CFLAGS)

clean:
	rm -f $(TARGET) $(OBJECTS)

submodules:
	git submodule update --init --recursive

vendor/SDL_$(platform).a: submodules
	cd vendor/sdl-libretro && make -f Makefile.libretro TARGET_NAME=../SDL_$(platform).a

vendor/SDL_gfx_$(platform).a: submodules
	cd vendor/sdl-libretro/tests/SDL_gfx-2.0.26 && make -f Makefile.libretro STATIC_LIB=../../../SDL_gfx_$(platform).a

dependencies: vendor/SDL_$(platform).a vendor/SDL_gfx_$(platform).a
	@echo "Built dependencies\n"

test: all
	@echo "Execute the following to run tests:\n\n    retroarch -L $(TARGET) test/main.chai\n"

examples: all
	retroarch -L $(TARGET) test/examples/main.chai

test-script: all
	retroarch -L $(TARGET) test/main.chai

noscript: dependencies
	$(MAKE) HAVE_CHAISCRIPT=0 HAVE_TESTS=1

test-noscript: noscript
	retroarch -L $(TARGET) test/main.chai

PREFIX := /usr
INSTALLDIR := $(PREFIX)/lib/libretro
install: all
	mkdir -p $(DESTDIR)$(INSTALLDIR)
	cp $(TARGET) $(DESTDIR)$(INSTALLDIR)
