#!/usr/bin/env python3
# WebAssembly side study, frames diagnostic (a timing probe, not a fix): rewrites the named functions of a
# wasmtime .cwasm so Cranelift's chained pre-index register pushes and post-index pops become one stack
# adjustment with offset-addressed saves, the form clang and V8 use. Instruction count, frame size and saved
# registers are unchanged; .eh_frame is not updated. Runs inside the lane image (needs /opt/llvm/bin/clang
# and objcopy). The disassembly argument is `wasmtime objdump --color never --addresses <in.cwasm>`.
# usage: repatch.py <in.cwasm> <out.cwasm> <disasm-with-addresses> func1 func2 ...
# Rewrites each named function's chained pre-index pushes / post-index pops into one sp adjustment
# with offset-addressed saves (same instruction count, same frame size, same saved registers).
import re,subprocess,sys,os
src,dst,dis=sys.argv[1:4]; funcs=sys.argv[4:]; TEXT=0x10000
b=bytearray(open(src,'rb').read())
lines=open(dis).read().split('\n')
def asm(ins):
    open('/tmp/p.S','w').write('\n'.join(ins)+'\n')
    subprocess.check_call(['/opt/llvm/bin/clang','--target=aarch64-linux-gnu','-c','/tmp/p.S','-o','/tmp/p.o'])
    subprocess.check_call(['objcopy','-O','binary','-j','.text','/tmp/p.o','/tmp/p.bin'])
    return open('/tmp/p.bin','rb').read()
for fn in funcs:
    i=next(k for k,l in enumerate(lines) if l.endswith('::'+fn+':'))
    body=[]
    for l in lines[i+1:]:
        if re.match(r'^[0-9a-f]{8} ',l): break
        m=re.match(r'^\s+([0-9a-f]+):\s+(.*)$',l)
        if m: body.append((int(m.group(1),16),m.group(2).strip()))
    assert body[0][1]=='stp     x29, x30, [sp, #-0x10]!', body[0]
    pushes=[(a,t) for a,t in body if re.match(r'(stp|str)\s+.*\[sp, #-0x10\]!$',t)]
    # pushes after the fp/lr one
    saves=pushes[1:]; n=len(saves); F=16*(n+1)
    regs=[re.match(r'(stp|str)\s+(.*), \[sp',t).group(1,2) for a,t in saves]
    # slot of the k-th push (k=0 first pushed, highest address): offset F-16*(k+1)
    slot={r:F-16*(k+1) for k,(op,r) in enumerate(regs)}
    patches=[(body[0][0],asm([f'stp x29, x30, [sp, #-{F}]!']))]
    for (a,t),(op,r) in zip(saves,regs): patches.append((a,asm([f'{op} {r}, [sp, #{slot[r]}]'])))
    for (a,t) in body:
        m=re.match(r'(ldp|ldr)\s+(.*), \[sp\], #0x10$',t)
        if m:
            op,r=m.group(1,2)
            if r=='x29, x30': patches.append((a,asm([f'ldp x29, x30, [sp], #{F}'])))
            else: patches.append((a,asm([f'{op} {r}, [sp, #{slot[r]}]'])))
    # no other sp use allowed
    for a,t in body:
        if 'sp' in t and not any(a==p for p,_ in patches) and t not in ('mov     x29, sp',) and not t.startswith('cmp     sp, x16'):
            raise SystemExit(f'{fn}: unexpected sp use at {a:x}: {t}')
    for a,blob in patches:
        assert len(blob)==4; b[TEXT+a:TEXT+a+4]=blob
    print(fn,'frame',F,'saves',regs,'patched',len(patches))
open(dst,'wb').write(b)
