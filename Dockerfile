FROM debian:bookworm-slim

ARG RELEASE_VERSION=dev
ARG VCS_REF=local
ARG FLUTTER_VERSION=3.41.4
ARG ANDROID_CMDLINE_TOOLS_VERSION=13114758
ARG ANDROID_PLATFORM=android-36
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_NDK_VERSION=28.2.13676358

ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_HOME=/opt/flutter \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    PUB_CACHE=/opt/.pub-cache

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      libglu1-mesa \
      openjdk-17-jdk \
      unzip \
      xz-utils \
      zip && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /opt/java /root/.android && \
    ln -s "$(dirname "$(dirname "$(readlink -f "$(which java)")")")" /opt/java/openjdk && \
    touch /root/.android/repositories.cfg

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${FLUTTER_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${JAVA_HOME}/bin:${PATH}"

RUN printf '%s\n' \
      'export FLUTTER_HOME=/opt/flutter' \
      'export ANDROID_HOME=/opt/android-sdk' \
      'export ANDROID_SDK_ROOT=/opt/android-sdk' \
      'export JAVA_HOME=/opt/java/openjdk' \
      'export PATH=/opt/flutter/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/java/openjdk/bin:$PATH' \
      > /etc/profile.d/befam-env.sh && \
    chmod +x /etc/profile.d/befam-env.sh

RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" | \
      tar -xJ -C /opt && \
    mkdir -p "${ANDROID_HOME}/cmdline-tools" && \
    curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
      -o /tmp/commandlinetools.zip && \
    unzip -q /tmp/commandlinetools.zip -d /tmp/android-cmdline-tools && \
    mv /tmp/android-cmdline-tools/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest" && \
    rm -rf /tmp/commandlinetools.zip /tmp/android-cmdline-tools && \
    git config --global --add safe.directory "${FLUTTER_HOME}" && \
    yes | sdkmanager --licenses >/dev/null && \
    sdkmanager \
      "build-tools;${ANDROID_BUILD_TOOLS}" \
      "ndk;${ANDROID_NDK_VERSION}" \
      "platform-tools" \
      "platforms;${ANDROID_PLATFORM}" && \
    flutter config --no-analytics --android-sdk "${ANDROID_HOME}" && \
    flutter precache --android

WORKDIR /workspace/mobile/befam

COPY mobile/befam/pubspec.yaml mobile/befam/pubspec.lock mobile/befam/l10n.yaml ./
COPY mobile/befam/lib/l10n ./lib/l10n

RUN flutter pub get

COPY mobile/befam ./

RUN flutter gen-l10n

LABEL org.opencontainers.image.title="BeFam Mobile Release Builder" \
      org.opencontainers.image.description="Containerized Android release builder for the BeFam Flutter app" \
      org.opencontainers.image.source="https://github.com/phamhungptithcm/gia-pha" \
      org.opencontainers.image.version="${RELEASE_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"

CMD ["bash"]
