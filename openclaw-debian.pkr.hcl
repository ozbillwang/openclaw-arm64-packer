variable "version" {
  type    = string
  default = "1.0.0"
}

variable "arch" {
  type    = string
  default = "amd64"  # Can be amd64 or arm64
}

variable "headless" {
  type    = string
  default = "true"
}

locals {
  vm_name = "openclaw-${var.version}-${var.arch}"
}

# Source definition for VirtualBox ISO builder
source "virtualbox-iso" "openclaw" {
  vm_name           = local.vm_name
  guest_os_type     = var.arch == "arm64" ? "Debian_64" : "Debian_64"  # VirtualBox doesn't distinguish well between arch types
  disk_size         = 10000
  
  dynamic "iso_config" {
    for_each = var.arch == "arm64" ? [
      {
        url      = "https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-12.8.0-arm64-netinst.iso"
        checksum = "sha256:079cd351af2d9985f14da2abc6bb92a759e8d49e8c4f3245d71398a31e2e922f"
      }
    ] : [
      {
        url      = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso"
        checksum = "sha256:aac3f3dee934bc10f1eeb6a72e417bf051e8dead14781533b0655ed04c8fe3b6"
      }
    ]
    content {
      iso_url      = iso_config.value.url
      iso_checksum = iso_config.value.checksum
    }
  }
  
  ssh_username      = "vagrant"
  ssh_password      = "vagrant"
  ssh_port          = 22
  ssh_wait_timeout  = "10000s"
  shutdown_command  = "echo 'vagrant' | sudo -S shutdown -h now"
  
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--memory", "2048"],
    ["modifyvm", "{{.Name}}", "--cpus", "2"]
  ]

  # Different boot commands for ARM64 vs AMD64
  dynamic "boot_cmd" {
    for_each = var.arch == "arm64" ? [
      ["<wait2s><esc><wait>", "install <wait>",
       " preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/preseed.cfg <wait>",
       "debian-installer=en_US.UTF-8 <wait>",
       "auto <wait>",
       "locale=en_US.UTF-8 <wait>",
       "kbd-chooser/method=us <wait>",
       "keyboard-configuration/xkb-keymap=us <wait>",
       "netcfg/get_hostname={{user `vm_name`}} <wait>",
       "netcfg/get_domain=vagrantup.com <wait>",
       "<enter><wait>"]
    ] : [
      ["<esc><wait>",
       "install <wait>",
       " preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/preseed.cfg <wait>",
       "debian-installer=en_US.UTF-8 <wait>",
       "auto <wait>",
       "locale=en_US.UTF-8 <wait>",
       "kbd-chooser/method=us <wait>",
       "keyboard-configuration/xkb-keymap=us <wait>",
       "netcfg/get_hostname={{user `vm_name`}} <wait>",
       "netcfg/get_domain=vagrantup.com <wait>",
       "<enter><wait>"]
    ]
    content {
      boot_command = boot_cmd.value
    }
  }

  http_directory = "."
}

# Also add a QEMU builder for better ARM64 support
source "qemu" "openclaw_arm64" {
  # Only build for ARM64 with QEMU since VirtualBox has limited ARM64 support
  count             = var.arch == "arm64" ? 1 : 0
  vm_name           = local.vm_name
  format            = "qcow2"
  disk_image        = true
  iso_url           = "https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-12.8.0-arm64-netinst.iso"
  iso_checksum      = "sha256:079cd351af2d9985f14da2abc6bb92a759e8d49e8c4f3245d71398a31e2e922f"
  qemu_binary       = "qemu-system-aarch64"
  floppy_files      = []
  
  # Additional QEMU args for ARM64
  qemuargs = [
    ["-machine", "virt"],
    ["-cpu", "cortex-a57"],  # Compatible ARM64 CPU
    ["-m", "2048"],
    ["-smp", "2"]
  ]
  
  ssh_username      = "vagrant"
  ssh_password      = "vagrant"
  ssh_port          = 22
  ssh_wait_timeout  = "10000s"
  shutdown_command  = "echo 'vagrant' | sudo -S shutdown -h now"
  
  boot_command = [
    "<wait2s><esc><wait>",
    "install <wait>",
    " preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/preseed.cfg <wait>",
    "debian-installer=en_US.UTF-8 <wait>",
    "auto <wait>",
    "locale=en_US.UTF-8 <wait>",
    "kbd-chooser/method=us <wait>",
    "keyboard-configuration/xkb-keymap=us <wait>",
    "netcfg/get_hostname={{user `vm_name`}} <wait>",
    "netcfg/get_domain=vagrantup.com <wait>",
    "<enter><wait>"
  ]
}

# Build block to reference the source
build {
  name = "openclaw-vagrant-${var.arch}"
  
  dynamic "sources" {
    for_each = var.arch == "arm64" ? [
      "source.qemu.openclaw_arm64"
    ] : [
      "source.virtualbox-iso.openclaw"
    ]
    content {
      sources = sources.value
    }
  }

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y sudo curl wget git vim"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'vagrant ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/vagrant",
      "chmod 440 /etc/sudoers.d/vagrant"
    ]
  }

  # Install architecture-specific Node.js
  provisioner "shell" {
    inline = [
      "# Install Node.js v22 with architecture detection",
      "ARCH=$(uname -m)",
      "if [ \"$ARCH\" = \"aarch64\" ] || [ \"$ARCH\" = \"arm64\" ]; then",
      "  # For ARM64 systems",
      "  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -",
      "  sudo apt-get install -y nodejs",
      "else",
      "  # For AMD64 systems",
      "  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -",
      "  sudo apt-get install -y nodejs",
      "fi",
      "node --version"
    ]
  }

  provisioner "shell" {
    inline = [
      "# Install Bun (required for build scripts)",
      "curl -fsSL https://bun.sh/install | bash",
      "export PATH=\"/root/.bun/bin:$PATH\"",
      "echo 'export PATH=\"/root/.bun/bin:$PATH\"' >> /home/vagrant/.bashrc"
    ]
  }

  provisioner "shell" {
    inline = [
      "# Enable corepack",
      "corepack enable"
    ]
  }

  provisioner "shell" {
    inline = [
      "# Install common packages needed for OpenClaw",
      "# Architecture-specific package installation",
      "ARCH=$(dpkg --print-architecture)",
      "echo \"Installing packages for architecture: $ARCH\"",
      "sudo apt-get update",
      "if [ \"$ARCH\" = \"arm64\" ] || [ \"$ARCH\" = \"aarch64\" ]; then",
      "  # ARM64-specific packages",
      "  sudo apt-get install -y --no-install-recommends \\",
      "    ca-certificates \\",
      "    curl \\",
      "    gnupg \\",
      "    lsb-release \\",
      "    build-essential \\",
      "    python3 \\",
      "    python3-pip \\",
      "    libnss3-tools \\",
      "    jq \\",
      "    ffmpeg \\",
      "    graphicsmagick \\",
      "    imagemagick \\",
      "    libvips-dev \\",
      "    xvfb \\",
      "    x11-utils \\",
      "    x11-xserver-utils \\",
      "    xdg-utils \\",
      "    x11-apps \\",
      "    xorg \\",
      "    wmctrl \\",
      "    libxtst6 \\",
      "    libxss1 \\",
      "    libgtk-3-0 \\",
      "    libgbm1 \\",
      "    libu2f-udev \\",
      "    libvulkan1 \\",
      "    libasound2 \\",
      "    fonts-liberation \\",
      "    libappindicator3-1 \\",
      "    libsecret-1-0 \\",
      "    libnss3 \\",
      "    libxkbcommon0 \\",
      "    libxcomposite1 \\",
      "    libxdamage1 \\",
      "    libxrandr2 \\",
      "    libxss1 \\",
      "    libasound2 \\",
      "    libpangocairo-1.0-0 \\",
      "    libatk1.0-0 \\",
      "    libcairo-gobject2 \\",
      "    libgdk-pixbuf-2.0-0 \\",
      "    libgtk-3-0 \\",
      "    && apt-get clean \\",
      "    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*",
      "else",
      "  # AMD64 packages (original list)",
      "  sudo apt-get install -y --no-install-recommends \\",
      "    ca-certificates \\",
      "    curl \\",
      "    gnupg \\",
      "    lsb-release \\",
      "    build-essential \\",
      "    python3 \\",
      "    python3-pip \\",
      "    libnss3-tools \\",
      "    jq \\",
      "    ffmpeg \\",
      "    graphicsmagick \\",
      "    imagemagick \\",
      "    libvips-dev \\",
      "    xvfb \\",
      "    x11-utils \\",
      "    x11-xserver-utils \\",
      "    xdg-utils \\",
      "    x11-apps \\",
      "    xorg \\",
      "    wmctrl \\",
      "    libxtst6 \\",
      "    libxss1 \\",
      "    libgtk-3-0 \\",
      "    libgbm1 \\",
      "    libu2f-udev \\",
      "    libvulkan1 \\",
      "    libasound2 \\",
      "    fonts-liberation \\",
      "    libappindicator3-1 \\",
      "    libsecret-1-0 \\",
      "    libnss3 \\",
      "    libxkbcommon0 \\",
      "    libxcomposite1 \\",
      "    libxdamage1 \\",
      "    libxrandr2 \\",
      "    libxss1 \\",
      "    libasound2 \\",
      "    libpangocairo-1.0-0 \\",
      "    libatk1.0-0 \\",
      "    libcairo-gobject2 \\",
      "    libgdk-pixbuf-2.0-0 \\",
      "    libgtk-3-0 \\",
      "    libxss1 \\",
      "    libatspi2.0-0 \\",
      "    libxcomposite1 \\",
      "    libxdamage1 \\",
      "    libxrandr2 \\",
      "    libgbm1 \\",
      "    libxkbcommon0 \\",
      "    libdrm2 \\",
      "    libxfixes3 \\",
      "    libxrender1 \\",
      "    libgconf-2-4 \\",
      "    libxshmfence1 \\",
      "    libgtk-3-0 \\",
      "    libnss3 \\",
      "    libgdk-pixbuf-2.0-0 \\",
      "    libpangoft2-1.0-0 \\",
      "    libpangocairo-1.0-0 \\",
      "    libatk1.0-0 \\",
      "    libcairo-gobject2 \\",
      "    libpixman-1-0 \\",
      "    libxcb-shm0 \\",
      "    libxcb-render0 \\",
      "    libxcb-randr0 \\",
      "    libxcb-xfixes0 \\",
      "    libxcb-shape0 \\",
      "    libxcb-xinerama0 \\",
      "    libxcb-sync1 \\",
      "    libxcb-present1 \\",
      "    libxcb-dri3-0 \\",
      "    libxcb-dri2-0 \\",
      "    libxcb-glx0 \\",
      "    libxcb-xinput0 \\",
      "    libxkbcommon-x11-0 \\",
      "    && apt-get clean \\",
      "    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*",
      "fi"
    ]
  }

  provisioner "shell" {
    inline = [
      "# Create app directory and switch to it",
      "sudo mkdir -p /app",
      "sudo chown vagrant:vagrant /app",
      "cd /app"
    ]
  }

  provisioner "shell" {
    inline = [
      "# Clone OpenClaw repository",
      "cd /app",
      "git clone https://github.com/openclaw/openclaw.git .",
      "ls -la"
    ]
  }

  provisioner "shell" {
    inline = [
      "# Install dependencies using pnpm",
      "cd /app",
      "pnpm install --frozen-lockfile"
    ]
    expect_disconnect = false
  }

  provisioner "shell" {
    inline = [
      "# Build OpenClaw application",
      "cd /app",
      "export OPENCLAW_A2UI_SKIP_MISSING=1",
      "pnpm build",
      "export OPENCLAW_PREFER_PNPM=1",
      "pnpm ui:build"
    ]
    expect_disconnect = false
  }

  provisioner "shell" {
    inline = [
      "# Set production environment",
      "echo 'export NODE_ENV=production' >> /home/vagrant/.bashrc"
    ]
  }

  provisioner "shell" {
    inline = [
      "# Set ownership to vagrant user",
      "sudo chown -R vagrant:vagrant /app"
    ]
  }

  provisioner "shell" {
    inline = [
      "# Install Vagrant insecure key for easy SSH access",
      "mkdir -p /home/vagrant/.ssh",
      "chmod 700 /home/vagrant/.ssh",
      "wget --no-check-certificate 'https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub' -O /home/vagrant/.ssh/authorized_keys",
      "chmod 600 /home/vagrant/.ssh/authorized_keys",
      "chown -R vagrant:vagrant /home/vagrant/.ssh"
    ]
  }

  provisioner "shell" {
    inline = [
      "# Clean up for smaller VM size",
      "sudo rm -rf /var/cache/* /var/log/*",
      "sudo dd if=/dev/zero of=/EMPTY bs=1M",
      "sudo rm -f /EMPTY"
    ]
  }
}