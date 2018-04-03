#!/bin/bash

echo "step start: globals"
ADMIN_USER=$1
DOCKER_USER=$2
DOCKER_PASS=$3
DOCKER_REGISTRY=$4
AQUA_VERSION=$5
AQUA_CONTAINER_NAME=$6
AQUA_DB_PASSWORD=$7
AQUA_LICENSE_TOKEN=$8
AQUA_ADMIN_PASSWORD=$9
PROXY_SERVER=$10
PROXY_USER=$11
PROXY_PASSWORD=$12
echo "step end: globals"

echo "AQUA_ADMIN_PASSWORD: $AQUA_ADMIN_PASSWORD"

echo "step start: set proxies"
sudo cat <<EOT >> /etc//etc/environment
# Begin proxy info added by Aqua install script
http_proxy="http://${PROXY_SERVER}:8080/"
https_proxy="http://${PROXY_SERVER}:8080/"
ftp_proxy="http://${PROXY_SERVER}:8080/"
no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com"
HTTP_PROXY="http://${PROXY_SERVER}:8080/"
HTTPS_PROXY="http://${PROXY_SERVER}:8080/"
FTP_PROXY="http://${PROXY_SERVER}:8080/"
NO_PROXY="localhost,127.0.0.1,localaddress,.localdomain.com"
# end proxy info added by Aqua install script
EOT
sudo cat <<EOT >> /etc/apt/apt.conf.d/95proxies
# begin proxy info added by Aqua install script
Acquire::http::proxy "http://${PROXY_SERVER}:8080/";
Acquire::ftp::proxy "ftp://${PROXY_SERVER}:8080/";
Acquire::https::proxy "https://${PROXY_SERVER}:8080/";
# end proxy info added by Aqua install script
EOT
echo "stem end: set proxies"

echo "step start: install docker-ce"
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce jq
sudo groupadd docker
sudo usermod -aG docker $ADMIN_USER
sudo systemctl start docker
sudo systemctl enable docker
sleep 10
docker version
lExitCode=$?
if [ $lExitCode == "0" ];then
  echo "Docker installed successfully"
else
  echo "Failed to install docker, exit code : $lExitCode, exiting"
  exit 1
fi
echo "step end: install docker-ce"

#Docker login
echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin $DOCKER_REGISTRY
lExitCode=$?
if [ $lExitCode == "0" ];then
  echo "Sucessfully logged in to DOCKER_REGISTRY"
else
  echo "Failed to login to DOCKER_REGISTRY, exit code : $lExitCode , exiting"
  exit 1
fi


#Run Aqua Services
echo "step start: deploy Aqua Databse"
AQUA_IMAGE="aquasec/database:${AQUA_VERSION}"
docker run -d -p 5432:5432 --name aqua-db:${AQUA_VERSION}
   -e POSTGRES_PASSWORD=${AQUA_DB_PASSWORD} \
   -v /var/lib/postgresql/data:/var/lib/postgresql/data \
   --restart unless-stopped \
 $AQUA_IMAGE
 
 lExitCode=$?
if [ $lExitCode == "0" ];then
  echo "Sucessfully ran $AQUA_IMAGE"
else
  echo "Failed to run $AQUA_IMAGE, exit code : $lExitCode , exiting"
  exit 1
fi
echo "step end: deploy Aqua Database"

echo "step start: deploy Aqua Gateway"
AQUA_IMAGE="aquasec/gateway:${AQUA_VERSION}"
docker run -d -p 3622:3622 --name aqua-gateway:${AQUA_VERSION}
   -e SCALOCK_DBUSER=postgres \
   -e SCALOCK_DBPASSWORD=${AQUA_DB_PASSWORD} \
   -e SCALOCK_DBNAME=scalock \
   -e SCALOCK_DBHOST=$(hostname -i) \
   -e SCALOCK_AUDIT_DBUSER=postgres \
   -e SCALOCK_AUDIT_DBPASSWORD=${AQUA_DB_PASSWORD} \
   -e SCALOCK_AUDIT_DBNAME=slk_audit \
   -e SCALOCK_AUDIT_DBHOST=$(hostname -i) \
   -e LICENSE_TOKEN=${AQUA_LICENSE_TOKEN} \
   -e ADMIN_PASSWORD=${AQUA_ADMIN_PASSWORD} \
   -v /var/lib/postgresql/data:/var/lib/postgresql/data \
   -v /var/run/docker.sock:/var/run/docker.sock \
   --restart unless-stopped \
 $AQUA_IMAGE

 lExitCode=$?
if [ $lExitCode == "0" ];then
  echo "Sucessfully ran $AQUA_IMAGE"
else
  echo "Failed to run $AQUA_IMAGE, exit code : $lExitCode , exiting"
  exit 1
fi
echo "step end: deploy Aqua gateway"

echo "step start: deploy Aqua Server"
AQUA_IMAGE="aquasec/server:${AQUA_VERSION}"
docker run -d -p 8080:8080 --name aqua-server:${AQUA_VERSION}
   -e SCALOCK_DBUSER=postgres \
   -e SCALOCK_DBPASSWORD=${AQUA_DB_PASSWORD} \
   -e SCALOCK_DBNAME=scalock \
   -e SCALOCK_DBHOST=$(hostname -i) \
   -e SCALOCK_AUDIT_DBUSER=postgres \
   -e SCALOCK_AUDIT_DBPASSWORD=${AQUA_DB_PASSWORD} \
   -e SCALOCK_AUDIT_DBNAME=slk_audit \
   -e SCALOCK_AUDIT_DBHOST=$(hostname -i) \
   -e LICENSE_TOKEN=${AQUA_LICENSE_TOKEN} \
   -e ADMIN_PASSWORD=${AQUA_ADMIN_PASSWORD} \
     -v /var/run/docker.sock:/var/run/docker.sock \
   --restart unless-stopped \
 $AQUA_IMAGE

 lExitCode=$?
if [ $lExitCode == "0" ];then
  echo "Sucessfully ran $AQUA_IMAGE"
else
  echo "Failed to run $AQUA_IMAGE, exit code : $lExitCode , exiting"
  exit 1
fi
echo "step end: deploy Aqua gateway"
