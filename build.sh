#!/bin/bash

cp index.html ../homepage/devblog.croquis.com

cd ko
jekyll --no-auto
cd ..

#cd en
#jekyll --no-auto
#cd ..
