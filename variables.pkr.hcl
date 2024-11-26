golang_version = "1.22.4"
python_version = "3.11"
nvm_version    = "0.39.7"
zig_version    = "0.13.0"
region         = "ap-southeast-1"

source_image_arm64 = {
  image_id            = "ami-0a74328eb0d575ee1"
  root_device_type    = "ebs"
  virtualization_type = "hvm"
  owner               = "099720109477"
  ssh_username        = "ubuntu"
}
instance_type_arm64 = "c6g.12xlarge"

source_image_x86 = {
  image_id            = "ami-0a74328eb0d575ee1"
  root_device_type    = "ebs"
  virtualization_type = "hvm"
  owner               = "099720109477"
  ssh_username        = "ubuntu"
}
instance_type_x86 = "c6g.12xlarge"
