#!/bin/bash

# source information about kolla-ansible
source ~/env.sh

# see https://docs.openstack.org/kolla-ansible/2023.2/reference/containers/magnum-guide.html for more information
kolla_mod="magnum"
tags="common,horizon,magnum"
option="--tags"

# Download kolla docker container
sh ~/deploy-scripts/download-svc.sh $option $kolla_mod

# Create magnum.conf file. In this file you can define additional settings for Magnum
cat > /etc/kolla/config/magnum.conf << EOF
[trust]
cluster_user_trust = True
EOF

# Each OpenStack release has a specific version of Fedora CoreOS (FCOS) and K8s that are compatible
# See: https://docs.openstack.org/magnum/latest/user/index.html#supported-versions
case $release in
2023.2)
    k8svers="v1.25.9"
    newk8svers="v1.26.8"
    # Fedora Coreos 38
    COREOSMAJ="38"
    COREOSVERS="$COREOSMAJ.20230806.3.0"
    ;;
2023.1)
    k8svers="v1.23.3"
    newk8svers="v1.24.16"
    # Fedora Coreos 37
    COREOSMAJ="37"
    COREOSVERS="$COREOSMAJ.20221127.3.0"
    ;;
*)
    k8svers="v1.21.11"
    k8slabels=""
    # Fedora Coreos 35
    COREOSMAJ="35"
    COREOSVERS="$COREOSMAJ.20220424.3.0"
    ;;
esac

. $HOME/activate.sh
. /etc/kolla/admin-openrc.sh

COREOSFILE="fedora-coreos-$COREOSVERS-openstack.x86_64.qcow2"
COREOSXZ="$COREOSFILE.xz"
COREOSDLURL="https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/$COREOSVERS/x86_64/$COREOSXZ"

# Download Fedora CoreOS images
echo "Downloading Fedora CoreOS $COREOSMAJ..."
curl -k0 $COREOSDLURL -o $COREOSXZ
echo "Extracting Fedora CoreOS $COREOSMAJ..."
unxz $COREOSXZ

# Upload Fedora Core OS image to glance
echo "Uploading Fedora CoreOS $COREOSMAJ to Glance..."
openstack image create Fedora-CoreOS-$COREOSMAJ \
--public \
--disk-format=qcow2 \
--container-format=bare \
--property os_distro='fedora-coreos' \
--file=$COREOSFILE --progress

# Create small Flavor to use with K8s
openstack flavor create m1.kubernetes.small \
--disk 10 \
--vcpu 1 \
--ram 2048 \
--public \
--description "kubernetes small flavor"

# Create medium Flavor to use with K8s
openstack flavor create m1.kubernetes.med \
--disk 20 \
--vcpu 2 \
--ram 4096 \
--public \
--description "kubernetes medium flavor"

# Create big flavor to use with K8s
openstack flavor create m1.kubernetes.big \
--disk 40 \
--vcpu 2 \
--ram 8192 \
--public \
--description "kubernetes big flavor"

# Fix Bug
# For more info see: https://lists.openstack.org/archives/list/openstack-discuss@lists.openstack.org/message/Z2Y47MLZCO6YTHOJQHDQXVTQV6HKG7RF/
openstack role add --user=magnum_trustee_domain_admin --user-domain magnum --domain magnum admin

# Deploy kolla svc
sh ~/deploy-scripts/deploy-svc.sh $kolla_mod $tags

# Install Openstack Magnum CLI client
pip install python-magnumclient python-heatclient

# Create cinder csi yml file
cat > csi-cinder-sc.yml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-sc-cinderplugin
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: cinder.csi.openstack.org
allowVolumeExpansion: true
EOF

# Pull and push magnum container images only if pull_magnum_local_registry is true
if [ "$pull_magnum_local_registry" = "true" ]; then
    echo "Pulling Magnum container images as pull_magnum_local_registry is set to true..."

    # Pull all magnum container images from the external file
    while read -r img; do
        # Skip empty lines and comments
        [[ -z "$img" || "$img" =~ ^# ]] && continue
        echo "Pulling $img..."
        sudo docker pull $img
    done < magnum_docker_images.txt

    # Create script to push magnum docker images to central docker registry
    cat > ~/push_magnum_docker_img.sh << EOF
#!/bin/bash
REGISTRY="${docker_registry_magnum}"
docker images --format "{{.Repository}} {{.Tag}}" | grep -v ${release} | grep -v local | while read -r image tag; do
    newimg=\$(echo \${image} | rev | cut -d / -f 1 | rev)
    echo "Tagging \${image}:\${tag} as \${REGISTRY}/\${newimg}:\${tag}"
    docker tag \${image}:\${tag} \${REGISTRY}/\${newimg}:\${tag}
    echo "Pushing \${REGISTRY}/\${newimg}:\${tag}"
    docker push \${REGISTRY}/\${newimg}:\${tag}
done
EOF

    # Make the script executable
    chmod +x ~/push_magnum_docker_img.sh

    echo "Pushing Magnum container images to local registry..."
    sudo sh ~/push_magnum_docker_img.sh
else
    echo "Skipping Magnum container image pull and push as pull_magnum_local_registry is not set to true."
fi

# Create cluster templates script
cat > create_magnum_templates.sh << EOF
#!/bin/bash

# Cluster templates for Openstack release $release

# Create cluster template with k8s version $newk8svers and containerd CRI
openstack coe cluster template create k8s-flan-small-$COREOSMAJ-$newk8svers-containerd \\
--image Fedora-CoreOS-$COREOSMAJ \\
--keypair mykey \\
--external-network ${EXT_NET} \\
--fixed-network demo-net \\
--fixed-subnet demo-subnet \\
--dns-nameserver ${neutron_ext_net_dns} \\
--flavor m1.kubernetes.small \\
--master-flavor m1.kubernetes.small \\
--volume-driver cinder \\
--docker-volume-size 10 \\
--network-driver flannel \\
--docker-storage-driver overlay2 \\
--coe kubernetes \\
--labels kube_tag=$newk8svers-rancher1,hyperkube_prefix=docker.io/rancher/,container_runtime=containerd,docker_volume_type=__DEFAULT__

# Create cluster template with k8s version $newk8svers and containerd CRI using local docker registry
openstack coe cluster template create k8s-flan-small-$COREOSMAJ-$newk8svers-containerd-local-reg \\
--image Fedora-CoreOS-$COREOSMAJ \\
--keypair mykey \\
--external-network ${EXT_NET} \\
--fixed-network demo-net \\
--fixed-subnet demo-subnet \\
--dns-nameserver ${neutron_ext_net_dns} \\
--flavor m1.kubernetes.small \\
--master-flavor m1.kubernetes.small \\
--volume-driver cinder \\
--docker-volume-size 5 \\
--network-driver flannel \\
--docker-storage-driver overlay2 \\
--coe kubernetes \\
--labels kube_tag=$newk8svers-rancher1,container_infra_prefix=${docker_registry_magnum}/,container_runtime=containerd,docker_volume_type=__DEFAULT__

openstack coe cluster template update k8s-flan-small-$COREOSMAJ-$newk8svers-containerd-local-reg replace insecure_registry="${docker_registry_magnum}"

# Create cluster template with k8s version $k8svers
openstack coe cluster template create k8s-flan-small-$COREOSMAJ-$k8svers \\
--image Fedora-CoreOS-$COREOSMAJ \\
--keypair mykey \\
--external-network ${EXT_NET} \\
--fixed-network demo-net \\
--fixed-subnet demo-subnet \\
--dns-nameserver ${neutron_ext_net_dns} \\
--flavor m1.kubernetes.small \\
--master-flavor m1.kubernetes.small \\
--volume-driver cinder \\
--docker-volume-size 10 \\
--network-driver flannel \\
--docker-storage-driver overlay2 \\
--coe kubernetes \\
--labels kube_tag=$k8svers-rancher1,hyperkube_prefix=docker.io/rancher/,docker_volume_type=__DEFAULT__

# Create cluster template with k8s version $k8svers using local docker registry
openstack coe cluster template create k8s-flan-small-$COREOSMAJ-$k8svers-local-reg \\
--image Fedora-CoreOS-$COREOSMAJ \\
--keypair mykey \\
--external-network ${EXT_NET} \\
--fixed-network demo-net \\
--fixed-subnet demo-subnet \\
--dns-nameserver ${neutron_ext_net_dns} \\
--flavor m1.kubernetes.small \\
--master-flavor m1.kubernetes.small \\
--volume-driver cinder \\
--docker-volume-size 5 \\
--network-driver flannel \\
--docker-storage-driver overlay2 \\
--coe kubernetes \\
--labels kube_tag=$k8svers-rancher1,container_infra_prefix=${docker_registry_magnum}/,docker_volume_type=__DEFAULT__

openstack coe cluster template update k8s-flan-small-$COREOSMAJ-$k8svers-local-reg replace insecure_registry="${docker_registry_magnum}"

# Create cluster template with k8s version $k8svers, containerd CRI and Master LB FIP - REQUIRES OCTAVIA!!!
openstack coe cluster template create k8s-flan-small-$COREOSMAJ-$k8svers-octavia-containerd-mlb-fip \\
--image Fedora-CoreOS-$COREOSMAJ \\
--keypair mykey \\
--external-network ${EXT_NET} \\
--fixed-network demo-net \\
--fixed-subnet demo-subnet \\
--dns-nameserver ${neutron_ext_net_dns} \\
--flavor m1.kubernetes.med \\
--master-flavor m1.kubernetes.med \\
--volume-driver cinder \\
--docker-volume-size 10 \\
--network-driver flannel \\
--docker-storage-driver overlay2 \\
--coe kubernetes \\
--master-lb-enabled \\
--floating-ip-disabled \\
--labels kube_tag=$k8svers-rancher1,hyperkube_prefix=docker.io/rancher/,container_runtime=containerd,master_lb_floating_ip_enabled=true,docker_volume_type=__DEFAULT__

# Create cluster template with k8s version $newk8svers, containerd CRI and Master LB FIP - REQUIRES OCTAVIA!!!
openstack coe cluster template create k8s-flan-small-$COREOSMAJ-$newk8svers-octavia-containerd-mlb-fip \\
--image Fedora-CoreOS-$COREOSMAJ \\
--keypair mykey \\
--external-network ${EXT_NET} \\
--fixed-network demo-net \\
--fixed-subnet demo-subnet \\
--dns-nameserver ${neutron_ext_net_dns} \\
--flavor m1.kubernetes.small \\
--master-flavor m1.kubernetes.small \\
--volume-driver cinder \\
--docker-volume-size 10 \\
--network-driver flannel \\
--docker-storage-driver overlay2 \\
--coe kubernetes \\
--master-lb-enabled \\
--floating-ip-disabled \\
--labels kube_tag=$newk8svers-rancher1,hyperkube_prefix=docker.io/rancher/,container_runtime=containerd,master_lb_floating_ip_enabled=true,docker_volume_type=__DEFAULT__
EOF

# Make the script executable
chmod +x create_magnum_templates.sh

# Create test app deployment files
cat > test-app-deployment.yml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app
spec:
  selector:
    app: test-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
EOF

cat > test-app-ingress.yml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app-ingress
spec:
  rules:
  - host: test.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-app
            port:
              number: 80
  ingressClassName: nginx
EOF

# Run the cluster templates creation script
sh create_magnum_templates.sh

# Get the list of cluster templates
CLUSTEMPS=$(openstack coe cluster template list)

# Create readme file
cat > readme_magnum.txt << EOF
In order to interact with the OpenStack cluster, first run activate.sh and then authenticate:

source ./activate.sh
. /etc/kolla/admin-openrc.sh

To check if Magnum container service is up and running run:

openstack coe service list

We have created the following cluster templates, based on the OpenStack release:

$CLUSTEMPS

Additionally, there is a shell script "create_magnum_templates.sh" that you can use to create templates.

To deploy a demo K8s $k8svers cluster based on Fedora CoreOS $COREOSMAJ with 2 nodes and 1 master, run:

openstack coe cluster create \\
    --cluster-template k8s-flan-small-$COREOSMAJ-$k8svers \\
    --master-count 1 \\
    --node-count 2 \\
    --keypair mykey \\
    k8s-flannel-small-$COREOSMAJ-$k8svers

To deploy a demo K8s $k8svers cluster based on Fedora CoreOS $COREOSMAJ using a local insecure registry with 2 nodes and 1 master, run:

openstack coe cluster create \\
    --cluster-template k8s-flan-small-$COREOSMAJ-$k8svers-local-reg \\
    --master-count 1 \\
    --node-count 2 \\
    --keypair mykey \\
    k8s-flannel-small-$COREOSMAJ-$k8svers-local-reg

To deploy a demo K8s cluster based on Fedora CoreOS $

openstack coe cluster create \\
    --cluster-template k8s-flan-small-$COREOSMAJ-containerd \\
    --master-count 1 \\
    --node-count 2 \\
    --keypair mykey \\
    k8s-flannel-small-$COREOSMAJ-containerd

If you want to measure the time on how long it takes to deploy a K8s cluster, run the following:

time while [ -n \$(openstack coe cluster list | grep k8s-flannel-small-$COREOSMAJ-local-reg | grep -w HEALTHY) ] ; do echo cluster not ready yet; done

You can check the overall deployment status with:

openstack coe cluster list

To interact with the K8s cluster we need kubectl and probably helm. For this we can simply use Arkade:

curl -sLS https://get.arkade.dev | sudo sh
arkade get kubectl@$k8svers helm
export PATH=\$PATH:~/.arkade/bin
export KUBECONFIG=~/config
openstack coe cluster config <coe_cluster_name>

In case the cluster is in an unhealthy state like shown in the example below:

(yoga) [vagrant@seed ~]$ kubectl get nodes -o wide
NAME                                        STATUS     ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP    OS-IMAGE                        KERNEL-VERSION          CONTAINER-RUNTIME
k8s-test-37-loc-reg-r7juxkqsxysk-master-0   NotReady   master   15h   v1.23.3   10.0.0.46     172.28.4.139   Fedora CoreOS 37.20221127.3.0   6.0.9-300.fc37.x86_64   docker://20.10.20
k8s-test-37-loc-reg-r7juxkqsxysk-node-0     NotReady   <none>   15h   v1.23.3   10.0.0.236    172.28.4.133   Fedora CoreOS 37.20221127.3.0   6.0.9-300.fc37.x86_64   docker://20.10.20
(yoga) [vagrant@seed ~]$ openstack coe cluster list
+--------------------------------------+---------------------+---------+------------+--------------+-----------------+---------------+
| uuid                                 | name                | keypair | node_count | master_count | status          | health_status |
+--------------------------------------+---------------------+---------+------------+--------------+-----------------+---------------+
| 31d36f6b-5760-4c47-a3ac-65b885ff1259 | k8s-test-37-loc-reg | mykey   |          1 |            1 | CREATE_COMPLETE | UNHEALTHY     |
+--------------------------------------+---------------------+---------+------------+--------------+-----------------+---------------+

You can use the following commands to further debug the cluster creation:

ssh <floating ip of master node> -l core
ssh <floating ip of worker node> -l core

kubectl get nodes -o wide

kubectl get pods -A

if you see a failed pod, you can dig further with:

kubectl describe -n kube-system pod kube-flannel-ds-8469v

Once connected to the K8s master instance check systemctl --failed and tail the heat logs

sudo -i
tail -f /var/log/heat-config/heat-config-script/*.log

To download the K8s cluster config run

openstack coe cluster config k8s-flannel-small-$COREOSMAJ-local-reg

If your cluster deployed successfully, you need to add a storage class. You can do so by simply running:

kubectl apply -f csi-cinder-sc.yml

You can check for storage classes by running:

kubect get sc

In case you have also deployed Octavia, you can deploy ingress-nginx using helm:

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx

Octavia will automatically deploy a loadbalancer that can be used in the K8s cluster

You can check the status and the assigned external IP of the deployed ingress controller with:

kubectl --namespace default get services -o wide -w nginx-ingress-ingress-nginx-controller

For further testing you can deploy a small nginx pod with a test website:

kubectl apply -f test-app-deployment.yml
kubectl apply -f test-app-ingress.yml
echo "192.168.2.232 test.example.com" | sudo tee -a /etc/hosts
curl -H "Host: test.example.com" http://test.example.com

EOF

cat readme_magnum.txt

echo "To see this info again, check out readme_magnum.txt."
