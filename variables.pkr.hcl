golang_version = "1.22.4"
python_version = "3.11"
region = "ap-southeast-1"
source_image = {
  image_id            = "ami-0a74328eb0d575ee1"
  root_device_type    = "ebs"
  virtualization_type = "hvm"
  owner               = "099720109477"
  ssh_username        = "ubuntu"
}
instance_type = "c6g.12xlarge"
