#!/bin/bash

# buidout-bootstrap - how to bootstrap python buildout with virtualenv
# Copyright (C) 2014 Michael Rice <michael at riceclan dot org>
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 

cat << EOF
************
Bootstrapping buildout.  This will create buildout.cfg and bootstrap.py
in the current directory
   `pwd`

************
If this is NOT what you want, hit ^C now
EOF
echo -n "Ok to continue? "
read ans

BBSURL="http://downloads.buildout.org/2/bootstrap.py"
BBSURL="https://raw.githubusercontent.com/buildout/buildout/master/bootstrap/bootstrap.py"

if [ ! -f bootstrap.py ]; then

    curl -q -z bootstrap.py -O $BBSURL
fi

if [ ! -f buildout.cfg ]; then

  eggs="pip virtualenv"
  
  echo "Automatic: setuptools, pip, virtualenv, buildout"
  echo "Enter additional eggs>> "
  read addeggs
  
  eggs="$eggs $addeggs"

  cat > buildout.cfg <<EOT
[buildout]
parts = $eggs
bin-directory = bin

EOT
  
  for egg in ${eggs}; do
  
  cat >> buildout.cfg <<EOT
[$egg]
recipe = zc.recipe.egg
eggs = $egg

EOT

  cat >> buildout.cfg <<EOT
[versions]
setuptools = 7.0

EOT
  
  done
  
fi

# First pass, get virtualenv installed so that we can use the local python
python bootstrap.py --setuptools-version 7.0 || exit   # configure for bin/buildout
bin/buildout || exit          # run buildout to get egss from buildout.cfg
bin/virtualenv . || exit      # configure to use virtualenv
source bin/activate || exit   # activate via virtualenv

# Second pass, rebuild using the local python
python bootstrap.py --setuptools-version 7.0 || exit   # re-run bootstrap with the local python
bin/buildout || exit          # re-run buildout
