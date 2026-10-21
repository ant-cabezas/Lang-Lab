# Build context is the repo root: docker build -f languages/ocaml/Dockerfile .
# Requires the prebuilt base image:  docker build -f languages/_base/Dockerfile.qemu-insn -t lang-lab-qemu-insn .
# Plain ocamlopt, default flags: no flambda, no -unsafe, no -O3, no OCAMLRUNPARAM (see docs/fairness-audit.md).
ARG OCAML_VERSION=5.4
FROM ocaml/opam:debian-12-ocaml-${OCAML_VERSION}
ARG OCAML_VERSION
ENV LANG_VERSION=${OCAML_VERSION}
USER root
# The image's entrypoint is `opam exec --` (prints warnings as root, injects env): drop it and
# put the switch's bin on PATH instead, so measure.sh runs the bare binaries.
ENTRYPOINT []
ENV PATH=/home/opam/.opam/${OCAML_VERSION}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

# Fail the build if the switch is flambda (it would change the whole inlining story).
# Keep the exact compiler version next to the binaries for the record.
RUN ocamlopt -config | grep -q '^flambda: false' \
 && mkdir -p /app && ocamlopt -version | tee /app/OCAMLOPT_VERSION

WORKDIR /app
COPY languages/ocaml/*.ml /app/
RUN for f in /app/*.ml; do ocamlopt "$f" -o "/app/$(basename "$f" .ml)"; done \
 && rm -f /app/*.cmi /app/*.cmx /app/*.o
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "ocaml", "fannkuch", "--", "/app/fannkuch"]
