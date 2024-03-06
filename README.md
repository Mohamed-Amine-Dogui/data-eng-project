data-eng-project Template
=============================
This project template is designed to bootstrap data engineering projects, focusing on the efficient management and processing of data, deployment of machine learning models, and providing a foundation for building robust data pipelines.
[GitHub new SSH key]: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
[GitHub add SHH key]: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account
[GitHub create repository secret]: https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository
[Create repo from template]: https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/creating-a-repository-from-a-template
[CLI documentation]: https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/aws-get-started


1. Extract, Transform and Load job(s) [`python`, `spark`, `aws glue`, `aws lambda`]
1. Jupyter Notebook(s) [`python`, `aws sagemaker`]
1. Deploy and expose business logic as an HTTP Service / RESTful API [`python`, `docker`]
1. Unit testing and Integration testing [`python`, `docker`, `docker-compose`]
1. CICD pipeline(s)/workflow(s) to ensure automation of tests and deployment [`python`, `docker`]

Table of Contents
=================

* [Introduction](#introduction)
* [Project structure](#project-structure)
* [Steps for using this template](#steps-for-using-this-template)
* [Local setup](#local-setup)
* [Deployment and CICD](#deployment-and-cicd)
* [ETL](#etl)
* [Notebook and exploration](#notebook-and-exploration)
* [Model Services](#model-services)
   * [Serve](#serve)
      * [OpenAPI Spec](#openapi-spec)
   * [Train](#train)
* [Terraform](#terraform)
* [Testing](#testing)
   * [Unit testing](#unit-testing)
   * [Integration testing](#integration-testing)



## Introduction

This template is aimed at facilitating the setup and development of data engineering projects. It serves as a starting point to help data engineers and scientists in organizing and executing their tasks efficiently, focusing on automation, scalability, and maintainability of data processes.

## Project Structure

The template organizes the project into modular components, ensuring clear separation of concerns and easy navigation. Here's a high-level overview:

```
├── etl                     <- individual directories for each ETL logic (Glue, Lambda)
│   └── ingest_raw_data     <- example dir with Glue Job
├── model
│   ├── serve
│   │   └── src             <- http server that implements an exposes the business logic of the project
│   └── train
│       └── src
├── notebook                <- directory to store notebooks
├── terraform
│   ├── environments
│   │   └── infrastructure  <- infrastructure (.tf) are expected to be loaded in here.
│   ├── modules
│   └── templates
├── tests                   <- tests to all etl's and model serve/train logics. check the test section to find out how to run them
│   ├── data                <- test/example data
│   ├── integration
│   │   └── serve
│   │       └── src         <- define integration tests to the model http service
│   ├── setup
│   └── unit
│       ├── ingest_raw_data <- tests example etl **ingrest_raw_data**
│       └── serve
│           └── src         <- tests specific to the business logic defined in model/serve/src
├── docker-compose.yaml     <- defines containers to run unit-test and integration-test -> see testing section
└── dst.mk                  <- project's makefile. no change should be needed here
```

## Steps for using this template

Main steps and responsibilities needed to take in order to reuse this template for your project.


1. Create a GitHub Environments named `destroy-feature-workspace`, `deploy-int`, `deploy-prd` (repository Settings -> Environments) and add users/teams as reviewers. This is used to require approval for specific jobs of GitHub workflows (Deployment to `int`/`prd`, destruction of feature branches' infrastructure) and add the proper team members needed for the 3x environments defined:
   - `destroy-feature-workspace`: any team member who is developing their own feature branch should be able to approve
   - `deploy-int` and `deploy-prd`: people listed here will be able to authorize deployments to such stages when respective pipelines are being executed.

1. Set up Branch protection rules (Settings -> Branches -> Branch protection rules -> `main/master` branch) by checking the following boxes:
   - Require pull request reviews before merging
   - Require status checks to pass before merging
   - Require that temporary resources are deleted on Pull Requests, job called `Ensure Workspace Cleanup` is run for all PRs to your `main/master` branch - this guarantees that temporary infrastructure is destroyed. **Unfortunately, you can only do this after the first pipeline run**, as GitHub doesn't allow to create a policy for a job it has never "seen" before. On repo `Settings` -> `Branches` -> `Add rule` for branch pattern `master/main`.
   - Include administrators

1. Adjust template code

   - set terraform variables `/terraform/environments/infrastructure/variables.tf`, especially `project`, `wa_number`, `project_id`, `tag_KST`. 
   - In all files under `.github/workflows/*.yaml`, configure these to the proper value 
    ```yaml
    env:
      
      ECR_REPOSITORY: 'dst-model-serve'
      DEPLOY_PROJECT: 'dst'
      TF_BUCKET_BASE_NAME: 'terraform-backend'
      TF_DYNAMO_BASE_NAME: 'terraform-state-lock'
    ```
	 The Black Duck Workflow (in `.github/workflows/black-duck-scans.yml`) is by default disabled in forked repos. In the run-params section, a variable is created that skips all scans when the repo name is not the one of Data Science Template (dst_forked_skip). Removing the skip can be achieved by removing all conditions in the steps, setting the variable name to be always false, or changing the condition to match the repo name.
	 This workflow contains the required steps for performing the Black Duck scans. The global variables mentioned in the code above should be also adjusted on this file, next to the ones including the `BD_` prefix.
   ```yaml
      BD_PROJECT_NAME: 'data_eng_project'
      BD_DISTRIBUTION: 'external'
      BD_URL: 'https://blackduck.mega.cariad.cloud/'
      BD_DOCKER_REPO_NAME: "dst-model-serve"
      BD_TAGS: 'none'
    ```
	 Additionally, some steps on the workflow might be required to be deleted. For example, if there's no Docker Scan in the repo, the whole step needs to be removed, if there are not requirements.txt files in the repo, the relevant scan should be removed, and so on.
    - In `.github/workflows/feature-branch`, job `run-params`, step `tf-feature-space`, make sure to replace you JIRA base ticketing name as in the example. E.g. `feature/WEDATAIN-XXXX` should be parsed to `we-XXXX`
    - Delete unwanted resources from template

1. Using your project role log in to all stages and add to your projects secrets in secrets manager including *at least* `stage=<stage>` (e.g. in dev: `stage="dev"`).


1. create secrets in AWS SecretsManager. These secrets target to have the contents of the `tfvars` which will be injected by the pipeline during terraform operations. Since they are empty, you need to locate them in each of the AWS account and fill in, as a minimum: `stage="<stage_name>"` (dev/int/prd). The secret looks like: `github-actions-<project>-<tf-environment>-<stage>`. **NOTE**: choose "plain text" when editing the secret and delete the `{}` json-like brackets before inserting your secret contents. An example of the full contents of that secret would be exactly as:
    ```
    stage="dev"
    ```

## Local setup

Steps to use the template locally most efficiently.
Definitly check out [Testing](#testing) to build and run your tests locally!!

### Proxy
1. Set HTTP_PROXY and HTTPS_PROXY following the steps described in [How-to Proxy].

### Requirements

1. `docker-compose` (typically installed with `docker`)
1. `conda` (not required, but recommended for local development if available)
1. `terraform` from [here][CLI documentation] - be sure to use the version mentioned in `terraform/environments/infrastructure/main.tf`

### Pre-commit hooks

1. Configure your pre-commit hooks (`pre-commit` was installed in step (3) and the pre-commit configuration is in the root of the repo `.pre-commit-config.yaml`)

    ```shell
    # make you run this command from the root of the repository
    pre-commit install
    ```

### Conda setup

1. Create a conda environment

    ```shell
    conda env create -n dst python=3.9
    ```

1. Activate the new conda environment

    ```shell
    conda activate dst
    ```

1. Install project test requirements (these will install also pre-commit and black, used for linting)

    ```shell
    pip install -r tests/requirements.txt
    ```

## Deployment and CICD

The projects uses Github Actions to build and deploy the project components. Out of the box you will be able to use a sophisticated workflows that supports:

1. [Local development](#local-setup)

1. [Deployment pipelines/workflows](#triggering-the-workflows)

    - Feature-Development in an isolated deployment in DEV using Terraform Workspaces
    - Deployment of the main branch to INT
    - Releasing to PRD

this aims to provide you with _fast integration_  as well as necessary _independence_ and _speed_.

The Github Action workflows can be found at `.github/workflows` and will continuously be updated as Github releases new capabilities.

### Triggering the workflows

The template comes with working, automated pipelines that deploy the infrastructure over the different stages (TF Workspace in DEV, DEV, INT, PRD)

#### `feature brances`:
`feature brances`: to trigger the first stage of the workflows, simply open a PR for your branch (`feature/WEDATAIN-XXXX-some-feature`), targetting the main branch. This will automatically create your resources with a prefix based on your branch name: `feature/WEDATAIN-XXXX-some-feature` --> `we-XXXX-some-feature-<resource-name>`

This way you can inspect changes in the code directly on the DEV account without interfering with other projects / feature development.

Please note: You will need to destroy your resources before you merge your PR to master (last step of the workflow).

#### Merging to main/master

`merge to main/master`: triggers deployment to dev/int accounts

#### Releasing to PRD

`release/X.X.X branch or tag formatted X.X.X`: triggers deployment to the production account

#### Rerunning a pipeline

If it is possible to rerun a pipeline you can push an empty commit to rerun the pipeline.

   ```bash
   git commit --allow-empty -m "Trigger Build"`
   ```

Using the UI will currently fail as the Github Run ID (currently) doesn't update.

## ETL

--tbd--

## Notebook and exploration

A project that uses the template as is will deploy a notebook automatically which can be accessed on DEV with `PA_DEVELOPER` and `PA_LIMITEDDEV`. Access to the notebook at higher stages (INT, PRD) need to be granted explicitly on a roles-basis.

## Model Services
Algorithms are served via REST interface

### Custom Container Deployment

#### OpenAPI Spec

The Swagger/OpenAPI spec is **generated automatically** based on the classes and endpoints defined in the model serve app. It's possible to check them directly.

1. Run the model service on docker

    ```shell script
    docker-compose up --build --always-recreate-deps model-service
    # or on Linux, you may require sudo
    sudo docker-compose up --build model-service
    ```

1. Pop open your favourite browser and check the Open API Spec at: http://0.0.0.0:8080/docs

1. You are done, you can ensure all docker resources are turned off

    ```shell script
    docker-compose down
    # or on Linux, you may require sudo
    sudo docker-compose down
    ```

**NOTE:** the `--always-recreate-deps` option ensures that docker rebuilds dependencies. This option is not always mandatory. However, if you are running the tests/container repetitively after making changes, you'll be sure that your changes have been built into the dependencies as well.

## Machine Learning workflow

After creating an MLflow Module instance in `mlflow.tf` for your dedicated project, as well as setting up the notebook in `notebook.tf`, continue with the following steps

### Train Machine Learning models

Add and train new models e.g. via Jupyter Notebook on the Sagemaker notebook user interface in AWS. <br>
You can add your Trainingcode as an`.ipynb` script into the notebook module folder and
train them inside the AWS UI after deployment. <br>
Also update the `notebook_on_startup_script.sh` under `terraform/templates`.
You can find an official training example from mlflow under `notebook/example-mlflow-train.ipynb`.
Adjust the tracking uri with the right hostname and port: `mlflow.set_tracking_uri("http://${mlflow_hostname}:${mlflow_port}")`.
### Track Machine Learning models via mlflow

MLFlow is used as a service to track the trained ML Model Artifacts.
The following Confluence page [How-to-MLflow] lists all the necessary steps to access the MLflow UI from your laptop.

### Deployment of a Machine Learning model via dst
For the deployment of a dedicated ML Model Artifact add the proper s3 URIs of the trained model(s) as a `ml_model_deploy_experiment_s3_uri` Variable in the `variables.tf` file of the project.
There are options, to set the right URI for different stages of a project.The Terraform Stack for the ML Deployment is located in the `model-service-ml.tf` file.


To find the right URI, follow the below mentioned path.

1. After training the models and having access to the mlflow UI where the models are tracked, open the Models folder on the top and chose the right Model which you have trained e.g. Diabetes
   ![Screenshot 2021-08-10 085229](https://user-images.githubusercontent.com/78474103/128869211-a4acf645-4cf4-4f98-8da7-368605b55b03.jpg)
2. Search for the right Version, which should be deployed and choose it
   ![Screenshot 2021-08-10 085343](https://user-images.githubusercontent.com/78474103/128869257-f7cd95a9-2fb1-44d8-bae9-2844b0ccf400.jpg)
3. Click to the run ID under `Source Run`
   ![Screenshot 2021-08-10 085449](https://user-images.githubusercontent.com/78474103/128869294-9e9e7cfd-b60c-4d98-bb01-b22d099199ca.jpg)
4. Scroll to the bottom of the page to `Artifacts` and open the model folder. The `Full path` which should be used as the `ml_model_deploy_experiment_s3_uri` variable will be listed
   ![Screenshot 2021-08-10 085524](https://user-images.githubusercontent.com/78474103/128869504-a080cc40-3b10-4585-8da9-8a3e2cb706ba.jpg)

Inside the Notebook, under `example-mlflow-train.ipynb` you can find an example call to the endpoint to get a prediction from the deployed model.

### Automated ML training
Info: automated ml training is disabled by default within the data-science-template, if your project requires the automated ml training setup, please do followed steps:

1. run the copied data-science-template within your own Repository/Pipeline with mlflow `mlflow.tf`enabled and deploy it once into production
2. After a successful deployment enable automated ml training (Stepfunction) within `model-training.tf` and run the pipeline.



## Terraform

For in introduction look [here][Terraform introduction] or search the internet.

## Testing

The objective of the template a development blueprint that can be easily replicated and shared between environments/teams. For this reason, the tests are designed to run in docker containers with the help of docker-compose.

The `docker-compose.yaml` in the root of this repository defines the docker services that will run (and its dependencies) for `unit-test` and `integration-test`. It's also important to note that you should not change the names of the services `unit-test`, `integration-test` and `model-service`.

This ensures that both CICD engine and developers can run the tests with exact same methodology as described in the following sections.

### Unit testing

(Recommended) test with docker (ensures same testing environment as in the CICD Pipeline)

```shell script
docker-compose up --build unit-test
# or on Linux, you may require sudo
sudo docker-compose up --build unit-test
```

(Alternatively **for developers with linux**) if you have `conda` and `java` (only needed if testing Glue Jobs) properly setup locally:

```shell script
# create virtual env, only needed once
conda create -n dst python=3.7 -y
conda activate dst
pip install -r tests/requirements.txt

# run tests
pytest tests/unit tests/unit
```

### Integration testing

(Recommended) test with docker because it ensures all dependencies are in place.

```shell script
docker-compose up --build --always-recreate-deps integration-test

# or on Linux, you may require sudo
sudo docker-compose up --build --always-recreate-deps integration-test
```
