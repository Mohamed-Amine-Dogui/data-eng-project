""" WIP EC2 utils """

from logging import Logger

import boto3
from botocore.client import BaseClient
from botocore.exceptions import ClientError


class Ec2(object):
    def __init__(self, client: BaseClient, logger: Logger):
        self._client = client or boto3.client("sagemaker")
        self._logger = logger

    def create_ec2_instance(self, image_id, instance_type, keypair_name):
        """Provision and launch an EC2 instance"""

        # Provision and launch the EC2 instance
        try:
            response = self._client.run_instances(
                ImageId=image_id,
                InstanceType=instance_type,
                KeyName=keypair_name,
                MinCount=1,
                MaxCount=1,
            )
            instance_info = (
                response.get("Instances")[0]
                if response and response.get("Instances")
                else None
            )
            if instance_info is not None:
                self._logger.info(
                    f'Launched EC2 Instance {instance_info["InstanceId"]}'
                )
                self._logger.info(f'    VPC ID: {instance_info["VpcId"]}')
                self._logger.info(
                    f'    Private IP Address: {instance_info["PrivateIpAddress"]}'
                )
                self._logger.info(
                    f'    Current State: {instance_info["State"]["Name"]}'
                )
                return response, None
        except ClientError as e:
            self._logger.error(e)
            return None, e

    def instance_status(self, instances):
        """Convenience func for retrieving status of instances
        See details of client.describe_instance_status():
        http://boto3.readthedocs.org/en/latest/reference/services/ec2.html#EC2.Client.describe_instance_status
        """
        status = self._client.describe_instance_status(
            InstanceIds=[ec2.id for ec2 in instances]
        )
        if isinstance(status, dict) and "InstanceStatuses" in status.keys():
            return [
                (
                    vm.id,
                    status["InstanceStatuses"][0]["InstanceStatus"]["Status"],
                )
                for vm in instances
            ]

    def instance_state(self, instances):
        """Convenience func for retrieving status of instances"""
        state = self._client.describe_instance_status(
            InstanceIds=[ec2.id for ec2 in instances]
        )
        if state is not None and "InstanceStatuses" in state.keys():
            return [
                (vm.id, state["InstanceStatuses"][0]["InstanceState"]["Name"])
                for vm in instances
            ]

    def get_target_ec2s(self, tags):
        """
        Convenience function to filter master instance(s)
        NOTE: Filter dicts have not been implemented in Moto yet.
        Thus implemented alternative way, so that this method could
        be tested as well
        instances = self.ec2.instances.filter(
            Filters=[{'Names': 'tag:spark-masters', 'Values': ['ephemeral-spark']},
                     {'Names': 'tag:owner', 'Values': [owner]},
                     ])
        """
        filters = []
        for tag in tags:
            filter = {
                "Name": "tag:{}".format(tag["Key"]),
                "Values": [tag["Value"]],
            }
            filters.append(filter)

        return [ec2 for ec2 in self._client.instances.filter(Filters=filters)]

    def terminate(self, instance_ids, dry_run=True):
        """Terminates a specific ec2 instance"""
        response = self._client.instances.filter(InstanceIds=instance_ids).terminate(
            DryRun=dry_run
        )
        result = []
        if isinstance(response, list) and "TerminatingInstances" in response[0].keys():
            result = [
                (vm["InstanceId"], vm["CurrentState"]["Name"])
                for vm in response[0]["TerminatingInstances"]
            ]
        return result
