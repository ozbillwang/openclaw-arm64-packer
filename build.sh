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
    # For ARM64, we currently use VirtualBox but recommend QEMU
    if ! command -v VBoxManage &> /dev/null; then
        echo "Error: VirtualBox is not installed. Please install VirtualBox first."
        echo "For better ARM64 support, also install QEMU and the Packer QEMU plugin:"
        echo "  brew install qemu"
        echo "  packer plugins install github.com/hashicorp/qemu"
        exit 1
    fi
    
    echo "Starting Packer build process for ARM64 (using VirtualBox - limited support)..."
    echo "Note: VirtualBox has limited ARM64 support. For better results, install QEMU plugin."
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
echo "To add the box to Vagrant, run:"
echo "  vagrant box add openclaw/openclaw package/output-virtualbox-iso/openclaw-*.box"
echo ""
echo "Then create a new directory, initialize Vagrant, and start the VM:"
echo "  mkdir openclaw-vm && cd openclaw-vm"
echo "  vagrant init openclaw/openclaw"
echo "  vagrant up"
echo ""