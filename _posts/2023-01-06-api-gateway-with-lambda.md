---
title: Building a Serverless Function using Amazon API Gateway and AWS Lambda
tags: [aws, docker, python, serverless]
toc: true
toc_sticky: true
post_no: 15
---
This post is a quick tutorial to build a very simple serverless function using Amazon API Gateway and AWS Lambda.

Amazon API Gateway and AWS Lambda are resources that allow developers to build a serverless architecture in AWS.
Leaving aside the fact that I don't really like the term "serverless", a serverless architecture can be much more cost-effective than having a full-time running server, that can be be underutilized for long periods.
The following benefits described in [the whitepaper of this serverless logic tier using Amazon API Gateway and AWS Lambda](https://d0.awsstatic.com/whitepapers/AWS_Serverless_Multi-Tier_Archiectures.pdf) are worth mentioning:
- No operating systems to choose, secure, patch, or manage.
- No servers to right size, monitor, or scale out.
- No risk to your cost by over-provisioning.
- No risk to your performance by under-provisioning. 

On the other hand, it has some disadvantages such as performance due to the cold start.
Therefore, it is the responsibility of the developers to decide whether or not this approach is suitable for their particular problems.

For our purpose, we will first create a function and package it into a container image, and then push that image to Amazon ECR.
The next step is to create a Lambda function.
And lastly, create an API Gateway and integrate it with the Lambda.

![diagram](/assets/images/15/diagram.png)

Our programming language of choice for this tutorial is Python and all the required AWS resources are deployed using AWS CDK.

## Prerequisites
* AWS account
* AWS CLI
* AWS CDK
* Docker
* Python 3

## Create a container image
There are two methods to deploy code to Lambda function:
- a zip file archive
- a container image

This tutorial is based on the latter - a container image.

The function code of our Lambda function handler method is as follows:
```python
def handler(event, context) -> dict[str, str]:
    message = "Hello!"
    return {"message": message}

```
This is what's run when our Lambda function is invoked.

About two arguments passed to the function handler:
- `event`: a JSON-formatted document that contains data for a Lambda function to process.
- `context`: an object that provides methods and properties that provide information about the invocation, function, and runtime environment.

A Dockerfile for our Python funtion with the `python:3.9` base image is as follows:
```dockerfile
FROM public.ecr.aws/lambda/python:3.9
COPY app.py ${LAMBDA_TASK_ROOT}

CMD [ "app.handler" ]
```

To build an image, we will use the Docker command:
```
$ docker build -t myfunction .
```

Now we need a container registry to save our container image.
The following code creates an Amazon ECR named `myfunction` with a lifecycle policy that expires untagged images older than 1 day:
```python
import aws_cdk as cdk
from aws_cdk import Stack, aws_ecr as ecr
from constructs import Construct


ACCOUNT = "012345678901"
REGION = "ap-northeast-2"

LIFECYCLE_POLICY_TEXT = """
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire untagged images older than 1 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
"""


class EcrStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        ecr.CfnRepository(
            self,
            id="Registry",
            encryption_configuration=ecr.CfnRepository.EncryptionConfigurationProperty(
                encryption_type="KMS", kms_key=None
            ),
            image_scanning_configuration=None,
            image_tag_mutability="MUTABLE",
            lifecycle_policy=ecr.CfnRepository.LifecyclePolicyProperty(
                lifecycle_policy_text=LIFECYCLE_POLICY_TEXT
            ),
            repository_name="myfunction",
        )


app = cdk.App()
EcrStack(app, "EcrStack", env=cdk.Environment(account=ACCOUNT, region=REGION))

app.synth()

```

Use the AWS CDK Toolkit to deploy the stack:
```
$ cdk deploy EcrStack
```

After deploying the ECR, we tag and push the image to it.
You can view push commands to this ECR in the ECR console at [https://console.aws.amazon.com/ecr](https://console.aws.amazon.com/ecr)

After pushing the image, we can confirm that our image is pushed to our ECR by using AWS CLI:
```
$ aws ecr list-images --repository-name myfunction
{
    "imageIds": [
        {
            "imageDigest": "sha256:...",
            "imageTag": "latest"
        }
    ]
}
```

## Create a Lambda function
AWS Lambda is a compute service that runs your code without provisioning any always-running server.
The main benefit of this service is that it only costs when it runs your code, and there is no charge when your code is not running.

Here are some of good use cases of Lambda:
- file processing
- stream processing
- web applications
- IoT backends
- mobile backends

The AWS CDK example for our Lambda function named `MyFunction` is as follows:
```python
import aws_cdk as cdk
from aws_cdk import Stack, aws_lambda as lambda_, aws_apigatewayv2 as apigateway, aws_iam as iam
from constructs import Construct


ACCOUNT = "012345678901"
REGION = "ap-northeast-2"


class ServerlessStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        role = iam.CfnRole(
            self,
            id="Role",
            role_name="lambda_role",
            assume_role_policy_document={
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": {"Service": ["lambda.amazonaws.com"]},
                        "Action": ["sts:AssumeRole"],
                    }
                ],
            },
            description="Allows Lambda Function to use AWS resources.",
            # grants permissions to upload logs to CloudWatch.
            managed_policy_arns=[
                "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
            ],
        )

        code_property = lambda_.CfnFunction.CodeProperty(
            image_uri="012345678901.dkr.ecr.ap-northeast-2.amazonaws.com/myfunction:latest"
        )
        ephemeral_storage_property = lambda_.CfnFunction.EphemeralStorageProperty(size=512)
        function = lambda_.CfnFunction(
            self,
            id="LambdaFunction",
            code=code_property,
            role=role.attr_arn,
            architectures=["x86_64"],
            code_signing_config_arn=None,
            dead_letter_config=None,
            description="My function",
            environment=None,
            ephemeral_storage=ephemeral_storage_property,
            file_system_configs=None,
            function_name="MyFunction",
            handler=None,
            image_config=None,
            kms_key_arn=None,
            layers=None,
            memory_size=128,
            package_type="Image",
            reserved_concurrent_executions=None,
            runtime=None,
            timeout=3,
            tracing_config=None,
            vpc_config=None,
        )
        function.add_depends_on(role)

        permission = lambda_.CfnPermission(
            self,
            id="LambdaApiGatewayInvoke",
            action="lambda:InvokeFunction",
            function_name=function.function_name,
            principal="apigateway.amazonaws.com",
        )
        permission.add_depends_on(function)


app = cdk.App()
ServerlessStack(app, "ServerlessStack", env=cdk.Environment(account=ACCOUNT, region=REGION))

app.synth()

```

We have three types of L1 constructs in this example:
- `Role`: to allow Lambda function to use AWS resources
- `Function`: the Lambda function
- `Permission`: to allow API Gateway to invoke the Lambda function

Use the AWS CDK Toolkit to deploy the stack:
```
$ cdk deploy ServerlessStack
```

After deploying the stack, you can manually invoke the function using AWS CLI:
```
$ aws lambda invoke --function-name MyFunction out.json
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
```

This command creates a JSON file named `out.json` that is the response of our Lambda handler method:
```json
{"message": "Hello!"}
```

## Create an API Gateway
Amazon API Gateway is a service that allows developers to create, publish, maintain, monitor, and secure APIs at any scale.
Using API Gateway, we can execute a Lambda function through its API endpoint.

Amazon API Gateway provides two types of products:
- REST APIs
- HTTP APIs

While REST APIs support more features than HTTP APIs, HTTP APIs support minimal features with a lower price.
Refer to the [documenation](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html) for more information.

This example uses HTTP APIs.

To create an API Gateway, we will add the following lines of code to `ServerlessStack`:
```python
class ServerlessStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        ...

        api = apigateway.CfnApi(
            self,
            id="HttpApi",
            name="Lambda Proxy",
            description="My Lambda proxy to HTTP API",
            cors_configuration=apigateway.CfnApi.CorsProperty(
                allow_methods=["GET"], allow_origins=["*"]
            ),
            protocol_type="HTTP",
            target=function.attr_arn,
        )
        api.add_depends_on(function)

```
Note that the argument for `target` parameter is a function ARN.
This property is part of quick create which produces an API with an integration, a default route, and a default stage.

After updating `ServerlessStack`, you can see a list of APIs and check out the API endpoint for our Lambda function using AWS CLI:
```
$ aws apigatewayv2 get-apis
{
    "Items": [
        {
            "ApiEndpoint": "https://someapiid.execute-api.ap-northeast-2.amazonaws.com",
            "ApiId": "someapiid",
            "ApiKeySelectionExpression": "$request.header.x-api-key",
            "CorsConfiguration": {
                "AllowMethods": [
                    "GET"
                ],
                "AllowOrigins": [
                    "*"
                ]
            },
            "CreatedDate": "2023-01-06T10:50:14+00:00",
            "Description": "My Lambda proxy to HTTP API",
            "DisableExecuteApiEndpoint": false,
            "Name": "Lambda Proxy",
            "ProtocolType": "HTTP",
            "RouteSelectionExpression": "$request.method $request.path",
            "Tags": {
                "aws:cloudformation:stack-id": "...",
                "aws:cloudformation:stack-name": "ServerlessStack",
                "aws:cloudformation:logical-id": "HttpApi"
            }
        }
    ]
}
```

Finally, we have now built a simple serverless function.
We can invoke our Lambda function by using `curl`:
```
$ curl https://someapiid.execute-api.ap-northeast-2.amazonaws.com
{"message": "Hello!"}
```
