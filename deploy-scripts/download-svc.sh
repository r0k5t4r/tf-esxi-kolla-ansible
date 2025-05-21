#!/bin/bash
option=$1
kolla_mod=$2
kolla_globals_src_dir="$HOME/globals.d"
kolla_globals_file="$kolla_mod.yml"
kolla_globals_file_src=$kolla_globals_src_dir/$kolla_globals_file
kolla_globals_dir="/etc/kolla/globals.d"

# Ensure the globals directory exists
test -d $kolla_globals_dir || mkdir -p $kolla_globals_dir

# Copy $kolla_mod.yml to $kolla_globals_dir
echo "Copying $kolla_globals_file_src to $kolla_globals_dir..."
cp $kolla_globals_file_src $kolla_globals_dir

# Check if use_local_registry is set to true
if [[ "$use_local_registry" == "true" ]]; then
    echo "Pulling $kolla_mod docker image..."
    sh -v $HOME/pull_kolla_docker_img.sh $option $kolla_mod

    echo "Pushing $kolla_mod to local docker registry..."
    sudo sh -v $HOME/push_docker_img.sh
else
    kolla-ansible -i all-in-one pull $option $kolla_mod
    echo "Skipping pull and push operations as use_local_registry is not set to true."
fi
