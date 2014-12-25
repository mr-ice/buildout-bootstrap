#!/bin/bash

# The buildout bootstrap url to use
GITPIPURL="https://raw.github.com/pypa/pip/master/contrib/get-pip.py"
BBSURL="http://downloads.buildout.org/2/bootstrap.py"
BBSURL="https://raw.githubusercontent.com/buildout/buildout/master/bootstrap/bootstrap.py"

# Process Commandline Arguments ##>
# bootstrap.py
# --use /path/to/python
# --prefix /some/where/to/work
# --workdir /some/where/else
# or
#
# bootstrap.py
# --build /path/to/python.tgz
# --prefix /some/where/to/work
# --workdir /some/where/else

usepython=""
useprefix=""
useworkdir=""
usebuild=""

while [ "$#" -ge 1  ]; do
    case "$1" in
        --use) usepython="$2"; shift;;
        --use=*) usepython="${1#--use=}";;
        --prefix) useprefix="$2"; shift;;
        --prefix=*) useprefix="${1#--prefix=}";;
        --workdir) useworkdir="$2"; shift;;
        --workdir=*) useworkdir="${1#--workdir=}";;
        --build) usebuild="$2"; shift;;
        --build=*) usebuild="${1#--usebuild=}";;
        --proxy) useproxy="$2"; shift;;
        --proxy=*) useproxy="${1#--useproxy=}";noproxy=false;;
        --no-proxy) useproxy=""; noproxy=true;;
        --wget-options) wgetoptions="$2"; shift;;
        --wget-options=*) wgetoptions="${1#--wget-options=}"; shift;;
        --curl-options) curloptions="$2"; shift;;
        --curl-options=*) curloptions="${1#--curl-options=}"; shift;;
    esac
    shift
done ##<


##> Define some variable defaults
usepython_valid=false
useprefix_valid=false
useworkdir_valid=false
usebuild_valid=false

##<
inspect_tarball() { ##>
    _tarball="$1"
    case "$_tarball" in
       *.tar.gz|*.tgz)  _zopt="-z";;
       *.tar.bz2|*.tbz2) _zopt="-j";;
       *.tar.xz|*.txz) _zopt="-J";;
       *.tar.Z) _zopt="-Z";;
       *) _zopt="";
    esac

    _directory="`tar $_zopt -tf $_tarball | head -1`"
} ##<

die() { ##>
    format=$1
    case "$format" in
        *"\n") :;;
        *) format="$format\n";;
    esac
    shift
    printf "$format" "$@" >&2
    exit 1
} ##<

# cannot specify both a python already installed and to build our own
if [ -n "$usepython" -a -n "$usebuild" ]; then
    die "Error, --use is invalid with --build and vice versa" 
fi

# but must specify one of use python or build python
if [ -z "$usepython" -a -z "$usebuild" ]; then
    die "Error: one of --use or --build is required"
fi

# if we're building, we require a prefix directory
if [ -n "$usebuild" -a -z "$useprefix" ]; then
    eval usebuild="$usebuild"     # expand specials
    die "Error: --build requires --prefix"
fi

# validate that usepython is an executable (if it is executable and not
# python it won't work either).
if [ -n "$usepython" -a -f "$usepython" -a -x "$usepython" ]; then
    eval usepython="$usepython"   # expand specials
    usepython_valid=true
fi

# validate that the workdir specified either already exists as a directory
# or that it is creatable. 
if test -d "$useworkdir" || mkdir -p "$useworkdir" >/dev/null; then
    eval useworkdir="$useworkdir"   # expand specials
    useworkdir_valid=true
fi

if ! "$useworkdir_valid"; then
    die "Cannot use workdir \"$useworkdir\""
fi

# validate that the prefix specified either
#    exists, is a directory, and is empty
#    or
#    can be created
if [ -n "$useprefix" ]; then
    eval useprefix="$useprefix"   # expand specials
    if [ -d "$useprefix" ]; then
        if [ -n "`ls -A $useprefix`" ]; then
            die "Error: prefix \"%s\" is not empty!" "$useprefix"
        else
            useprefix_valid=true
        fi
    elif mkdir -p "$useprefix" >/dev/null; then
        useprefix_valid=true
    fi
fi

if ! "$useprefix_valid"; then
    die "Cannot work in $useprefix."
fi


# find one of wget or curl in the path
usewget=false
usecurl=false

if `which curl > /dev/null`; then
    usecurl=true
elif `which wget > /dev/null`; then
    usewget=true
fi

download() { ##> uses wget or curl and any proxy settings to download a URL
    _url="$1"

    if ! "$noproxy" && test -n "$useproxy"; then
        export HTTP_PROXY="$useproxy"
        export HTTPS_PROXY="$useproxy"
        export http_proxy="$useproxy"
        export https_proxy="$useproxy"
    fi
    if $usecurl; then
        curl -q -O "$_url"
    elif $usewget; then
        wget -q -O - "$_url"
    fi
} ##<

create_buildout_config() { ##> create our buildout.cfg template
cat <<EOF > buildout.cfg
# this is a skeleton buildout.cfg to install pip, virtualenv, and
# virtualenvwrapper.  You can read about zc.buildout and it's config
# file format once you've installed zc.buildout, and configure your
# own list of modules for buildout to manage.  
#
# Note that in this scheme pip, setuptools, setup.py, and buildout
# are all configured to do virtually the same things.  buildout will
# uninstall modules installed in those other ways, so be sure to
# update this config if you intend to use buildout.
#
[buildout]
parts = pip virtualenv virtualenvwrapper
bin-directory = bin

[pip]
recipe = zc.recipe.egg
eggs = pip

[virtualenv]
recipe = zc.recipe.egg
eggs = virtualenv

[virtualenvwrapper]
recipe = zc.recipe.egg
eggs = virtualenvwrapper

EOF
} ##<

if ! "$usecurl" && ! "$usewget"; then
    die "Couldn't find wget or curl, aborting, have to download stuff"
fi

if [ -n "$usebuild" -a -e "$usebuild" -a -f "$usebuild" ]; then
    case "$usebuild" in
        *.tar.gz|*.tar|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz)
            inspect_tarball "$usebuild"
            if [ "$_directory" ]; then
                usebuild_valid=true
            fi
    esac
fi

if "$usebuild_valid" && "$useprefix_valid"; then
    mkdir -p "$useprefix/.build"
    cd "$useprefix/.build"
    tar $_zopt -xf $usebuild
    cd $_directory
    echo "Configuring Python..."
    ./configure --prefix=$useprefix > configure.log 2>&1
    echo "Building Python..."
    make > make.log 2>&1
    echo "Installing Python..."
    make install > install.log 2>&1
    usepython="$useprefix/bin/python"
    usepython_valid=true
fi

if "$useworkdir_valid"; then
    mkdir -p $useworkdir
else
    die "Workdir is not valid"
fi

if "$usepython_valid" && "$useworkdir_valid"; then
    mkdir -p "$useworkdir"
    cd "$useworkdir"
    download "$BBSURL"
    create_buildout_config
    $usepython bootstrap.py
    bin/bootstrap
    bin/virtualenv .
    source bin/activate
    bin/python bootstrap.py
    bin/bootstrap
else
    die "Error, got to bootstrap without a valid python or workdir"
fi

