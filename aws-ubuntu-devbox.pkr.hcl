packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "golang_version" {
  type = string
}

variable "python_version" {
  type = string
}

variable "nvm_version" {
  type = string
}

variable "zig_version" {
  type = string
}

variable "source_image" {
  type = map(string)
}

variable "instance_type" {
  type = string
}

variable "region" {
  type = string
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "awesome-devbox-{{timestamp}}"
  instance_type = "${var.instance_type}"
  region        = "${var.region}"
  source_ami_filter {
    filters = {
      image-id            = "${var.source_image.image_id}"
      root-device-type    = "${var.source_image.root_device_type}"
      virtualization-type = "${var.source_image.virtualization_type}"
    }
    most_recent = true
    owners      = ["${var.source_image.owner}"]
  }
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    encrypted   = true
    volume_size = 32
  }

  ssh_username = "${var.source_image.ssh_username}"
}

build {
  name = "awesome-devbox"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  // Wait for cloud-init
  provisioner "shell" {
    inline = [
      "cloud-init status --wait"
    ]
  }

  // Update and upgrade the distro
  provisioner "shell" {
    inline = [
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",
      "sudo apt update",
      "sudo apt upgrade -y -q",
      "sudo apt autoremove -y",
      <<EOT
      sudo apt install -y \
          build-essential gcc g++ \
          libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
          libsqlite3-dev libncurses5-dev libncursesw5-dev xz-utils \
          tk-dev libffi-dev liblzma-dev openssl htop tree neofetch \
          ninja-build cmake moreutils netcat mold ccache
      EOT
    ]
  }

  // Install ZSH
  provisioner "file" {
    source      = "config-files/zshrc"
    destination = "$HOME/.zshrc"
  }

  provisioner "file" {
    source      = "config-files/p10k.zsh"
    destination = "$HOME/.p10k.zsh"
  }

  provisioner "shell" {
    inline = [
      "sudo apt update",
      "sudo apt install -y zsh",
      "sudo chsh -s $(which zsh) $USER",
      "touch $HOME/.zshrc",
      "wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O $HOME/ohmyzsh-install.sh",
      "sh $HOME/ohmyzsh-install.sh --keep-zshrc --unattended",
      "rm -f $HOME/ohmyzsh-install.sh",
      "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k",
    ]
  }

  // Install VIM
  provisioner "file" {
    source      = "config-files/vimrc"
    destination = "$HOME/.vimrc"
  }

  provisioner "shell" {
    inline = [
      "sudo add-apt-repository ppa:jonathonf/vim",
      "sudo apt update",
      "sudo apt install -y vim",
      "curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim",
      "vim -c '+:PlugInstall' -c '+:qa!'",
    ]
  }

  // Install AWS CLI
  provisioner "shell" {
    inline = [
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip\" -o \"awscliv2.zip\"",
      "unzip awscliv2.zip",
      "sudo ./aws/install",
      "rm -rf awscliv2.zip aws",
    ]
  }

  // Install Golang
  provisioner "shell" {
    inline = [
      "wget https://go.dev/dl/go${var.golang_version}.linux-arm64.tar.gz",
      "sudo tar -C /usr/local -xzf go${var.golang_version}.linux-arm64.tar.gz",
      "rm go${var.golang_version}.linux-arm64.tar.gz",
      "mkdir -p $HOME/go/bin",
      "echo '#Golang bin' >> ~/.zshrc",
      "echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.zshrc",
    ]
  }

  //Install Docker
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install ca-certificates curl",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      <<EOT
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        EOT
      ,
      "sudo apt-get update",
      "sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin -y",
      "sudo usermod -aG docker ubuntu",
    ]
  }

  // Install pyevn and python
  provisioner "shell" {
    inline = [
      "curl https://pyenv.run | zsh",
      "echo '#pyenv and python' >> ~/.zshrc",
      "echo 'export PYENV_ROOT=\"$HOME/.pyenv\"' >> $HOME/.zshrc",
      "echo '[[ -d $PYENV_ROOT/bin ]] && export PATH=\"$PYENV_ROOT/bin:$PATH\"' >> $HOME/.zshrc",
      "echo 'eval \"$(pyenv init -)\"' >> $HOME/.zshrc",
      "echo 'eval \"$(pyenv virtualenv-init -)\"' >> $HOME/.zshrc",

      "export PYENV_ROOT=$HOME/.pyenv",
      "export PATH=\"$PYENV_ROOT/bin:$PATH\"",
      "eval \"$(pyenv init -)\"",
      "eval \"$(pyenv virtualenv-init -)\"",
      "pyenv install ${var.python_version}",
      "pyenv virtualenv ${var.python_version} default",
      "pyenv global default",
      "pip install --upgrade pip",
      <<EOT
      pip install \
        requests aiohttp conan \
        pandas polars duckdb \
        cython matplotlib seaborn ipython jupyter \
        scikit-learn xgboost lightgbm catboost
      EOT
    ]
  }

  // Install nvm and nodejs
  provisioner "shell" {
    inline = [
      "git clone https://github.com/nvm-sh/nvm.git $HOME/.nvm",
      "cd $HOME/.nvm && git checkout v${var.nvm_version}",
      ". $HOME/.nvm/nvm.sh",
      "nvm install --lts",
      "nvm use --lts",

      "echo '#NVM and Nodejs' >> ~/.zshrc",
      "echo 'export NVM_DIR=\"$HOME/.nvm\"' >> ~/.zshrc",
      "echo '[ -s \"$NVM_DIR/nvm.sh\" ] && \\. \"$NVM_DIR/nvm.sh\"' >> ~/.zshrc",
      "echo '[ -s \"$NVM_DIR/bash_completion\" ] && \\. \"$NVM_DIR/bash_completion\"' >> ~/.zshrc",
    ]
  }

  // Install LLVM tools
  provisioner "shell" {
    inline = [
      "wget https://apt.llvm.org/llvm.sh -O $HOME/llvm.sh",
      "chmod +x $HOME/llvm.sh",
      "sudo $HOME/llvm.sh 17 all",
      "rm -f $HOME/llvm.sh",
      "echo '#LLVM' >> ~/.zshrc",
      "echo 'export PATH=/usr/lib/llvm-17/bin:$PATH' >> $HOME/.zshrc",
    ]
  }

  // Install Zig
  provisioner "shell" {
    inline = [
      "wget https://ziglang.org/download/${var.zig_version}/zig-linux-aarch64-${var.zig_version}.tar.xz",
      "tar -xf zig-linux-aarch64-${var.zig_version}.tar.xz",
      "sudo mv zig-linux-aarch64-${var.zig_version} /usr/local",
      "rm -f zig-linux-aarch64-${var.zig_version}.tar.xz",
      "echo '#Zig' >> $HOME/.zshrc",
      "echo 'export PATH=/usr/local/zig-linux-aarch64-${var.zig_version}:$PATH' >> $HOME/.zshrc",
      "source $HOME/.zshrc",
      "zig version",
    ]
  }

  // Install Rust
  provisioner "shell" {
    inline = [
      "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | zsh -s -- -y",
      "echo '. \"$HOME/.cargo/env\"' >> $HOME/.zshrc",
      ". \"$HOME/.cargo/env\"",
      <<EOT
        RUSTFLAGS="-C link-arg=-fuse-ld=mold" \
        cargo install --locked \
            exa bat ripgrep fd-find du-dust \
            tokei cargo-expand cargo-edit cargo-outdated \
            cargo-tree cargo-lambda tauri-cli maturin \
            cargo-watch cargo-make cargo-generate \
            cargo-modules cargo-asm cargo-bloat cargo-deb \
            cargo-zigbuild cargo-udeps \
            sccache
        EOT
    ]
  }

  // Install CUDA toolkit
  provisioner "shell" {
    inline = [
      "wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/sbsa/cuda-ubuntu2204.pin",
      "sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600",
      "wget https://developer.download.nvidia.com/compute/cuda/12.5.1/local_installers/cuda-repo-ubuntu2204-12-5-local_12.5.1-555.42.06-1_arm64.deb",
      "sudo dpkg -i cuda-repo-ubuntu2204-12-5-local_12.5.1-555.42.06-1_arm64.deb",
      "sudo cp /var/cuda-repo-ubuntu2204-12-5-local/cuda-*-keyring.gpg /usr/share/keyrings/",
      "sudo apt-get update",
      "sudo apt-get -y install cuda-toolkit-12-5",
      "rm -f cuda-repo-ubuntu2204-12-5-local_12.5.1-555.42.06-1_arm64.deb",
      "sudo apt-get install -y nvidia-driver-555-open",
      "sudo apt-get install -y cuda-drivers-555",

      "echo '#CUDA Toolkit' >> ~/.zshrc",
      "echo 'export PATH=/usr/local/cuda/bin:$PATH' >> $HOME/.zshrc",
    ]
  }

  // Convinient aliases
  provisioner "shell" {
    inline = [
      "echo '#Convinient aliases' >> ~/.zshrc",
      "echo 'alias ls=\"ls -lh\"' >> $HOME/.zshrc",
      "echo 'search=\"grep -HnIire --color=auto\"' >> $HOME/.zshrc",
    ]
  }
}

