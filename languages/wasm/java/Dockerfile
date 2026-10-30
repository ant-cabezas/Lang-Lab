# WebAssembly side study, java column, built through TeaVM 0.13.1 (NOT the JVM: nothing here is
# comparable to the matrix java cells). Build context is the repo root:
#   docker build -f languages/wasm/java/Dockerfile -t lang-lab-wasm:java .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
#
# TeaVM 0.13.1 is a frozen release: its WASI backend was removed in 0.14.0. Java, Kotlin and Scala
# all go through it, so they share one builder stage (languages/wasm/{java,kotlin,scala}/Dockerfile
# carry the IDENTICAL builder text, so Docker's layer cache builds it once and each final image
# only copies its own language's binaries).
#
# Per benchmark, from the canonical languages/java/<b> source (never edited), languages/wasm/teavm/build.sh:
#   1. one front-end compile: javac --release 25 (JDK 25: TeaVM 0.13.1's bundled ASM rejects class
#      file major version 70, i.e. the matrix Java 26) / kotlinc 2.1.0 (run on JRE 21: it cannot parse the JDK 25 version string) / Scala 3.6.2 dotc; the
#      resulting class files feed BOTH backends below
#   2. teavm -t C    -O 3 --min-heap 32 --max-heap 512 -> all.c -> /opt/llvm/bin/clang -O2 -lm
#   3. teavm -t wasi -O 3 --min-heap 32 --max-heap 512 -> <b>.wasm -> wasmtime compile (AOT)
# Artifacts in the final image:
#   /app/java/native/<b>        TeaVM C backend + LLVM clang 23.1.0 -O2 (native column)
#   /app/java/wasm/<b>.wasm     TeaVM wasi backend (own emitter, no LLVM, no binaryen)
#   /app/java/wasm/<b>.cwasm    the same module precompiled by wasmtime
#   /app/java/BUILD-FAIL.txt    benchmarks TeaVM could not build, with the first error lines
# message-ring and the -par variants are excluded (threads).
# Pins: every jar by sha256 in languages/wasm/teavm/jars.lock, Kotlin compiler zip by sha256 below.
FROM lang-lab-wasm-base AS build
ARG JDK_APT_VERSION=25.0.4.1+1-1~deb13u1
ARG JRE21_APT_VERSION=21.0.12.1+1-1~deb13u1
# Debian drops superseded security builds, so the OpenJDK pins are fetched from a fixed snapshot.
ARG DEBIAN_SNAPSHOT=20261027T000000Z
ARG KOTLIN_VERSION=2.1.0
ARG KOTLIN_SHA256=b6698d5728ad8f9edcdd01617d638073191d8a03139cc538a391b4e3759ad297
RUN echo "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT} trixie-security main" > /etc/apt/sources.list.d/snapshot.list \
 && apt-get update -qq && apt-get install -y -qq --no-install-recommends openjdk-25-jdk-headless=${JDK_APT_VERSION} openjdk-25-jre-headless=${JDK_APT_VERSION} openjdk-21-jre-headless=${JRE21_APT_VERSION} unzip curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/snapshot.list
COPY languages/wasm/teavm/jars.lock /opt/teavm/jars.lock
RUN set -eu; mkdir -p /opt/jars; cd /opt/jars; \
    grep -v '^#' /opt/teavm/jars.lock | while read -r sha p; do \
      mkdir -p "$(dirname "$p")"; curl -fsSL -o "$p" "https://repo1.maven.org/maven2/$p"; echo "$sha  $p" | sha256sum -c --quiet -; done; \
    curl -fsSL -o /tmp/k.zip "https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip"; \
    echo "${KOTLIN_SHA256}  /tmp/k.zip" | sha256sum -c -; unzip -q /tmp/k.zip -d /opt; rm /tmp/k.zip
COPY languages/wasm/teavm/build.sh /opt/teavm/build.sh
COPY languages/java/*.java   /src/java/
COPY languages/kotlin/*.kt   /src/kotlin/
COPY languages/scala/*.scala /src/scala/
ENV PATH="/opt/kotlinc/bin:${PATH}"
RUN /opt/teavm/build.sh java   /src/java   /out/java
RUN /opt/teavm/build.sh kotlin /src/kotlin /out/kotlin
RUN /opt/teavm/build.sh scala  /src/scala  /out/scala
RUN { echo "javac: $(javac -version 2>&1) (--release 25)"; echo "kotlinc: $(JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 kotlinc -version 2>&1 | grep ^info)"; \
      echo "scala: 3.6.2 (dotty.tools.dotc.Main)"; echo "teavm: 0.13.1 (-t C and -t wasi, -O 3, --min-heap 32 --max-heap 512)"; \
      echo "clang: $(/opt/llvm/bin/clang --version | head -1) (-O2 -lm on TeaVM all.c)"; echo "wasmtime: $(wasmtime --version)"; \
      echo "node: $(node --version)"; } > /out/TOOLCHAIN

FROM lang-lab-wasm-base
COPY --from=build /out/java /app/java
COPY --from=build /out/TOOLCHAIN /app/TOOLCHAIN
ENV LANG_VERSION=java-teavm-0.13.1
