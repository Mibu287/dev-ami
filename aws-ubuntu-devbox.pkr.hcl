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

source "amazon-ebs" "ubuntu" {
  ami_name      = "awesome-devbox-{{timestamp}}"
  instance_type = "t4g.large"
  region        = "ap-southeast-1"
  source_ami_filter {
    filters = {
      image-id            = "ami-0a74328eb0d575ee1"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

build {
  name = "awesome-devbox"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]


  // Update and upgrade the distro
  provisioner "shell" {
    inline = [
      "sudo apt update",
      "sudo apt upgrade -y",
      <<EOT
      sudo apt install -y \
          build-essential gcc g++ \
          libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
          libsqlite3-dev libncurses5-dev libncursesw5-dev xz-utils \
          tk-dev libffi-dev liblzma-dev openssl
     EOT
    ]
  }

  // Install ZSH
  provisioner "shell" {
    inline = [
      "sudo apt install -y zsh",
      "sudo chsh -s $(which zsh) $USER",
      "sh -c '$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -A)'",
    ]
  }

  // Install Golang
  provisioner "shell" {
    inline = [
      "https://go.dev/dl/go${var.golang_version}.linux-arm64.tar.gz",
      "sudo tar -C /usr/local -xzf go${var.golang_version}.linux-arm64.tar.gz",
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
    ]
  }

  // Install pyevn and python 3.11
  provisioner "shell" {
    inline = [
      "curl https://pyenv.run | zsh",
      "echo 'export PYENV_ROOT=\"$HOME/.pyenv\"' >> ~/.zshrc",
      "echo '[[ -d $PYENV_ROOT/bin ]] && export PATH=\"$PYENV_ROOT/bin:$PATH\"' >> ~/.zshrc",
      "echo 'eval \"$(pyenv init -)\"' >> ~/.zshrc",
      "PYENV_ROOT=\"$HOME/.pyenv\" PATH=\"$HOME/.pyenv/bin:$PATH\" pyenv install ${var.python_version}",
    ]
  }
}

