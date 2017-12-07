#!/bin/bash
set -e # kill script on first error

function echoDuration {
	time=$2
	secs=$(($time % 60))
	mins=$(($time % 3600 / 60)) 
	hrs=$(($time % 86400 / 3600))
	days=$(($time % 2592000 / 86400 ))
	mons=$(($time % 31104000 / 2592000 ))

	echo -e ""$1" time:"$2" seconds ( months:"$mons" days:"$days" \t hours:"$hrs" \t minutes:"$mins" \t seconds:"$secs" )"
}

if [ -e $1 ] ; then # if no param is given
	echo "in continuation mode, apply any param if you want to clone"
	echo
	continueMode=true;
fi

svnUrl=https://svn.firma.de/... # svn repository to clone from
fromRev=0 # change this to fetch only history from a certain revision onwards
interval=10 # interval for fetching
commitsPerDay=900 # average commits per day migrated (for estimation how long migration will take, depends on commit sizes)
dir=projectdir # target folder to create the git repo (next to this script)
workspace=/path/to/workspacedir # parent folder of the target folder

STARTTIME=$(date +%s)

# initial clone (just one revision so everything is set up for the iterative fetching)
# comment this block when script is only used to continue fetching
if [ -e $continueMode ] ; then 
	cd $workspace
	echo "### initial cloning from svn (from revision "$fromRev")###"
	git svn clone --authors-file=svn-to-git-authors.txt --preserve-empty-dirs --placeholder-filename=.empty --stdlayout --prefix=origin/ -r$fromRev:$(($fromRev+1)) $svnUrl $dir
fi


# start fetching in iterations
cd $workspace/$dir

currentHEAD_SVNrev=`svn info $svnUrl | grep 'Last Changed Rev' | awk '{ print $4; }'`
currentHEAD_GITref=`git rev-parse HEAD`
currentFETCH_HEADref=`git rev-parse origin/trunk`
currentMigrateRev=`git svn find-rev $currentHEAD_GITref`  # kurzer fetch dazwischen um rev zu finden
currentFetchedRev=`git svn find-rev $currentFETCH_HEADref`  # kurzer fetch dazwischen um rev zu finden

commitsToFetch=`svn log -q -r$currentFetchedRev:$currentHEAD_SVNrev --stop-on-copy $svnUrl | grep "^r" | wc -l`
commitsToFetch=$(($commitsToFetch - 1)) # always shows one more, even if on same revision
estimateFetchTime=$(($commitsToFetch * 86400 / $commitsPerDay))

commitsToMigrate=`svn log -q -r$currentMigrateRev:$currentHEAD_SVNrev --stop-on-copy $svnUrl | grep "^r" | wc -l`
commitsToMigrate=$(($commitsToMigrate - 1)) # always shows one more, even if on same revision
estimateMigrationTime=$(($commitsToMigrate * 86400 / $commitsPerDay))


echo "svn url: "$svnUrl
echo "start time: " `date`
echo
echo "(remote)  svn at: "$currentHEAD_SVNrev
echo "(local)   svn at: "$currentMigrateRev"  (git ref: "$currentHEAD_GITref")"
echo "(fetched) svn at: "$currentFetchedRev"  (git ref: "$currentFETCH_HEADref")"
echo "commits to migrate (per url): "$commitsToMigrate
echo "commits left to fetch       : "$commitsToFetch
echoDuration "estimate time to migrate commits: " $estimateMigrationTime
echoDuration "estimate time left to migrate   : " $estimateFetchTime
echo

# set current migration state to last fetched commit
if [[ $currentFetchedRev > $currentMigrateRev ]] ; then
	currentMigrateRev=$currentFetchedRev
	echo "continue fetching at revision "$currentFetchedRev
fi

while [[ $(($currentMigrateRev + $interval)) -le $currentHEAD_SVNrev ]] ; do
	echo "### git svn fetch -r"$currentMigrateRev":"$(($currentMigrateRev + $interval))" ###"
	git svn fetch -r$currentMigrateRev:$(($currentMigrateRev + $interval))
    currentMigrateRev=$(($currentMigrateRev + $interval))
done

# the rest added since script start
echo "### git svn fetch -r"$currentMigrateRev":HEAD ###"
git svn fetch -r$currentMigrateRev:HEAD

BEFORE_BAK_TIME=$(date +%s)

# make a backup before rebasing
echo "### backup, before final rebase will rewrite the history ###"
echo "### in case of interrupt restore folder, then run 'git svn rebase' in it ###"

bakDir=_bak_$(date +%s)_$dir
mkdir -p $workspace/$bakDir
cp -R $workspace/$dir/* $workspace/$bakDir

AFTER_BAK_TIME=$(date +%s)

# set head pointers
echo "### final rebase to set head pointers ###"
git svn rebase

# remove backup after successful rebase
echo "### removing backup after successful rebase ###"
rm -Rf $workspace/$bakDir

# final stats
ENDTIME=$(date +%s)
FINALDURATION=$((( $ENDTIME - $AFTER_BAK_TIME ) + ( $BEFORE_BAK_TIME - $STARTTIME )))
correctCommitsPerDay=$(( $commitsToMigrate * 86400 / $FINALDURATION ))

echo
echoDuration "estimate migration " $estimateMigrationTime
echo " - at avg "$commitsPerDay" commits per day"
echoDuration "elapsed. migration " $FINALDURATION
echo " - at avg "$correctCommitsPerDay" commits per day"
echo
echo "commits migrated: "$commitsToMigrate
echo
echo "### Migration successful ###"
