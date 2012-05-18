#!/bin/bash

mkdir -p ../homepage/devblog.croquis.com

cp index.html ../homepage/devblog.croquis.com/

cd ko
jekyll --no-auto
cd ..

#cd en
#jekyll --no-auto
#cd ..
