# These are your values that would be in arguments.txt
imageid                = "ami-0360c520857e3138f"
instance-type          = "t3.micro"
key-name               = "coursera-key"
vpc_security_group_ids = ["sg-0b1a68d08a66f0a1b"]
cnt                    = 3
install-env-file       = "install-env.sh"
elb-name               = "modulefinal-tag"
tg-name                = "pt-tg"
asg-name               = "pt-elb"
lt-name                = "lt-pt"
module-tag             = "modulefinal-tag"
raw-s3                 = "pt-raw-images-2402"
finished-s3            = "pt-processed-images-2402"
dynamodb-table-name    = "pt-database"
ebs-size               = "15"
