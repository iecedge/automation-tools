#!/bin/bash
WORKSPACE="${WORKSPACE:-$HOME}"
AUTO_TOOLS="${WORKSPACE}/automation-tools"
AUTO_TOOLS_REPO="https://github.com/iecedge/automation-tools.git"
AUTO_TOOLS_REV="cord-7.0-arm64"
HELM_CHARTS="${WORKSPACE}/cord/helm-charts"
HELM_CHARTS_REPO="https://github.com/iecedge/helm-charts.git"
HELM_CHARTS_REV="${HELM_CHARTS_REV:-cord-7.0-arm64}"
PIP_HTTPIE_VER=0.9.4
PIP_PYGMENTS_VER=2.5.2

export CORDCTL_PLATFORM="linux-arm64"
export CORDCTL_SHA256SUM="454d93a64d833225fd3fcc26718125415323f02aec35a82afaf3ef87362a8e5d"
export BUILD="/tmp"
export M="${BUILD}/milestones"
export SEBAVALUES=configs/seba-ponsim-iec-arm64.yaml

rm -rf "${M}"
mkdir -p "${M}"
mkdir -p "${WORKSPACE}/cord/test"

if apt --version >/dev/null 2>&1; then
  sudo apt install -y httpie jq software-properties-common bridge-utils make
else
  pip install httpie=="${PIP_HTTPIE_VER}" pygments=="${PIP_PYGMENTS_VER}" --user
fi
sudo iptables -P FORWARD ACCEPT
touch "${M}/setup"

# Skip helm installation if it already exists and fake /usr/local/bin/helm
if xhelm=$(command -v helm)
then
  if [ "${xhelm}" != "/usr/local/bin/helm" ]
  then
     echo "helm is installed at ${xhelm}; symlinking to /usr/local/bin/helm"
     mkdir -p /usr/local/bin/ || true
     if [ -L /usr/local/bin/helm ]
     then
       echo "Symlink already exists"
     else
       sudo ln -sf "${xhelm}" /usr/local/bin/helm
     fi
  fi
else
  echo "helm is not installed"
fi

# Faking helm-charts repo clone to our own git submodule if not already there
if [ -d "${HELM_CHARTS}" -o -L "${HELM_CHARTS}" ]
then
   echo "The helm-charts repo already exists"
else
   git clone "${HELM_CHARTS_REPO}" "${HELM_CHARTS}"
   (cd "${HELM_CHARTS}"; git checkout "${HELM_CHARTS_REV}")
fi

# Pull automation-tools if it doesn't already exist
if [ -d "${AUTO_TOOLS}" -o -L "${AUTO_TOOLS}" ]
then
  echo "The automation-tools repo already exists"
else
  git clone "${AUTO_TOOLS_REPO}" "${AUTO_TOOLS}"
  (cd "${AUTO_TOOLS}"; git checkout "${AUTO_TOOLS_REV}")
fi

if [ ! -f /etc/kubernetes/admin.conf ] && [ -f "${HOME}/.kube/config" ]; then
  sudo cp "${HOME}/.kube/config" /etc/kubernetes/admin.conf
fi

sudo touch "/usr/bin/kubeadm"
touch "${M}/kubeadm"
helm repo add incubator https://iecedge.github.io/helm-k8s-charts/incubator/
helm repo add stable https://iecedge.github.io/helm-k8s-charts/stable/
touch "${M}/helm-init"

# The PONSim related charts expect to find a node with a certain label
# Will try to figure it out based on the K8S_MASTER_IP value
if ! kubectl get nodes --show-labels | grep -q "node-role.kubernetes.io/master="; then
  if [ "x${K8S_MASTER_IP}" = "x" ]; then
    echo "No node with label node-rule.kubernetes.io/master and K8S_MASTER_IP not set"
    return 1
  fi
  mnode=$(kubectl get nodes -o wide | grep ${K8S_MASTER_IP} | cut -f1 -d' ')
  kubectl label nodes "${mnode}" node-role.kubernetes.io/master=
fi
