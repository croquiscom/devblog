#!/bin/bash

TARGET=~/_site

if [ -n "$1" ]
then
  TARGET=$1
fi

mkdir -p $TARGET/devblog.croquis.com

cp index.html favicon.ico $TARGET/devblog.croquis.com/

cd ko
jekyll --no-auto $TARGET/devblog.croquis.com/ko
cd ..

#cd en
#jekyll --no-auto $TARGET/devblog.croquis.com/en
#cd ..
