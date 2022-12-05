## IaC and CaC Example for Azure 
This is an IaC/CaC example for an web application stack (based on linux server) including an loadbalancer, deployed using Terraform and Ansible.

**What does it do**
This App shows how to deploy multiple IaaS ressources (in this case on Azure) with Terraform 
and configure the server services with ansible.

**Why would you do this**
Instead of manually clicking, editing and adding all the needed ressources e.g. instances, loadbalancers, storages etc.
you can automatically create, scale and configure them by using YAML-files.

Terraform provides the infrastructure, while ansible takes care of the linux server configuration.
