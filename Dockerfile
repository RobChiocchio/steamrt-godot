ARG GODOT_VERSION="4.0.2"
ARG STEAMWORKS_VERSION="157"

FROM registry.gitlab.steamos.cloud/steamrt/sniper/sdk:latest AS build

ENV NAME=steamrt-godot
LABEL org.opencontainers.image.source=https://github.com/RobethX/steamrt-godot/

# Pass Steamworks login cookie from GitHub secrets
ARG STEAMWORKS_COOKIE
ENV STEAMWORKS_COOKIE ${STEAMWORKS_COOKIE}

ARG GODOT_VERSION
ENV GODOT_VERSION=${GODOT_VERSION}

ARG STEAMWORKS_VERSION
ENV STEAMWORKS_VERSION=${STEAMWORKS_VERSION}

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_FLAGS="linker=mold use_lto=no builtin_libogg=no builtin_libtheora=no builtin_libvorbis=no builtin_libwebp=no builtin_pcre2=no"
# builtin_freetype=no builtin_libpng=no builtin_zlib=no builtin_graphite=no builtin_harfbuzz=no

# RUN add-apt-repository ppa:kisak/kisak-mesa && apt-get update

# RUN ~/.steam/root/ubuntu12_32/steam-runtime/setup.sh

# Install dependencies for Godot compile
RUN apt-get install -yqq --no-install-recommends \
    # build-essential \
    # scons \
    # pkg-config \
    libx11-dev \
    libxcursor-dev \
    libxinerama-dev \
    libgl1-mesa-dev \
    libglu-dev \
    libasound2-dev \
    libpulse-dev \
    libudev-dev \
    libxi-dev \
    libxrandr-dev \
    mingw-w64
    # mesa-vulkan-drivers

# Download Godot editor binary
RUN wget -nv https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && unzip Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && rm Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && mv Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot

# Download Godot templates
#RUN wget -nv https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}/Godot_v${GODOT_VERSION}-stable_export_templates.tpz \
#    && unzip Godot_v${GODOT_VERSION}-stable_export_templates.tpz \
#    && rm Godot_v${GODOT_VERSION}-stable_export_templates.tpz \
#    && mkdir --parents ~/.local/share/godot/templates/${GODOT_VERSION}.stable \
#    && mv templates/* ~/.local/share/godot/templates/${GODOT_VERSION}.stable

# Download Godot source code
RUN wget -nv https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}/godot-${GODOT_VERSION}-stable.tar.xz \
    && tar -xf godot-${GODOT_VERSION}-stable.tar.xz \
    && rm godot-${GODOT_VERSION}-stable.tar.xz \
    && mv godot-${GODOT_VERSION}-stable godot

# Download GodotSteam module
RUN wget -nv https://github.com/Gramps/GodotSteam/archive/refs/heads/godot4.zip \
    && unzip godot4.zip \
    && rm godot4.zip \
    && mv GodotSteam-godot4 godot/modules/godotsteam
    
# Download and set up mold for faster linking
RUN export MOLD_LATEST=$(curl -L -s https://api.github.com/repos/rui314/mold/releases/latest | grep -o -E "https://(.*)mold-(.*)-x86_64-linux.tar.gz") \
    && wget -nv ${MOLD_LATEST} \
    && tar -xf $(echo $MOLD_LATEST | sed "s/.*\/\(.*\)/\1/") \
    && rsync -a $(echo $MOLD_LATEST | sed "s/.*\/\(.*\)\.tar.gz/\1/")/ /usr/local/

# Download Steamworks SDK
RUN wget -nv --no-cookies --header "${STEAMWORKS_COOKIE}" https://partner.steamgames.com/downloads/steamworks_sdk_${STEAMWORKS_VERSION}.zip \
    && unzip steamworks_sdk_${STEAMWORKS_VERSION}.zip \
    && rm steamworks_sdk_${STEAMWORKS_VERSION}.zip \
    && mv sdk/* godot/modules/godotsteam/sdk/

WORKDIR /godot

# Build Godot release template for Linux
RUN scons -j$(nproc) platform=linuxbsd target=template_release production=yes arch=x86_64 ${BUILD_FLAGS}

# Build Godot debug template for Linux
RUN scons -j$(nproc) platform=linuxbsd target=template_debug arch=x86_64 ${BUILD_FLAGS}

# Build Godot editor for Linux
#RUN scons -j$(nproc) platform=linuxbsd target=editor arch=x86_64 ${BUILD_FLAGS}

# Configure MinGW
RUN update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix \
    && update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

# Build Godot release template for Windows
RUN scons -j$(nproc) platform=windows  target=template_release production=yes arch=x86_64

# Build Godot debug template for Windows
RUN scons -j$(nproc) platform=windows  target=template_debug arch=x86_64

# Copy Godot template to user's templates folder
RUN mkdir --parents ~/.local/share/godot/templates/${GODOT_VERSION}.stable \
    && cp bin/godot.linuxbsd.template_release.x86_64 ~/.local/share/godot/templates/${GODOT_VERSION}.stable/ \
    && cp bin/godot.linuxbsd.template_debug.x86_64 ~/.local/share/godot/templates/${GODOT_VERSION}.stable/ \
    && cp bin/godot.windows.template_release.x86_64.exe ~/.local/share/godot/templates/${GODOT_VERSION}.stable/ \
    && cp bin/godot.windows.template_debug.x86_64.exe ~/.local/share/godot/templates/${GODOT_VERSION}.stable/ \
    && ls bin

# Multi-stage build
FROM registry.gitlab.steamos.cloud/steamrt/sniper/platform:latest

ARG GODOT_VERSION
ENV GODOT_VERSION=${GODOT_VERSION}

ARG STEAMWORKS_VERSION
ENV STEAMWORKS_VERSION=${STEAMWORKS_VERSION}

ENV USER steam
ENV HOMEDIR "/home/${USER}"
ENV STEAMCMDDIR "${HOMEDIR}/steamcmd"

COPY --from=build /root/.local/share/godot/templates/${GODOT_VERSION}.stable/ ${HOMEDIR}/.local/share/godot/templates/${GODOT_VERSION}.stable/
COPY --from=build /usr/local/bin/godot /usr/local/bin/godot

# Insert Steam prompt answers
RUN echo steam steam/question select "I AGREE" | debconf-set-selections \
 && echo steam steam/license note "" | debconf-set-selections

# Install SteamCMD
RUN dpkg --add-architecture i386 \
    && apt-get update -yqq \
    && apt-get install -yqq --no-install-recommends lib32gcc-s1 steamcmd git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
    
# Create user and run SteamCMD
RUN useradd "${USER}" -m -d ${HOMEDIR} \
    && su "${USER}" \
    && /usr/games/steamcmd +quit
    
# Switch user
USER ${USER}
