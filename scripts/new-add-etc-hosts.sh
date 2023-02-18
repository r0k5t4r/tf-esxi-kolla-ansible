hostname="$1"
domain_name="$2"
ip="$3"

echo ${ip} ${hostname}.${domain_name} ${hostname}
echo ${ip} ${hostname}.${domain_name} ${hostname} | sudo tee -a /etc/hosts
echo ${ip} ${hostname}.${domain_name} ${hostname} | sudo tee -a hosts