#!/bin/bash
SERVER=croquis@homepage.croquis.com
TARGET=hp/devblog.croquis.com

./build.sh

cd docs
rsync -az --delete . $SERVER:$TARGET
