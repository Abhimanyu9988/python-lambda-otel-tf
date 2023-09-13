provider "aws" {
  region = "us-west-2"
#  profile = "abhipersonalawsroot"  # Change to your desired AWS region
}

resource "aws_dynamodb_table" "lambda_table" {
  name           = "student-abhi-python"  # Replace with your table name
  billing_mode   = "PAY_PER_REQUEST"  # You can change this to "PROVISIONED" if needed

  attribute {
    name = "studentId"
    type = "S"  # Assuming studentId is a number, use "S" for string
  }

  hash_key = "studentId"

  # Additional table settings, such as provisioned capacity, can be defined here if using "PROVISIONED" billing mode

  tags = {
    Owner      = "abhibaj@cisco.com"
  }
}


resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda-role-abhi"  # Replace with your desired role name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_policy" "dynamodb_full_access" {
  name = "AmazonDynamoDBFullAccess"
}

data "aws_iam_policy" "cloudwatch_full_access" {
  name = "CloudWatchFullAccess"
}

data "aws_iam_policy" "lambda_full_access" {
  name = "AWSLambda_FullAccess"
}

data "aws_iam_policy" "ec2_full_access"{
 name = "AmazonEC2FullAccess"
}


resource "aws_iam_policy_attachment" "dynamodb_policy_attachment" {
  policy_arn = data.aws_iam_policy.dynamodb_full_access.arn
  name = "dynamodb_policy_attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
}

resource "aws_iam_policy_attachment" "cloudwatch_policy_attachment" {
  policy_arn = data.aws_iam_policy.cloudwatch_full_access.arn
  name = "cloudwatch_policy_attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  policy_arn = data.aws_iam_policy.lambda_full_access.arn
  name = "lambda_policy_attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
}


resource "aws_iam_policy_attachment" "ec2_policy_attachment" {
  policy_arn = data.aws_iam_policy.ec2_full_access.arn
  name = "lambda_policy_attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.students_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_lambda_function" "students_lambda" {
  function_name = "abhi-python-lambda"  # Replace with your desired function name
  handler      = "lambda_function.lambda_handler"  # Replace with your actual Lambda handler function name
  runtime      = "python3.9"
  role         = aws_iam_role.lambda_execution_role.arn  # Use the ARN of the IAM role you created
  layers = ["arn:aws:lambda:us-west-2:184161586896:layer:opentelemetry-python-0_2_0:1"]
  # Replace this with your Lambda function code
  filename     = "${path.module}/lambda_deployment.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_deployment.zip")
  vpc_config {
    #subnet_ids = ["subnet-0d2bd3d040025361f"]
    subnet_ids = [aws_subnet.public-subnet.id]
    security_group_ids = [aws_security_group.aws_security_group.id]
  }
  environment {
    variables = {
      # Add your environment variables here if needed
      AWS_LAMBDA_EXEC_WRAPPER = "/opt/otel-instrument",
      OTEL_EXPORTER_OTLP_ENDPOINT = "${aws_instance.ec2_instance_for_abhi.public_dns}:4318"
      OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf"
      OTEL_RESOURCE_ATTRIBUTES = "service.namespace=abhi-python-lambda,cloud.resource_id=arn:aws:lambda:us-east-1:277288375286:function:abhi-python-lambda"
    }
  }
}




####Create Networking
####Create Networking
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "abhi-vpc"
  }
}

# Define the public subnet
resource "aws_subnet" "public-subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.aws_az
  map_public_ip_on_launch = true
}

# Define the internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

# Define the public route table
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.vpc.id
}

# Route traffic to 0.0.0.0/0 via the internet gateway
resource "aws_route" "public-internet-route" {
  route_table_id         = aws_route_table.public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}


# Assign the public route table to the public subnet
resource "aws_route_table_association" "public-rt-association" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-rt.id
}

#resource "aws_route" "dynamodb_route" {
#  route_table_id         = aws_route_table.public-rt.id
#  #destination_prefix_list_id = "pl-00a54069"
#  vpc_endpoint_id = aws_vpc_endpoint.dynamoDB.id
#  destination_cidr_block = "0.0.0.0/0"
#}

resource "aws_vpc_endpoint" "dynamoDB" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.us-west-2.dynamodb"
  vpc_endpoint_type = "Gateway"
  tags = {
    Name = "abhi-otel-lambda"
  }
  route_table_ids = [aws_route_table.public-rt.id]
  #subnet_ids = [aws_subnet.public-subnet.id]
}


####Create key for SSH access
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Create the Key Pair
resource "aws_key_pair" "key_pair" {
  key_name   = "abhi-otel"
  public_key = tls_private_key.key_pair.public_key_openssh
}
# Save file
resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.key_pair.key_name}.pem"
  content  = tls_private_key.key_pair.private_key_pem
}


####Get AWS AMI
data "aws_ami" "ubuntu-linux-2004" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_instance" "ec2_instance_for_abhi" {
  ami                    = data.aws_ami.ubuntu-linux-2004.id  #Ubuntu
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.key_pair.key_name
  iam_instance_profile   = aws_iam_instance_profile.dev-resources-iam-profile.name
  vpc_security_group_ids = [aws_security_group.aws_security_group.id]
  subnet_id              = aws_subnet.public-subnet.id
  #subnet_id = "subnet-0d2bd3d040025361f"
  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
    volume_size           = 20
  }
  tags = {
    Name                  = "abhi_otel_lambda"
    owner                 = "Abhi Bajaj"
    ResourceOwner         = "abhibaj@cisco.com"
    CreatedBy             = "abhibaj@cisco.com"
    JIRAProject           = "NA"
    DeploymentEnvironment = "Sandbox"
    IntendedPublic        = "OnlyWithinVpnRange"
    DataClassification    = "Cisco Highly Confidential"
    CostCenter            = "NA"
    AlwaysOn              = "true"
    Team                  = "US-Support"
    Purpose               = "Ec2 with all Services"

  }
  user_data = data.template_file.startup.rendered

}

resource "aws_iam_instance_profile" "dev-resources-iam-profile" {
  name = "ec2_profile_for_abhi_otel"
  role = aws_iam_role.dev-resources-iam-role.name
}

resource "aws_iam_role" "dev-resources-iam-role" {
  name               = "abhi_otel"
  description        = "The role for the developer resources EC2"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": {
"Effect": "Allow",
"Principal": {"Service": "ec2.amazonaws.com"},
"Action": "sts:AssumeRole"
}
}
EOF
  tags = {
    Owner = "abhibaj@cisco.com"
  }
}
resource "aws_iam_role_policy_attachment" "dev-resources-ssm-policy" {
  role       = aws_iam_role.dev-resources-iam-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


###COMMENT: File for getting SSM Agent
data "template_file" "startup" {
  template = file("ssm-agent-installer.sh")
}

resource "aws_security_group" "aws_security_group" {
  name_prefix = "AllAllowed"
  description = "This Security group contains access from everywhere"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}
