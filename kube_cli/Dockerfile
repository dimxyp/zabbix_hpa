FROM alpine:3.12

#Azure and kubectl
# Install Azure CLI
RUN apk add py3-pip gcc musl-dev python3-dev libffi-dev openssl-dev cargo make curl
RUN pip install --upgrade pip
RUN pip install azure-cli
# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin/kubectl
# Config Azure CLI
RUN az login --service-principal --username "7af45c88-b300-4e6d-a5a2-c480ef6a8105" --password "1QL8Q~FilrpsQ-9OFxlYhbKVyGh2I6b~q_C5DbFK" --tenant "b11b0e93-0aec-47ed-bbaf-fc3e014e0b35"
RUN az aks get-credentials --resource-group Eurolife_AKS_RG --name Eurolife_AKS_Prod

