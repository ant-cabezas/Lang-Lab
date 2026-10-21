# Build context is the repo root: docker build -f languages/cobol/Dockerfile -t lang-lab-cobol .
# COBOL SIDE STUDY ONLY (out of the ranking; never in languages.json / the matrix / CI).
# GnuCOBOL transpiles COBOL -> C -> a native ELF linked against libcob (+ GMP), so COBOL
# measures as a NATIVE single-process program under qemu+insn (bit-exact, like C).
# Requires the prebuilt base: docker build -f languages/_base/Dockerfile.qemu-insn -t lang-lab-qemu-insn .
#
# Two compiler axes, selected with --build-arg COBOL_SOURCE:
#   src (default) GnuCOBOL 3.2 built from the official GNU tarball, sha256-pinned
#                 (tarball signature checked once against the GNU keyring: key
#                 B9459D0CA8A740B323235CDF13E96B53C005604E, Simon Sobisch).
#   apt           Debian bookworm's packaged gnucobol (3.1.2), recorded via `cobc --version`.
# Compile flags: COBC_FLAGS (default "-O2 -free").
ARG COBOL_SOURCE=src

FROM debian:bookworm-slim AS gnucobol-build
ARG GNUCOBOL_VERSION=3.2
ARG GNUCOBOL_SHA256=3bb48af46ced4779facf41fdc2ee60e4ccb86eaa99d010b36685315df39c2ee2
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libgmp-dev ca-certificates curl xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://ftp.gnu.org/gnu/gnucobol/gnucobol-${GNUCOBOL_VERSION}.tar.xz" -o /tmp/gc.tar.xz \
    && echo "${GNUCOBOL_SHA256}  /tmp/gc.tar.xz" | sha256sum -c - \
    && mkdir /tmp/gc && tar -xJf /tmp/gc.tar.xz -C /tmp/gc --strip-components=1 \
    && cd /tmp/gc \
    && ./configure --prefix=/opt/gnucobol --without-db --without-curses --without-xml2 --without-json \
    && make -j"$(nproc)" && make install \
    && rm -rf /tmp/gc /tmp/gc.tar.xz

# --- toolchain: GnuCOBOL 3.2 from source ---
FROM debian:bookworm-slim AS toolchain-src
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libgmp-dev \
    && rm -rf /var/lib/apt/lists/*
COPY --from=gnucobol-build /opt/gnucobol /opt/gnucobol
ENV PATH=/opt/gnucobol/bin:$PATH LANG_VERSION=gnucobol-3.2
RUN echo /opt/gnucobol/lib > /etc/ld.so.conf.d/gnucobol.conf && ldconfig

# --- toolchain: Debian bookworm's packaged GnuCOBOL (3.1.2) ---
FROM debian:bookworm-slim AS toolchain-apt
RUN apt-get update && apt-get install -y --no-install-recommends \
      gnucobol build-essential \
    && rm -rf /var/lib/apt/lists/*
ENV LANG_VERSION=gnucobol-3.1.2-bookworm

FROM toolchain-${COBOL_SOURCE}
ARG COBC_FLAGS="-O2 -free"
COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
COPY languages/cobol/*.cob /app/
# The compiler version and flags are logged into the build output and recorded in the image (the study
# driver reads /app/COBC_VERSION and /app/COBC_FLAGS into every envelope). A failing compile aborts the build.
RUN cobc --version | tee /app/COBC_VERSION \
    && echo "cobc -x ${COBC_FLAGS}" | tee /app/COBC_FLAGS \
    && for f in /app/*.cob; do cobc -x ${COBC_FLAGS} "$f" -o "/app/$(basename "$f" .cob)" || exit 1; done
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "cobol", "fannkuch", "--", "/app/fannkuch"]
