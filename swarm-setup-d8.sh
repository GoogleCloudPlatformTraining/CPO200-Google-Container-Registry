#! /bin/sh
#
# File: swarm-setup.sh
#
# Purpose: Complete setup steps for the Jenkins worker node instance
#
# Pre-conditions:
#  Debian 8 OS
#  slave.jar is downloaded to the user home directory
#  This script is run from the Git repo directory
#

echo 'Changing to user home directory'
cd

echo 'Installing Docker...'
sudo apt-get purge lxc-docker*
sudo apt-get purge docker.io*
sudo apt-get update
sudo apt-get -y -qq install apt-transport-https ca-certificates
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
sudo bash -c "echo deb https://apt.dockerproject.org/repo debian-jessie main >> /etc/apt/sources.list.d/docker.list"
sudo apt-get update
sudo apt-cache policy docker-engine
sudo apt-get -y -qq install docker-engine
sudo service docker start
sudo docker run hello-world
sudo gpasswd -a $USER docker
sudo service docker restart

echo 'Installing Supervisor...'
# Install supervisor package
sudo apt-get install supervisor

sudo addgroup build
sudo adduser --disabled-password --system --ingroup build jenkins
sudo mkdir /home/jenkins/build
sudo chown jenkins:build /home/jenkins/build

# Install the Jenkins build agent agent code

echo 'Installing Jenkins Slave software'
sudo mkdir -p /opt/jenkins-slave
sudo mv slave.jar /opt/jenkins-slave
sudo chown -R root:root /opt/jenkins-slave

echo 'Installing Jenkins Swarm plugin client-side software'
wget -q -O swarm-client-2.0.jar \
http://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/2.0/swarm-client-2.0-jar-with-dependencies.jar
sudo mkdir -p /opt/swarm-client
sudo mv swarm-client*.jar /opt/swarm-client/
sudo chown -R root:root /opt/swarm-client

echo 'Installing Swarm supervisor config'
cat >/etc/supervisor/conf.d/swarm.conf << EOF
[program:swarm]
directory=/home/jenkins
command=java -Xmx256m -Xmx256m -Dfile.encoding=UTF-8 -jar /opt/swarm-client/swarm-client-2.0.jar -master http://jenkins-master:8080 -username admin -password JPW -fsroot /home/jenkins -description 'auto' -labels 'slave' -name 'slave-auto' -executors 1 -mode exclusive
autostart=true
autorestart=true
user=jenkins
stdout_logfile=syslog
stderr_logfile=syslog
EOF

sudo sed -i "s|JPW|$JENKINS_PW|g" /etc/supervisor/conf.d/swarm.conf

echo 'Installing UNZIP program'
cd
sudo apt-get -y -qq install unzip

echo 'Installing Packer program'
wget -q -O packer.zip https://releases.hashicorp.com/packer/0.9.0/packer_0.9.0_linux_amd64.zip
sudo mkdir -p /opt/packer
sudo unzip -d /opt/packer packer.zip
sudo chown root:staff /opt/packer/*

# Remove the Packer installation ZIP file
rm packer.zip

# Update gcloud SDK components
sudo gcloud components update -q

# Configure the Swarm service to start when the instance boots
sudo supervisorctl reread
sudo supervisorctl update

echo 'Finished with installation script'