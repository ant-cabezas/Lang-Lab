#!/usr/bin/env bash
# Builds one language's TeaVM artifacts, one benchmark at a time (intermediates are deleted
# per benchmark: TeaVM's C output is several MB each and the Docker VM disk is tiny).
#   build.sh <java|kotlin|scala> <src-dir> <out-dir>
# Per benchmark <b>, from the canonical <src-dir>/<b>.<ext> (never edited):
#   (kotlinc 2.1.0 cannot parse the 4-component java.version "25.0.4.1", so it runs on JRE 21;
#    its class-file target is independent of the JVM it runs on)
#   1. compile ONCE to class files (javac --release 25 / kotlinc 2.1.0 / scalac 3.6.2)
#   2. the SAME class files go to both TeaVM backends (same -O level, same heap sizes):
#        -t C    -> all.c -> /opt/llvm/bin/clang -O2   -> <out>/native/<b>
#        -t wasi -> <b>.wasm -> wasmtime compile       -> <out>/wasm/<b>.{wasm,cwasm}
# A benchmark that fails to build is recorded in <out>/BUILD-FAIL.txt (with the first error
# lines) instead of aborting, so the report can name it N/A with evidence.
set -u
lang=$1; src=$2; out=$3
J=/opt/jars
TEAVM_O=${TEAVM_O:-3}
TEAVM_MINHEAP=${TEAVM_MINHEAP:-32}
TEAVM_MAXHEAP=${TEAVM_MAXHEAP:-512}
CFLAGS_NATIVE=${CFLAGS_NATIVE:--O2}
WASMTIME_COMPILE_FLAGS=${WASMTIME_COMPILE_FLAGS:-}
TEAVM_CP=$(grep -v '^#' /opt/teavm/jars.lock | awk '$2 ~ /teavm|commons|jzlib|joda|hppc|asm|rhino|httpcore|javax/ {print "'$J'/" $2}' | paste -sd: -)
SCALA_CP=$(grep -v '^#' /opt/teavm/jars.lock | awk '$2 ~ /scala|jline|jna|sbt/ {print "'$J'/" $2}' | paste -sd: -)
SCALA_LIB=$J/org/scala-lang/scala3-library_3/3.6.2/scala3-library_3-3.6.2.jar:$J/org/scala-lang/scala-library/2.13.15/scala-library-2.13.15.jar
KOTLIN_LIB=/opt/kotlinc/lib/kotlin-stdlib.jar
mkdir -p "$out/native" "$out/wasm"; : > "$out/BUILD-FAIL.txt"
work=$(mktemp -d)
case $lang in java) ext=java;; kotlin) ext=kt;; scala) ext=scala;; esac

for f in "$src"/*.$ext; do
  b=$(basename "$f" .$ext)
  case "$b" in *-par|message-ring) continue;; esac
  pascal=$(printf '%s' "$b" | awk -F- '{s="";for(i=1;i<=NF;i++){w=$i;s=s toupper(substr(w,1,1)) substr(w,2)};print s}')
  rm -rf "$work"/*; mkdir -p "$work/cls"
  case $lang in
    java)   main=$pascal; libcp=""
            javac --release 25 -d "$work/cls" "$f" 2>"$work/err" ;;
    kotlin) main="$(printf '%s' "${b^}" | tr - _)Kt"; libcp=$KOTLIN_LIB
            JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 kotlinc "$f" -d "$work/cls" 2>"$work/err" ;;
    scala)  main=$pascal; libcp=$SCALA_LIB
            java -cp "$SCALA_CP" dotty.tools.dotc.Main -classpath "$SCALA_CP" -d "$work/cls" "$f" 2>"$work/err" ;;
  esac
  if [ $? -ne 0 ]; then { echo "== $b: front-end compile failed"; head -20 "$work/err"; } >> "$out/BUILD-FAIL.txt"; continue; fi
  run_teavm() { # <target> <outdir> <file-name>
    java -cp "$work/cls:${libcp:+$libcp:}$TEAVM_CP" org.teavm.cli.TeaVMRunner -t "$1" -O "$TEAVM_O" \
      --min-heap "$TEAVM_MINHEAP" --max-heap "$TEAVM_MAXHEAP" -d "$2" ${3:+-f "$3"} "$main" >"$work/tv.log" 2>&1
    # TeaVM exits 0 even on "built with errors": look at the log
    ! grep -q -E '^ERROR|built with errors|Exception' "$work/tv.log"
  }
  # native column: TeaVM -t C, then LLVM clang
  if run_teavm C "$work/c" "" && /opt/llvm/bin/clang $CFLAGS_NATIVE -o "$out/native/$b" "$work/c/all.c" -lm 2>"$work/cc.log"; then :;
  else { echo "== $b: TeaVM C backend / clang failed"; grep -E '^ERROR|Exception|error:' "$work/tv.log" "$work/cc.log" | head -8; } >> "$out/BUILD-FAIL.txt"; fi
  rm -rf "$work/c"
  # wasm column: TeaVM -t wasi, then wasmtime AOT precompile
  if run_teavm wasi "$work/w" "$b.wasm"; then
    cp "$work/w/$b.wasm" "$out/wasm/$b.wasm" && wasmtime compile $WASMTIME_COMPILE_FLAGS "$out/wasm/$b.wasm" -o "$out/wasm/$b.cwasm"
  else { echo "== $b: TeaVM wasi backend failed"; grep -E '^ERROR|Exception' "$work/tv.log" | head -8; } >> "$out/BUILD-FAIL.txt"; fi
  echo "built $lang/$b"
done
rm -rf "$work"
