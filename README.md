# Deploy OpenStack Yoga, Zed or Antelope (2023.1) on a single ESXi node, no vCenter required, with Kolla-Ansible using Terraform and Cloud-init

This Terraform project can deploy an all-in-one or multinode OpenStack Cluster on an ESXi host. It will take complete care of this by using the Terraform provider terraform-provider-esxi from josenk:

https://github.com/josenk/terraform-provider-esxi

The project does the following:

- Download the latest Rocky Linux 9.x Vagrantbox, upload it to your ESXi host so that it can be used as a template (by default it will use VM Portgroup "VM Network")
- Create the necessary port groups on vSwitch0
- In case of a multinode deployment it will clone the VMs needed for OpenStack from this template
- By default install an NFS Server, Kolla-Ansible, a local docker registry and deploy OpenStack via Kolla-Ansible
- Includes scripts to deploy additional services like Magnum, Octavia etc.

By default it will download the official Rocky Linux 9.x Vagrantbox, but you can easily adjust this and many others setings in your terraform.tfvars file. Rocky Linux 9.x is supported for OpenStack Yoga, Zed and Antelope (2023.1). You won't need Vagrant for this to work. Once the Vagrantbox has been downloaded it will be extracted using tar, nested hardware virtualization will be enabled and finally it will be uploaded to your ESXi host. After that the VM will be powered on to install cloud-init and last but not least the vm will be powered off so that it can be used as template. The actual VMs required for the OpenStack multinode cluster will be cloned from this template.

In order to use this code you must have:
1. An ESXi 7.x host with some free resources (RAM,CPU,DISK) and SSH enabled. You can also use an older version of ESXi but then you need to adjust the variable vmtemplate.hwvers = "13" in your terraform.tfvars file.
2. You need to enable promiscuous_mode, mac_changes and forged_transmits on vSwitch0.
3. Terraform (https://developer.hashicorp.com/terraform/downloads) and VMware OVFTool (https://developer.vmware.com/web/tool/4.4.0/ovf) installed. Make sure to have the ovftool binary in your PATH. E.g. on MacOS run the following in a terminal:
```ruby
PATH=$PATH:"/Applications/VMware OVF Tool/"
````
4. A terraform.tfvars file. I have added example files for all-in-one and multinode for the OpenStack Antelope (2023.1) releases:

   - terraform.antelope.all-in-one.tfvars
   - terraform.antelope.multinode.tfvars

The Terraform project was successfully tested on Windows 10 and MacOS. It should also work just fine under Linux. On Windows make sure that you have a tar binary in your Path. E.g. on Windows 2016 there is no tar by default, so you need to download it first.

Below is the contents of the terraform.antelope.multinode.tfvars file. It will deploy a total of 5 VMs (3 control and 2 compute nodes). 

The following services will be enabled:
  - Cinder: NFS

You need to at least adjust the ESXi username, password, hostname, disk_store and all the IP adresses 192.168.2.x to match your local network. Be sure to read the comments before using or modifying the file. Just watch out for the comment:

# **** Adjust this to match your environment *****

This marks sections where you need to make adjustments to match your local environment / network.

The following examples work fine for me:

[Multinode deployment of OpenStack Antelope (2023.1) Release](terraform.antelope.multinode.tfvars)

[All-in-One deployment of OpenStack Antelope (2023.1) Release](terraform.antelope.all-in-one.tfvars)

In order to run this:

1. clone the git repo
```ruby
 git clone https://github.com/r0k5t4r/tf-esxi-kolla-ansible.git
```
2. cd into the cloned directory
```ruby
cd tf-esxi-kolla-ansible
```
3. run:
```ruby
 terraform init
```
5. Choose one of the example terraform.tfvars files. Make adjustments to the file to match your local environemnt. For example to deploy OpenStack release Antelope (2023.1) just run: 
```ruby
terraform plan -var-file terraform.antelope.multinode.tfvars
```
This will first check if there are any problems with the deployment.
6. To actually deploy it run:
```ruby
terraform apply -var-file terraform.antelope.multinode.tfvars
```
At the end of the deployment Terraform will output valuable information on how to interact with your OpenStack deployment. You can lookup this info again by running:
```ruby
terraform output
```
After the deployment, ssh to the seed node with user vagrant and password vagrant:
```ruby
ssh vagrant@<ip_of_seed_node>
```

In case you have set deploy_kolla and install_kolla to false you can run the following commands:
```ruby
sh -v install-kolla.sh
sh -v deploy-kolla.sh
```

This will install kolla-ansible and deploy OpenStack. After the deployment, check out the readme.txt on the seed node. It contains various hints and some example configurations.
```ruby
cat readme.txt
```

Have a look in the deploy-scripts folder. You can easily deploy addtional services by running the shell scripts. For example to deploy OpenStack Magnum simply run:
```ruby
sh deploy-scripts/deploy-magnum.sh
sh deploy-scripts/deploy-octavia.sh
```

In case you want to remove the OpenStack cluster just run:
```ruby
kolla-ansible -i multinode destroy --yes-i-really-really-mean-it
```

In case you completly want to remove everything that was deployed by Terraform run:
```ruby
terraform destroy --auto-approve
``` 

Please let me know in case you have problems with the deployment or ideas for improvements.

Have fun. :)

Quick Tip:

if you occasionally discard the deployment and start from scratch, it can be helpful to clone the seed VM to avoid constantly downloading the contents of the docker registry. This saves a lot of time. To do this, you can simply connect to your ESXi server via SSH and change to the VMDK directory.

Example:

cd /vmfs/volumes/datastore01

and clone the hard disk of the VM:

mkdir registry
cd seed
vmkfstools -i seed.vmdk ../registry/registry.vmdk
cp seed.vmx ../registry/registry.vmx
cd ..
cd registry
sed -i 's/seed/registry/g registry.vmx

Then you simply have to register the cloned VMDK via the ESXi Host Client (web interface). And subsequently adjust the IP address of the cloned VM.