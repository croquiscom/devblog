#!/bin/bash

./build.sh

aws --profile croquis s3 sync docs s3://website.s.croquis.com/devblog --delete --cache-control max-age=0
