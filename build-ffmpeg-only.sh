#!/bin/sh

#  Automatic build script for ffmpeg 
#  for iPhoneOS and iPhoneSimulator

###########################################################################
#  Change values here													  #
#																		  #
VERSION="1.0.1"													      #
SDKVERSION="6.0"														  #
#																		  #
###########################################################################
#																		  #
# Don't change anything under this line!								  #
#																		  #
###########################################################################


CURRENTPATH=`pwd`
ARCHS="i386 armv7 armv7s"
DEVELOPER=`xcode-select -print-path`

if [ ! -d "$DEVELOPER" ]; then
  echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
  echo "run"
  echo "sudo xcode-select -switch <xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

set -e
if [ ! -e ffmpeg-${VERSION}.tar.bz2 ]; then
	echo "Downloading ffmpeg-${VERSION}.tar.bz2"
    curl -O  http://ffmpeg.org/releases/ffmpeg-${VERSION}.tar.bz2
else
	echo "Using ffmpeg-${VERSION}.tar.bz2"
fi

mkdir -p "${CURRENTPATH}/src"
mkdir -p "${CURRENTPATH}/bin"
mkdir -p "${CURRENTPATH}/lib"

tar jxvf ffmpeg-${VERSION}.tar.bz2 -C "${CURRENTPATH}/src"
cd "${CURRENTPATH}/src/ffmpeg-${VERSION}"

for ARCH in ${ARCHS}
do
	if [ "${ARCH}" == "i386" ];
	then
		PLATFORM="iPhoneSimulator"
		EXTRA_FLAGS="--cpu=i386 --enable-pic --disable-yasm --disable-asm --disable-armv5te"
        EXTRA_CFLAGS=""
        FFARCH=i386
	else
		#sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
		PLATFORM="iPhoneOS"
		EXTRA_FLAGS="--cpu=cortex-a8 --enable-pic"
        EXTRA_CFLAGS="-mfpu=neon"
        FFARCH=arm
	fi
	
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
	export RANLIB=${CROSS_TOP}/usr/bin/ranlib

	echo "Building ffmpeg-${VERSION} for ${PLATFORM} ${SDKVERSION} ${ARCH}"
	echo "Please stand by..."

	mkdir -p "${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
	LOG="${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/build-ffmpeg-${VERSION}.log"

./configure \
--cc=${CROSS_TOP}/usr/bin/gcc \
--as="gas-preprocessor.pl ${CROSS_TOP}/usr/bin/gcc" \
--prefix=${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk \
--sysroot=${CROSS_TOP}/SDKs/${CROSS_SDK} \
--extra-cflags="-I../../include" \
--extra-cflags="-I../../include/x264" \
--extra-ldflags="-L../../lib" \
--extra-ldflags="-L${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/lib/system" \
--target-os=darwin \
--arch=${FFARCH} \
--extra-cflags="-arch ${ARCH}" \
--extra-ldflags="-arch ${ARCH}" \
${EXTRA_FLAGS} \
--enable-gpl \
--enable-cross-compile \
--disable-ffmpeg  \
--disable-ffplay \
--disable-ffserver \
--disable-doc \
--disable-encoders \
--disable-decoders \
--disable-demuxers \
--disable-muxers \
--enable-demuxer=flv \
--enable-demuxer=mov \
--enable-muxer=flv \
--enable-muxer=mov \
--enable-decoder=mp3 \
--enable-decoder=aac \

	make >> "${LOG}" 2>&1
	make install >> "${LOG}" 2>&1
	make clean >> "${LOG}" 2>&1
done

echo "Build library..."
FFMPEG_LIBS="libavcodec libavdevice libavformat libavutil libswscale"
for i in ${FFMPEG_LIBS}
do 
	lipo -create ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/lib/$i.a  ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-armv7.sdk/lib/$i.a ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-armv7s.sdk/lib/$i.a -output ${CURRENTPATH}/lib/$i.a
done

mkdir -p ${CURRENTPATH}/include

for i in ${FFMPEG_LIBS}
do
cp -R ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-i386.sdk/include/$i ${CURRENTPATH}/include/
done

echo "Building done."
echo "Cleaning up..."
rm -rf ${CURRENTPATH}/src/ffmpeg-${VERSION}
echo "Done."