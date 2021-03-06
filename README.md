# Ansible documentation.

1. Get the vault keyfile from a team member and put it in `deploy/vault-key`
2. Install the Python requirements: `$ pip install -r deploy/requirements.txt`
3. Install the Ansible requirements: `$ ansible-galaxy install -r deploy/roles/requirements.yml` 
4. Install and initialize the `gcloud` CLI: https://cloud.google.com/sdk/docs/install
5. Login to gcloud: `$ gcloud auth login`
6. [Optional] Get the project ID from GCP and place it in the `GCR_PREFIX` var of the `deploy/Makefile`
7. [Optional] Place it also in `deploy/ansible_vars/base.yml#gcp_project`
8. [Optional] Place the project number in `deploy/ansible_vars/base.yml#gcp_project_number`
9. Create the machine: `$ ansible-playbook --verbose --vault-password-file deploy/vault-key -i deploy/production --private-key ~/.ssh/google_compute_engine deploy/machines.yml`
10. Build and push the cloud-init config: `ansible-playbook --verbose --vault-password-file deploy/vault-key -i deploy/production --private-key ~/.ssh/google_compute_engine deploy/containers.yml`
11. Restart the machine, which will restart the containers: `gcloud compute instances reset --zone <yourZone> <instanceID> --project <yourProject>`


# OLD DOCS BELOW


[![Cookiecutter Django Ansible Badge](https://img.shields.io/badge/built%20with-Cookiecutter%20Django%20Ansible-green.svg)](https://github.com/HackSoftware/cookiecutter-django-ansible)

## What is this repository?

Our machines are provisioned and maintained **ONLY with ansible roles**. So if you want to make any changes to the machines **DONT DO IT VIA SSH**. Make changes in this repo and run the ansible code to change the server state. 

Ansible is really handy for deployment too. Thanks to the guys from [ansistrano](https://github.com/ansistrano/deploy) we can deploy our project in a nice and smooth way.

**What this ansible code do?**

- It installs python.
- It sends the team keys to the server.
- It installs the postgresql server and configures it.
- It installs the nginx server and configures the vhost.
- It configures everyting that django needs: directory structure, upstart jobs, env vars, etc.
- It can deploy you project.

## Why do we use ansible?
Using ansible, we have dramatically reduced the time it takes us to deliver applications into production, from weeks to days and even hours.

Eliminate Configuration Drift - With ansible, our servers remain in the state we set for them.

Visibility - Ansible gives us rich data sets not only of infrastructure configuration but also of any changes to that infrastructure. We have much more visibility into the changes occurring in our infrastructure over time and their impact to service levels.

Ansible can provision a fully working server in 20 minutes. That would have taken close to a full day of work without ansible!

## How to run the ansible code?
First of all you need to have latest ansible installed.

Keep in mind that ansible works **only with python2 for now**. So create a python2 virtualenv for it.

```
$ pip install ansible
```

Then you have to install all ansible roles. ``ansible-galaxy`` is the package manager here.

```
$ ansible-galaxy install -r roles/requirements.yml
```

### And now you are ready to run the ansible code

You can run the ansible code in a vagrant virtual box just to test it. **Always test your code in a virtual box before running it in production!**

```
vagrant up
```

**Lets run the vagrant code in production**

Provision the staging server

```
ansible-playbook -i staging sites.yml
```

Provision the production server

```
ansible-playbook -i production sites.yml
```

## How to deploy your project?

```
ansible-playbook -i staging deploy.yml
```

## Common things that you can change here.

### Change the machine IP address or add a new machine

We have two types of machines: webservers and dbservers. That makes scaling easyer but you can use the same machine for both types.

Here are the machine addresses:
- [Staging machines](/staging)
- [Production machines](/production)

### Nginx configuration

Maybe you want to change the nginx config? [It is here.](/roles/application/templates/nginx_config.j2)

### SSH Keys

Maybe you want to give someone access to the server? [Look at this dir.](/ansible_vars/public_keys/)

### Django related changes

#### Change some env vars

There are two env configurations. One for your production server and one for your staging server. [The env files are located here.](/application_vars/)

#### See sensible information
All sensible information like passwords for postgres and rabbitmq can be changed from [here.](/ansible_vars/)

## How to run only a certain piece of code

You can filter tasks based on tags from the command line with `--tags` or `--skip-tags`. You can list available tags with `--list-tags`

```bash
ansible-playbook -i staging sites.yml --tags "sshkeys,packages"
```
The existing tags are:

**Upload new ssh public keys from git:**

```bash
ansible-playbook -i staging sites.yml --tags "sshkeys"
```

**Update env vars:**

```bash
ansible-playbook -i staging sites.yml --tags "environment"
```

**Update or install new apt packages:**

```bash
ansible-playbook -i staging sites.yml --tags "packages"
```
