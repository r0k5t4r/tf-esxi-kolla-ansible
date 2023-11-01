# source information about kolla-ansible
source ~/env.sh
service="NFS Server"

. $HOME/activate.sh

echo "deploying $service..."
ansible-playbook ~/install-scripts/deploy_nfssrv.yml
