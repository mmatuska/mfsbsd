#!/bin/sh

set -x

mkdir tmp
#
# Download packages (and their dependencies) listed in packages.txt
#
pkg fetch -y -d -o tmp `cat packages.txt`
#
# Copy them into the packages directory
#
mv tmp/All/*.txz .

rm -rf tmp
