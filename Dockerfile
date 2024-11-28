# Build the manager binary
FROM registry.access.redhat.com/ubi9/go-toolset:1.21.11-9 as builder

ENV SEALIGHTS_TOKEN="eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL1BST0QtUkVESEFULmF1dGguc2VhbGlnaHRzLmlvLyIsImp3dGlkIjoiUFJPRC1SRURIQVQsbmVlZFRvUmVtb3ZlLEFQSUdXLTgzMDMzZmM0LWZkMzMtNDUzNy1hOWVkLTEwNzUzZWZiZTg4NiwxNzMyNjM3NTQ5NTc5Iiwic3ViamVjdCI6InJlZGhhdEBhZ2VudCIsImF1ZGllbmNlIjpbImFnZW50cyJdLCJ4LXNsLXJvbGUiOiJhZ2VudCIsIngtc2wtc2VydmVyIjoiaHR0cHM6Ly9yZWRoYXQuc2VhbGlnaHRzLmNvL2FwaSIsInNsX2ltcGVyX3N1YmplY3QiOiIiLCJpYXQiOjE3MzI2Mzc1NDl9.FoY3KQXz8zSs9eiIssRV3aEjPZmyFzSm5QUIj8jpMTEXqUS2b551VHaaYF_6I5ap0suwGdmiDhDQXWhGnEnYZ1hcH33b8YFEWyU7sYWgsnPUbfmG6xcFeyeQyOU4-I3lmX2Uza21o0kNfL0rVTaOxc8pIILySRDOnOTN6-KrpOM6QH1-1eggVwjTMlGGVV8xjKManeHECoJDWgjyUTt8T39G9R62gjKxTQz7Fjgql9aFWMQC7kSwlF48OUFpTXmC3YWjor4TRo-Fi13hHUTuUSZJVH61W04lzu1q10ZPOz_ohE6IH-eZtHW7iSHHW_9h7X9989CrxjGZ8j0EzV2a_WkfoC5J92rHcQT3UKfWol8aT8mBIIKfeyveln73IjBh4UtoWceN6OrwSNdvF7TsPcIvSbiMYKIMjI7veKqV4-1Z1mUQI2YGXuwFuz7WRf32G7cC733T7URuDacmAy3-8K4qBoli1ZmFpbyGZBr05LFslI79UWzKT2fyOfkD2HYH2xv566aWWERg0PXTieuv724bfwbdzp8hrXcrVcL78COKcqNyio7TM_ca6-vNq7FUWpW4nx6UrJybHcuBGpGV6tiNLYgN1kcynvly98bXwtwm5AInBPU60Ybn6TitWP7qHZ5Ku9uXiZRnT0jG4Gr4WikfSyT50sTgozwoJ8_Y0EI" \
    AGENT_URL='https://agents.sealights.co/slgoagent/latest/slgoagent-linux-amd64.tar.gz' \
    AGENT_URL_SLCI='https://agents.sealights.co/slcli/latest/slcli-linux-amd64.tar.gz'

USER root

# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY . .

RUN curl -sSL ${AGENT_URL} | tar -xz -C /usr/local/bin/
RUN curl -sSL ${AGENT_URL_SLCI} | tar -xz -C /usr/local/bin/

RUN slcli config init --lang go --token ${SEALIGHTS_TOKEN}

RUN slcli config create-bsid --app release-service-fla --branch main --build release-service_$(date +'%y%m%d.%H%M')

#Scanning the code
RUN slcli scan --bsid buildSessionId.txt --path-to-scanner /usr/local/bin/slgoagent --workspacepath ./ --scm git

# Build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o manager main.go

ARG ENABLE_WEBHOOKS=true
ENV ENABLE_WEBHOOKS=${ENABLE_WEBHOOKS}

# Use ubi-micro as minimal base image to package the manager binary
# See https://catalog.redhat.com/software/containers/ubi9/ubi-micro/615bdf943f6014fa45ae1b58
FROM registry.access.redhat.com/ubi9/ubi-micro:9.4-15
COPY --from=builder /opt/app-root/src/manager /

# It is mandatory to set these labels
LABEL name="Konflux Release Service"
LABEL description="Konflux Release Service"
LABEL io.k8s.description="Konflux Release Service"
LABEL io.k8s.display-name="release-service"
LABEL summary="Konflux Release Service"
LABEL com.redhat.component="release-service"

ENV SEALIGHTS_TOKEN='eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL1BST0QtUkVESEFULmF1dGguc2VhbGlnaHRzLmlvLyIsImp3dGlkIjoiUFJPRC1SRURIQVQsbmVlZFRvUmVtb3ZlLEFQSUdXLTgzMDMzZmM0LWZkMzMtNDUzNy1hOWVkLTEwNzUzZWZiZTg4NiwxNzMyNjM3NTQ5NTc5Iiwic3ViamVjdCI6InJlZGhhdEBhZ2VudCIsImF1ZGllbmNlIjpbImFnZW50cyJdLCJ4LXNsLXJvbGUiOiJhZ2VudCIsIngtc2wtc2VydmVyIjoiaHR0cHM6Ly9yZWRoYXQuc2VhbGlnaHRzLmNvL2FwaSIsInNsX2ltcGVyX3N1YmplY3QiOiIiLCJpYXQiOjE3MzI2Mzc1NDl9.FoY3KQXz8zSs9eiIssRV3aEjPZmyFzSm5QUIj8jpMTEXqUS2b551VHaaYF_6I5ap0suwGdmiDhDQXWhGnEnYZ1hcH33b8YFEWyU7sYWgsnPUbfmG6xcFeyeQyOU4-I3lmX2Uza21o0kNfL0rVTaOxc8pIILySRDOnOTN6-KrpOM6QH1-1eggVwjTMlGGVV8xjKManeHECoJDWgjyUTt8T39G9R62gjKxTQz7Fjgql9aFWMQC7kSwlF48OUFpTXmC3YWjor4TRo-Fi13hHUTuUSZJVH61W04lzu1q10ZPOz_ohE6IH-eZtHW7iSHHW_9h7X9989CrxjGZ8j0EzV2a_WkfoC5J92rHcQT3UKfWol8aT8mBIIKfeyveln73IjBh4UtoWceN6OrwSNdvF7TsPcIvSbiMYKIMjI7veKqV4-1Z1mUQI2YGXuwFuz7WRf32G7cC733T7URuDacmAy3-8K4qBoli1ZmFpbyGZBr05LFslI79UWzKT2fyOfkD2HYH2xv566aWWERg0PXTieuv724bfwbdzp8hrXcrVcL78COKcqNyio7TM_ca6-vNq7FUWpW4nx6UrJybHcuBGpGV6tiNLYgN1kcynvly98bXwtwm5AInBPU60Ybn6TitWP7qHZ5Ku9uXiZRnT0jG4Gr4WikfSyT50sTgozwoJ8_Y0EI'

CMD export SEALIGHTS_TOKEN="${SEALIGHTS_TOKEN}"

USER 65532:65532

ENTRYPOINT ["/manager"]
