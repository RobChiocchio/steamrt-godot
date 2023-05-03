FROM registry.gitlab.steamos.cloud/steamrt/sniper/sdk:latest

ENV NAME=steamrt-godot

ARG GODOT_VERSION="4.0.2"
ARG STEAMWORKS_VERSION="157"
ARG USE_LTO="no"
ARG DEBIAN_FRONTEND=noninteractive

# RUN add-apt-repository ppa:kisak/kisak-mesa && apt-get update

# RUN ~/.steam/root/ubuntu12_32/steam-runtime/setup.sh

# Install dependencies for Godot compile
RUN apt-get install -yqq \
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
    libxrandr-dev
    # mesa-vulkan-drivers

# Download Godot editor binary
RUN wget https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && unzip Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && rm Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
    && mv Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot

# Download Godot templates
RUN wget https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}/Godot_v${GODOT_VERSION}-stable_export_templates.tpz \
    && unzip Godot_v${GODOT_VERSION}-stable_export_templates.tpz \
    && rm Godot_v${GODOT_VERSION}-stable_export_templates.tpz \
    && mv templates/* ~/.local/share/godot/templates/${GODOT_VERSION}.stable

# Download Godot source code
RUN wget https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}/godot-${GODOT_VERSION}-stable.tar.xz \
    && tar -xf godot-${GODOT_VERSION}-stable.tar.xz \
    && rm godot-${GODOT_VERSION}-stable.tar.xz \
    && mv godot-${GODOT_VERSION}-stable godot

# Download GodotSteam module
RUN wget https://github.com/Gramps/GodotSteam/archive/refs/heads/godot4.zip \
    && unzip godot4.zip \
    && rm godot4.zip \
    && mv GodotSteam-godot4 godot/modules/godotsteam

# Download Steamworks SDK
RUN wget https://partner.steamgames.com/downloads/steamworks_sdk_${STEAMWORKS_VERSION}.zip \
    && unzip steamworks_sdk_${STEAMWORKS_VERSION}.zip \
    && rm steamworks_sdk_${STEAMWORKS_VERSION}.zip \
    && mv sdk/* godot/modules/godotsteam/sdk/

WORKDIR /godot

# Build Godot template for Linux
RUN scons platform=linuxbsd target=template_release production=yes tools=no arch=x86_64 use_lto=${USE_LTO} \
    builtin_libogg=no builtin_libtheora=no builtin_libvorbis=no builtin_libwebp=no builtin_pcre2=no 
    # builtin_freetype=no builtin_libpng=no builtin_zlib=no builtin_graphite=no builtin_harfbuzz=no
    
    # builtin_embree=no builtin_enet=no builtin_freetype=no builtin_graphite=no builtin_harfbuzz=no \
    # builtin_libogg=no builtin_libpng=no builtin_libtheora=no builtin_libvorbis=no builtin_libwebp=no \
    # builtin_mbedtls=no builtin_miniupnpc=no builtin_pcre2=no builtin_zlib=no builtin_zstd=no

# Copy Godot template to user's templates folder
RUN cp bin/godot.linuxbsd.template_release.x86_64 ~/.local/share/godot/templates/${GODOT_VERSION}.stable/

# Install SteamCMD
RUN dpkg --add-architecture i386 \
    && apt-get update -yqq \
    && apt-get install -yqq --no-install-recommends lib32gcc-s1 steamcmd

# Create symlink for SteamCMD
RUN ln -s /usr/games/steamcmd /home/steam/steamcmd

# Update SteamCMD and quit
RUN steamcmd +quit
