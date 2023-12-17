#!/bin/bash
kolla_mod=$1
kolla_globals_src_dir="$HOME/globals.d"
kolla_globals_file="$kolla_mod.yml"
kolla_globals_file_src=$kolla_globals_src_dir/$kolla_globals_file
kolla_globals_dir="/etc/kolla/globals.d"
test -d $kolla_globals_dir || mkdir -p $kolla_globals_dir
# copy $kolla_mod.yml to $kolla_globals_dir
echo "Copying $kolla_globals_file_src to $kolla_globals_dir..."
cp $kolla_globals_file_src $kolla_globals_dir
echo "Pulling $kolla_mod docker image..."
sh -v $HOME/pull_kolla_docker_img.sh $kolla_mod
echo "Pushing $kolla_mod to local docker registry..."
sudo sh -v $HOME/push_docker_img.sh