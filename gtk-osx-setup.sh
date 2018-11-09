#!/usr/bin/env bash
 ####################################################################
 # new-setup.sh gtk-osx setup with python virtual environments.     #
 #                                                                  #
 # Copyright 2018 John Ralls <jralls@ceridwen.us>                   #
 #                                                                  #
 # This program is free software; you can redistribute it and/or    #
 # modify it under the terms of the GNU General Public License as   #
 # published by the Free Software Foundation; either version 2 of   #
 # the License, or (at your option) any later version.              #
 #                                                                  #
 # This program is distributed in the hope that it will be useful,  #
 # but WITHOUT ANY WARRANTY; without even the implied warranty of   #
 # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the    #
 # GNU General Public License for more details.                     #
 #                                                                  #
 # You should have received a copy of the GNU General Public License#
 # along with this program; if not, contact:                        #
 #                                                                  #
 # Free Software Foundation           Voice:  +1-617-542-5942       #
 # 51 Franklin Street, Fifth Floor    Fax:    +1-617-542-2652       #
 # Boston, MA  02110-1301,  USA       gnu@gnu.org                   #
 ####################################################################

# Function envvardir. Tests environment variable, sets default value if unset,
# and creates the specified directory if it doesn't already exist. This
# will barf if the name indicates a file that isn't a directory.
envvar ()
{
    local _varname=$1
    if test -z "`eval echo '"$'"$_varname"'"'`"; then
        eval "export $_varname"'="'"$2"'"'
    fi
    if test ! -d "`eval echo '"$'"$_varname"'"'`"; then
        eval "mkdir -p $_varname"
    fi
}
# Environment variable defaults:
#
envvar DEVROOT $HOME
envvar DEVPREFIX $DEVROOT/.new_local
envvar PYTHONUSERBASE $DEVROOT/.new_local
envvar DEV_SRC_ROOT $DEVROOT/Source
envvar PYENV_ROOT $DEV_SRC_ROOT/pyenv
envvar PIP_CONFIG_DIR $HOME/.config/pip

export PYTHONPATH=$PYTHONUSERBASE/lib/python/site-packages:$PYTHONPATH

if test ! -d $DEVPREFIX/bin ; then
    mkdir -p $DEVPREFIX/bin
fi

GITLAB="https://gitlab.gnome.org/GNOME"
GITHUB="https://github.com"

# We need to have a local copy of bash when compiling to prevent SIP problems.
if test ! -x $DEVPREFIX/bin/bash; then
    cp /bin/bash $DEVPREFIX/bin
fi

# Setup pyenv
if test ! -x $PYENV_ROOT/libexec/pyenv; then
  if test -d $PYENV_ROOT; then
     rm -rf $PYENV_ROOT;
  fi
    git clone $GITHUB/pyenv/pyenv.git $PYENV_ROOT
fi

if test ! -x $DEVPREFIX/bin/pyenv ; then
    ln -s $PYENV_ROOT/bin/pyenv $DEVPREFIX/bin
fi

# Setup PIP; note that we're assuming that python is the system python
# at this point. Having set $PYTHONUSERBASE, pip will be installed in
# $PYTHONUSERBASE/bin and the requisite modules will go in
# $PYTHONUSERBASE/lib/python/site-packages.

if test ! -f "`eval echo $PIP_CONFIG_FILE`" ; then
    export PIP_CONFIG_FILE=$PIP_CONFIG_DIR/pip.conf
    mkdir -p $PIP_CONFIG_DIR
fi
PIP=`which pip`
if test ! -x "`eval echo $PIP`" ; then
    mv=`python --version 2>&1 | cut -b 12-13`
    if test $mv -lt 9 ; then
        curl https://bootstrap.pypa.io/get-pip.py -o $DEVPREFIX/get-pip.py
        python $DEVPREFIX/get-pip.py --user
        rm $DEVPREFIX/get-pip.py
    else
        python -m ensurepip --user
    fi
    pip install --upgrade --user pip
fi

# Install pipenv
pip install --upgrade --user pipenv

# Install jhbuild
if test ! -d $DEV_SRC_ROOT/jhbuild/.git ; then
    git clone $GITLAB/jhbuild.git $DEV_SRC_ROOT/jhbuild
    cd $DEV_SRC_ROOT/jhbuild
else #Get the latest if it's already installed
    cd $DEV_SRC_ROOT/jhbuild
    git pull
fi

# Install Ninja
NINJA=`which ninja`
if test ! -x "`eval echo $NINJA`"; then
    curl -kLs https://github.com/ninja-build/ninja/releases/download/v1.8.2/ninja-mac.zip -o $DEVPREFIX/ninja-mac.zip
    unzip -d $DEVPREFIX/bin $DEVPREFIX/ninja-mac.zip
    rm $DEVPREFIX/ninja-mac.zip
fi

if test ! -d $DEVPREFIX/etc ; then
    mkdir -p $DEVPREFIX/etc
fi
if test ! -f $DEVPREFIX/etc/Pipfile ; then
    cat  <<EOF > $DEVPREFIX/etc/Pipfile
[[source]]
url = "https://pypi.python.org/simple"
verify_ssl = true

[packages]
six = "*"
meson = "*"

[scripts]
jhbuild = "$DEVPREFIX/libexec/run_jhbuild.py"

[requires]
python_version = "3.6"
EOF
    cat <<EOF > $DEVPREFIX/etc/pipenv-env
export DEVROOT=$HOME
export DEVPREFIX=$DEVPREFIX
export PYTHONUSERBASE=$PYTHONUSERBASE
export DEV_SRC_ROOT=$DEV_SRC_ROOT
export PYENV_ROOT=$PYENV_ROOT
export PIP_CONFIG_DIR=$PIP_CONFIG_DIR
export PATH=$PYENV_ROOT/shims:$PATH
export LANG=C
EOF
fi
if test ! -f $DEVPREFIX/bin/jhbuild ; then
    cat <<EOF > $DEVPREFIX/bin/jhbuild
#!$DEVPREFIX/bin/bash
export PYTHONPATH=$PYTHONPATH
export PIPENV_DOTENV_LOCATION=$DEVPREFIX/etc/pipenv-env
export PIPENV_PIPFILE=$DEVPREFIX/etc/Pipfile
export PYENV_ROOT=$PYENV_ROOT

exec pipenv run jhbuild \$@
EOF
fi
if test ! -d $DEVPREFIX/libexec ; then
    mkdir -p $DEVPREFIX/libexec
fi
if test ! -f $DEVPREFIX/libexec/run_jhbuild.py ; then
    cat <<EOF > $DEVPREFIX/libexec/run_jhbuild.py
#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import os
import __builtin__
sys.path.insert(0, '$DEV_SRC_ROOT/jhbuild')
pkgdatadir = None
datadir = None
import jhbuild
srcdir = os.path.abspath(os.path.join(os.path.dirname(jhbuild.__file__), '..'))
__builtin__.__dict__['PKGDATADIR'] = pkgdatadir
__builtin__.__dict__['DATADIR'] = datadir
__builtin__.__dict__['SRCDIR'] = srcdir

import jhbuild.main
jhbuild.main.main(sys.argv[1:])

EOF
fi
if test ! -x $DEVPREFIX/bin/jhbuild ; then
    chmod +x $DEVPREFIX/bin/jhbuild
fi
if test ! -x $DEVPREFIX/libexec/run_jhbuild.py ; then
    chmod +x $DEVPREFIX/libexec/run_jhbuild.py
fi
if test "x`echo $PATH | grep $DEVPREFIX/bin`" == x ; then
    echo "PATH does not contain $DEVPREFIX/bin. You probably want to fix that."
fi
# pipenv wants enum34 because it's installed with Py2 but that conflicts
# with Py3 so remove it.
pip uninstall --yes enum34

SDKROOT=`xcrun --show-sdk-path`

export PIPENV_DOTENV_LOCATION=$DEVPREFIX/etc/pipenv-env
export PIPENV_PIPFILE=$DEVPREFIX/etc/Pipfile
export PATH=$PYENV_ROOT/shims:$PATH
export CFLAGS="-isysroot $SDKROOT -I$SDKROOT/usr/include"
export PYTHON_CONFIGURE_OPTS="--enable-shared"

pipenv install

BASEURL="https://gitlab.gnome.org/GNOME/gtk-osx/raw/master"

if test -L $HOME/.jhbuildrc ; then
    echo "Installing jhbuild configuration..."
    curl -ks $BASEURL/jhbuildrc-gtk-osx -o $HOME/.jhbuildrc
fi

if test ! -e $HOME/.jhbuildrc-custom ; then
   curl -ks $BASEURL/jhbuildrc-gtk-osx-custom-example -o $HOME/.jhbuildrc-custom
fi
