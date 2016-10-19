#!/bin/sh

showHelpInfo() {
    echo "--------------- USAGE INFO ---------------"
    echo "-m : make docker image"
    echo "-r : run docker container"
    echo "-l : list running docker"
    echo "-c : connect to docker container with ssh"
    echo "-a : attach docker container"
    echo "-s : stop docker container"
    echo "-d : delete docker container"
    echo "------------------------------------------"
}

makeDockerImage() {
    if [ $# -lt 3 ]; then
        echo ${1} ${2} ${3}
        echo "You should specify the [image name] and [root password] when make docker image!"
        exit 1
    fi

    if [ "$1" != "-m" ]; then
        exit 1
    fi
    shift;

    local image_name=${1}
    local container_root_password=${2}
    local build_temp_dir=__make_dist_server_temp__

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

    echo [1] pull docker centos image ....
    docker pull centos:7
    echo [1] pull docker centos image success!

    echo [2] create startup.sh ....
    cat << EOF > startup.sh
#!/bin/sh
/usr/sbin/sshd
git init --bare myrep.git
EOF
    echo [2] create startup.sh success!

    echo [3] create rsa key if not exists ....
    if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
    fi
    chmod 600 ~/.ssh/id_rsa
    cp ~/.ssh/id_rsa.pub .
    echo [3] create rsa key success!

    echo [4] create Dockerfile
    cat << EOF > Dockerfile
FROM docker.io/centos:7
RUN mkdir -p /root/.ssh
ADD id_rsa.pub /root/.ssh/id_rsa.pub
ADD startup.sh /startup.sh
RUN chmod +x /startup.sh
RUN yum install git -y
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
    docker build -t ${image_name} .
    echo [7] create Docker image success!

    cd -
    rm -rf ${build_temp_dir}
}

clearSSHKey() {
    ssh-keygen -R [localhost]:10022
}

runDockerContainer() {
    local command=${1}
    if [ $command != -r ]; then
        echo "wrong argument to run docker!"
        exit 1;
    fi
    local image_name=${2}
    shift 2
    local port_map=""
    local prefix="-p "
    local ws=" "
    for i in $@; do
        port_map=${port_map}${prefix}${ws}${i}${ws}
    done
    echo "docker run -dt $port_map $image_name"
    docker run -dt $port_map $image_name
    return 0;
}

connectDockerContainer() {
    local port=${1}
    ssh localhost -p ${port}
    return 0
}

attachDockerContainer() {
    local cid=${1}
    echo "docker exec -it ${cid} /bin/bash"
    docker exec -it ${cid} /bin/bash
    return 0
}

stopDockerContainer() {
    local cid=${1}
    echo "docker stop ${cid}"
    docker stop ${cid}
    return 0
}

deleteDockerContainer() {
    local cid=${1}
    echo "docker rm ${cid}"
    docker rm ${cid}
    return 0
}

listDockerContainer() {
    echo "docker ps -a"
    docker ps -a
    return 0
}

if [ $# -lt 1 ]; then
    showHelpInfo;
    exit 1;
fi

while getopts "hlm:r:c:a:s:d:" arg
do
    case $arg in
        h)
            showHelpInfo;
            ;;
        l)
            listDockerContainer;
            ;;
        m)
            makeDockerImage $@;
            clearSSHKey;
            ;;
        r)
            runDockerContainer $@;
            ;;
        c)
            connectDockerContainer $OPTARG;
            ;;
        a)
            attachDockerContainer $OPTARG;
            ;;
        s)
            stopDockerContainer $OPTARG;
            ;;
        d)
            deleteDockerContainer $OPTARG;
            ;;

        ?)
            echo $@
            echo "unknown argument"
            exit 1;;
    esac
done
