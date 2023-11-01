#!/bin/bash
kolla_mod=$1
tags=$2

. $HOME/activate.sh

echo "deploying $kolla_mod..."
kolla-ansible -i $HOME/$deployment deploy --tags $tags