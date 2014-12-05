#!/bin/bash


# NOTICE: Should be run from repo's root dir.


# Binaries
GIT=`which git`;
REPO=`which repo`;
DCH=`which dch`;
DPKGBUILD=`which dpkg-buildpackage`;


PROJECTS="cinder python-cinderclient"
BASEDIR=`pwd`;

MANIFEST="$BASEDIR/debian/manifest"
OLD_MANIFEST="$BASEDIR/debian/manifest.old"
GITLOG="$BASEDIR/debian/changelog.git"

VERSION="1:2014.2"

log () {
	echo -en "$1";
}


# Let's sync the repo first
cd $BASEDIR;
$REPO sync;

if [ $? -ne 0 ]; then
	log "Repo sync failed. Aborting.\n\n";
	exit 1;
fi


# Frist, backup the old manifest
log "Backup $MANIFEST to $OLD_MANIFEST\n\n";
mv -f $MANIFEST $OLD_MANIFEST;


# Now lets create current manifest file
log "Generating new manifest file in $MANIFEST\n\n";
$REPO forall -c 'echo -n "${REPO_PROJECT} " ; git rev-parse HEAD' > $MANIFEST;



if ! [ -f $MANIFEST ]; then
	log "Manifest file $MANIFEST not available. Aborting.\n";
fi

if ! [ -f $OLD_MANIFEST ]; then
	log "Manifest file $OLD_MANIFEST not available. Aborting.\n";
fi

rm $GITLOG

for PROJ in $PROJECTS;
do
	CUR_LOG=`cat $MANIFEST | grep ^$PROJ | cut -d ' ' -f2`;
	PREV_LOG=`cat $OLD_MANIFEST | grep ^$PROJ | cut -d ' ' -f2`;

	if [ -z $CUR_LOG ] || [ -z $PREV_LOG ]; then
		echo -en "Error in getting git log for proj $PROJ\n\n" >> $GITLOG;
	else
		if [ "$CUR_LOG" = "$PREV_LOG" ]; then
			echo -en "No changes in project $PROJ\n\n" >> $GITLOG;
		else
			echo -en "Changes for project $PROJ since git revision $PREV_LOG\n\n" >> $GITLOG;
			cd $BASEDIR/$PROJ;
			$GIT log $PREV_LOG..$CUR_LOG --oneline >> $GITLOG;
			cd $BASEDIR;
			echo -en "Changes end for project $PROJ\n\n" >> $GITLOG;
		fi
	fi
done


# Create the changelog version first
$DCH --newversion $VERSION.$BUILD_NUMBER "Building against $VERSION.$BUILD_NUMBER"

# Now let's populate debian/changelog
cat $GITLOG | while read line; do $DCH "$line"; done


# Now let's (source) build it
$DPKGBUILD -uc -us -S

