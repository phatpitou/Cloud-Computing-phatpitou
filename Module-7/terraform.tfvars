# These are your values that would be in arguments.txt
imageid                = "ami-0360c520857e3138f"
instance-type          = "t3.micro"
key-name               = "coursera-key"
vpc_security_group_ids = ["sg-0b92eeb182a99dd70"]
cnt                    = 3
install-env-file       = "install-env.sh"
elb-name               = "pt-elb"
tg-name                = "pt-tg"
asg-name               = "pt-asg"
lt-name                = "lt-pt"
module-tag             = "module7-tag"
raw-s3-bucket          = "pt-raw-images"
finished-s3-bucket     = "pt-processed-images"