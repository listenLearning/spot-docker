#!/bin/bash

# config hostname
echo "[+] $(date) config k8s hostname"

while [ ! -e /etc/hostname -o ! -e /etc/hosts ]; do
  echo "[-] $(date) hostname or hosts not found"
  sleep 2s
done

hostname $HOSTNAME
echo $HOSTNAME > /etc/hostname

if [ ! -e /etc/sysconfig/network ]; then
  touch /etc/sysconfig/network
fi

if [ $(grep -c $HOSTNAME /etc/sysconfig/network) -eq 0 ]; then
  echo $HOSTNAME >> /etc/sysconfig/network
fi

if [ $(grep -c $HOSTNAME /etc/hosts) -eq 0 ]; then
  echo "${POD_IP} ${HOSTNAME}" >> /etc/hosts
  echo "[+] $(date) reboot"
  shutdown -r now
fi

# config mysql
echo "[+] $(date) config cloudera mysql"
sed -i /^"\[mysqld\]"/a\\"character-set-server=utf8" /etc/my.cnf
sed -i /^"\[mysqld\]"/a\\"skip-grant-tables" /etc/my.cnf
systemctl restart mysqld
mysql -u root < /cloudera-init/run/mysql.sql
sed -i /^"skip-grant-tables/d" /etc/my.cnf
systemctl restart mysqld
/opt/cm/share/cmf/schema/scm_prepare_database.sh mysql scm scm temp

# check dir for k8s sa
echo "[+] $(date) fix k8s serviceaccount mount error"
if [ ! -d "/run/secrets/kubernetes.io/serviceaccount" ]; then
  mkdir -p /run/secrets/kubernetes.io/serviceaccount
fi

if [ ! -d "/var/run/secrets/kubernetes.io/serviceaccount" ]; then
  mkdir -p /var/run/secrets/kubernetes.io/serviceaccount
fi

# start server
echo "[+] $(date) start cloudera server"
/opt/cm/etc/init.d/cloudera-scm-server start
exit 0