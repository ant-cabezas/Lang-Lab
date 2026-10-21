# Build context is the repo root: docker build -f languages/vbnet/Dockerfile .
ARG DOTNET_VERSION=9.0
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}
ARG DOTNET_VERSION
ENV LANG_VERSION=${DOTNET_VERSION}

COPY --from=lang-lab-qemu-insn /plugin/qemu-aarch64 /opt/qi/qemu-aarch64
COPY --from=lang-lab-qemu-insn /plugin/libinsn.so   /opt/qi/libinsn.so
COPY --from=lang-lab-qemu-insn /plugin/lib          /opt/qi/lib

WORKDIR /app
# One subdirectory per benchmark (each has its own .vbproj + Program.vb - a .NET project
# can't hold two Main methods). Self-contained single-file → measurable as ONE process
# under qemu+insn (no `dotnet` muxer execve chain). Adding a benchmark = adding a subdir.
COPY languages/vbnet/ /app/src/
RUN RID="linux-$(uname -m | sed 's/aarch64/arm64/;s/x86_64/x64/')" \
 && for proj in /app/src/*/*.vbproj; do \
      b="$(basename "$(dirname "$proj")")"; \
      dotnet publish "$proj" -c Release -r "$RID" --self-contained true \
        -p:PublishSingleFile=true -p:DotnetVersion=${DOTNET_VERSION} -o "/app/out/$b"; \
    done
COPY scripts/measure.sh /usr/local/bin/measure.sh
RUN chmod +x /usr/local/bin/measure.sh

CMD ["/usr/local/bin/measure.sh", "vbnet", "fannkuch", "--", "/app/out/fannkuch/fannkuch"]
