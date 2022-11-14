#! /bin/sh

PWD=$(pwd)

git clone git@github.com:ramos-ai/MoStress.git $(pwd)/data/mostress

docker build -t coeus .build/

docker run --gpus all -d -it -p 8888:8888 -v $(pwd)/data:/home/coeus/development \
-e GRANT_SUDO=yes -e JUPYTER_ENABLE_LAB=yes -e NB_UID=1000 -e NB_GID=1000 \
--user root --restart always --name coeus_1 coeus