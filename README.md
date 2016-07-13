# Lambda R Survival Statistics

This project walks you through creating an AWS Lambda package that bundles R and a Python Lambda function for calculating survival statistics.  We will also briefly walk you through using API Gateway to execute Lambda.

This concept can be applied to other projects where you would like to use AWS Lambda to run R for statistical computing.

## Launch an EC2 instance to compile R and all dependencies

To start, you need an instance running the same version of Amazon Linux as used by AWS Lambda. You can find the AMI version at [Lambda Execution Environment and Available Libraries](http://docs.aws.amazon.com/lambda/latest/dg/current-supported-versions.html).  Since we are only using this instance to build our package for Lambda, a t2.micro is sufficient.

Here is a sample command to launch an instance in US East (N. Virginia):
```
aws ec2 run-instances \
    --image-id ami-60b6c60a \
    --count 1 \
    --instance-type t2.medium \
    --key-name YourKeyPair \
    --security-group-ids sg-xxxxxxxx \
    --subnet-id subnet-xxxxxxxx
```
After you have launched your instance, SSH into it. For more information, see [Getting Started with Amazon EC2 Linux Instances](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html).  Once you have connected to the instance, configure AWS CLI with your security credentials.  This is necessary because we will be copying our Lambda package to S3.
```
aws configure
```

## Compile R and all dependencies, build Lambda package, and copy to S3

Clone this repository onto the EC2 instance
```
sudo yum install git-all
git clone https://github.com/station-x/lambda-r-survival-stats
cd lambda-r-survival-stats
```
Now run the build script which will do the following:
* install all required libraries, including R, Fortran, and Python
* because we are using the -s option, build the survival R library which is required for our example
* use virtualenv to manage all of our Python dependencies, so that we can package them easily
* install rpy2, a Python interface to R.  We will use this to call R directly from the Python handler
* create the Lambda package (including handler.py, which is the Lambda handler for calculating survival statistics)
* copy the package to s3
```
./build_lambda_r_stats.sh [-s] [-n <package_name>] [-d <destination_s3_bucket_folder>]
```
## Test the Lambda package on another EC2 instance
As in the first step, start a new EC2 t2.micro instance and SSH to it.  As before, be sure to configure AWS CLI with your security credentials. 

Then unpack our Lambda package and set some R environment variables so we can test things. 
```
aws s3 cp s3://<your-lambda-package-s3-path> .
unzip <your-lambda-package>
export R_HOME=$HOME
export LD_LIBRARY_PATH=$HOME/lib
python ./test_handler.py
```

## Deploy the Lambda function and API Gateway
Information on deploying Lambda functions can be found in [the official documentation](http://docs.aws.amazon.com/lambda/latest/dg/lambda-python-how-to-create-deployment-package.html) as well as in Step 4 of a [recent Compute Blog article written by Michael Raposa](https://aws.amazon.com/blogs/compute/extracting-video-metadata-using-lambda-and-mediainfo/).

While configuring the Lambda function, specify the handler as handler.lambda_handler, set the memory to the maximum size of 1536 MB (greater memory allocation in Lambda is correlated with greater compute power), and set the timeout to 30s (the max for API Gateway).

## Deploy API Gateway
The steps for this are covered in the AWS API Gateway Documentation [Make Synchronous Calls to Lambda Functions](http://docs.aws.amazon.com/apigateway/latest/developerguide/getting-started.html).

## Test API Gateway
```
./test_api_gateway.sh [-u <api_url>] [-t <optional_api_token>]
```

expected result:
```
{
    "statistics_list": [
        {
            "hazard": 1.3926333898762577,
            "pval": 0.005922935208231839
        },
        {
            "hazard": 0.957292958555334,
            "pval": 0.7976137866147548
        }
    ]
}
```
