#!/bin/bash
AUTO_TOOLS="${WORKSPACE}/automation-tools"
AUTO_TOOLS_REPO="https://github.com/iecedge/automation-tools.git"
AUTO_TOOLS_REV="cord-7.0-arm64"
HELM_CHARTS="${WORKSPACE}/cord/helm-charts"
HELM_CHARTS_REPO="https://github.com/iecedge/helm-charts.git"
HELM_CHARTS_REV="cord-7.0-arm64"
HELM_K8S_CHARTS="${WORKSPACE}/helm-k8s-charts"
HELM_K8S_CHARTS_REPO="https://github.com/iecedge/helm-k8s-charts.git"
HELM_K8S_CHARTS_REV="master"

export CORDCTL_PLATFORM="linux-arm64"
export CORDCTL_SHA256SUM="454d93a64d833225fd3fcc26718125415323f02aec35a82afaf3ef87362a8e5d"
export BUILD="/tmp"
export M="${BUILD}/milestones"
export SEBAVALUES=configs/seba-ponsim-iec-arm64.yaml
export WORKSPACE=${HOME}

rm -rf "${M}"
mkdir -p "${M}"
mkdir -p "${WORKSPACE}/cord/test"

sudo apt install -y httpie jq software-properties-common bridge-utils make
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

# Pull the repo for extra K8S repos
if [ -d "${HELM_K8S_CHARTS}" -o -L "${HELM_K8S_CHARTS}" ]
then
  echo "The helm-k8s-charts repo already exists"
else
  git clone "${HELM_K8S_CHARTS_REPO}" "${HELM_K8S_CHARTS}"
  (cd "${HELM_K8S_CHARTS}"; git checkout "${HELM_K8S_CHARTS_REV}")
fi

touch "${M}/kubeadm"
test -L "${HELM_CHARTS}/incubator" || \
ln -s "${HELM_K8S_CHARTS}/incubator" "${HELM_CHARTS}/incubator"
test -L "${HELM_CHARTS}/stable" || \
ln -s "${HELM_K8S_CHARTS}/stable" "${HELM_CHARTS}/stable"
touch "${M}/helm-init"

