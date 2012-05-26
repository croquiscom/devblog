#!/bin/bash

mkdir -p ../homepage/devblog.croquis.com

cp index.html favicon.ico ../homepage/devblog.croquis.com/

cd ko
jekyll --no-auto ../../homepage/devblog.croquis.com/ko
cd ..

#cd en
#jekyll --no-auto ../../homepage/devblog.croquis.com/en
#cd ..
