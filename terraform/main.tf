provider "aws" {
  region     = "eu-central-1"
  access_key = "AKI**********H4A"
  secret_key = "OC/MJh********************gArP4r3T1v"
}

locals {
  asg_name_manager = "terraform-asg-manager"
  asg_name_node    = "terraform-asg-node"
  asg_name_count   = "2"
}

data "aws_iam_user" "talib" {
  user_name = "talib"
}

output "talib_arn" {
  value = "${data.aws_iam_user.talib.arn}"
}

resource "tls_private_key" "swarm_key" {
  algorithm = "RSA"
}

resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "terraform-swarm-worker-"
  image_id      = "ami-0ef3340cffa705c4b"
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }

  iam_instance_profile = "${aws_iam_instance_profile.swarm_manager.name}"
  security_groups      = ["${aws_security_group.allow_all.id}", "${data.aws_security_group.default.id}"]

  user_data = <<YAML
#cloud-config

users:
 - name: swarm
   ssh_authorized_keys:
     - "${tls_private_key.swarm_key.public_key_openssh}"

runcmd:
 - [sh, -c, "echo ${local.asg_name_node} >> /autoscaling-group.txt"]
 - [sh, -c, "echo ${tls_private_key.swarm_key.private_key_pem} > /root/.ssh/id_rsa"]
 - /bin/sed -i 's/-- /--\n/' /root/.ssh/id_rsa
 - /bin/sed -i 's/ --/\n--/' /root/.ssh/id_rsa
 - usermod -aG docker swarm
 - [sh, -c, "chmod 600  /root/.ssh/id_rsa"]
YAML
}

resource "aws_launch_configuration" "as_manager" {
  name_prefix   = "terraform-swarm-manager-"
  image_id      = "ami-0ef3340cffa705c4b"
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }

  iam_instance_profile = "${aws_iam_instance_profile.swarm_manager.name}"
  security_groups      = ["${aws_security_group.allow_all.id}", "${data.aws_security_group.default.id}"]

  user_data = <<YAML
#cloud-config

runcmd:
 - [sh, -c, "echo ${local.asg_name_node} >> /autoscaling-group.txt"]
 - [sh, -c, "echo ${tls_private_key.swarm_key.private_key_pem} > /root/.ssh/id_rsa"]
 - /bin/sed -i 's/-- /--\n/' /root/.ssh/id_rsa
 - /bin/sed -i 's/ --/\n--/' /root/.ssh/id_rsa
 - usermod -aG docker swarm
 - [sh, -c, "chmod 600  /root/.ssh/id_rsa"]
 - docker swarm init
 - echo "* * * * * /swarm.sh" > /mycron
 - crontab /mycron
YAML
}

resource "aws_iam_instance_profile" "swarm_manager" {
  name = "swarm_manager"
  role = "${aws_iam_role.swarm_manager.name}"
}

resource "aws_iam_role" "swarm_manager" {
  name = "swarm_manager"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "swarm_manager_autoscaling" {
  name       = "swarm manager autoscaling access"
  roles      = ["${aws_iam_role.swarm_manager.name}"]
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess"
}

resource "aws_iam_policy_attachment" "swarm_manager_ec2" {
  name       = "swarm manager ec2 access"
  roles      = ["${aws_iam_role.swarm_manager.name}"]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_autoscaling_group" "swarm_manager" {
  name                 = "${local.asg_name_manager}"
  launch_configuration = "${aws_launch_configuration.as_manager.name}"
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  availability_zones   = ["eu-central-1a"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "swarm_node" {
  name                 = "${local.asg_name_node}"
  launch_configuration = "${aws_launch_configuration.as_conf.name}"
  min_size             = 1
  max_size             = 5
  desired_capacity     = "${local.asg_name_count}"
  availability_zones   = ["eu-central-1a"]

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_security_group" "default" {
  id = "sg-85c1b7ea"
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
