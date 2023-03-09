deployment="${deployment}"
release="${release}"
virtdir="./$${release}"
source $${virtdir}/bin/activate

echo "Disabling local docker registry in /etc/kolla/globals.yml..."
sed -i 's/^docker_registry:.*/#docker_registry: "172.28.7.127:4000"/g' /etc/kolla/globals.yml
sed -i 's/^docker_registry_insecure:.*/#docker_registry_insecure: yes/g' /etc/kolla/globals.yml
echo "Pulling Kolla-Ansible containers to localhost..."
kolla-ansible -i all-in-one pull
echo "Enabling local docker registry in /etc/kolla/globals.yml..."
sed -i 's/^#docker_registry:.*/docker_registry: "172.28.7.127:4000"/g' /etc/kolla/globals.yml
sed -i 's/^#docker_registry_insecure:.*/docker_registry_insecure: yes/g' /etc/kolla/globals.yml
echo "All done. Now run push_docker_img.sh in order to push the docker images to the local docker registry."
