# use this script to switch to the python venv
cd
deployment="${deployment}"
release="${release}"
virtdir="./$${release}"

source $${virtdir}/bin/activate
ansible -i $${deployment} -m ping all