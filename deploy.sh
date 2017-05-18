#!/bin/bash
SERVER=croquis@homepage.croquis.com
TARGET=hp/devblog.croquis.com

./build.sh

cd docs
rsync --iconv=UTF-8-MAC,UTF-8 -az --delete . $SERVER:$TARGET
