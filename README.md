# Lambda R Survival Statistics

This project walks you through creating a AWS Lambda package that bundles R and a Python Lambda function for calculating survival statistics.  

## Build Lambda package and copy to S3

Note: The optional -s option must be used when you want to package R survival library.  This is needed to utilize the test scripts below.
```
aws configure
./build_lambda_r_stats.sh [-s] [-n <package_name>] [-d <destination_s3_bucket_folder>]
```

## Test Lambda handler
```
aws configure
s3 cp <destination_s3_bucket_folder>/<package_name> .
export R_HOME=$HOME
export LD_LIBRARY_PATH=$HOME/lib

python ./test_handler.py
```

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
