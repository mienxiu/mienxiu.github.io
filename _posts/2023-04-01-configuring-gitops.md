---
title: Configuring GitOps with Argo CD
tags: [cicd, kubernetes]
toc: true
toc_sticky: true
post_no: 18
---
In this post, I am going to share my experience of configuring *GitOps* for a continuous deployment process.
(FYI, you may refer to the following content for configuration, however, this is not a complete tutorial.)

## What is GitOps?
**GitOps** is a continuous deployment (CD) pattern in which a Git repository acts as the single source of truth (SSOT) for infrastructure configuration, particularly for cloud native applications.
The Git repository contains declarative descriptions of the desired state of the infrastructure, and a tool that supports GitOps automatically synchronizes the desired state in the target infrastructure.

As a result, you can leverage all powerful features of Git to administer the cluster.
For example, you can
- use Git pull requests to review
- use Git revert to rollback
- check the history of deployments (commits)
- plan branching strategies
- (you name it)

[**Argo CD**](https://argo-cd.readthedocs.io/en/stable/) is one such implementation of GitOps, specifically for Kubernetes.
It continuously monitors and compares resources in a kubernetes cluster (live state) and descriptions specified in the Git repository (desired target state).
Any observed deviation between two states is handled by Argo CD application controller automatically or manually.

## Context
The previous deployment workflow of our dev team was mostly carried out through [GitHub Actions](https://github.com/features/actions), a CI/CD platform provided by GitHub.
The workflow would be described as the following diagram:

![previous deployment workflow](/assets/images/18/previous_workflow.png)

To explain it in more detail,
1. a developer pushes a commit to the source code repository (app repo)
2. GitHub-hosted runner builds and pushes a new image to the container registry (Amazon ECR)
3. GitHub-hosted runner requests kubernetes to update image
4. kubernetes pulls the corresponding image from the container registry and updates the pods

The GitHub Actions workflow, a YAML file that defines the actual workflow, would look something like this:
```yaml
name: My Application
on:
  push:
    branches:
      - develop

jobs:
  test:
    name: Test the application
    uses: ./.github/workflows/test.yaml
  build:
    needs: test
    name: Build and push image to the container registry
    uses: ./.github/workflows/build.yaml
  update-image:
    needs: build
    name: Request to update image
    runs-on: ubuntu-latest
    steps:
      - name: Set up context
        uses: azure/kubernetes-set-context@v1
        with:
          method: kubeconfig
          kubeconfig: {% raw %}${{ secrets.kubeconfig }}{% endraw %}
      - name: Update image
        run: |
          kubectl set image deployments/my-application my-application={% raw %}${{ needs.build.outputs.image }}{% endraw %}
```

## Problem
Here are some of the problems or limitations of the previous approach:
- difficult to track changes in infrastructure
- difficult to recover from disasters
- difficult to migrate from one cluster to another
- difficult to keep manifests up to date

Some of the bullets are interrelated.
For example, even with the central place to store all manifests, having drifted manifests makes it hard to recover from disasters or migrate from one cluster to another because the manifests don't guarantee that they represent the latest live environment.

## Solution
### Overview
The following diagram describes the current deployment workflow using GitOps pattern:

![gitops workflow](/assets/images/18/gitops_workflow.png)

To explain it in more detail,
1. a developer pushes a commit to the source code repository (app repo)
2. GitHub-hosted runner builds and pushes a new image to the container registry (Amazon ECR)
3. GitHub-hosted runner updates manifests in a configuration repository (config repo)
4. ArgoCD application controller finds a deviation between two states (`OutOfSync`) and syncs the live state to the desired target state

Let me elaborate on the process of configuring GitOps.

### Configuration
1. Create a new GitHub repository named `manifests` - this is your *configuration repository*.
  In order to configure GitOps, you need a new repository to be the single source of your manifests.
2. Add manifests into the configuration repository.
  In this example, we add a manifest file for `Deployment` in `manifests/my-app/develop/deployment.yaml`.
  Make sure to add the latest manifests so that there is no discrepancy after moving to GitOps.
3. Install Argo CD in your kubernetes cluster.
  Refer to the [Argo CD documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/) and choose the best option of your needs.
4. Create Argo CD applications.
  You can create Argo CD applications by either using the web UI or applying a manifest of `Application` resource type.
  I recommend that you use and maintain manifests so as to recover from disasters, just in case.
  Our example application spec is as follows:
  ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: my-application
      namespace: argocd
      labels:
        env: develop
    spec:
      project: my-project
      source:
        repoURL: git@github.com:user/manifests.git
        targetRevision: develop
        path: my-app/develop
      destination:
        server: https://kubernetes.default.svc
        namespace: my-namespace
      syncPolicy:
        automated:
          prune: true
        syncOptions:
          - CreateNamespace=true
      revisionHistoryLimit: 10
  ```
  You can find the newly created `Application` in the Argo CD UI.
5. Modify GitHub Actions worfklow.
  ```yaml
    name: My Application
    on:
      push:
        branches:
          - develop

    jobs:
      test:
        name: Test the application
        uses: ./.github/workflows/test.yaml
      build:
        needs: test
        name: Build and push image to the container registry
        uses: ./.github/workflows/build.yaml
      update-manifest:
        needs: build
        name: Update manifest in the config repo
        runs-on: ubuntu-latest
        steps:
          - name: Authenticate to GitHub
            ...
          - name: git clone
            run: |
              git clone git@github.com:user/manifests.git
              cd manifests
          - name: Update manifest
            uses: mikefarah/yq@master
            with:
              cmd: |
                yq eval -i '.spec.template.spec.containers[0].image = "${{ needs.build.outputs.image }}"' manifests/my-app/develop/deployment.yaml
          - name: git push
            run: |
              cd manifests
              git config user.name "${{ github.actor }}"
              git config user.email "${{ github.actor }}@users.noreply.github.com"
              git commit -am "Update ${{ github.event.repository.name }}"
              git push origin main
  ```
  As you see in this example, we use `yq`, a portable CLI YAML processor, to modify manifests from GitHub Actions.
  Another option to achieve this is to use `kustomize`, which can also modify manifests by `kustomize edit set image` command.
  You can choose whatever is convenient for your experience.
6. Test.
  If everything is correctly set up, once you push a new commit to your app repo, Argo CD will find the change between app repo and config repo, and then automatically update the corresponding resource.
  You can also manually update the resource by clicking the `SYNC` button in the web UI:
  ![sync button on web UI](/assets/images/18/sync_button_on_web_ui.png)

The update might take some time as [the default polling interval is 3 minutes](https://argo-cd.readthedocs.io/en/stable/faq/#how-often-does-argo-cd-check-for-changes-to-my-git-or-helm-repository).
You can update this value by changing the `timeout.reconciliation` value in the `argocd-cm` config map.
{: .notice--info}

Note that although the example in this post is specific to a particular case as it only deploys `Deployment` and the process described is very simplified, you can integrate Argo CD into any other resources in your kubernetes cluster:
![Argo CD example](/assets/images/18/argocd_example.png)

## Trade-offs
Here are the key pros and cons of GitOps I feel worth to mention.

### Pros
- declarative:
  Declarative programming is concise, easy to understand and reuse.
- git features:
  You can leverage all features of Git with your choice of text editors or IDEs to administer you clusters from provisioning to auditing.
- visualization:
  Argo CD supports web UI that visualizes resources, status, and activity across your clusters.
- A single source of truth for cluster configurations:
  GitOps forces to maintain a single, central place to store configuration files, which gives a great benefit to maintainability.

### Cons
- initial cost to set up:
  The more dispersed your manifests across many repositories, the higher the initial configuration cost.
- additional complexity to CD pipeline:
  An added component (e.g. Argo CD server) is something that someone should maintain and to be educated to newcomers who are not familiar with GitOps.

## Conclusion
- GitOps is a workflow that uses Git repositories to provision and manage infrastructures in an infrastructure as code (IaC) way.
- You will likely to get many advantages if you can afford to pay the initial cost while you must evaluate the trade-offs depending on your organization's need before adopting GitOps.
- It is important to store all configuration files in a single repository, otherwise, dispersed configuration files result in high maintenance cost.
