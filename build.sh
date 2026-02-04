#!/bin/bash

set -e

ARCH=${1:-"amd64"}  # Default to amd64, but accept arm64 as argument

echo "Building OpenClaw Vagrant Box with Packer for architecture: $ARCH"
echo "This will download Debian ISO, create a VM, install OpenClaw, and package it as a Vagrant box."
echo ""

# Check if required tools are available
if ! command -v packer &> /dev/null; then
    echo "Error: Packer is not installed. Please install Packer first."
    exit 1
fi

if [ "$ARCH" = "arm64" ]; then
    # For ARM64, check if QEMU is available
    if ! command -v qemu-system-aarch64 &> /dev/null; then
        echo "Warning: qemu-system-aarch64 is not installed. For ARM64 builds, QEMU is recommended."
        echo "On macOS, you can install with: brew install qemu"
        echo "On Ubuntu/Debian: sudo apt install qemu-system-arm"
        echo "VirtualBox has limited ARM64 support."
    fi
    
    echo "Starting Packer build process for ARM64..."
    packer build -var="arch=arm64" openclaw-debian.pkr.hcl
elif [ "$ARCH" = "amd64" ]; then
    if ! command -v VBoxManage &> /dev/null; then
        echo "Error: VirtualBox is not installed. Please install VirtualBox first."
        exit 1
    fi
    
    echo "Starting Packer build process for AMD64..."
    packer build -var="arch=amd64" openclaw-debian.pkr.hcl
else
    echo "Usage: $0 [amd64|arm64]"
    echo "Supported architectures: amd64 (default), arm64"
    exit 1
fi

echo ""
echo "Build completed successfully!"
echo ""
if [ "$ARCH" = "arm64" ]; then
    echo "To add the ARM64 box to Vagrant, run:"
    echo "  vagrant box add openclaw/openclaw-arm64 package/output-qemu/openclaw-*.box"
    echo ""
    echo "For ARM64, you may need to use libvirt/QEMU provider in Vagrant."
else
    echo "To add the box to Vagrant, run:"
    echo "  vagrant box add openclaw/openclaw package/output-virtualbox-iso/openclaw-*.box"
    echo ""
fi
echo "Then create a new directory, initialize Vagrant, and start the VM:"
echo "  mkdir openclaw-vm && cd openclaw-vm"
echo "  vagrant init openclaw/openclaw"
echo "  vagrant up"
echo ""