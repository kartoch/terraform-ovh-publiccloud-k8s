# Simple Kubernetes Cluster from a prebuilt Glance Image

This examples shows how to use the terraform-ovh-publiccloud-k8s module to launch a simple Kubernetes cluster on OVH Public Cloud, based on a CoreOS Stable image with kubernetes preinstalled, without post-provisionning.

## Pre-requisites

- a proper terraform installation

  You can find information on how to install terraform [here](https://www.terraform.io/intro/getting-started/install.html).

- an OVH Public Cloud project
  
  Create a public cloud project on OVH following the [official documentation](https://docs.ovh.com/gb/en/public-cloud/getting_started_with_public_cloud_logging_in_and_creating_a_project/).

  Create an Openstack user ([official documentation](https://docs.ovh.com/gb/en/public-cloud/configure_user_access_to_horizon/)).
  Then download the Openstack configuration file. You can get it from [OVH Manager](https://www.ovh.com/manager/cloud/), or from [Horizon interface](https://horizon.cloud.ovh.net/project/api_access/openrc/).

  Source the configuration file:

  ```bash
  $ source openrc.sh
  Please enter your OpenStack Password:
  ```
  
- (Optional) Install the openstack cli

  ```bash
  $ sudo pip install python-openstackclient==3.15.0
  ```

- an ssh public key or openstack keypair

  The module allows you to either use an ssh public key file or a predefined openstack keypair

  Example: 

   ```bash
   # Generate a new keypair without passphrase
   $ ssh-keygen -f terraform_ssh_key -q
   # Add it to the ssh-agent 
   $ eval $(ssh-agent)
   $ ssh-add terraform_ssh_key
   ```
   
   Or:
   
   ```bash
   $ openstack keypair create -f value k8s > ssh_key
   $ openstack keypair show --public-key -f value k8s > ssh_key.pub
   $ chmod 0600 ./ssh_key
   # Add it to the ssh-agent
   $ eval $(ssh-agent)
   $ ssh-add ./ssh_key
   ```

## Quickstart

### Initialisation

```bash
$ terraform init
Initializing modules...
- module.network
- module.kube
[...]
Terraform has been successfully initialized!
```

Wait for the successfull initialization of terraform.

### Launch the cluster

You have to choose an openstack region to launch the cluster in, and a keypair name. You can either setup these variables in the customized `.tfvars` file or pass them in the command line.

In order to list your OpenStack compute regions, you can perform this command:

```bash
$ openstack catalog show nova
```

Export your choice in an env variable:

```bash
$ export OS_REGION_NAME=<REGION-NAME>
```

Regarding the keypair name, you can easily find the keypairs associated to your project in the selected region:

```bash
$ openstack keypair list
```

Export the keypair name in an env variable:
```bash
$ export OS_KEYPAIR_NAME=<KEYPAIR-NAME>
```

Then, start the cluster:

```bash
$ terraform apply -var region=$OS_REGION_NAME -var key_pair=$OS_KEYPAIR_NAME
```

This should give you an infra with 3 kubernetes masters in a public network with Canal (Flannel + Calico) CNI, Untainted nodes (pods can run on masters), kube-proxy for services.

## Get Started with Kubernetes

Use this command to get some help. Do not forget that all the SSH commands have to be performed from a terminal on your personal computer where your SSH key is deployed.

```bash
$ terraform output helper
Your kubernetes cluster is up.

Retrieve k8s configuration locally:

    $ mkdir -p ~/.kube/myk8s
    $ ssh core@A.B.C.D sudo cat /etc/kubernetes/admin.conf > ~/.kube/myk8s/config
    $ kubectl --kubeconfig ~/.kube/myk8s/config get nodes

You can also ssh into one of your instances:

    $ ssh core@A.B.C.D
    $ ssh core@A.B.D.E
    $ ssh core@A.B.C.F

Enjoy!
```

## More configuration

### Configure flavor

If you want to configure the type of instances you will start on your Kubernetes cluster, you can simply override the default value.

First of all, list all available flavors.

```bash
$ openstack flavor list -c Name -c RAM -c Disk -c VCPUs
```

Export the choosen flavor.

```bash
$ export OS_FLAVOR_NAME=<FLAVOR-NAME>
```

### Configure number of nodes

By default, we start 3 instances on your project.

```bash
$ export NODES=5
```

### Start your cluster

Then, start the cluster with your custom configuration:

```bash
$ terraform apply -var region=$OS_REGION_NAME -var key_pair=$OS_KEYPAIR_NAME -var flavor_name=$OS_FLAVOR_NAME -var count=$NODES
```