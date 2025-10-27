#!/usr/bin/env bash
set -e

pkg_dir=$1

if [ -z "$pkg_dir" ] || [ ! -d "$pkg_dir" ]; then
    echo "Usage: ipkg-make-index <package_directory>" >&2
    exit 1
fi

empty=1

for pkg in $(find "$pkg_dir" -maxdepth 1 -name '*.ipk' | sort); do
    empty=
    name="${pkg##*/}"
    name="${name%%_*}"
    [[ "$name" = "kernel" ]] && continue
    [[ "$name" = "libc" ]] && continue

    echo "Generating index for package $pkg" >&2

    file_size=$(stat -L -c%s "$pkg")
    sha256sum=$(sha256sum "$pkg" | cut -d' ' -f1)
    filename=$(basename "$pkg")
    filetype=$(file -b "$pkg")
    control=""

    if echo "$filetype" | grep -q "current ar archive"; then
        control=$(ar p "$pkg" control.tar.gz | tar -xzO ./control 2>/dev/null || \
                  ar p "$pkg" control.tar.xz | tar -xJO ./control 2>/dev/null || true)
    else
        control=$(tar -Oxf "$pkg" ./control.tar.gz 2>/dev/null | tar -xzO ./control 2>/dev/null || \
                  tar -Oxf "$pkg" ./control.tar.xz 2>/dev/null | tar -xJO ./control 2>/dev/null || true)
    fi

    if [ -z "$control" ]; then
        echo "Warning: failed to extract control file from $pkg" >&2
        continue
    fi

    echo "$control" | sed -e "s/^Description:/Filename: $filename\\
Size: $file_size\\
SHA256sum: $sha256sum\\
Description:/"

    echo ""
done

[ -n "$empty" ] && echo
exit 0
