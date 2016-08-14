#!/bin/bash
set -e
rm -rf bin || exit 0;
mkdir bin;
haxe doc.hxml

if [ -z "$GH_TOKEN" ]; then
	echo "Skipping pushing documentation to GitHub - missing $GH_TOKEN (probably in a PR build).";
    exit 0;
else
    echo "Pushing documentation to GitHub"
fi

cd bin/api
git init
git config user.name "Travis CI"
git config user.email "slusnucky@gmail.com"
git add .
git commit -m "Deploy to GitHub Pages"

# Force push from the current repo's master branch to the remote
# repo's gh-pages branch. (All previous history on the gh-pages branch
# will be lost, since we are overwriting it.) We redirect any output to
# /dev/null to hide any sensitive credential data that might otherwise be exposed.
git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:gh-pages > /dev/null 2>&1