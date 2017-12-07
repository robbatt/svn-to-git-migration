#!/bin/bash
set -e

repoDir=$1

echo "stripping blobs from history bigger than 1MB ($repoDir)"

java -jar bfg-1.11.6.jar --strip-biggest-blobs 500 --protect-blobs-from branch1,branch2,develop,master,trunk $repoDir

echo
echo '#############################################'
echo
cd $repoDir
echo switched to `pwd`
echo runnig 'git gc'

git reflog expire --expire=now --all
git gc --prune=now --aggressive
