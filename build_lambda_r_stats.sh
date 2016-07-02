#!/bin/sh
# Copyright 2016 Station X, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

usage() { echo "Usage: $0 [-s] [-n <package_name>] [-d <destination_s3_bucket_folder>]" 1>&2; exit 1; }
SURVIVAL=0
while getopts ":n:d:s" opt; do
  case $opt in
    s)
      echo "will do a survival build" >&2
      SURVIVAL=1
      ;;
    n)
      echo "package name: $OPTARG" >&2
      PACKAGE_NAME=$OPTARG
      ;;
    d)
      echo "destination s3 bucket/folder: $OPTARG" >&2
      S3_PATH=$OPTARG
      # remove trailing slash
      S3_PATH=${S3_PATH%/}
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done
shift $((OPTIND-1))

if [ -z "${PACKAGE_NAME}" ]; then
    usage
fi

if [ -z "${S3_PATH}" ]; then
    usage
fi

# keep track of current directory since it has handler and we will need to package it
INITIAL_DIR=`pwd`

# First, make sure everything is up-to-date:
sudo yum -y update
sudo yum -y upgrade

# install everything
# readline is needed for rpy2, and fortran is needed for R
sudo yum install -y python27-devel python27-pip gcc gcc-c++ readline-devel libgfortran.x86_64 R.x86_64

# build survival R function if requested
if [ $SURVIVAL == 1 ]; then
    cd /tmp
    wget https://cran.r-project.org/src/contrib/Archive/survival/survival_2.39-4.tar.gz
    sudo R CMD INSTALL survival_2.39-4.tar.gz
fi

# setup virtualenv and install rpy2
virtualenv ~/env && source ~/env/bin/activate
pip install rpy2

# create a directory called lambda for our package
mkdir $HOME/lambda && cd $HOME/lambda
# copy R 
cp -r /usr/lib64/R/* $HOME/lambda/
# Use ldd on R executable to find shared libraries, and copy all of the ones that were not already on the box
cp /usr/lib64/R/lib/libR.so $HOME/lambda/lib/
cp /usr/lib64/libgomp.so.1 $HOME/lambda/lib/  
cp /usr/lib64/libblas.so.3 $HOME/lambda/lib/
cp /usr/lib64/libgfortran.so.3 $HOME/lambda/lib/
cp /usr/lib64/libquadmath.so.0 $HOME/lambda/lib/

# we also need to grab this one (as we learned from trial and error)
cp /usr/lib64/liblapack.so.3 $HOME/lambda/lib/

# copy R executable to root of package
cp $HOME/lambda/bin/exec/R $HOME/lambda/

#Add the libraries from the activated Python virtual environment
cp -r $VIRTUAL_ENV/lib64/python2.7/site-packages/* $HOME/lambda
# we could copy all of $VIRTUAL_ENV/lib/python2.7/site-packages/, but let's grab the esseentials only
cp -r $VIRTUAL_ENV/lib/python2.7/site-packages/singledispatch* $HOME/lambda

cd $HOME/lambda
zip -r9 $HOME/${PACKAGE_NAME} *
cd $INITIAL_DIR
zip -r9 $HOME/${PACKAGE_NAME} handler.py
zip -r9 $HOME/${PACKAGE_NAME} test_handler.py

# copy to S3
aws s3 cp $HOME/${PACKAGE_NAME} ${S3_PATH}/${PACKAGE_NAME}
