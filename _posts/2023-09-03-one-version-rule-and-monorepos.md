---
title: Explaining the One-Version Rule and Monorepos in the context of Microservices
tags: [microservices]
toc: true
toc_sticky: true
post_no: 21
featured: true
---
The organization I am currently working at develops applications built on microservice architecture, and we were trying to follow the internal policy that the source code for each microservice should be stored in its own repository.
As a result, there are hundreds of repositories with dozens of developers collaborating together, and the number of repositories continues to grow as the service evolves.

Here are a few pain points I have experienced while working in such environment:
- Distributed codebase:
    Even in a microservice architecture, many developers often need to work across multiple services.
    This can make development process and collaboration more complex and costly.
- Version management:
    As we use HTTP-based REST API as the primary means for interservice communication, we often version APIs to make changes without breaking existing clients.
    This ensures reliability, but the cost of maintaining different versions of the same service is high and increases as the number of versions grows.
- Different coding rules:
    Even when using the same programming language among different teams, different coding rules cause confusion for those involved in multiple services.
- Decentralized CI/CD:
    Since we have per-repository CI/CD pipelines, deploying a new service requires setting up a fresh CI/CD pipeline, or at the very least, duplicating an existing one.
    With GitOps, we also have to locate the appropriate repository and configure it to deploy the corresponding service.
- End-to-end testing:
    End-to-end testing is often performed manually, which is costly and does not scale well but could be significantly more cost-effective if automated.

As a solution for addressing these problems, we are in the middle of shifting from polyrepos to a monorepo, largely inspired by [the success of Google's monorepo approach](https://cacm.acm.org/magazines/2016/7/204032-why-google-stores-billions-of-lines-of-code-in-a-single-repository/fulltext).
While making this transition, I also became intrigued by the concept of the one-version rule.
Monorepos and the one-version rule are distinct concepts, however, they are closely related with each other in certain aspects.

This post is my attempt to explain the one-version rule and monorepos particularly in the context of microservices.

![three circle of one-Version rule, monorepo and microservices](/assets/images/21/three_circles.png)

## The One-Version Rule
The core idea of the "One-Version" rule is that:
> Developers must never have a choice of “What version of this component should I depend upon?"

The rationales behind this idea are the followings:
- Diamond dependency
- Maintenance

### Diamond Dependency
The biggest problem this rule addresses is the *diamond dependency problem*, especially in package management systems.
This problem occurs when multiple packages depend on different versions of a common package, resulting in conflicts.

Imagine a scenario where you're developing an application that depends on two packages, `package_a` and `package_b`, both of which have a dependency on a shared third-party package named `package_c`.

![diamond dependency - initial state](/assets/images/21/normal_state.png)

Now suppose that `package_c` releases a new version and `package_b` updates to use that new version of `package_c`, while `package_a` remains compatible only with the older version of `package_c`.
Here, you have a conflict as only one version of `package_c` can exist in the project.

![diamond dependency - broken state](/assets/images/21/broken_state.png)

{: .notice--info}
If you use package management system like [`pip`](https://pip.pypa.io/en/stable/), it would throw an error unless you let it automatically solve the dependency conflict.

Even if your project can accommodate both versions of `package_c`, it can still lead to unexpected behavior if you don't specify which version `package_a` should depend on.

With the one-version rule, `package_a` and `package_b` are forced to use the same version of `package_c`.
This resolves any potential conflicts and ensures that the dependencies are consistent throughout the entire dependency tree, avoiding [*dependency hell*](https://en.wikipedia.org/wiki/Dependency_hell).

In the context of microservices, while each service project can maintain its own isolated dependency tree separate from other projects, we can simplify the management of shared libraries among multiple services by adhering to the one-version rule.

### Maintenance
If a dependency is an internal package, having multiple available versions compels the team responsible for it to maintain multiple versions of the code, resulting in increased maintenance costs.

For instance, consider a scenario where you are in charge of an internal library that several other teams rely on.
You find the library's interface unsatisfactory and decide to make improvements, creating a new version to prevent compatibility issues.
While some teams swiftly update their projects to use the new version, others continue to use the old one because they are too busy to update ther code.
As time passes, with both versions in use for months, you find yourself incurring double the cost every time you encounter a bug or security issue, and so forth.

This includes not only maintaining the code but also updating documentation and writing tests.
Additionally, for new teams, the cost of deciding which version to use also matters.
(Renaming the package instead of creating a new version can prevent such confusion if you have no choice but have to fork a package to make some improvements and mix with the original one.)

With the one-version rule, developers can focus on *a single version of the truth*, resulting in a faster developmenet cycle.

In general, the one-version rule applies to package management systems.
However, in the context of microservices that use REST API as the primary means for interservice communication, this rule can go further and suggests that there should be only one version of a particular API at any given time.

From a practical point of view, sticking to a single version of an API may seem pedantic since maintaining strict backward compatibility introduces other challenging problems.
For example, any change in an API could enforce all the other services to update their versions in the codebase.
And we often want to make necessary changes or improvements that are not backward compatible without breaking the whole application.

We can mitigate such pain by having an exception plan that allows two versions for a temporary period for developers to transition to a new version.
Setting up a clear deadline for the removal of the old versions can be helpful to enforce migration in this scenario (aka compulsory deprecation).

If you push this rule to the extreme, it's even possible to not do API versioning at all.

![No API versioning](/assets/images/21/no_api_versioning.png)

While it seems somewhat radical, I could reinforce my thoughts after reading this [excellent article](https://devops.com/7-principles-for-using-microservices-to-build-an-api-that-lasts/).

> Versioning an API can also slow down development and testing, complicate monitoring and confuse user documentation.

In my view, it aims to address the exact same problems as the one-version rule.
By maintaining only a single endpoint of an API at any given time, we can achieve the same benefits as this rule offers with package management systems.

## Monorepos
A monorepo (short for "monolithic repository") is a single repository that contains the codebase for an entire application or system.
This includes all the services, packages or libraries, and components that make up the application.

![polyrepo and monorepo](/assets/images/21/polyrepo_and_monorepo.png)

The advantages of having a single central repository over having multiple fine-grained repos can be grouped into three categories:
- Development efficiency
- Collaboration and communication
- Larger testing (particularly in microservices)

### Development Efficiency
- Code sharing:
    By storing common dependencies such as packages or utilities that are shared across multiple services in the same repository, it helps to reduce code duplication and efficiently maintain consistency.
- Version management:
    Monorepos inherently make it easier to follow the one-version rule by providing a central location to handle dependencies and updates.
- Centralized CI/CD:
    By setting up CI/CD pipelines at the single repository level, you can save time and resources compared to managing distributed pipelines for each microservice.

### Collaboration and Communication
- Code visibility:
    Monorepos make it easier to review, debug, and search code of other services, which can lead to improved collaboration and knowledge sharing.
- Uniform coding rules:
    Enforcing consistent coding rules, such as formatting and style, across the services results in cleaner and more maintainable code.
    It can also lead to more debates among teams regarding better rules and guidance.

### Larger Testing
Coordinating larger tests is challenging particulary in microservices for its distributed nature.
Since the services interact with each other through APIs, end-to-end testing often involves deploying the real dependencies (or services).
This is not only complex and expensive but also prone to issues.
The complexity adds up if the services have different deployment environments and configurations.

In monorepos, larger tests become easier since deploying real services are simplified due to its centralized CI/CD pipeline and a shared codebase.

![End-to-end testing in monorepo](/assets/images/21/end_to_end_testing_in_monorepo.png)

However, monorepos come with the following disadvantages:
- Overhead:
    Potentially, increased size of a repository can make version control system slower.
- Security:
    Without some fine-grained access control mechanism, securing some top-secret projects might be challenging since everyone can see all the code of that organization.
- Merge conflicts:
    Because anyone can easily access and update the code, there's a higher chance of merge conflicts if there's no careful coordination between teams.

## Conclusion
The one-version rule improves maintainability by streamlining dependency management and the development process.
Sticking to the rule with some acceptable yet compulsory exception plans would help ensure long-term sustainability, even for microservice architecture.

I am still evaluating the trade-offs between monorepos and polyrepos.
However, for those who are not satisfied with "it-depends" kind-of sentences, here's my verdict so far:
you are likely to experience more benefits than drawbacks with a monorepo, regardless of the size of your organization unless you have problems with security requirements.

## References
- [Software Engineering at Google](https://www.oreilly.com/library/view/software-engineering-at/9781492082781/)
- [Why Google Stores Billions of Lines of Code in a Single Repository
](https://cacm.acm.org/magazines/2016/7/204032-why-google-stores-billions-of-lines-of-code-in-a-single-repository/fulltext)
- [The One Version Rule](https://opensource.google/documentation/reference/thirdparty/oneversion)
- [Versioning microservices in GitLab monorepos and polyrepos](https://avestura.dev/blog/versioning-microservices-projects)
- [7 Principles for Using Microservices to Build an API That Lasts
](https://devops.com/7-principles-for-using-microservices-to-build-an-api-that-lasts/)
