# Setup procedure for IBM TEST Cloud (Staging environment)
[Guide](./README.md) describes how to set up a demo environment on IBM Cloud (Production environment) for peer pod VMs (all vms are x86 arch)

This guide describes how to set up a demo environment on IBM TEST Cloud (Staging environment) for peer pod VMs (all vms are s390x arch).

This procedure has been confirmed using the following repositories:

* https://github.com/liudalibj/cloud-api-adaptor/tree/zvsi
* https://github.com/yoheiueda/kata-containers/tree/peerpod-2022.04.04

The setup procedure includes the following sub tasks.

* Create a Virtual Private Cloud (VPC) including security groups, subnet, and gateway
* Create a Kubernetes cluster on two s390x virtual server instances
* Build a custom VM image for pod VMs (s390x arch)
* Install cloud-api-adaptor on a worker node
* Run a demo

## Prerequisites

To automate preparation of VPC and VSIs, you need to install terraform and ansible on your client machine. Please follow the the official installation guides.

* [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
Simply:
```
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get install terraform -y
```
* [Install Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
Simply:
```
sudo apt-get install -y python3
sudo ln -s /usr/bin/python3 /usr/bin/python
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get install ansible
```
Optionally, you can install IBM Cloud CLI.

* [Installing the stand-alone IBM Cloud CLI and plugins](https://cloud.ibm.com/docs/cli?topic=cli-install-ibmcloud-cli)
Simply:
```
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
ibmcloud plugin install vpc-infrastructure cloud-object-storage
```

Note that you can use the IBM Cloud Web UI for most of the operations of IBM Cloud.

* [https://test.cloud.ibm.com/vpc-ext/overview](https://test.cloud.ibm.com/vpc-ext/overview)

You need IBM TEST Cloud API key. You can create your own API key at [https://test.cloud.ibm.com/iam/apikeys](https://test.cloud.ibm.com/iam/apikeys).

## Create a VPC

First, you need to create a Virtual Private Cloud (VPC). The Terraform configuration files are in [ibmcloud/terraform/common](./terraform/common/).

To use the Terraform configuration, you need to create a file `terraform.tfvars` at in the same directory of the other files of the Terraform configuration to specify your IBM TEST Cloud API Key and overwrite the default parameter values. We will create s390x VSIs at `Dallas` region in IBM TEST Cloud, the `terraform.tfvars` looks like this.
```
ibmcloud_api_key = "<your TEST API key>"
region_name = "us-south"
zone_name = "us-south-2"
vpc_name = "dallas-vpc"
public_gateway_name = "dallas-gateway"
floating_ip_name = "dallas-gateway-ip"
primary_subnet_name= "dallas-primary-subnet"
primary_security_group_name = "dallas-primary-security-group"
```

Then, you can create your VPC on IBM TEST Cloud by executing the following commands.

```
export IBMCLOUD_API_ENDPOINT=https://test.cloud.ibm.com
export IBMCLOUD_IAM_API_ENDPOINT=https://iam.test.cloud.ibm.com
export IBMCLOUD_IS_NG_API_ENDPOINT=https://us-south-stage01.iaasdev.cloud.ibm.com/v1
export IBMCLOUD_IS_API_ENDPOINT=https://us-south-stage01.iaasdev.cloud.ibm.com

cd ibmcloud/terraform/common
terraform init
terraform plan
terraform apply
```

The following cloud resources will be created. Please check [main.tf](terraform/common/main.tf) for the details.
* VPC
* Security groups
* Subnets
* Public gateway
* Floating IP for the public gateway

## Create a Kubernetes cluster base on s390x VSIs

Another Terraform configuration is available at [ibmcloud/terraform/cluster](./terraform/cluster) to create a Kubernetes cluster on the VPC you just created. Note that you can create multiple clusters by using different cluster names.

As usual, you need to create `terraform.tfvars` to specify parameter values. We will create s390x VSIs at `Dallas` region in IBM TEST Cloud, the `terraform.tfvars` looks like this:

```
ibmcloud_api_key = "<your API key>"
ssh_key_name = "<your SSH key name>"
cluster_name = "<cluster name>"
region_name = "us-south"
zone_name = "us-south-2"
vpc_name = "dallas-vpc"
primary_subnet_name= "dallas-primary-subnet"
primary_security_group_name = "dallas-primary-security-group"
instance_profile_name = "bz2-2x8"
image_name = "ibm-ubuntu-18-04-6-minimal-s390x-3"
```
The `region_name`,`zone_name`,`vpc_name`,`primary_subnet_name`,`primary_security_group_name` must same as the values you just used for creating VPC.

`ssh_key_name` is a name of your SSH key registered in IBM TEST Cloud.
You can add your SSH key at [https://test.cloud.ibm.com/vpc-ext/compute/sshKeys](https://test.cloud.ibm.com/vpc-ext/compute/sshKeys). This ssh key will be installed on control-plane and worker nodes.

`cluster_name` is a name of a Kubernetes cluster. This name is used for the prefix of the names of control-plane and worker nodes. If you want to create another cluster in the same VPC, you need to use a different name for the new cluster.

Then, execute the following commands to create a new Kubernetes cluster consisting of two s390x arch virtual server instances. One for a control-plane node, and another one for a worker node. Please check [main.tf](terraform/cluster/main.tf) for the details.

```
cd ibmcloud/terraform/cluster
terraform init
terraform plan
terraform apply
```

You can check the status of provisioned Kubernetes node s390x VM instances at [https://test.cloud.ibm.com/vpc-ext/compute/vs](https://test.cloud.ibm.com/vpc-ext/compute/vs).

This Terraform configuration also triggers execution of an Ansible playbook to set up
Kubernetes and other prerequisite software in the two nodes. Please check [ansible/playbook.yml](terraform/cluster/ansible/playbook.yml) for the details.

If ansible fails for some reason, you can rerun the ansible playbook as follows.
```
cd ansible
ansible-playbook -i ./inventory -u root ./playbook.yml
```

When ansible fails, Terraform does not execute the setup script for Kubernetes. In this case, you can manually run it as follows. Note that you do not need to run this script manually, when everything goes well.

```
./scripts/setup.sh --bastion <floating IP of the worker node> --control-plane <IP address of the control-plane node> --workers  <IP address of the worker node>
```

When two s390x VSIs are successfully provisioned, a floating IP address is assigned to the worker node. Please use the floating IP address to access the worker node from the Internet.

## Build a s390x pod VM image

You need to build a pod VM s390x image for peer pod s390x VMs. A pod VM s390x image contains the following components.

* Kata agent
* Agent protocol forwarder
* skopeo
* umoci

The build scripts are located in [ibmcloud/image](./image). The prerequisite software to build a pod VM s390x image is already installed in the worker node by [the Ansible playbook](terraform/cluster/ansible/playbook.yml) for convenience. Note that building a pod VM s390x image on a worker node is not recommended for production, and we need to build a pod VM s390x image somewhere secure to protect workloads running in a peer pod s390x VM.

- SSH to worker node
```
ssh root@floating-ip-for-work-node
```
- Check the architecture of work node
```
uname -a
```
The expected output:
```
Linux peer-pod-z-worker 4.15.0-171-generic #180-Ubuntu SMP Wed Mar 2 17:24:41 UTC 2022 s390x s390x s390x GNU/Linux
```
- Go to image folder
```
cd /root/cloud-api-adaptor/ibmcloud/image
```
- Build a custom VM s390x image. A new QCOW2 file with prefix `podvm-` will be created in the current directory.
```
CLOUD_PROVIDER=ibmcloud make build
```

You need to configure Cloud Object Storage (COS) to upload your custom VM s390x image.

https://test.cloud.ibm.com/objectstorage/

First, create a COS service instance if you have not create one. Then, create a COS bucket with the COS instance(please use `us-south` to get high performance in this demo). The COS service instance and bucket names are necessary to upload a custom VM image.

The following environment variables are necessary to be set before executing the image upload script.

```
export IBMCLOUD_API_KEY=<your API key>
export IBMCLOUD_COS_SERVICE_INSTANCE=<COS service instance name>
export IBMCLOUD_COS_BUCKET=<COS bucket name>
export IBMCLOUD_API_ENDPOINT=https://test.cloud.ibm.com
export IBMCLOUD_VPC_REGION=us-south
export IBMCLOUD_COS_REGION=us-south
export IBMCLOUD_COS_SERVICE_ENDPOINT=https://s3.us-west.cloud-object-storage.test.appdomain.cloud
```

Next, you need to grant access to COS to import images as described at [https://test.cloud.ibm.com/docs/vpc?topic=vpc-object-storage-prereq&interface=cli](https://test.cloud.ibm.com/docs/vpc?topic=vpc-object-storage-prereq&interface=cli).

```
ibmcloud login -a $IBMCLOUD_API_ENDPOINT -r $IBMCLOUD_VPC_REGION -apikey $IBMCLOUD_API_KEY
COS_INSTANCE_GUID=$(ibmcloud resource service-instance --output json "$IBMCLOUD_COS_SERVICE_INSTANCE" | jq -r '.[].guid')
ibmcloud iam authorization-policy-create is cloud-object-storage Reader --source-resource-type image --target-service-instance-id $COS_INSTANCE_GUID
```

Then, you can execute the image upload script by using `make`.

```
CLOUD_PROVIDER=ibmcloud make push
```

After successfully uploading an image, you can verify the image by creating a s390x virtual server instance using it.

The `Operator` and `Console Admin` roles must be [assigned](https://test.cloud.ibm.com/docs/vpc?topic=vpc-vsi_is_connecting_console&interface=ui) to the user.

The following command will create a new s390x server, and delete it.
The VPC, subnet, zone name are must same as the values you just used for creating VPC.

```
export IBMCLOUD_VPC_NAME=dallas-vpc
export IBMCLOUD_VPC_SUBNET_NAME=dallas-primary-subnet
export IBMCLOUD_VPC_ZONE=us-south-2

CLOUD_PROVIDER=ibmcloud make verify
```

Note that creating a server from a new image may take long time. It typically takes about 10 minutes. From the second time, creating a server from the image takes one minute.

You can check the name and ID of the new image at [https://test.cloud.ibm.com/vpc-ext/compute/images](https://test.cloud.ibm.com/vpc-ext/compute/images). Alternatively, you can use the `ibmcloud` command to list your images as follows.

```
ibmcloud is images --visibility=private
```


## Install custom Kata shim

The Ansible playbook automatically installs the custom Kata shim binary and its configuration file. If you want to rebuild the Kata shim, please follow the steps below.

```
cd /root/kata-containers/src/runtime
make $PWD/containerd-shim-kata-v2
install containerd-shim-kata-v2 /usr/local/bin/
```

A minimum Kata shim configuration file at `/etc/kata-containers/configuration.toml` looks like this.

```
[runtime]
internetworking_model = "none"
disable_new_netns = true
disable_guest_seccomp = true
enable_pprof = true
enable_debug = true
[hypervisor.remote]
remote_hypervisor = "/run/peerpod/hypervisor.sock"
[agent.kata]
```

## Install Cloud API adaptor

The Ansible playbook automatically installs the Cloud API adaptor binary. If you want to rebuild it, please follow the steps below.

```
cd /root/cloud-api-adaptor
CLOUD_PROVIDER=ibmcloud make
install cloud-api-adaptor /usr/local/bin/
```

## Launch Cloud API adaptor at work node

You can start Cloud API adaptor as follows. Please update the variable values if you use custom ones. The VPC, region, zone, subnet, security name are must same as the values you just used for creating VPC.

```
api_key=<your API key>
image_name=<pod VM image name>
ssh_key_name=<your SSH key name>
iam_service_url=https://iam.test.cloud.ibm.com/identity/token
vpc_service_url=https://us-south-stage01.iaasdev.cloud.ibm.com/v1
vpc_name=dallas-vpc
subnet_name=dallas-primary-subnet
security_group_name=dallas-primary-security-group
vpc_region=us-south
vpc_zone=us-south-2
instance_profile=bz2-2x8

ibmcloud login -a https://test.cloud.ibm.com -r $vpc_region -apikey $api_key

image_id=$(ibmcloud is image --output json $image_name | jq -r .id)
vpc_id=$(ibmcloud is vpc --output json $vpc_name | jq -r .id)
ssh_key_id=$(ibmcloud is key --output json $ssh_key_name | jq -r .id)
subnet_id=$(ibmcloud is subnet --output json $subnet_name | jq -r .id)
security_groupd_id=$(ibmcloud is security-group --output json $security_group_name | jq -r .id)

/usr/local/bin/cloud-api-adaptor ibmcloud \
    -api-key "$api_key" \
    -iam-service-url "$iam_service_url" \
    -vpc-service-url "$vpc_service_url" \
    -key-id "$ssh_key_id" \
    -image-id "$image_id" \
    -profile-name "$instance_profile" \
    -zone-name "$vpc_zone" \
    -primary-subnet-id "$subnet_id" \
    -primary-security-group-id "$security_groupd_id" \
    -vpc-id "$vpc_id" \
    -pods-dir /run/peerpod/pods \
    -socket /run/peerpod/hypervisor.sock
```

## Demo

You can create a demo pod as follows. This YAML file will create an nginx pod using a peer pod VM.
- Open a new terminal, ssh to work node again
```
ssh root@floating-ip-of-work-node
cd /root/cloud-api-adaptor/ibmcloud/demo
kubectl apply -f runtime-class.yaml -f nginx.yaml
```

The following command shows the status of the pod you just created. When it becomes running, a new peer pod s390x VM instance is running.
```
kubectl get pods
```

You can check the status of pod VM instance at [https://test.cloud.ibm.com/vpc-ext/compute/vs](https://test.cloud.ibm.com/vpc-ext/compute/vs). Alternatively, you can use the `ibmcloud` command to list your images as follows.

```
ibmcloud is instances
```
the output looks like:
```
Listing instances in all resource groups and region us-south under account Da Li Liu's Account as user liudali@cn.ibm.com...
ID                                          Name                                       Status    Reserved IP    Floating IP      Profile   Image                                VPC          Zone         Resource group
0726_4d4c7fe6-6606-4beb-9ba9-5a4cf2497e84   peer-pod-z-cp                              running   10.240.64.16   169.59.212.218   bz2-2x8   ibm-ubuntu-18-04-6-minimal-s390x-3   dallas-vpc   us-south-2   Default
0726_cf4dc73d-7353-4b15-91d0-912a27b3df89   peer-pod-z-worker                          running   10.240.64.15   169.47.89.55     bz2-2x8   ibm-ubuntu-18-04-6-minimal-s390x-3   dallas-vpc   us-south-2   Default
0726_ac730799-ac8b-4542-9d75-249d779f0d52   peer-pod-z-worker-default-nginx-52db84e0   running   10.240.64.18   -                bz2-2x8   podvm-5947618-dirty-s390x            dallas-vpc   us-south-2   Default
```

The above YAML file also define a NodePort service. You can access the HTTP port of the pod at the worker node as follows.

```
curl http://localhost:30080
```

The cloud API adaptor establishes a network tunnel between the worker and pod VMs, and the network traffic to/from the pod VM is transparently transferred via the tunnel.

You can also check the pod VM instance architecture by command:
```
kubectl exec nginx -- uname -a
```
The output looks like:
```
Linux nginx 5.4.0-109-generic #123-Ubuntu SMP Fri Apr 8 11:56:05 UTC 2022 s390x GNU/Linux
```
