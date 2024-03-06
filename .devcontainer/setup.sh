#!/usr/bin/env
project="cap-data-science-template"
## update and install some things we should probably have
set -xe
sudo apt-get update

## install terraform
mkdir terraform-env && cd terraform-env
sudo wget https://releases.hashicorp.com/terraform/0.14.8/terraform_0.14.8_linux_amd64.zip
unzip terraform_0.14.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/
sudo rm -rf ../terraform-env

## install conda
cd /tmp
sudo curl -O https://repo.anaconda.com/archive/Anaconda3-2019.10-Linux-x86_64.sh
sudo bash ./Anaconda3-2019.10-Linux-x86_64.sh -b -p $HOME/anaconda3
source ~/.bashrc
conda create --name cs_env python=3 -y
source ~/anaconda3/etc/profile.d/conda.sh
conda activate cs_env

cd /workspaces/$project/
sudo pip install pre-commit
pre-commit install
