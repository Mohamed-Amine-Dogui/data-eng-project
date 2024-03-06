FROM amazonlinux:2

ARG buildHash

WORKDIR /app

RUN yum update -y \
    && amazon-linux-extras enable python3.8 \
    && yum install -y \
        python38 \
    && yum clean all \
    && rm -rf /var/cache/yum \
    ;

ENV VIRTUAL_ENV=/opt/venv
RUN python3.8 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"


COPY requirements.txt .

RUN pip3 install --no-cache-dir --upgrade pip  \
    && pip3 install --no-cache-dir -r requirements.txt

COPY src .

ENV MODEL_PORT=80

CMD uvicorn main:app --host 0.0.0.0 --port $MODEL_PORT
