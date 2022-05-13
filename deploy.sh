#!/bin/bash

./build.sh

AWS_PROFILE=croquis

aws --profile $AWS_PROFILE sts get-caller-identity > /dev/null 2>&1
if [ $? -ne 0 ]; then
  aws sso login --profile $AWS_PROFILE
fi

aws --profile $AWS_PROFILE s3 sync docs s3://kakaostyle.in/website/devblog --delete --cache-control max-age=0
