""" Sagemaker utils """

from logging import Logger

import boto3
import time
from botocore.client import BaseClient
from botocore.exceptions import ClientError
from typing import Dict, List, Tuple, Optional, Any


class SageMaker(object):
    def __init__(self, client: BaseClient, logger: Logger):
        self._client = client or boto3.client("sagemaker")
        self._logger = logger

    def describe_sagemaker_notebook_instance(
        self, notebook_instance_name: str
    ) -> Tuple[Optional[Any], Optional[ClientError]]:
        try:
            response = self._client.describe_notebook_instance(
                NotebookInstanceName=notebook_instance_name
            )
            return response, None
        except ClientError as e:
            self._logger(
                "Unable to retrieve notebook instance '{}' details: {}".format(
                    notebook_instance_name, e
                )
            )
            return None, e

    def stop_sagemaker_notebook_instance(
        self, notebook_instance_name: str, max_runs: int = 3
    ) -> Tuple[bool, Optional[Exception]]:
        result = False
        notebook_running = True
        count = 0
        while notebook_running and count < max_runs:
            count += 1
            try:
                response = self.describe_sagemaker_notebook_instance(
                    notebook_instance_name=notebook_instance_name
                )
                if not response:
                    return False, Exception(
                        "Unable to retrieve notebook {} instance "
                        "state".format(notebook_instance_name)
                    )
                self._logger(response)
                if response and isinstance(response, dict):
                    notebook_running = (
                        response.get("NotebookInstanceStatus") == "InService"
                    )
                self._logger("Notebook is running? {}".format(notebook_running))
                # Note: void return method, as can be seen in API doc: https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/sagemaker.html#SageMaker.Client.stop_notebook_instance
                if notebook_running:
                    self._logger(
                        "Attempting to stop Sagemaker notebook instance: {}".format(
                            notebook_instance_name
                        )
                    )
                    self._client.stop_notebook_instance(
                        NotebookInstanceName=notebook_instance_name
                    )
                result = not notebook_running
                time.sleep(5)
            except ClientError as e:
                self._logger(
                    "Failed to stop Sagemaker notebook instance: {} - {}".format(
                        notebook_instance_name, e
                    )
                )
                return result, e

        if not notebook_running:
            self._logger(
                "Sagemaker notebook instance: {} is stopped".format(
                    notebook_instance_name
                )
            )
        return result, None

    def update_sagemaker_notebook_instance(
        self,
        notebook_instance_name: str,
        disk_size: str,
        root_access_enabled: bool = True,
    ) -> Tuple[Optional[Any], Optional[Exception]]:
        """Updates SageMaker with the settings that Terraform currently does not support"""
        self._logger(
            "Updating notebook instance '{}' settings".format(notebook_instance_name)
        )
        try:
            response = self._client.update_notebook_instance(
                NotebookInstanceName=notebook_instance_name,
                VolumeSizeInGB=int(disk_size),
                RootAccess="Enabled" if root_access_enabled else "Disabled",
            )
            self._logger(response)
            return response, None
        except ClientError as e:
            self._logger("Failed to update sagemaker: {}".format(e))
            return None, e

    def create_sagemaker_notebook_instance(
        self,
        instance_name: str,
        instance_type: str,
        subnet_id: str,
        sg_id: str,
        role_arn: str,
        kms_key_id: str,
        tags: List[Dict[str, str]],
        lifecycle_config_name: str,
        direct_internet_access: str,
        disk_size: str,
        accelerator_type: str,
        root_access_enabled: bool,
        additional_code_repositories,
        default_code_repository=None,
    ) -> Tuple[Optional[Any], Optional[ClientError]]:
        self._logger("Creating sagemaker notebook instance {}".format(instance_name))
        try:
            response = self._client.create_notebook_instance(
                NotebookInstanceName=instance_name,
                InstanceType=instance_type,
                SubnetId=subnet_id,
                SecurityGroupIds=sg_id,
                RoleArn=role_arn,
                KmsKeyId=kms_key_id,
                Tags=tags,
                LifecycleConfigName=lifecycle_config_name,
                DirectInternetAccess="Disabled"
                if not direct_internet_access
                else "Enabled",
                VolumeSizeInGB=disk_size,
                AcceleratorTypes=accelerator_type,
                # DefaultCodeRepository=default_code_repository,
                # AdditionalCodeRepositories=additional_code_repositories,
                RootAccess="Enabled" if root_access_enabled else "Disabled",
            )
            self._logger(response)
            return response, None
        except ClientError as e:
            self._logger(
                "Failed to create sagemaker notebook: {}".format(instance_name)
            )
            return None, e

    def destroy_notebook_instance(
        self, instance_name: str
    ) -> Tuple[Optional[Any], Optional[ClientError]]:
        try:
            response = self._client.delete_notebook_instance(
                NotebookInstanceName=instance_name
            )
            self._logger(response)
            return response, None
        except ClientError as e:
            self._logger("Failed to destroy sagemaker notebook instance: {}".format(e))
            return None, e
