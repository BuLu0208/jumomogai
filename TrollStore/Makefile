TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES = TrollStore
ARCHS = arm64

# 直接用 Xcode SDK 路径，绕过 Theos 的 SDK 解析
_XCODE_SDK_PATH := $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
_FRAMEWORK_PATH := $(_XCODE_SDK_PATH)/System/Library/PrivateFrameworks
_FRAMEWORK_PUBLIC_PATH := $(_XCODE_SDK_PATH)/System/Library/Frameworks

TARGET_CODESIGN = ../Exploits/fastPathSign/fastPathSign

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollStore

TrollStore_FILES = $(wildcard *.m) $(wildcard ../Shared/*.m)
TrollStore_FRAMEWORKS = UIKit CoreGraphics CoreServices CoreTelephony
TrollStore_PRIVATE_FRAMEWORKS = Preferences MobileIcons MobileContainerManager
TrollStore_LDFLAGS = -F$(_FRAMEWORK_PATH) -F$(_FRAMEWORK_PUBLIC_PATH)
TrollStore_LIBRARIES = archive
TrollStore_CFLAGS = -fobjc-arc -I../Shared -I$(shell brew --prefix)/opt/libarchive/include
TrollStore_CODESIGN_FLAGS = --entitlements entitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
