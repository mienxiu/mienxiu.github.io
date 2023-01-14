---
title: Creating a VPC with AWS CDK
tags: [aws, python]
toc: true
toc_sticky: true
post_no: 12
featured: true
---
The **AWS CDK(Cloud Development Kit)** is an open-source framework to provision and manage the cloud resources using familiar programming languages.

Before AWS launched the AWS CDK in 2019, AWS CloudFormation was the only resource-provisioning tool that AWS officially supports in a so-called *IaC(Infrastructure as code)* way.
In fact, the AWS CDK leverages the AWS CloudFormation internally.

> Familiarity with AWS CloudFormation is also useful, as the output of an AWS CDK program is an AWS CloudFormation template.

I have used AWS CloudFormation to create and manage most of the AWS resources: VPC, IAM, EC2, RDS, S3, Route 53, ECR and many others.
The downside of AWS CloudFormation is that it only accepts YAML or JSON format.
This template-based approach is somewhat verbose and not as flexible as the object-oriented approach that the AWS CDK provides.

The AWS CDK has some advantages over AWS CloudFormation:
- supports familiar programming languages
- easier to use parameters, conditionals, loops, composition, and etc.
- supports code completion with IDE

In this post, I'm going to create a custom VPC with AWS CDK.
The client language for the demonstration is Python.
I will also show the CloudFormation templates for comparison between the two different approaches.

All examples in this post are written in L1 constructs in order to focus on the fundamentals.
These are essentially the same as the AWS CloudFormation resource types.
These constructs have names that begin with `Cfn`.
{: .notice--info}

The end result of this tutorial is as follows:

![vpc](/assets/images/12/vpc.png)

- 2 public and 2 private subnets in different AZs for better availability
- an internet gateway to communicate outside of the VPC
- 2 NAT gateways in each AZ for resources in private subnets

You can think of this architecture as a good starting point for most web applications.

## Prerequisites
* AWS account
* AWS CLI
* Node.js 10.13 or later
* AWS CDK Toolkit (`npm install -g aws-cdk`)
* Preferred programming language (e.g. TypeScript, Python, C#)

## 0. Bootstrapping and Creating the app
Bootstrapping is a process of provisioning the necessary resources for deployments.
The resources include an Amazon S3 bucket for storing files and IAM roles.

To bootstrap, run:
```
cdk [--profile string] bootstrap aws://ACCOUNT-NUMBER/REGION
```

You can confirm that a new stack is created by using AWS CLI:
```
aws [--profile string] cloudformation list-stacks --stack-status-filter CREATE_COMPLETE?
```
```yaml
{
    "StackSummaries": [
        {
            "StackId": "arn:aws:cloudformation:...",
            "StackName": "CDKToolkit",
            "TemplateDescription": "This stack includes resources needed to deploy AWS CDK apps into this environment",
            "CreationTime": "...",
            "LastUpdatedTime": "...",
            "StackStatus": "CREATE_COMPLETE",
            "DriftInformation": {
                "StackDriftStatus": "NOT_CHECKED"
            }
        }
    ]
}
```

After bootstrapping, create a new CDK project:
```
mkdir my-cdk
cd my-cdk
cdk init app --language python
```

The created files look as follows:
```
.
├── README.md
├── app.py
├── cdk.json
├── my_cdk
│   ├── __init__.py
│   └── my_cdk_stack.py
├── requirements-dev.txt
├── requirements.txt
├── source.bat
└── tests
    ├── __init__.py
    └── unit
        ├── __init__.py
        └── test_my_cdk_stack.py
```

When it's done, simply install the libraries in your preferred virtual environment:
```
pip install -r requirements.txt
```

And specify the environment for your stack in `app.py` file in your AWS CDK project:
```python
#!/usr/bin/env python3
import aws_cdk as cdk

from my_cdk.my_cdk_stack import MyCdkStack


app = cdk.App()
MyCdkStack(app, "MyCdkStack", env=cdk.Environment(account="my_account_num", region="ap-northeast-2"))

app.synth()
```
> For production stacks, we recommend that you explicitly specify the environment for each stack in your app using the env property.

You are now ready to deploy the AWS resources.

<!-- As of this writing, the CDK version is 2.24.1 -->

## 1. VPC & Subnets
![vpc](/assets/images/12/vpc1.png)

The CIDR rules are as follows:

|Subnet ID|CIDR|AZ|
|:---:|:---:|:---:|
|PublicSubnetA|10.0.0.0/24|A|
|PublicSubnetB|10.0.1.0/24|B|
|PrivateSubnetA|10.0.10.0/24|A|
|PrivateSubnetB|10.0.11.0/24|B|

An AWS CloudFormation template to provision this VPC and subnets is:
```yaml
AWSTemplateFormatVersion: "2010-09-09"

Parameters:
  AppName:
    Description: The app name.
    Type: String
  Env:
    Description: The deployment environment.
    Type: String
    AllowedValues:
      - dev
      - staging
      - prod
    Default: dev

Mappings:
  SubnetConfig:
    VPC:
      CIDR: "10.0.0.0/16"
    Public0:
      CIDR: "10.0.0.0/24"
    Public1:
      CIDR: "10.0.1.0/24"
    Private0:
      CIDR: "10.0.10.0/24"
    Private1:
      CIDR: "10.0.11.0/24"
  AZRegions:
    ap-northeast-2: # Asia Pacific (Seoul)
      AZs: ["a", "b", "c", "d"]

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock:
        Fn::FindInMap:
          - SubnetConfig
          - VPC
          - CIDR
      EnableDnsHostnames: true
      EnableDnsSupport: true
      InstanceTenancy: default
      Tags:
        - Key: Name
          Value: !Sub ${AppName}-vpc
        - Key: Env
          Value: !Ref Env

  PublicSubnet0:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone:
        Fn::Sub:
          - "${AWS::Region}${AZ}"
          - AZ: !Select [0, !FindInMap ["AZRegions", !Ref "AWS::Region", "AZs"]]
      CidrBlock:
        Fn::FindInMap:
          - SubnetConfig
          - Public0
          - CIDR
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Network
          Value: public
        - Key: Name
          Value: !Join
            - "-"
            - - !Ref AppName
              - public
              - !Select [0, !FindInMap ["AZRegions", !Ref "AWS::Region", "AZs"]]
        - Key: Env
          Value: !Ref Env
    DependsOn: VPC
  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone:
        Fn::Sub:
          - "${AWS::Region}${AZ}"
          - AZ: !Select [1, !FindInMap ["AZRegions", !Ref "AWS::Region", "AZs"]]
      CidrBlock:
        Fn::FindInMap:
          - SubnetConfig
          - Public1
          - CIDR
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Network
          Value: public
        - Key: Name
          Value: !Join
            - "-"
            - - !Ref AppName
              - public
              - !Select [1, !FindInMap ["AZRegions", !Ref "AWS::Region", "AZs"]]
        - Key: Env
          Value: !Ref Env
    DependsOn: VPC

  PrivateSubnet0:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone:
        Fn::Sub:
          - "${AWS::Region}${AZ}"
          - AZ: !Select [0, !FindInMap ["AZRegions", !Ref "AWS::Region", "AZs"]]
      CidrBlock:
        Fn::FindInMap:
          - SubnetConfig
          - Private0
          - CIDR
      Tags:
        - Key: Network
          Value: private
        - Key: Name
          Value: !Join
            - "-"
            - - !Ref AppName
              - private
              - !Select [0, !FindInMap ["AZRegions", !Ref "AWS::Region", "AZs"]]
        - Key: Env
          Value: !Ref Env
    DependsOn: VPC
  PrivateSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone:
        Fn::Sub:
          - "${AWS::Region}${AZ}"
          - AZ: !Select [1, !FindInMap ["AZRegions", !Ref "AWS::Region", "AZs"]]
      CidrBlock:
        Fn::FindInMap:
          - SubnetConfig
          - Private1
          - CIDR
      Tags:
        - Key: Network
          Value: private
        - Key: Name
          Value: !Join
            - "-"
            - - !Ref AppName
              - private
              - !Select [1, !FindInMap ["AZRegions", !Ref "AWS::Region", "AZs"]]
        - Key: Env
          Value: !Ref Env
    DependsOn: VPC
```
Note that I intentionally added `ENV` variable to specify the deployment environment to follow the best practices.
I also set a `Mappings` to predefine the CIDRs for better maintainability.

The AWS CloudFormation template above can be transformed into a Python file By editing `my_cdk/my_cdk_stack.py`:
```python
from aws_cdk import Stack, aws_ec2, CfnTag
from constructs import Construct


class MyCdkStack(Stack):
    ENV: str = "dev"
    APP_NAME: str = "myservice"
    CIDRS: dict[str, str] = {
        "vpc": "10.0.0.0/16",
        "public0": "10.0.0.0/24",
        "public1": "10.0.1.0/24",
        "private0": "10.0.10.0/24",
        "private1": "10.0.11.0/24",
    }

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # The code that defines your stack goes here
        vpc = aws_ec2.CfnVPC(
            self,
            id="VPC",
            cidr_block=self.CIDRS["vpc"],
            enable_dns_hostnames=True,
            enable_dns_support=True,
            instance_tenancy="default",
            tags=[
                CfnTag(key="Name", value=f"{self.APP_NAME}-vpc"),
                CfnTag(key="Env", value=self.ENV),
            ],
        )

        public_subnet0 = aws_ec2.CfnSubnet(
            self,
            id="PublicSubnet0",
            vpc_id=vpc.ref,
            availability_zone=self.availability_zones[0],
            cidr_block=self.CIDRS["public0"],
            map_public_ip_on_launch=True,
            tags=[
                CfnTag(key="Network", value="public"),
                CfnTag(key="Name", value=f"{self.APP_NAME}-public-a"),
                CfnTag(key="Env", value=self.ENV),
            ],
        )
        public_subnet1 = aws_ec2.CfnSubnet(
            self,
            id="PublicSubnet1",
            vpc_id=vpc.ref,
            availability_zone=self.availability_zones[1],
            cidr_block=self.CIDRS["public1"],
            map_public_ip_on_launch=True,
            tags=[
                CfnTag(key="Network", value="public"),
                CfnTag(key="Name", value=f"{self.APP_NAME}-public-b"),
                CfnTag(key="Env", value=self.ENV),
            ],
        )

        private_subnet0 = aws_ec2.CfnSubnet(
            self,
            id="PrivateSubnet0",
            vpc_id=vpc.ref,
            availability_zone=self.availability_zones[0],
            cidr_block=self.CIDRS["private0"],
            tags=[
                CfnTag(key="Network", value="private"),
                CfnTag(key="Name", value=f"{self.APP_NAME}-private-a"),
                CfnTag(key="Env", value=self.ENV),
            ],
        )
        private_subnet1 = aws_ec2.CfnSubnet(
            self,
            id="PrivateSubnet1",
            vpc_id=vpc.ref,
            availability_zone=self.availability_zones[1],
            cidr_block=self.CIDRS["private1"],
            tags=[
                CfnTag(key="Network", value="private"),
                CfnTag(key="Name", value=f"{self.APP_NAME}-private-b"),
                CfnTag(key="Env", value=self.ENV),
            ],
        )
```
Here are some benefits you can find in this comparison:
- more concise representation (the custom `!Ref` tag to `.ref`)
- easier reference to availability zones

The next step is to *synthesize* the stack to create an AWS CloudFormation template:
```
cdk synth
```
This command reads the account and region information in `app.py` file and generates the corresponding AWS CloudFormation templates in `cdk.out` directory in JSON format.
The output of the command may look quite different from the template above, but they essentially create the same VPC.

To deploy our VPC, run:
```
cdk [--profile string] deploy
```

Confirm that a new stack named `MyCdkStack` is created by using AWS CLI:
```
aws [--profile string] cloudformation list-stack-resources --stack-name MyCdkStack
```
```yaml
{
    "StackResources": [
        {
            "StackName": "MyCdkStack",
            "StackId": "arn:aws:cloudformation:...",
            "LogicalResourceId": "PrivateSubnet0",
            "PhysicalResourceId": "...",
            "ResourceType": "AWS::EC2::Subnet",
            "Timestamp": "...",
            "ResourceStatus": "CREATE_COMPLETE",
            "DriftInformation": {
                "StackResourceDriftStatus": "NOT_CHECKED"
            }
        },
        {
            "StackName": "MyCdkStack",
            "StackId": "arn:aws:cloudformation:...",
            "LogicalResourceId": "PrivateSubnet1",
            "PhysicalResourceId": "...",
            "ResourceType": "AWS::EC2::Subnet",
            "Timestamp": "...",
            "ResourceStatus": "CREATE_COMPLETE",
            "DriftInformation": {
                "StackResourceDriftStatus": "NOT_CHECKED"
            }
        },
        {
            "StackName": "MyCdkStack",
            "StackId": "arn:aws:cloudformation:...",
            "LogicalResourceId": "PublicSubnet0",
            "PhysicalResourceId": "...",
            "ResourceType": "AWS::EC2::Subnet",
            "Timestamp": "...",
            "ResourceStatus": "CREATE_COMPLETE",
            "DriftInformation": {
                "StackResourceDriftStatus": "NOT_CHECKED"
            }
        },
        {
            "StackName": "MyCdkStack",
            "StackId": "arn:aws:cloudformation:...",
            "LogicalResourceId": "PublicSubnet1",
            "PhysicalResourceId": "...",
            "ResourceType": "AWS::EC2::Subnet",
            "Timestamp": "...",
            "ResourceStatus": "CREATE_COMPLETE",
            "DriftInformation": {
                "StackResourceDriftStatus": "NOT_CHECKED"
            }
        },
        {
            "StackName": "MyCdkStack",
            "StackId": "arn:aws:cloudformation:...",
            "LogicalResourceId": "VPC",
            "PhysicalResourceId": "...",
            "ResourceType": "AWS::EC2::VPC",
            "Timestamp": "...",
            "ResourceStatus": "CREATE_COMPLETE",
            "DriftInformation": {
                "StackResourceDriftStatus": "NOT_CHECKED"
            }
        }
    ]
}
```

You can further confirm that our new VPC or subnets are configured as we wanted by using AWS CLI:
```
aws [--profile string] ec2 describe-vpcs --vpc-ids (vpc-id)
```
```yaml
{
    "Vpcs": [
        {
            "CidrBlock": "10.0.0.0/16",
            "DhcpOptionsId": "...",
            "State": "available",
            "VpcId": "...",
            "OwnerId": "...",
            "InstanceTenancy": "default",
            "CidrBlockAssociationSet": [
                {
                    "AssociationId": "...",
                    "CidrBlock": "10.0.0.0/16",
                    "CidrBlockState": {
                        "State": "associated"
                    }
                }
            ],
            "IsDefault": false,
            "Tags": [
                {
                    "Key": "aws:cloudformation:logical-id",
                    "Value": "VPC"
                },
                {
                    "Key": "Name",
                    "Value": "myservice-vpc"
                },
                {
                    "Key": "aws:cloudformation:stack-id",
                    "Value": "arn:aws:cloudformation:..."
                },
                {
                    "Key": "Env",
                    "Value": "dev"
                },
                {
                    "Key": "aws:cloudformation:stack-name",
                    "Value": "MyCdkStack"
                }
            ]
        }
    ]
}
```

## 2. Internet & NAT Gateways
![vpc](/assets/images/12/vpc2.png)

The AWS CloudFormation template to create an Internet gateway and two NAT gateways:
```yaml
InternetGateway:
  Type: AWS::EC2::InternetGateway
  Properties:
    Tags:
      - Key: Network
        Value: public
      - Key: Name
        Value: !Sub ${AppName}-igw
      - Key: Env
        Value: !Ref Env
VPCGatewayAttachment:
  Type: AWS::EC2::VPCGatewayAttachment
  Properties:
    VpcId: !Ref VPC
    InternetGatewayId: !Ref InternetGateway
  DependsOn: [VPC, InternetGateway]

ElasticIP0:
  Type: AWS::EC2::EIP
  Properties:
    Domain: vpc
ElasticIP1:
  Type: AWS::EC2::EIP
  Properties:
    Domain: vpc
NATGateway0:
  Type: AWS::EC2::NatGateway
  Properties:
    AllocationId: !GetAtt ElasticIP0.AllocationId
    SubnetId: !Ref PublicSubnet0
  DependsOn: PublicSubnet0
NATGateway1:
  Type: AWS::EC2::NatGateway
  Properties:
    AllocationId: !GetAtt ElasticIP1.AllocationId
    SubnetId: !Ref PublicSubnet1
  DependsOn: PublicSubnet1
```

The AWS CDK contructs:
```python
internet_gateway = aws_ec2.CfnInternetGateway(
    self,
    id="InternetGateway",
    tags=[
        CfnTag(key="Network", value="public"),
        CfnTag(key="Name", value=f"{self.APP_NAME}-igw"),
        CfnTag(key="Env", value=self.ENV),
    ],
)
aws_ec2.CfnVPCGatewayAttachment(
    self,
    id="VPCGatewayAttachment",
    vpc_id=vpc.ref,
    internet_gateway_id=internet_gateway.ref,
)

eip0 = aws_ec2.CfnEIP(self, id="ElasticIP0", domain="vpc")
eip1 = aws_ec2.CfnEIP(self, id="ElasticIP1", domain="vpc")
nat_gateway0 = aws_ec2.CfnNatGateway(
    self,
    id="NATGateway0",
    allocation_id=eip0.attr_allocation_id,
    subnet_id=public_subnet0.ref,
)
nat_gateway1 = aws_ec2.CfnNatGateway(
    self,
    id="NATGateway1",
    allocation_id=eip1.attr_allocation_id,
    subnet_id=public_subnet1.ref,
)
```

To update the stack, issue:
```
cdk [--profile string] synth
cdk [--profile string] deploy
```

From now on, I will skip the `synth` and `deploy` steps.

## 3. NACL & Route Tables
![vpc](/assets/images/12/vpc3.png)

The route tables I'm going to create are as follows:
- PublicRouteTable

    |Destination|Target|
    |:---:|:---:|
    |10.0.0.0/16|local|
    |0.0.0.0/0|InternetGateway|

- PrivateRouteTable0

    |Destination|Target|
    |:---:|:---:|
    |10.0.0.0/16|local|
    |0.0.0.0/0|NATGateway0|

- PrivateRouteTable1

    |Destination|Target|
    |:---:|:---:|
    |10.0.0.0/16|local|
    |0.0.0.0/0|NATGateway1|

The AWS CloudFormation template to create all necessary route tables and routes:
```yaml
PublicRouteTable:
  Type: AWS::EC2::RouteTable
  Properties:
    VpcId: !Ref VPC
    Tags:
      - Key: Network
        Value: public
      - Key: "Name"
        Value: !Sub ${AppName}-public-rt
      - Key: Env
        Value: !Ref Env
  DependsOn: VPC
PublicRoute:
  Type: AWS::EC2::Route
  Properties:
    RouteTableId: !Ref PublicRouteTable
    DestinationCidrBlock: "0.0.0.0/0"
    GatewayId: !Ref InternetGateway
  DependsOn: [PublicRouteTable, InternetGateway]
PublicSubnetRouteTableAssociation0:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PublicSubnet0
    RouteTableId: !Ref PublicRouteTable
  DependsOn: [PublicSubnet0, PublicRouteTable]
PublicSubnetRouteTableAssociation1:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PublicSubnet1
    RouteTableId: !Ref PublicRouteTable
  DependsOn: [PublicSubnet1, PublicRouteTable]

PublicNetworkAcl:
  Type: AWS::EC2::NetworkAcl
  Properties:
    VpcId: !Ref VPC
    Tags:
      - Key: Network
        Value: public
      - Key: "Name"
        Value: !Sub ${AppName}-public-nacl
      - Key: Env
        Value: !Ref Env
  DependsOn: VPC
PublicNetworkAclInboundEntry:
  Type: AWS::EC2::NetworkAclEntry
  Properties:
    CidrBlock: "0.0.0.0/0"
    Egress: false
    NetworkAclId: !Ref PublicNetworkAcl
    Protocol: -1
    RuleAction: allow
    RuleNumber: 100
    PortRange:
      From: 0
      To: 65535
  DependsOn: PublicNetworkAcl
PublicNetworkAclOutboundEntry:
  Type: AWS::EC2::NetworkAclEntry
  Properties:
    CidrBlock: "0.0.0.0/0"
    Egress: true
    NetworkAclId: !Ref PublicNetworkAcl
    Protocol: -1
    RuleAction: allow
    RuleNumber: 100
    PortRange:
      From: 0
      To: 65535
  DependsOn: PublicNetworkAcl
PublicSubnetNetworkAclAssociation0:
  Type: AWS::EC2::SubnetNetworkAclAssociation
  Properties:
    SubnetId: !Ref PublicSubnet0
    NetworkAclId: !Ref PublicNetworkAcl
  DependsOn: [PublicSubnet0, PublicNetworkAcl]
PublicSubnetNetworkAclAssociation1:
  Type: AWS::EC2::SubnetNetworkAclAssociation
  Properties:
    SubnetId: !Ref PublicSubnet1
    NetworkAclId: !Ref PublicNetworkAcl
  DependsOn: [PublicSubnet1, PublicNetworkAcl]

PrivateRouteTable0:
  Type: AWS::EC2::RouteTable
  Properties:
    VpcId: !Ref VPC
    Tags:
      - Key: "Name"
        Value: !Sub ${AppName}-private-rt0
      - Key: Env
        Value: !Ref Env
  DependsOn: VPC
PrivateRouteTable1:
  Type: AWS::EC2::RouteTable
  Properties:
    VpcId: !Ref VPC
    Tags:
      - Key: "Name"
        Value: !Sub ${AppName}-private-rt1
      - Key: Env
        Value: !Ref Env
  DependsOn: VPC
PrivateRoute0:
  Type: AWS::EC2::Route
  Properties:
    RouteTableId: !Ref PrivateRouteTable0
    DestinationCidrBlock: "0.0.0.0/0"
    NatGatewayId: !Ref NATGateway0
  DependsOn: [PrivateRouteTable0, NATGateway0]
PrivateRoute1:
  Type: AWS::EC2::Route
  Properties:
    RouteTableId: !Ref PrivateRouteTable1
    DestinationCidrBlock: "0.0.0.0/0"
    NatGatewayId: !Ref NATGateway1
  DependsOn: [PrivateRouteTable1, NATGateway1]
PrivateSubnetRouteTableAssociation0:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PrivateSubnet0
    RouteTableId: !Ref PrivateRouteTable0
  DependsOn: [PrivateSubnet0, PrivateRouteTable0]
PrivateSubnetRouteTableAssociation1:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PrivateSubnet1
    RouteTableId: !Ref PrivateRouteTable1
  DependsOn: [PrivateSubnet1, PrivateRouteTable1]
```

The AWS CDK contructs:
```python
public_route = aws_ec2.CfnRouteTable(
    self,
    id="PublicRouteTable",
    vpc_id=vpc.ref,
    tags=[
        CfnTag(key="Network", value="public"),
        CfnTag(key="Name", value=f"{self.APP_NAME}-public-rt"),
        CfnTag(key="Env", value=self.ENV),
    ],
)
aws_ec2.CfnRoute(
    self,
    id="PublicRoute",
    route_table_id=public_route.ref,
    destination_cidr_block="0.0.0.0/0",
    gateway_id=internet_gateway.ref,
)
aws_ec2.CfnSubnetRouteTableAssociation(
    self,
    id="PublicSubnetRouteTableAssociation0",
    route_table_id=public_route.ref,
    subnet_id=public_subnet0.ref,
)
aws_ec2.CfnSubnetRouteTableAssociation(
    self,
    id="PublicSubnetRouteTableAssociation1",
    route_table_id=public_route.ref,
    subnet_id=public_subnet1.ref,
)

public_network_acl = aws_ec2.CfnNetworkAcl(
    self,
    id="PublicNetworkAcl",
    vpc_id=vpc.ref,
    tags=[
        CfnTag(key="Network", value="public"),
        CfnTag(key="Name", value=f"{self.APP_NAME}-public-nacl"),
        CfnTag(key="Env", value=self.ENV),
    ],
)
aws_ec2.CfnNetworkAclEntry(
    self,
    id="PublicNetworkAclInboundEntry",
    cidr_block="0.0.0.0/0",
    egress=False,
    network_acl_id=public_network_acl.ref,
    protocol=-1,
    rule_action="allow",
    rule_number=100,
    port_range=aws_ec2.CfnNetworkAclEntry.PortRangeProperty(from_=0, to=65535),
)
aws_ec2.CfnNetworkAclEntry(
    self,
    id="PublicNetworkAclOutboundEntry",
    cidr_block="0.0.0.0/0",
    egress=True,
    network_acl_id=public_network_acl.ref,
    protocol=-1,
    rule_action="allow",
    rule_number=100,
    port_range=aws_ec2.CfnNetworkAclEntry.PortRangeProperty(from_=0, to=65535),
)
aws_ec2.CfnSubnetNetworkAclAssociation(
    self,
    id="PublicSubnetNetworkAclAssociation0",
    subnet_id=public_subnet0.ref,
    network_acl_id=public_network_acl.ref,
)
aws_ec2.CfnSubnetNetworkAclAssociation(
    self,
    id="PublicSubnetNetworkAclAssociation1",
    subnet_id=public_subnet1.ref,
    network_acl_id=public_network_acl.ref,
)

private_route_table0 = aws_ec2.CfnRouteTable(
    self,
    id="PrivateRouteTable0",
    vpc_id=vpc.ref,
    tags=[
        CfnTag(key="Name", value=f"{self.APP_NAME}-private-rt0"),
        CfnTag(key="Env", value=self.ENV),
    ],
)
private_route_table1 = aws_ec2.CfnRouteTable(
    self,
    id="PrivateRouteTable1",
    vpc_id=vpc.ref,
    tags=[
        CfnTag(key="Name", value=f"{self.APP_NAME}-private-rt1"),
        CfnTag(key="Env", value=self.ENV),
    ],
)
aws_ec2.CfnRoute(
    self,
    id="PrivateRoute0",
    route_table_id=private_route_table0.ref,
    destination_cidr_block="0.0.0.0/0",
    nat_gateway_id=nat_gateway0.ref,
)
aws_ec2.CfnRoute(
    self,
    id="PrivateRoute1",
    route_table_id=private_route_table1.ref,
    destination_cidr_block="0.0.0.0/0",
    nat_gateway_id=nat_gateway1.ref,
)
aws_ec2.CfnSubnetRouteTableAssociation(
    self,
    id="PrivateSubnetRouteTableAssociation0",
    subnet_id=private_subnet0.ref,
    route_table_id=private_route_table0.ref,
)
aws_ec2.CfnSubnetRouteTableAssociation(
    self,
    id="PrivateSubnetRouteTableAssociation1",
    subnet_id=private_subnet1.ref,
    route_table_id=private_route_table1.ref,
)
```

Lastly, you can list up all of the resources in our VPC stack by using AWS CLI:
```
aws [--profile string] cloudformation describe-stack-resources --stack-name MyCdkStack
```

To destroy all resources in the stack, run:
```
cdk [--profile string] destroy
```
```
Are you sure you want to delete: MyCdkStack (y/n)? y
MyCdkStack: destroying...
...

 ✅  MyCdkStack: destroyed
```

---
## About Construct Levels
Constructs are categorized into three different levels.
- layer 1 (AWS CloudFormation-only)
- layer 2 (Curated)
- layer 3 (Patterns)

If you are someone with prior experience with AWS CloudFormation, there's not much to learn to use L1 (layer 1) constructs.
But if you are not, using L1 constructs requires a complete understanding of the underlying AWS resource models.

L2 constructs provide a higher-level API than L1 constructs.
They might lack fine-grained configuration like L1 constructs, but come with reasonable defaults and convenient methods.

L3 constructs include multiple kind of resources to provision a complete AWS architectures.

You can choose whatever constructs in different layers for particular use cases.
However, *you can't use L2 property types with L1 constructs, or vice versa*.
