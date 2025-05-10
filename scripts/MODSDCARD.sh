#!/bin/bash

# Source the include file containing common functions and variables
if [[ ! -f "./scripts/INCLUDE.sh" ]]; then
    echo "ERROR: INCLUDE.sh not found in ./scripts/" >&2
    exit 1
fi

set -o errexit  # Exit on error
set -o nounset  # Exit on unset variables
set -o pipefail # Exit if any command in a pipe fails

. ./scripts/INCLUDE.sh

build_mod_sdcard() {
    local image_path="$1"
    local dtb="$2"
    local suffix="$3"

    log "STEPS" "Modifying boot files for Amlogic s905x devices..."

    # Validasi parameter
    if [[ -z "$image_path" || -z "$dtb" || -z "$suffix" ]]; then
        error_msg "Missing parameters. Usage: build_mod_sdcard <image_path> <dtb> <suffix>"
        return 1
    fi

    local img_dir="$GITHUB_WORKSPACE/$WORKING_DIR/compiled_images"
    if ! cd "$img_dir"; then
        error_msg "Cannot enter compiled_images directory: $img_dir"
        return 1
    fi

    local file_to_process="$image_path"
    local file_name
    file_name=$(basename "${file_to_process%.gz}")

    # Trap untuk cleanup
    cleanup() {
        log "INFO" "Cleaning up temporary mounts and loop devices..."
        sudo umount boot 2>/dev/null || true
        sudo losetup -D 2>/dev/null || true
    }
    trap cleanup EXIT

    # Pastikan file image ada
    if [[ ! -f "$file_to_process" ]]; then
        error_msg "Image file not found: $file_to_process"
        return 1
    fi

    # Download & extract mod-boot-sdcard
    ariadl "https://github.com/rizkikotet-dev/mod-boot-sdcard/archive/refs/heads/main.zip" "main.zip"
    log "INFO" "Extracting boot patch..."
    unzip -oq main.zip || { error_msg "Failed to unzip main.zip"; return 1; }
    rm -f main.zip
    sleep 2

    # Persiapan direktori
    mkdir -p "${suffix}/boot"
    cp "$file_to_process" "${suffix}/" || return 1
    cp mod-boot-sdcard-main/BootCardMaker/u-boot.bin mod-boot-sdcard-main/files/mod-boot-sdcard.tar.gz "${suffix}/" || return 1

    cd "${suffix}" || return 1

    # Decompress image
    gunzip -f "${file_name}.gz" || { error_msg "Gagal decompress"; return 1; }

    # Setup loop device
    log "INFO" "Setting up loop device..."
    local device
    for i in {1..3}; do
        device=$(sudo losetup -fP --show "$file_name" 2>/dev/null)
        [[ -n "$device" ]] && break
        sleep 1
    done
    [[ -z "$device" ]] && { error_msg "Gagal setup loop device"; return 1; }

    # Mount partisi
    log "INFO" "Mounting boot partition..."
    for attempt in {1..3}; do
        sudo mount "${device}p1" boot && break || sleep 1
    done
    mountpoint -q boot || { error_msg "Failed to mount image"; return 1; }

    # Apply boot mods
    log "INFO" "Applying boot modifications..."
    sudo tar -xzf mod-boot-sdcard.tar.gz -C boot || return 1

    # Update dtb & root param
    log "INFO" "Patching uEnv/extlinux/boot.ini..."
    local uenv_root=$(grep -oP 'root=\S+' boot/uEnv.txt | cut -d= -f2)
    sudo sed -i "s|root=\S*|root=$uenv_root|g" boot/extlinux/extlinux.conf
    sudo sed -i "s|dtb_name=.*|dtb_name=$dtb|g" boot/uEnv.txt
    sudo sed -i "s|meson.*\.dtb|$dtb|g" boot/boot.ini boot/extlinux/extlinux.conf

    sync
    sudo umount boot

    # Write u-boot
    log "INFO" "Writing u-boot..."
    sudo dd if=u-boot.bin of="$device" bs=1 count=444 conv=fsync status=none
    sudo dd if=u-boot.bin of="$device" bs=512 skip=1 seek=1 conv=fsync status=none

    # Cleanup loop
    sudo losetup -d "$device"

    # Compress dan rename
    gzip "$file_name" || return 1

    local kernel
    kernel=$(grep -oP 'k[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9-]+)?' <<<"$file_name")
    local new_name="${OP_BASE}-${BRANCH}-Mod_SDCard-${suffix}-${kernel}-${TUNNEL}.img.gz"
    mv "${file_name}.gz" "../${new_name}" || return 1

    cd ..
    rm -rf "${suffix}" mod-boot-sdcard-main

    log "SUCCESS" "Successfully processed ${suffix}"
    return 0
}

process_builds() {
    local img_dir="$1"
    shift
    local builds=("$@")
    local exit_code=0

    for build in "${builds[@]}"; do
        IFS=: read -r device dtb model <<< "$build"

        local image_file
        image_file=$(find "$img_dir" -type f -name "*${device}*.img.gz" | head -n1)

        if [[ -n "$image_file" && -f "$image_file" ]]; then
            log "INFO" "Processing image for ${model} (${device})"
            if ! build_mod_sdcard "$image_file" "$dtb" "$model"; then
                error_msg "Build failed for ${model} (${device})"
                exit_code=1
            fi
        else
            log "WARNING" "No image file found for ${model} (${device})"
        fi
    done

    return $exit_code
}

get_builds_for_target() {
    local dtb label prefix
    local kernels=("_k5.15" "_k6.1" "_k6.6")

    case "$MATRIXTARGET" in
        "Amlogic s905x HG680P")
            dtb="meson-gxl-s905x-p212.dtb"
            label="HG680P"
            prefix="_s905x_"
            ;;
        "Amlogic s905x B860H")
            dtb="meson-gxl-s905x-b860h.dtb"
            label="B860H"
            prefix="_s905x-b860h_"
            ;;
        *)
            log "ERROR" "Unsupported MATRIXTARGET: $MATRIXTARGET"
            return 1
            ;;
    esac

    for k in "${kernels[@]}"; do
        echo "${prefix}${k}:${dtb}:${label}"
    done
}

main() {
    local img_dir="$GITHUB_WORKSPACE/$WORKING_DIR/compiled_images"
    
    if [[ ! -d "$img_dir" ]]; then
        error_msg "Image directory not found: $img_dir"
        return 1
    fi

    log "INFO" "Gathering builds for target: $MATRIXTARGET"
    mapfile -t builds < <(get_builds_for_target)
    if [[ ${#builds[@]} -eq 0 ]]; then
        error_msg "No builds configured for target: $MATRIXTARGET"
        return 1
    fi

    log "INFO" "Processing ${#builds[@]} build(s)..."
    process_builds "$img_dir" "${builds[@]}"
}

# Execute main function
main
