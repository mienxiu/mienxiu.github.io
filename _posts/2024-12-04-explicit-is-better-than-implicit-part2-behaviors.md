---
title: "Explicit is Better than Implicit - Part 2: Behaviors"
tags: [python, refactoring, testing]
toc: true
toc_sticky: true
post_no: 31
---
"Explicit is better than implicit" is one of my favorite lines from [the Zen of Python](https://peps.python.org/pep-0020/).
In essence, this guiding principle encourages clarity in code by favoring straightforward and easily comprehensible designs over ones that are hidden or implied.

In this series, I'll explore why explicit designs matter, focusing on two dimensions: **intentions** and **behaviors**.

In [*Part 1: Intentions*](/explicit-is-better-than-implicit-part1-intentions), we'll discuss the downsides and potential risks of unclear intentions in code.
I will also illustrate how making intentions explicit not only enhances readability but also contributes to better reliability.

In [*Part 2: Behaviors*](/explicit-is-better-than-implicit-part2-behaviors), we'll discuss how implicit behaviors can lead to unexpected outcomes through some commonly used programming paradigms and techniques.
I will also focus on balancing implicit behavior with explicit clarity.

## Aspect-Oriented Programming
Aspect-Oriented Programming (AOP) is a programming paradigm that aims to increase modularity by allowing the separation of *cross-cutting concerns*.
Cross-cutting concerns are aspects of a program that affect multiple components, such as logging or security.
AOP achieves this by adding additional behavior (called *advice*) to existing code (called *join points*) without modifying the code itself, thereby promoting separation of concerns.
(I will clarify these terms with upcoming examples.)

While AOP offers ways to modularize concerns that span multiple parts of an application, it introduces implicit behaviors that can make the code harder to understand and maintain.

Python doesn't have native AOP support like some other languages (e.g., AspectJ for Java), but we can facilitate AOP-like behavior using decorators and other [metaprogramming](https://en.wikipedia.org/wiki/Metaprogramming) techniques.

### Python Decorators
Python decorators are a language feature.
It should not be confused with the decorator pattern from design patterns.
{: .notice--info}

Python decorators enable you to modify the behavior of functions or methods without changing their original code.
While they are a powerful and versatile feature, they have this one intrinsic downside: their underlying behavior is not immediately apparent to users.
Misuse or overuse of decorators can lead to unexpected outcomes.

Here's an example to illustrate the misuse of Python decorators.

Consider a scenario where a decorator is used to measure and log the execution time of functions:
```python
import time
from functools import wraps

def time_logger(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        result = func(*args, **kwargs)
        end_time = time.time()
        execution_time = end_time - start_time
        print(f"Function '{func.__name__}' executed in {execution_time:.4f} seconds")
        return result, execution_time  # Implicitly modifying the return value
    return wrapper

@time_logger
def make_transaction():
    ...  # Simulate a network call
    return {"data": "Sample data from {}".format(api_endpoint)}
```
Let me pause for a moment and clarify the terminology of AOP in this particular context:
- cross-cutting concern: performance logging
- advice: `time_logger`
- join point: `make_transaction`

While this seems useful, the decorator implicitly modifies the return value by returning a tuple `(result, execution_time)` instead of just `result`.
This implicit change can lead to unexpected behavior, especially if the caller of `make_transaction` does not anticipate the additional `execution_time` value.
It can also break existing code that relies on the original return structure.

A better way to create decorators is to avoid modifying the wrapped function's return value within decorators unless it's clear and expected:
```python
import time
from functools import wraps

def time_logger(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        result = func(*args, **kwargs)
        end_time = time.time()
        execution_time = end_time - start_time
        print(f"Function '{func.__name__}' executed in {execution_time:.4f} seconds")
        return result  # Return the original result without changing function's signature.
    return wrapper

@time_logger
def make_transaction(api_endpoint) -> dict:
    ...  # Simulate a network call
    return {"data": "Sample data from {}".format(api_endpoint)}
```

Another way to introduce confusion is through the use of *pointcuts*.
Consider the following example:
```python
def time_logger(func):
    function_prefix_to_log = "make"  # pointcut specification

    @wraps(func)
    def wrapper(*args, **kwargs):
        func_name: str = func.__name__
        if func_name.startswith(function_prefix_to_log):
            start_time = time.time()
            result = func(*args, **kwargs)
            end_time = time.time()
            execution_time = end_time - start_time
            print(f"Function '{func_name}' executed in {execution_time:.4f} seconds")
        else:
            result = func(*args, **kwargs)
        return result

    return wrapper
```
In this example, the `time_logger` decorator applies the advice only to functions whose names start with the `make` prefix.
The developer of it might have wanted to reduce noise in the logs or focus on a particular subset of functions.
For whatever reasons, such selective execution can lead to unintended omissions and debugging challenges.
For instance, adding this decorator to the function named `create_transaction` would not work as expected if a developer does not know its *control flow*.

This example is just to highlight the potential pitfalls of using pointcuts.
In my opinion, such selective modifications are generally only justifiable in specific scenarios, such as framework development, where the benefits of such mechanisms outweigh the risks.

Then, what about the overuse of decorators?

One of the main advantages of decorators is that they help solve the DRY (Don't Repeat Yourself) problem.
However, let's consider a scenario where reusability isn't a concern, and you create a decorator specifically for a single function.
Here's an example:
```python
from functools import wraps

def authenticate(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        user = kwargs.get('user')
        if not user or not user.is_authenticated:
            raise PermissionError("User is not authenticated")
        return func(*args, **kwargs)
    return wrapper

@authenticate
def fetch_user_data(user: User) -> dict[str, str]:
    return {"name": user.name, "email": user.email}
```
In the context of AOP:
- cross-cutting concern: security (or authentication)
- advice: `authenticate`
- join point: `fetch_user_data`

This approach not only makes the behavior implicit but also introduces redundancy into the code.

In some cases like this scenario, it may be better to write the code explicitly without using decorators:
```python
def fetch_user_data(user: User):
    if not user or not user.is_authenticated:
        raise PermissionError("User is not authenticated")
    return {"name": user.name, "email": user.email}
```
By making the authentication check explicit within the function, the behavior becomes transparent to anyone reading the code.
There's no hidden logic; everything the function does is laid out plainly.

Here are some simple guidelines to minimize the unintended outcomes when using Python decorators:
- KISS(Keep it simple, stupid). Limit what decorators do.
- Avoid changing the function signatures or the return value unless absolutely needed.
- Clearly document what the behavior of decorators. (Otherwise, the only information available to users for inferring the behavior is the decorator's name.)

### Metaclasses
Python Metaclasses allow you to customize class creation and behavior.
While they may be useful in some very special cases (which I don't really think there are), overusing metaclasses can lead to code that is hard to understand, debug, and maintain as they can introduce hidden behaviors and side effects that are not immediately apparent from the class definition itself.

One example we will look at here is implicitly adding attributes or methods:
```python
class MetaLogger(type):
    def __new__(cls, name, bases, attrs):
        attrs["log_level"] = "INFO"
        attrs["log"] = lambda self, message: print(f"[{self.log_level}] {message}")
        return super().__new__(cls, name, bases, attrs)

class LoggerBase(metaclass=MetaLogger):
    """Base class for all logging-related classes"""
    pass

class ConsoleLogger(LoggerBase):
    pass

class FileLogger(LoggerBase):
    pass
```
In the context of AOP:
- cross-cutting concern: logging behavior
- advice: `MetaLogger`
- join point: all classes of `LoggerBase`

The behavior of a specific logger is as follows:
```python
>>> console_logger = ConsoleLogger()
>>> print(console_logger.log_level)
INFO
>>> console_logger.log("This is a console log.")
[INFO] This is a console log.
```

One problem is that anyone looking at this `Logger` class cannot directly find the `log_level` attribute or the `log` method, as the class's behavior is not fully described within its own definition.

Another problem is that subclasses cannot modify the `log` method by defining it in the class body, leading to unexpected outcomes.
Let's say a developer wants to create a `ConsoleLogger` subclass with a different `log_level`, such as `DEBUG`
```python
class ConsoleLogger(LoggerBase):
    def log(self, message):
        print(f"{datetime.now()} [{self.log_level}] {message}")
```

However, due to the way the metaclass is implemented, the `log` is overwritten back to that added in the metaclass:
This behavior can confuse developers who assume that defining `log` method in the subclass will work as intended.

You might argue that this is purely the developer's fault; however, such implicit behavior introduced by metaclasses violates what's called *the principle of least astonishment*, as code should be explicit and predictable, enabling developers to understand its behavior without spending extra time learning the complexities of the metaclass implementation.

Another issue is that the code editor can't find its references.
(This has been confirmed in both VS Code and PyCharm at the time of writing this post.)

A better approach would be just using simple inheritance like below:
```python
class LoggerBase:
    def __init__(self):
        self.log_level = "INFO"

    def log(self, message):
        print(f"[{self.log_level}] {message}")

class ConsoleLogger(LoggerBase):
    pass

class FileLogger(LoggerBase):
    pass
```
With this approach, the code is simpler, more explicit, and easier to understand, while still providing the same functionality and flexibility as the metaclass approach.

As a side note, whenever tempted to use metaclasses, remember this:
> Metaclasses are deeper magic than 99% of users should ever worry about. If you wonder whether you need them, you don't
> -- <cite>Tim Peters</cite>

### Test Fixtures
A test fixture is a setup or environment created to ensure that tests run consistently and reliably.
It includes the necessary conditions, data, or objects required for testing, such as initializing databases, creating mock objects, or cleaning up resources after tests.

While test fixtures aren't directly related to AOP, both serve to modularize concerns.
If you're already thinking in AOP terms, you might see fixtures as a testing-specific AOP pattern for setup and teardown logic.

#### In-line Setup
The simplest and most explicit way to define test fixtures is through *in-line setup*.
Here's an example of using this approach:
```python
def test_get_user():
    # Setting up test fixtures
    db = create_database()
    db.add(User(email="test_user@example.com", username="test_user"))

    user = get_user(email="test_user@example.com")
    assert user.email == "test_user@example.com"
    assert user.username == "test_user"
    
    db.teardown()

def delete_user():
    db = create_database()
    db.add(User(email="test_user@example.com", username="test_user"))

    user = get_user(email="test_user@example.com")
    delete_user(user)
    user = get_user(email="test_user@example.com")
    assert user is None

    db.teardown()
```
While in-line setup is straightforward, it leads to repetitive boilerplate when multiple tests rely on the same text fixture.
Duplicating fixture code not only clutters the test suite but also complicates maintenance.
This is not AOP.

#### Delegate Setup
To address this in an AOP manner, we can extract the shared fixture logic into a reusable method and inject it into test functions.
This approach, known as *delegate setup*, is shown below using `pytest`:
```python
import pytest

@pytest.fixture
def setup():
    db = create_database()
    db.add(User(email="test_user@example.com", username="test_user"))
    yield  # Execute the test
    db.teardown()

def test_get_user(setup):
    user = get_user(email="test_user@example.com")
    assert user.email == "test_user@example.com"
    assert user.username == "test_user"

def delete_user(setup):
    user = get_user(email="test_user@example.com")
    delete_user(user)
    user = get_user(email="test_user@example.com")
    assert user is None
```
Here, the `setup` fixture manages the creation and teardown of resources.
While there's a slight reduction in explicitness—test, it efficiently eliminates duplication, making tests cleaner and easier to maintain.

#### Implicit Setup
You can go further streamline test fixtures by using *implicit setup*.
By enabling `autouse=True`, the fixture automatically applies to all tests without requiring explicit inclusion:
```python
import pytest

@pytest.fixture(autouse=True)
def setup():
    db = create_database()
    db.add(User(email="test_user@example.com", username="test_user"))
    yield  # Execute the test
    db.teardown()

def test_get_user():
    user = get_user(email="test_user@example.com")
    assert user.email == "test_user@example.com"
    assert user.username == "test_user"

def delete_user():
    user = get_user(email="test_user@example.com")
    delete_user(user)
    user = get_user(email="test_user@example.com")
    assert user is None
```
This approach completely hides the cross-cutting concerns in testing, which are database setup and teardown.
While this approach minimizes boilerplate, it introduces potential pitfalls.
The implicit nature of the setup can obscure dependencies, leading to unexpected behavior.
For instance, imagine a new test `test_create_user` is added like below:
```python
def create_user(email: str, username: str) -> User:
    if check_duplicate_email(email):
        raise DuplicateEmailError
    ...

def test_create_user():
    user = create_user(email="test_user@example.com", username="test_user")
    assert user.email == "test_user@example.com"
```
Because the `setup` fixture already populates the database with a user having the same email, this test will fail with `DuplicateEmailError`.
A developer unaware of the implicit setup might waste time diagnosing the issue.

Another subtle issue is that unintended executions of the `setup` code can degrade performance across large test suites, especially for tests that don't need these fixtures.

In scenarios like this, a balance between explicit and implicit behavior often delivers the best results.
In my view, the delegate setup effectively strikes this balance in most cases.

---

So far, we've explored examples such as Python decorators, metaclasses, and test fixtures to examine the risks of implicit behavior introduced by AOP.
Here are a couple of key takeaways:
- When the control flow is obscured, it becomes more difficult to understand the program and can lead to unintended behaviors.
- Since every aspect is tightly coupled with all of its join points in a program, any change to it can result in widespread program failures.

## Convention over Configuration
Convention over configuration, also known as coding by convention, is a design paradigm that minimizes number of explicit configurations developers need to make by providing sensible default behaviors or configurations.
This approach is especially prevalent in libraries and frameworks across various programming languages.
While it simplifies the development process and adheres to principles like DRY (Don't Repeat Yourself), it also introduces some pitfalls when implicit behaviors clash with developers' expectations.

### Convention-based ORM
As an example, I will use this particular web framework, [Django](https://www.djangoproject.com/).
Django supports database migrations for its object-relational mapping (ORM) models.
When defining models, Django provides two implicit default behaviors:
1. It adds an auto-incrementing primary key field (`id`) to every table unless explicitly overridden.
2. It implicitly names database tables based on the model class name unless explicitly specified.

The first behavior is sensible enough for most cases.
Most database tables require primary keys, and automating this process removes repetitive code.
For most developers, this default is convenient and intuitive.

The second behavior, however, can lead to challenges.
Consider the following model definition:
```python
from django.db import models

class ClassSchedule(models.Model):
    day = models.CharField(max_length=10)
    time = models.TimeField()
```
By default, this creates a table named `appname_classschedule`.
While functional, here are a few downsides:
- If your organization requires table names to be in plural forms (e.g., `class_schedules`), forgetting to explicitly override the default can result in inconsistency with the policy.
- The default name `classschedule` is not easily readable. A more appropriate name would be `class_schedule`.

To customize the table name, developers must explicitly define it in the model's `Meta` class:
```python
class ClassSchedule(models.Model):
    day = models.CharField(max_length=10)
    time = models.TimeField()

    class Meta:
        db_table = "class_schedule"
```
Although this approach resolves the issue, it adds a little complexity, especially for developers unaware of the default behavior.
Failing to address implicit naming conventions may lead to technical debt.

### External Dependencies
Another common use case of convention over configuration is the reliance on environment variables for managing application settings.
This method is particularly useful for handling sensitive data (e.g., passwords, tokens) or configuring external systems without hardcoding values.

Consider the example of the `boto3` library for interacting with AWS services:
```python
import boto3

s3_client = boto3.client(service_name="s3")
s3_client.upload_file(file_name, bucket, object_name)
```
`boto3`, by default, implicitly reads AWS credentials from environment variables (e.g., `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) unless they are specified in the code.
While this approach simplifies setup where these variables are pre-configured, it introduces this potential issue.
If incorrect values are passed through environment variables in production, the system may operate seemingly correctly but interact with unintended resources.
Such issues are often hard to detect and debug.

To reduce these risks, it's better to explicitly manage environment variables within the application.
For example:
```python
import os

import boto3

aws_access_key_id = os.getenv("AWS_ACCESS_KEY_ID")
aws_secret_access_key = os.getenv("AWS_SECRET_ACCESS_KEY")
region_name = os.getenv("AWS_DEFAULT_REGION")

s3_client = boto3.client(
    service_name="s3",
    aws_access_key_id=aws_access_key_id,
    aws_secret_access_key=aws_secret_access_key,
    region_name=region_name,
)
s3_client.upload_file(file_name, bucket, object_name)
```
With some added verbosity, the application explicitly declares its dependency on external configuration, improving clarity and maintainability.

## Multithreading
Multithreading is another example that leads to non-intuitive behaviors.
The most notable drawbacks is the occurrence of race conditions.
A race condition arises when multiple threads simultaneously access and modify shared data without proper synchronization.
Without proper synchronization, they often result in unpredictable and erroneous outcomes.

Here's an example of a simple banking application that lacks proper synchronization:
```python
from concurrent.futures import ThreadPoolExecutor
from time import sleep

class BankAccount:
    def __init__(self, balance=0):
        self.balance = balance

    def deposit(self, amount):
        temp = self.balance
        sleep(0.1)  # Simulate processing time
        self.balance = temp + amount
```
At first glance, this code looks straightforward.
However, when multiple threads execute the `deposit` method concurrently, they may interfere with each other.
Let's test this scenario:
```python
def perform_transactions(account):
    account.deposit(100)
account = BankAccount(100)
with ThreadPoolExecutor(max_workers=5) as executor:
    for _ in range(5):
        executor.submit(perform_transactions, account)
print(f"Final balance: {account.balance}")
```

Output:
```
Final balance: 200
```
Although the expected final balance is 600, the actual result is incorrect.
Worse yet, the output can vary with each execution.
This unpredictability arises because the way multithreading handles shared resources is hidden from the user.
In more complex systems, such nondeterministic behavior becomes even more problematic, making bugs harder to identify, reproduce, and fix.

To prevent race conditions, we must manage access to shared resources explicitly like below:
```python
from concurrent.futures import ThreadPoolExecutor
from threading import Lock
from time import sleep

class BankAccount:
    def __init__(self, balance=0):
        self.balance = balance
        self.lock = Lock()  # Explicit lock

    def deposit(self, amount):
        with self.lock:  # Explicitly acquire and release the lock
            temp = self.balance
            sleep(0.1)  # Simulate processing time
            self.balance = temp + amount
            print(f"Deposited {amount}, new balance: {self.balance}")
```
Here, the `Lock` object ensures that only one thread can execute the critical section of the `deposit` method at a time.
By explicitly controlling access, the final balance consistently matches expectations.

In the context of threads, explicit behaviors are related to sequential computation.
And the value of sequential computation is well described here:
> Threads discard the most essential and appealing properties of sequential computation: understandability, predictability, and determinism. Threads, as a model of computation, are wildly non-deterministic, and the job of the programmer becomes one of pruning that nondeterminism.
> -- <cite>Edward A. Lee</cite>

## Conclusion
Implicit behaviors often emerge as a result of specific design choices (e.g. AOP or CoC) we make to address larger problems (e.g. managing cross-cutting concerns or streamlining configurations).
When applied appropriately, they help reduce redundancy and simplify complex tasks.
However, they also bring costs, including:
- Obscured control flow, making it harder to trace program execution.
- Increased debugging complexity, as unintended side effects may be difficult to find.
- Steeper learning curves, as they often require an in-depth understanding of specific implementations or frameworks.

It's important to recognize that the costs of implicit behaviors can be higher than anticipated.
And, there might be many situations where making implicit behaviors explicit could effectively improve both the productivity and reliability of the code.
While implicit behaviors can help streamline development and abstract away some complexity, the value of explicitness should not be underestimated.

## References
- [Aspect-oriented programming](https://en.wikipedia.org/wiki/Aspect-oriented_programming)
- [Pointcut](https://en.wikipedia.org/wiki/Pointcut)
- [Metaclass](https://en.wikipedia.org/wiki/Metaclass)
- [Python Metaclasses](https://realpython.com/python-metaclasses/)
- [Principle of least astonishment](https://en.wikipedia.org/wiki/Principle_of_least_astonishment)
- [Test fixture](https://en.wikipedia.org/wiki/Test_fixture)
- [Convention over configuration](https://en.wikipedia.org/wiki/Convention_over_configuration)
- [The Problem with Threads - Edward A. Lee](https://www2.eecs.berkeley.edu/Pubs/TechRpts/2006/EECS-2006-1.pdf)
