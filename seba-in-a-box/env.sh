#!/bin/bash
export AUTOMATION_TOOLS="https://github.com/iecedge/automation-tools.git"
export AUTOMATION_TOOLS_REV="cord-7.0-arm64"
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
HELM_CHARTS="${WORKSPACE}/cord/helm-charts"
IECEDGE_HELM_CHARTS="https://github.com/iecedge/helm-charts.git"
IECEDGE_HELM_CHARTS_REV="cord-7.0-arm64"
if [ -d "${HELM_CHARTS}" -o -L "${HELM_CHARTS}" ]
then
   echo "The helm-charts repo already exists"
else
   git clone "${IECEDGE_HELM_CHARTS}" -b "${IECEDGE_HELM_CHARTS_REV}" "${HELM_CHARTS}"
fi

if [ -d "${WORKSPACE}/automation-tools" -o -L "${WORKSPACE}/automation-tools" ]
then
  echo "The automation-tools repo already exists"
else
  git clone "${AUTOMATION_TOOLS}" automation-tools
  (cd automation-tools; git checkout "${AUTOMATION_TOOLS_REV}")
fi

# Pull the repo for extra K8S repos
cd "${WORKSPACE}"
git clone https://github.com/iecedge/helm-k8s-charts.git

touch "${M}/kubeadm"
test -L "${WORKSPACE}/cord/helm-charts/incubator" || \
ln -s "${WORKSPACE}/helm-k8s-charts/incubator" "${WORKSPACE}/cord/helm-charts/incubator"
test -L "${WORKSPACE}/cord/helm-charts/stable" || \
ln -s "${WORKSPACE}/helm-k8s-charts/stable" "${WORKSPACE}/cord/helm-charts/stable"
touch "${M}/helm-init"

