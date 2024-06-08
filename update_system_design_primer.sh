#!/bin/bash

rm -rf $(pwd)/docs/system-design/system-design-primer
cd $(pwd)/docs/system-design
git clone git@github.com:donnemartin/system-design-primer.git
cd system-design-primer
rm -rf .git
rm -rf .github
cp README-zh-Hans.md index.md