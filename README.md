# OpenClaw Vagrant Box

This repository contains the Packer template to build a Vagrant box for OpenClaw - an AI assistant platform. Supports both AMD64 and ARM64 architectures.

## Prerequisites

For macOS (especially Apple Silicon Macs):

1. Install Homebrew (if not already installed):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Install required tools:
   ```bash
   # Tap HashiCorp repository
   brew tap hashicorp/tap
   
   # Install Packer
   brew install hashicorp/tap/packer
   
   # Install Vagrant
   brew install vagrant
   
   # Install QEMU for ARM64 support (essential for Apple Silicon)
   brew install qemu
   ```

3. Install Packer QEMU plugin (required for ARM64 builds):
   ```bash
   # Install the QEMU plugin directly
   packer plugins install github.com/hashicorp/qemu
   ```

4. Install Vagrant QEMU plugin (for ARM64 Vagrant support):
   ```bash
   vagrant plugin install vagrant-qemu
   ```

For AMD64 builds, you may also want VirtualBox:
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

## Important Note about ARM64 Support

Currently, VirtualBox has limited support for ARM64 guests. The Packer template will attempt to build for ARM64 using the ARM64 Debian ISO, but VirtualBox may not properly emulate ARM64 hardware.

For proper ARM64 support on Apple Silicon Macs, you have two options:

1. **Use QEMU with Packer** (recommended for ARM64):
   - Install the Packer QEMU plugin as described above
   - This provides native ARM64 virtualization on Apple Silicon

2. **Use VirtualBox with AMD64 ISO** (fallback option):
   - The template will work with AMD64 Debian ISO on VirtualBox
   - This will run AMD64 Debian under emulation, which is slower but functional

## Building the Vagrant Box

1. Ensure all required software is installed:
   ```bash
   packer version
   vagrant version
   ```

2. Navigate to this directory:
   ```bash
   cd openclaw-debian
   ```

3. Build the box with Packer for your architecture:

   For AMD64 (Intel/AMD):
   ```bash
   packer build -var="arch=amd64" openclaw-debian.pkr.hcl
   ```
   
   For ARM64 (Apple Silicon Macs, Raspberry Pi):
   ```bash
   packer build -var="arch=arm64" openclaw-debian.pkr.hcl
   ```
   
   Or use the provided build script:
   ```bash
   # For AMD64:
   ./build.sh amd64
   
   # For ARM64:
   ./build.sh arm64
   ```

4. After successful build, the resulting `.box` file can be added to Vagrant:
   
   For both AMD64 and ARM64 (current implementation uses VirtualBox output):
   ```bash
   vagrant box add openclaw/openclaw package/output-virtualbox-iso/openclaw-*.box
   ```
   
   Note: For ARM64, the output will be a VirtualBox format box, but VirtualBox has limited ARM64 support. 
   For proper ARM64 virtualization, install the Packer QEMU plugin and modify the template accordingly.

## Using the Vagrant Box

1. Create a new directory for your OpenClaw instance:
   ```bash
   mkdir openclaw-instance
   cd openclaw-instance
   ```

2. Initialize the Vagrant environment:

   For AMD64:
   ```bash
   vagrant init openclaw/openclaw
   ```
   
   For ARM64:
   ```bash
   vagrant init openclaw/openclaw-arm64
   ```

3. Start the VM:
   ```bash
   vagrant up
   ```

4. Access OpenClaw at `http://localhost:3000`

## Configuration

The VM comes with:
- Debian 12 (Bookworm) base OS (matching architecture)
- Node.js v22
- Bun runtime
- All dependencies required by OpenClaw
- OpenClaw application pre-built and ready to run

## Ports

- `3000`: OpenClaw web interface
- `8080`: Alternative port for OpenClaw

## SSH Access

You can SSH into the VM with:
```bash
vagrant ssh
```

The OpenClaw application is located in `/app` directory.

## Notes for Apple Silicon Macs (ARM64)

For the best experience on Apple Silicon Macs, consider using QEMU provider for Vagrant:
1. Install the Vagrant QEMU plugin:
   ```bash
   vagrant plugin install vagrant-qemu
   ```
2. Use the ARM64 box with the QEMU provider

## Troubleshooting

### On macOS, if you encounter issues with command-line tools:

1. If packer command is not found after installation:
   ```bash
   # Make sure HashiCorp tap is added
   brew tap hashicorp/tap
   # Then install packer
   brew install hashicorp/tap/packer
   ```

2. If you get permission errors during Packer builds:
   - Make sure you have sufficient disk space for VM creation
   - Check that no other VM applications are consuming excessive resources

3. For ARM64 builds specifically:
   - Ensure QEMU is installed: `brew install qemu`
   - Consider increasing allocated memory in the Packer template if builds fail