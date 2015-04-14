#!/bin/sh
#
# Script that sets up jhbuild, and the jhbuildrc files and moduleset
# files as symlinks from the git repository.  This version is for
# maintainers of the setup. If you are a user, just run the
# gtk-osx-build-setup.sh script.
#
# Copyright 2007, 2008 Imendio AB
#

SOURCE=$HOME/Source

do_exit()
{
    echo $1
    exit 1
}

if test x`which git` == x; then
    do_exit "Git isn't available, please install it and try again."
fi

if test ! -d $SOURCE; then
    do_exit "The directory $SOURCE does not exist, please create it and try again."
fi

# This will use jhbuild from git master, but note that jhbuild depends on
# pkg-config. If you use this, you'll either need to have installed pkg-config
# already with gtk-osx-build, or you'll need to build pkg-config with Homebrew.

echo "Checking out jhbuild from git..."
if ! test -d $SOURCE/jhbuild; then
    (cd $SOURCE ; git clone git://git.gnome.org/jhbuild )
else
    (cd $SOURCE/jhbuild && git pull >/dev/null)
fi

echo "Installing jhbuild..."
sed -i.bak -e 's/env python2/env python/' $SOURCE/jhbuild/scripts/jhbuild.in
(cd $SOURCE/jhbuild && ./autogen.sh >/dev/null && make -f Makefile.plain DISABLE_GETTEXT=1 install >/dev/null)

echo "Installing jhbuild configuration..."
ln -sfh `pwd`/jhbuildrc-gtk-osx $HOME/.jhbuildrc
ln -sfh `pwd`/jhbuildrc-gtk-osx-fw-10.4 $HOME/.jhbuildrc-fw-10.4
ln -sfh `pwd`/jhbuildrc-gtk-osx-fw-10.4-test $HOME/.jhbuildrc-fw-10.4-test
ln -sfh `pwd`/jhbuildrc-gtk-osx-cfw-10.4 $HOME/.jhbuildrc-cfw-10.4
if [ ! -f $HOME/.jhbuildrc-custom ]; then
    cp jhbuildrc-gtk-osx-custom-example $HOME/.jhbuildrc-custom
fi

echo "Setting up modulesets..."
ln -sfh `pwd`/modulesets-stable/bootstrap.modules $SOURCE/jhbuild/modulesets/
cd modulesets
for f in `ls *modules`; do
    ln -sfh `pwd`/$f $SOURCE/jhbuild/modulesets/
done

echo "Done."
