#!/usr/bin/env bash
set -o nounset -o errexit

K8S_VERSION=$1
CNI_VERSION=$2
HOSTNAME=$3
NODE_IP=$4
K8S_FEATURE_GATES="$5"

cat << EOF > /etc/default/kubelet
KUBELET_EXTRA_ARGS="--cloud-provider=external --allow-privileged=true --feature-gates=${K8S_FEATURE_GATES}"
EOF

# Make sure we have Internet connectivity before proceeding
n=0
until [ $n -ge 120 ]
do
  curl -L "https://github.com" >/dev/null 2>&1 && curl -L "https://storage.googleapis.com" >/dev/null 2>&1 && break
  n=$[$n+1]
  sleep 1
done

mkdir -p /etc/kubernetes/manifests

mkdir -p /opt/cni/bin
curl -L >/dev/null 2>&1 "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz

mkdir -p /opt/bin
curl -L >/dev/null 2>&1 "https://github.com/kubernetes-incubator/cri-tools/releases/download/${K8S_VERSION}/crictl-${K8S_VERSION}-linux-amd64.tar.gz" | tar -C /opt/bin -xz

mkdir -p /opt/bin
cd /opt/bin
curl -L >/dev/null 2>&1 --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}

curl -sSL >/dev/null 2>&1 "https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/build/debs/kubelet.service" | sed "s:/usr/bin:/opt/bin:g" > /etc/systemd/system/kubelet.service
mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL >/dev/null 2>&1 "https://raw.githubusercontent.com/kubernetes/kubernetes/${K8S_VERSION}/build/debs/10-kubeadm.conf" | sed "s:/usr/bin:/opt/bin:g" > /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl enable kubelet.service
systemctl start kubelet.service
