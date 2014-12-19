#!/bin/bash


# NOTICE: Should be run from repo's root dir.


# Binaries
GIT=`which git`;
REPO=`which repo`;
DCH=`which dch`;
DPKGBUILD=`which dpkg-buildpackage`;
DISTRIBUTION="trusty"

PROJECTS="$($REPO forall -c 'echo ${REPO_PROJECT}')"
BASEDIR=`pwd`;

DEBCONTROL="$BASEDIR/debian/control"
MANIFEST="$BASEDIR/debian/manifest"
OLD_MANIFEST="$BASEDIR/debian/manifest.old"
GITLOG="$BASEDIR/debian/changelog.git"
GITLOGTMP="${GITLOG}.tmp"

VERSION="1:2014.2"

log () {
	echo -en "$1";
}


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

test -e $GITLOG && rm $GITLOG

for PROJ in $PROJECTS;
do
	CUR_LOG=`cat $MANIFEST | grep ^$PROJ | cut -d ' ' -f2`;
	PREV_LOG=`cat $OLD_MANIFEST | grep ^$PROJ | cut -d ' ' -f2`;

	if [ -z "$CUR_LOG" ]
	then
		echo "Could not get current revision of $PROJ. Bailing out."
		exit 1
	elif [ -z "$PREV_LOG" ]
	then
		echo -en "$PROJ added at revison ${CUR_LOG}\n\n" >> $GITLOG;
	elif [ "$CUR_LOG" != "$PREV_LOG" ]
	then
		if [ "$PROJ" == "autobuild" ]
		then
			$GIT log $PREV_LOG..$CUR_LOG --pretty='format:  [%h] %<(55,trunc)%s' | grep -v '] Build number' > $GITLOGTMP;
			if [ $(wc -l $GITLOGTMP | cut -f1 -d' ') -gt 0 ]
			then
				echo "Packaging:" >> $GITLOG;
				cat $GITLOGTMP >> $GITLOG;
				rm $GITLOGTMP
			fi
		else
			cd $BASEDIR/$PROJ;

			# If no symlink is present, we create them before proceeds.
			test -L debian || ln -s ../debian debian

			echo "${PROJ}:" >> $GITLOG;
			$GIT log $PREV_LOG..$CUR_LOG --pretty='format:  [%h] %<(55,trunc)%s' >> $GITLOG;
			cd $BASEDIR;
		fi
	fi
done

test -e $GITLOG || exit 2

# Create the changelog version first
$DCH --newversion $VERSION.$BUILD_NUMBER "Automated build"

# Now let's populate debian/changelog
cat $GITLOG | while IFS= read line; do $DCH "$line"; done

$DCH -D $DISTRIBUTION -r ""

# Now let's (source) build it
$DPKGBUILD -uc -us -S -I.repo -I.git

