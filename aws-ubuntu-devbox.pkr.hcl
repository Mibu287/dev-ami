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
  ssh_username = "${var.source_image.ssh_username}"
}

build {
  name = "awesome-devbox"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]


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
          tk-dev libffi-dev liblzma-dev openssl htop tree neofetch
     EOT
    ]
  }

  // Install ZSH
  provisioner "shell" {
    inline = [
      "sudo apt install -y zsh",
      "sudo chsh -s $(which zsh) $USER",
      "sh -c '$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)'",
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

  // Install Rust
  provisioner "shell" {
    inline = [
      "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | zsh -s -- -y",
      "echo 'export PATH=$PATH:$HOME/.cargo/bin' >> $HOME/.zshrc",
      "source $HOME/.zshrc",
      "cargo install exa bat ripgrep fd-find procs du-dust tokei cargo-expand cargo-edit cargo-outdated cargo-tree cargo-lambda tauri-cli",
    ]
  }

  // Install pyevn and python
  provisioner "shell" {
    inline = [
      "curl https://pyenv.run | zsh",
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
      "pip install requests numpy pandas polars duckdb scikit-learn cython matplotlib seaborn ipython jupyter"
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

      "echo 'export NVM_DIR=\"$HOME/.nvm\"' >> ~/.zshrc",
      "echo '[ -s \"$NVM_DIR/nvm.sh\" ] && \\. \"$NVM_DIR/nvm.sh\"' >> ~/.zshrc",
      "echo '[ -s \"$NVM_DIR/bash_completion\" ] && \\. \"$NVM_DIR/bash_completion\"' >> ~/.zshrc",
    ]
  }
}

