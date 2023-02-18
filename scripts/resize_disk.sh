diskpart=$(lsblk -l | grep "part /$" | awk '{print $1}')
disk=$(echo $${diskpart} | sed 's/.$//')
pnum=$(lsblk -l | grep "part /$" | awk '{print $2}' |cut -d : -f2)
echo "+++++++++++++ Resizing disk $disk ... +++++++++++++"
#sudo parted /dev/sda resizepart 1 100%
printf "fix\n" | sudo parted ---pretend-input-tty /dev/$${disk} print
echo Yes | sudo parted /dev/$${disk} ---pretend-input-tty resizepart $${pnum} 100%
# only if using LVM
#sudo pvresize /dev/sda2
#sudo lvextend -l +100%FREE /dev/centos/root
sudo xfs_growfs /dev/$${disk}$${pnum}
