# Reusable CI/CD Pipeline Project

## Project Overview

A project which stores a reusable GitHub Actions workflow. The `main` branch is a template workflow, which can easily be extended for different languages. See the other branches for examples for Python and Java applications.

## Workflow Stages

The workflow is separated in multiple stages. Stages, which are comprised of one or more jobs, are defined in such a way to optimise the running time of the whole workflow.

### Linters

Here the quickest linters are ran:

- **GitLeaks**: Analyses the files for hardcoded secrets - tokens, passwords, keys, etc.
- **Editorconfig-checker**: Defines styling rules for files, based on their filetype.
- **Markdownlint**: Enforces styling rules for markdown files.
- **Language-specific linters**: Any other language specific linters (e.g. flake8 for Python) can be ran here.
- **Unit tests**: Unit tests are also ran as part of this stage.

### Build

In this stage a Docker image is built and deployed to the GitHub Container Registry.

### Code analysis

- **Snyk**: Static security analysis of the code and the dependencies.
- **Trivy**: Active code analysis - runs the docker image and scans for vulnerabilities.
- **SonarLint**: Static code analysis for anti-patterns, code quality, best practices and more.
- **Flyway**: Tests if the database migrations are valid.

### Upload Docker image

Takes the already-built docker image from the GHCR and uploads it to Dockerhub (could also be uploaded to a custom Docker registry).

### Deploy to k8s

Deploys the built image to a k8s cluster.

## Deep-dive: Docker building

The Docker image building process is optimized in multiple ways and it's illustrated in the three examples in the [mdp-classwork-1](https://github.com/ivaylopp/mdp-classwork-1) repository.

### Overview

The naming scheme of the image tags is the following: `ivaylopp/<repository name>:<branch or tag name>-<commit hash>`. This guarantees that image tags are unique per repository, branch and commit, and they are easiliy identifiable at glance.

The core steps of the build process are as follows:

- **Setup buildx**: This is a build utility which allows for multi-platform builds, caching of images and has other useful functionalities.
- **Log in to GHCR**: Log in so we can publish the image for use in other jobs of the workflow.
- **Docker metadata**: This action extracts metadata for the image and allows us to set multiple image tags to build if needed.
- **Build and push**: This action builds from the Dockerfile and pushes to the GHCR. Additionally all image layers of the build process are stored in GitHub Actions' cache where they can be reused in subsequent builds.

### Python

*[(Dockerfile)](https://github.com/ivaylopp/mdp-classwork-1/blob/main/Dockerfile)*

The base image we use is `python:alpine3.19`. It's the thinnest base image with python binaries already installed. We also provide the hash of the image so we can be sure the pulled image is exactly the one we expect.

After that we copy the `requirements.txt` file, which defines the dependencies of the Python app and we pull them with `pip install`. We pass the `--no-cache-dir` argument which tells `pip` not to store unneeded installation/source files of the packages, which reduces the overall image size. Additionally, this part will be caches, as long as the `requirements.txt` file doesn't change, which shouldn't happen all that often.

After that we copy the rest of the project and define the entrypoint.

### Java (.jar packaging)

*[(Dockerfile)](https://github.com/ivaylopp/mdp-classwork-1/blob/example-java-project/Dockerfile)*

This is a multi-stage Dockerfile - the first stage builds a `.jar` which is copied into a different base image in the second stage, from where it is ran.

The build stage is optimised similarly to the python Dockerfile. We first copy only the `pom.xml` file which defines the dependencies of the project, and pull them with `mvn dependency:resolve`. This will be cached and reused in most workflows. After that we compile the app and package it in a `.jar`.

The base image of the second stage is `amazoncorretto:17-alpine-jre`, which is a slim image that contains only the JRE (Java Runtime Environment). It doesn't contain the rest of the JDK which is needed for compilation and packaging, since that's only used in the first step. This allows us to further reduce the size of the output image.

Lastly we define an entrypoint which applies the `$JAVA_OPTIONS` env variable as an argument. This allows us to pass arguments to the `java` binary like memory limits, the garbage collector which we want to use and other configurations.

### Java (GraalVM Build)

*[(Dockerfile)](https://github.com/ivaylopp/mdp-classwork-1/blob/example-java-graalvm-project/Dockerfile)*

Another multi-stage Dockerfile which first builds the native GraalVM binary and then copies it into a different base image.

The base image we use in the build stage is special in that the JDK has the needed functionalities to compile a Java project into a binary executable. It happens to lack the Maven binaries, so we copy those and download the dependencies of the project (cachable). After that we build the binary.

The second stage's base image is `scratch` which is an empty image. In this case we don't need the JRE, since the compiled executable can be ran directly. This significantly reduces the size of the output image, which is one of the main advantages of GraalVM
