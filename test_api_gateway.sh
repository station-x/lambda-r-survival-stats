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

usage() { echo "Usage: $0 [-u <api_url>] [-t <optional_api_token>]" 1>&2; exit 1; }
while getopts ":t:u:" opt; do
  case $opt in
    u)
      echo "URL: $OPTARG" >&2
      URL=$OPTARG
      ;;
    t)
      echo "Will utilize an API token" >&2
      API_TOKEN=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done
shift $((OPTIND-1))
if [ -z "${URL}" ]; then
    usage
fi

# build command via an array so we can add optional header easily
curlCmd=(curl -X POST ${URL} -d @sample.json -H "Content-Type: application/json")

# optionally add API key
if [ "${API_TOKEN}" ]; then
    curlCmd+=(-H "x-api-key: ${API_TOKEN}")
fi

# execute it
"${curlCmd[@]}"
