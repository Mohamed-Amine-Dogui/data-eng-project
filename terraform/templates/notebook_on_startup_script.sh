#!/usr/bin/env bash

# create requirements file
cat << 'EOF' > /tmp/requirements.txt
${requirements}
EOF

# create sample notebook
cat << 'EOF' > /tmp/example-mlflow-train.ipynb
${notebook_contents}
EOF

# create conda environment
sudo -u ec2-user -i <<'EOF'
conda create -y -n python_mlflow python=3.7 ipykernel
source /home/ec2-user/anaconda3/bin/activate /home/ec2-user/anaconda3/envs/python_mlflow
cp /tmp/requirements.txt /home/ec2-user/SageMaker/requirements.txt
source /home/ec2-user/anaconda3/bin/deactivate
cp /tmp/example-mlflow-train.ipynb /home/ec2-user/SageMaker/example-mlflow-train.ipynb
EOF

# ensure the notebook is turned off everyday
echo "Starting shell script that runs every time the SageMaker Notebook Instance is started including the time its created - useful for adding common dependencies"

cat << EOF > stopnotebook.py
#!/usr/bin/python
import sys
import boto3
import json
def read_notebook_name():
    with open('/opt/ml/metadata/resource-metadata.json', 'r') as meta:
        _metadata = json.load(meta)
    return _metadata['ResourceName']
notebook = boto3.client('sagemaker')
notebook.stop_notebook_instance(
    NotebookInstanceName=read_notebook_name()
)
EOF

chmod 750 stopnotebook.py

(crontab -l 2>/dev/null; echo "0 18 * * * /usr/bin/python $PWD/stopnotebook.py") | crontab -
