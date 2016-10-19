#!/bin/sh

container_root_password=123456
build_temp_dir=__make_dist_server_temp__

echo [0] check programs required ...
command -v wget >/dev/null 2>&1 || {
    echo "I require wget but it's not installed.  Aborting." >&2; 
    exit 1;
}
command -v docker >/dev/null 2>&1 || {
    echo "I require docker but it's not installed.  Aborting." >&2; 
    exit 1;
}
command -v ssh-keygen >/dev/null 2>&1 || {
    echo "I require ssh-keygen but it's not installed.  Aborting." >&2; 
    exit 1;
}
echo [0] check programs required success!

mkdir -p ${build_temp_dir}
cd ${build_temp_dir}

echo [1] create nginx repository file ....
cat << EOF > nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/7/\$basearch/
gpgcheck=1
enabled=1
EOF
echo [1] create nginx repository file success!

echo [2] download nginx checking key ....
wget http://nginx.org/keys/nginx_signing.key
echo [2] download nginx checking key success!

echo [3] pull docker centos image ....
docker pull centos:7
echo [3] pull docker centos image success!

echo [4] create startup.sh ....
cat << EOF > startup.sh
#!/bin/sh
/usr/sbin/sshd
nginx
EOF
echo [4] create startup.sh success!

echo [5] create rsa key if not exists ....
if [ ! -f ~/.ssh/id_rsa ]; then
ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
fi
chmod 600 ~/.ssh/id_rsa
cp ~/.ssh/id_rsa.pub .
echo [5] create rsa key success!

echo [6] create Dockerfile
cat << EOF > Dockerfile
FROM docker.io/centos:7
RUN mkdir -p /root/.ssh
ADD id_rsa.pub /root/.ssh/id_rsa.pub
ADD nginx.repo /etc/yum.repos.d/nginx.repo
ADD nginx_signing.key /tmp
ADD startup.sh /startup.sh
RUN chmod +x /startup.sh
RUN rpm --import /tmp/nginx_signing.key
RUN rm /tmp/nginx_signing.key
RUN yum install nginx -y
RUN yum install openssh-server -y
RUN yum install rsync -y
RUN touch /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys
RUN cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
RUN sed -iner 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
RUN echo ${container_root_password} | passwd --stdin root
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -q -P ""
RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -q -P ""
RUN ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -q -P ""
RUN ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -q -P ""
ENTRYPOINT /startup.sh && /bin/bash
EXPOSE 22
EXPOSE 80
EOF
echo [6] create Dockerfile success!

echo [7] create Docker image ....
docker build -t dist-server .
echo [7] create Docker image success!

cd -
rm -rf ${build_temp_dir}
