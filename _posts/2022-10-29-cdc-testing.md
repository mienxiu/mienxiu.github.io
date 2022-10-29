---
title: Consumer-Driven Contract Testing with Pact
tags: [microservices, python, testing]
toc: true
toc_sticky: true
post_no: 14
featured: true
---
Consumer-driven contract testing (or CDC for short) is a testing methodology that ensures that providers are compatible with the expectations that the consumer has of them.

This testing approach is considered a good alternative to E2E(end-to-end) testing that is brittle, slow, and expensive, specially for microservice architecture where many components should be deployed for testing.

To get a better understanding of **what** it is and **why** to use it, we need to know about the limitations of traditional testing approaches when it comes to dealing with interservice (or interprocess) communications.
And then I'm going to show some examples with Pact, a testing tool for CDC testing, to demonstrate **how** it works.

## Limitations of Traditional Testing Approaches
Testing an application that is built on microservice architecture would require creating many test doubles or carrying out end-to-end testing by deploying other services that the SUT depends on as services are loosely-coupled in which they are distributed and can't be communicated within the same process.

### Unit Testing with Test Doubles
A *test double* is an object that simulates the behavior of the dependency.
It's the released-intended counterpart, so to speak.

Test stubs and mock objects are the types of test doubles.

![test doubles](/assets/images/14/test_doubles.png)

With test doubles, tests are easy to write and fast to execute, because there is no need to deploy the required dependency components.

The problem is that it does not guarantee that the test doubles act the same way the actual dependencies do, especially if the test writer is not responsible for maintaining the actual dependency projects.
In addition to that, there is no way to ensure that there is no breaking changes to the dependencies or the service under test itself in a way that breaks the application as a whole.

In the context of microservices, the more services, the less confident the tests become.

- pros
    - faster
    - simpler
    - more realiable
- cons
    - less confident (with more services)

### End-to-end (E2E) Testing
E2E testing is a higher-level approach that typically involves many integrations because all the components should be operational in order to simulate the actual user scenario from the end user's experience.

![end-to-end testing](/assets/images/14/e2e_testing.png)

E2E testing provides the highest confidence in the application.

The problem, on the other hand, is that E2E tests are hard to coordinate and maintain, not to mention its execution time due to the fact that it requies you to deploy all the services that you need to simulate the test scenario.
It is slower, more complex, and more brittle than than the lower-level tests such as unit tests.

For these reasons, it is often recommended that you write fewer E2E tests and invest in writing more lower-level tests.
The well-known test pyramid is a good representation of what's being said:

![test pyramid](/assets/images/14/test_pyramid.png)

In the context of microservices, the more services, the more expensive to write and execute tests.

- pros
    - higher confident
- cons
    - slower
    - more complex
    - more brittle

The following table is a summary of traditional testing approaches from cost and confidence perspective.

||unit testing|E2E testing|
|:-|:-:|:-:|
|cost|low|high|
|confidence|low|high|

In the end, these approaches have their own pros and cons, but none of them seems ideal to microservice architecture in particular.

## Consumer-Driven Contract Testing
Let me elaborate further on the definition on the top of this page:
>Consumer-driven contract testing (or CDC for short) is a testing methodology that ensures that providers are compatible with the expectations that the consumer has of them.

The idea is to use what's called a *contract* as sort of an agreement between a consumer and a provider, instead of actually running fully operational providers for integration testing.

### Terminology
- A *contract* is a generated document or a specification that the consumer and the provider should comply with.
    It may contain information such as who's the consumer, who's the provider, and what result the provider must provide.
- A *consumer* refers to a component under test.
    It can be a client that sends an HTTP request in a REST-based system or literally a consumer in an event-based system.
- A *provider* refers to a dependency component.
    It can be an API server in a REST-based system or literally a provider in an event-based system.
- A *broker* is a central place to store contracts and share them with all participants.

The broker here, in fact, is an optional component to implement the CDC testing.
More on that later.

## How it works
### Without a Broker
Knowing how it works without a broker helps understanding the underlying idea of CDC testing with a broker.

Let me simplify and explain the process in easy terms as much as possible to focus on the essential concept of this testing methodology.

![test without broker](/assets/images/14/test_without_broker.png)

1. The consumer-side dev team writes a test case using a provider mock.
    The provider mock is provided by the integrated CDC testing framework.
2. The test runs, a contract is automatically generated if there is none.
    Generating the contract (as a JSON-formatted file, for example) is done by the integrated CDC testing framework.
3. Share the contract with a provider.
    You may share the file on S3 bucket, or simply pass it to the provider's dev team.
4. The provider-side dev team writes a test case against the contract.
5. The test runs and replays the shared contract.
    If it fails, the dev team would know that the provider will break the application.

Two take-aways here are:
- The contract is initially generated by the consumer - it's consumer-driven.
- The contract acts as a specification document for both consumer and provider.

### With a Broker
The only difference is that you don't share the contract with provider but publish it to a broker.

![test with broker](/assets/images/14/test_with_broker.png)

Not only the broker acts as a central server to store and share contracts, it also further enhances the CDC testing compared to that without the broker.

For example, it allows you to:
- share the verification results
- automate CDC testing in your deployment pipepine
- automatically version-control the contracts
- visualize the interservice communications
- ...

## Advantages and Trade-offs
CDC testing with a broker can solve the [limitations of the traditional testing approaches](#limitations-of-traditional-testing-approaches) that we've already seen before in the following ways:
- Provide isolated testing environment which is reliable, fast, and easy to maintain.
- Prevent any breaking change if contract verification fails.

As a result, you can continously evolve your service knowing that it will give you immediate feedback if contracts are not met.
Plus, providers can know clear and minimal requirements that consumers expect, and they can change only when a change is asked by consumers.

What about trade-offs?
I want to point out a couple of things from a cost perspective:
- Set-up cost: the more services in your application, the higher the cost.
- Education: A proper education is required for members in your dev team specially if they are not familiar with CDC testing.

A summary table for three different testing methods is as follows:

||unit testing|E2E testing|CDC testing|
|:-|:-:|:-:|:-:|
|cost|low|high|medium|
|confidence|low|high|high|

Now you know how it works, what are the advantages of it, and also the trade-offs.

Next, I will demonstrate CDC testing with real-life examples using Pact.

## Pact
[Pact](https://pact.io/) is one of the most known automated consumer-driven contract testing tool created by Pact Foundation.

Pact provides great libraries that include everything you need to implement CDC testing in various programming languages.
They also provide a broker server named Pact Broker, an open source tool that is optimized for use with Pact.

In Pact, a contract is called a *pact*.
From now on, I might use two terms interchangeably.

You may read the [documentation](https://docs.pact.io/) for more details.

For a fully managed Pact Broker with additional features and scaling options, refer to [PactFlow](https://pactflow.io/) which is maintained by Pact Foundation.
{: .notice--info}

## Example
### Prerequisites
- A PostgreSQL database for a Pact Broker to use
- A Pact Broker
- A Kafka Broker for event-based communication

### Services
Suppose that we have two services for an E-commerce application:
- order service
- product service

The order service has the REST API that is responsible to accept requests to create orders from clients.

When creating an order:
1. It checks the quantity of the product by getting the product data
2. persists on a database
3. and produces an event to a topic named `order-created`.

The product service has the REST API too for providing product data to the order service, and an event handler - a consumer - to update the quantity of a product when a new order is created.

The sequence diagram below shows the process interactions between two services when a client places an order:

![sequence diagram for create_order](/assets/images/14/create_order.png)

Do note that in our context both services act as both consumer and provider.
The interactions are described as follows:

![consumer and provider](/assets/images/14/consumer_provider.png)

Next are the implementation details:
```python
"""Order's REST API"""

from typing import Optional
from uuid import uuid4
from os import getenv
import json

from fastapi import FastAPI, Body, HTTPException, status
from confluent_kafka import Producer
import requests

# Represent a database
orders = {}


class Settings:
    PRODUCT_API = "http://localhost:8001"
    KAFKA_BOOTSTRAP_SERVERS = "localhost:9092"


class TestSettings:
    PRODUCT_API = "http://localhost:1234"
    KAFKA_BOOTSTRAP_SERVERS = "localhost:9292"


settings = Settings()
if getenv("ENV") == "test":
    settings = TestSettings()


app = FastAPI()
producer = Producer({"bootstrap.servers": settings.KAFKA_BOOTSTRAP_SERVERS})


@app.post("/orders", status_code=status.HTTP_201_CREATED)
def create_order(*, product_id: int = Body(), quantity: int = Body()):
    product = get_product(product_id=product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Product not found.")
    if product["quantity"] < quantity:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Not enough quantity.")

    order_id = uuid4().hex  # Generate a random identifier for an order.
    orders[order_id] = {"product_id": product_id, "quantity": quantity}  # Persist to database

    produce_event(topic="order-created", key=str(order_id), value=orders[order_id])

    return {"id": order_id}


def get_product(product_id: int) -> Optional[dict]:
    res = requests.get(settings.PRODUCT_API + "/products/" + str(product_id), timeout=5)
    if not res.ok:
        return None
    return res.json()


def produce_event(topic: str, key: str, value: dict):
    producer.produce(topic=topic, key=key, value=json.dumps(value))
    producer.flush(timeout=5)

```
The instantiation of `settings` object depends on `ENV` environment variable to dynamically change configuration variables when testing.

The only parts of our concern are `get_product` and `produce_event` as they are the consumer and the provider to be unit tested.

And the followings are the provider-side code:
```python
"""Product's REST API"""

from fastapi import FastAPI, Path, HTTPException, status

# Represent a database
products = {
    1: {"id": 1, "name": "sweatshirt", "price": 100, "quantity": 10},
    2: {"id": 2, "name": "hoodie", "price": 120, "quantity": 0},
}

app = FastAPI()


@app.get("/products/{product_id}")
def get_product(*, product_id: int = Path()):
    product = products.get(product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found.")

    return products.get(product_id)

```
```python
"""Product's Event handler to update the quantity of a product"""

import json

from confluent_kafka import Consumer, Message

# Represent a database
products = products = {
    1: {"id": 1, "name": "sweatshirt", "price": 100, "quantity": 10},
    2: {"id": 2, "name": "hoodie", "price": 120, "quantity": 0},
}


conf = {
    "bootstrap.servers": "localhost:9092",
    "group.id": "update_quantity",
    "enable.auto.commit": False,
}

def update_quantity(product_id: int, quantity: int) -> bool:
    product = products.get(product_id)
    if not product:
        return False
    product["quantity"] -= quantity

def msg_process(msg: Message) -> bool:
    value = json.loads(msg.value())
    print(value)
    product_id = value["product_id"]
    quantity = value["quantity"]
    product = products.get(product_id)
    if not product:
        return False
    product["quantity"] -= quantity
    print(product)
    return True


def basic_consume_loop(consumer: Consumer, topics: list[str]):
    try:
        consumer.subscribe(topics)
        while True:
            msg = consumer.poll(timeout=1.0)
            if msg is None:
                continue
            msg_process(msg)
            consumer.commit()
    finally:
        consumer.close()


if __name__ == "__main__":
    basic_consume_loop(consumer=Consumer(conf), topics=["order-created"])

```
The product's event handler follows a typical kafka consumer implementation.

One more note is that the example here is merely for the demonstration of CDC testing so it won't share the product data between the API server and the event handler as it does not really use a persistent database.
You can simply ignore the database layer or modify the examples and try out your own implementations.

### Testing REST-based Interaction
The followings are the actual implementations of [how it works](#with-a-broker) part.
We first write a consumer-side test case to generate a pact, and then write a provider-side test case to verify the pact.
#### Consumer Side (Order)
Below is the test case for `get_product`:
```python
# test_get_product.py
import atexit

from pact import Consumer, Provider, Broker, Like
import pytest

from .api import get_product


@pytest.fixture(scope="session")
def pact() -> Consumer:
    provider = Provider(name="Product API")
    pact_ = Consumer(name="Order Service").has_pact_with(provider)
    pact_.start_service()
    atexit.register(pact_.stop_service)
    yield pact_
    pact_.stop_service()


@pytest.fixture(scope="session", autouse=True)
def publish_contracts():
    """Publish contracts to Pact Broker after testing."""
    broker_ = Broker(broker_base_url="http://localhost:9292")
    yield
    broker_.publish(
        consumer_name="Order Service",
        version="1.0.0",
        branch="develop",
        pact_dir=".",
    )


def test_get_product(pact: Consumer):
    expected = {"id": 1, "name": "sweatshirt", "price": 100, "quantity": 100}
    product_id = 1
    pact.given(provider_state="Product 1 exists").upon_receiving(
        scenario="a request for product 1"
    ).with_request(method="GET", path=f"/products/{product_id}").will_respond_with(
        status=200, body=Like(expected)
    )
    with pact:
        result = get_product(product_id=product_id)

    assert result == expected

```
A few notes to mention:
- Pact Broker is running locally on port 9292.
- `pact_dir` argument specifies a location to store pacts.
- `Like` is one of matching features provided by Pact.
    For example, a consumer would expect the `id` to be an integer variable and does not care if it's 1 or 2.
    `Like` only asserts the data.
    There are other matchers in Pact library.

<!--
At the time of writing this post, Python Pact library has an [issue](https://github.com/pact-foundation/pact-python/issues/308) in `matchers`.
For example, `{'id': Like(1)}` does not work correctly while `Like({'id': 1})` does.
-->

You can run the test using `pytest`:

```sh
ENV=test pytest test_get_product.py
```

What happened is as follows:
1. Pact mocks `get_product` with an expected result of:
    ```json
    {"id": 1, "name": "sweatshirt", "price": 100, "quantity": 100}
    ```
2. The test client sends a request to a provider mock and verifies the result with the expected one.
3. Once the test is passed, a contract is created as a JSON-formatted file at `pact_dir` location:
    ```json
    {
        "consumer": {
            "name": "Order Service"
        },
        "provider": {
            "name": "Product API"
        },
        "interactions": [
            {
                "description": "a request for product 1",
                "providerState": "Product 1 exists",
                "request": {
                    "method": "GET",
                    "path": "/products/1"
                },
                "response": {
                    "status": 200,
                    "headers": {},
                    "body": {
                        "id": 1,
                        "name": "sweatshirt",
                        "price": 100,
                        "quantity": 100
                    },
                    "matchingRules": {
                        "$.body": {
                            "match": "type"
                        }
                    }
                }
            }
        ],
        "metadata": {
            "pactSpecification": {
                "version": "2.0.0"
            }
        }
    }
    ```
4. Pact publishes the contract (pact) to the Pact Broker.

You can check out that a new pact is listed in the broker's web UI which can be accessed through [http://localhost:9292](http://localhost:9292) if you have run the broker locally on port 9292:

![web UI](/assets/images/14/pact0.png)

It also provides the detailed information about a pact:

![web UI](/assets/images/14/pact1.png)

#### Provider Side (Product)
There are two ways to run verifications on the provider side:
- Pact verifications API for programming languages
- Pact provider verifier CLI

Our example uses the first option - the Pact verifications API for Python.

A verification test for a provider is as follows:
```python
from pact import Verifier

verifier = Verifier(provider="Product API", provider_base_url="http://localhost:8000")
success, logs = verifier.verify_with_broker(
    broker_url="http://localhost:9292",
    publish_version="1.0.0",  # 
    publish_verification_results=True,
)

assert success is True

```
A few notes for the code:
- `provider_base_url` specifies the URL the verifier will request to.
- `publish_version` argument is Required if `publish_verification_results` is `True`.

In order to run the verification test, we have to not only use Pact verification API, but also have to deploy the service before that.

It might seem a little tricky but a following bash script is for that purpose:
```sh
# verify_pact.sh
# Run the app
uvicorn api:app & &>/dev/null
APP_PID=$!

function teardown {
    kill -9 $APP_PID
}
trap teardown EXIT

sleep 1 # second for the app to be ready.

echo 'Verifying the contracts against the Pact Broker...'
python verify_pact.py
if [ $? = 0 ]
then
    echo 'Verified!'
else
    echo 'Failed!'
fi
```
As commented in the script, all it does is that it first runs the app, (wait for a second), runs the verification test and closes the app process.

Run the script above:
```sh
$ ./verify_pact.sh
...
Verifying a pact between Order Service and Product API
  Given Product 1 exists
    a request for product 1
      with GET /products/1
        returns a response which
WARN: Skipping set up for provider state 'Product 1 exists' for consumer 'Order Service' as there is no --provider-states-setup-url specified.
INFO:     None:0 - "GET /products/1 HTTP/1.1" 200 OK
          has status code 200
          has a matching body

1 interaction, 0 failures
...
Verified!
```

Now you can see the updated status in the web UI:
![web UI](/assets/images/14/pact2.png)

What if the test fails?
You can simulate it by modifying our product API to return a string-typed of `id`:
```python
# Represent a database
products = {
    1: {"id": "somerandomstring", "name": "sweatshirt", "price": 100, "quantity": 10},
}
```

Running the test will cause an error and show the output below:
```
...
Failures:

  1) Verifying a pact between Order Service and Product API Given Product 1 exists a request for product 1 with GET /products/1 returns a response which has a matching body
     Failure/Error: expect(response_body).to match_term expected_response_body, diff_options, example

       Actual: {"id":"somerandomstring","name":"sweatshirt","price":100,"quantity":10}

       Diff
       --------------------------------------
       Key: - is expected 
            + is actual 
       Matching keys and values are not shown

        {
       -  "id": Fixnum
       +  "id": String
        }

       Description of differences
       --------------------------------------
       * Expected a Fixnum (like 1) but got a String ("somerandomstring") at $.id

1 interaction, 1 failure

Failed interactions:

PACT_DESCRIPTION='a request for product 1' PACT_PROVIDER_STATE='Product 1 exists' verify_pact.py # A request for product 1 given Product 1 exists

...
```

You can also see the verification status in the web UI:
![web UI](/assets/images/14/pact3.png)

A contract modification is essentially drived by its consumer.
For example, you would want additional information of a product like `seller_id`:
```python
# test_get_product.py
...

@pytest.fixture(scope="session", autouse=True)
def publish_contracts():
    """Publish contracts to Pact Broker after testing."""
    broker_ = Broker(broker_base_url="http://localhost:9292")
    yield
    broker_.publish(
        consumer_name="Order Service",
        version="1.1.0",
        branch="develop",
        pact_dir=".",
    )

def test_get_product(pact: Consumer):
    expected = {"id": 1, "name": "sweatshirt", "price": 100, "quantity": 100, "seller_id": 1}
    product_id = 1
    pact.given(provider_state="Product 1 exists").upon_receiving(
        scenario="a request for product 1"
    ).with_request(method="GET", path=f"/products/{product_id}").will_respond_with(
        status=200, body=Like(expected)
    )
    with pact:
        result = get_product(product_id=product_id)

    assert result == expected

```
Do note that `version` argument is updated from `1.0.0` to `1.1.0`.
Otherwise, Pact will not publish the contract due to a version conflict.

And the verification status becomes `changed`:

![web UI](/assets/images/14/pact4.png)

At this time, the same version of provider verifying the changed contract will get an error, which ideally should be known to the provider team:
```
Failures:

  1) Verifying a pact between Order Service and Product API Given Product 1 exists a request for product 1 with GET /products/1 returns a response which has a matching body
     Failure/Error: expect(response_body).to match_term expected_response_body, diff_options, example

       Actual: {"id":1,"name":"sweatshirt","price":100,"quantity":10}

       Diff
       --------------------------------------
       Key: - is expected 
            + is actual 
       Matching keys and values are not shown

        {
       -  "seller_id": Fixnum
        }

       Description of differences
       --------------------------------------
       * Could not find key "seller_id" (keys present are: id, name, price, quantity) at $

1 interaction, 1 failure
```

### Testing Event-based Interaction
Testing event-based interaction is a lot similar to testing REST-based interaction except that it uses different modules - `MessageConsumer` and `MessageProvider`.
#### Consumer Side (Product)
```python
# test_update_quantity.py
import json

import pytest
from pact import MessageConsumer, Provider
from pact.matchers import Matcher

from .consumer import msg_process as update_quantity


class MockMessage(Matcher):
    """Mock kafka message"""

    def __init__(self, key: str, value: str):
        self._key = key
        self._value = value

    def key(self) -> bytes:
        return self._key.encode()

    def value(self) -> bytes:
        return self._value.encode()

    def generate(self) -> dict:  # For Pact to verify
        return {"key": self._key, "value": json.loads(self._value)}


@pytest.fixture(scope="session")
def pact() -> MessageConsumer:
    pact = MessageConsumer("Product Event Handler", version="1.0.0").has_pact_with(
        Provider("Order Service"),
        publish_to_broker=True,
        broker_base_url="http://localhost:9292",
        pact_dir=".",
    )
    yield pact


def test_update_quantity(pact: MessageConsumer):
    expected_event = MockMessage(key="1", value=json.dumps({"product_id": 1, "quantity": 10}))
    pact.given("An order is created").expects_to_receive("Order data").with_content(expected_event)
    with pact:
        update_quantity(expected_event)

    assert True

```

You can execute the consumer test by running:

```sh
pytest test_update_quantity.py
```

A new pact is listed on Pacts in Pact Broker's web UI:

![web UI](/assets/images/14/pact5.png)

#### Provider Side (Order)
```python
# test_provider.py
from pact import MessageProvider


def order_created_handler() -> dict:
    return {"key": "1", "value": {"product_id": 1, "quantity": 10}}


def test_verify_from_broker():
    provider = MessageProvider(
        message_providers={"An order is created": order_created_handler},
        provider="Order Service",
        consumer="Product Event Handler",
        pact_dir=".",
    )
    with provider:
        provider.verify_with_broker(
            broker_url="http://localhost:9292",
            publish_version="1.0.0",
            publish_verification_results=True,
        )

```

You can execute the provider test by running:

```sh
pytest test_provider.py
```

And the verification result is updated in Pact Broker:

![web UI](/assets/images/14/pact6.png)

One important note is that the name of the handler `An order is created` must be the same as the parameter of `pact.given()` in the consumer-side test case.

The demonstration in this post only explains the basic usage of Pact.
In production, you may have to set your own branching and versioning strategy depending on the development environment of your organization.

## Conclusion
CDC testing is suitable for microservices where multiple components should communicate with each other.
The more services, the more CDC testing shines.

It also encourages communication between consumer and provider developers when developing contract testing.

Last but not least, CDC testing does not, and cannot replace the other testing methodologies, and it should just focus on ensuring the interactions between consumers and providers.
If you need to test particular business logic then you should choose other proper methods to focus on that particular problem.
