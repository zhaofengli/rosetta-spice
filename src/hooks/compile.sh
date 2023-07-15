#!/usr/bin/env bash
set -euo pipefail

: "${CC:=gcc}"
: "${OBJCOPY:=objcopy}"

src="$1"
dst="$2"
name="${src%.c}"
obj=$(mktemp)
base=$(dirname $0)

cleanup() {
	rm -f "$obj"
}
trap cleanup EXIT

set -x

"$CC" \
	-fPIC \
	-fno-pic \
	-fno-plt \
	-ffreestanding \
	-nostdlib \
	-nodefaultlibs \
	-nostartfiles \
	-fno-exceptions \
	-fno-unwind-tables \
	-fno-asynchronous-unwind-tables \
	-fno-stack-protector \
	-ffunction-sections \
	-Wl,--gc-sections \
	-U_FORTIFY_SOURCE \
	-O2 \
	-Wl,-T,"${base}/hook.ld" \
	-Wl,--no-warn-rwx-segments \
	-I"${base}/../../vendor/nolibc" \
	-o "$obj" "$src"
"$OBJCOPY" -O binary "$obj" "$dst"
