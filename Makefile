
# Image URL to use all building/pushing image targets
GCLOUD_PROJECT ?= kubeflow-images-public
IMG ?= gcr.io/$(GCLOUD_PROJECT)/application-controller
TAG ?= $(eval TAG := $(shell git describe --tags --long --always))$(TAG)
GOLANG_VERSION ?= 1.12.4

.PHONY: test manager run debug install deploy manifests fmt vet generate docker-build docker-push

all: test manager

# Run tests
test: generate fmt vet manifests
	echo "Skip test..."
	#go test ./pkg/... ./cmd/... -coverprofile cover.out

# Build manager binary
manager: generate fmt vet
	go build -o bin/manager github.com/kubernetes-sigs/application/cmd/manager

# Run using the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet
	go run ./cmd/manager/main.go

# Debug using the configured Kubernetes cluster in ~/.kube/config
debug: generate fmt vet
	dlv debug cmd/manager/main.go

# Install CRDs into a cluster
install: manifests
	kubectl apply -f config/crds

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests
	kubectl apply -f config/crds
	kustomize build config/default | kubectl apply -f -


# unDeploy controller in the configured Kubernetes cluster in ~/.kube/config
undeploy: manifests
	kustomize build config/default | kubectl delete -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests:
	controller-gen all

# Run go fmt against code
fmt:
	go fmt ./pkg/... ./cmd/...

# Run go vet against code
vet:
	go vet ./pkg/... ./cmd/...

# Generate code
generate:
	go generate ./pkg/... ./cmd/...

# Build the docker image
docker-build: test
	docker build \
		--build-arg GOLANG_VERSION=$(GOLANG_VERSION) \
		--target=builder \
		--tag $(IMG):$(TAG) .
	@echo "updating kustomize image patch file for manager resource"
	sed -i'' -e 's@image: .*@image: '"${IMG}:${TAG}"'@' ./config/default/manager_image_patch.yaml

# Push the docker image
docker-push:
	docker push $(IMG):$(TAG)

docker-push-latest:
	gcloud container images add-tag --quiet $(IMG):$(TAG) $(IMG):latest --verbosity=info
	echo created $(IMG):latest
