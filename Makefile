include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbumHider
AlbumHider_OBJCC_FILES = /mnt/d/codes/albumhider/Tweak.xm
AlbumHider_FRAMEWORKS = UIKit CydiaSubstrate CoreGraphics Photos
AlbumHider_PRIVATE_FRAMEWORKS = Preferences
AlbumHider_CFLAGS = -fobjc-arc
AlbumHider_LDFLAGS = -Wl,-segalign,4000

export ARCHS = armv7 arm64
AlbumHider_ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk
