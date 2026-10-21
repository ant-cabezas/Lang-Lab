# Build context is the repo root: docker build -f languages/fortran/Dockerfile .
# Fortran = gfortran from the SAME gcc:${GCC_VERSION} image as the C baseline, so the two pins
# move together (versions.lock.json "fortran" tracks the C/GCC pin by hand; versionSource manual).
# Compiled with plain -O2 and nothing else, exactly like C (see the Fortran memo in
# docs/fairness-audit.md). One <bench>.f90 -> /app/<bench>.
# Requires the prebuilt base image:  docker build -f languages/_base/Dockerfile.qemu-insn -t lang-lab-qemu-insn .
ARG GCC_VERSION=14
FROM gcc:${GCC_VERSION}
ARG GCC_VERSION
ENV LANG_VERSION=${GCC_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

# Record the toolchain and the fp-contract / wrapv defaults next to C's (build log).
RUN gfortran --version | head -1 \
 && gfortran -O2 -Q --help=common | grep -E 'fp-contract|wrapv'

WORKDIR /app
COPY languages/fortran/*.f90 /app/
RUN for f in /app/*.f90; do gfortran -O2 "$f" -o "/app/$(basename "$f" .f90)"; done \
 && rm -f /app/*.mod \
 && ldd /app/fannkuch
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "fortran", "fannkuch", "--", "/app/fannkuch"]
