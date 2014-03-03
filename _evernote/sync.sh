#!/bin/sh
git pull origin master
rm ../ko/_posts/*.html
coffee fetch.coffee
git add ../ko
git commit -m 'posts from Evernote updated'
git push origin master
