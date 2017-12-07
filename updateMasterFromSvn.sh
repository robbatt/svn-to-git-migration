#!/bin/bash

#!/bin/bash
while [ true ] ; do
	echo '### updating master from svn ###'
	cd /path/to/workspace/projectdir/
	echo switched to `pwd`
	echo running 'git checkout master'
	git checkout master
	echo running 'git svn rebase'
	git svn rebase
done
