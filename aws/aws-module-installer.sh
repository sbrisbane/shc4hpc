#!/bin/bash
PYMINORVERS=$(python3 --version | awk '{ print $NF }' | awk -F . '{print $NF}')
if [ 6 -gt $PYMINORVERS ]; then
  VENV=pyvenv 
else
  VENV="python3 -m venv"
fi
BUILDDIR=../.build/aws
mkdir -p $BUILDDIR
#work around broken venv in rhel7
$VENV  --without-pip $BUILDDIR/python 
source  $BUILDDIR/python/bin/activate
python3 get-pip-21.0.1.py
deactivate
############################
source  $BUILDDIR/python/bin/activate

python3 -m pip install -r aws-requirements.txt
mkdir $BUILDDIR/ansible
cp ansible.cfg $BUILDDIR/ansible
cd $BUILDDIR/ansible
ansible-galaxy collection install amazon.aws -p ./


