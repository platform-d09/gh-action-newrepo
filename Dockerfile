FROM python:3.12-alpine

RUN apk update && \
    apk add --no-cache jq \
    curl \
    git \
    openssh-client \
    bash \
    && pip3 install cookiecutter && pip3 install six

COPY *.sh /
COPY requirements.txt /
RUN pip3 install -r requirements.txt
COPY *.py /
RUN chmod +x /*.sh
RUN chmod +x /*.py

ENTRYPOINT ["/new_repo.py"]