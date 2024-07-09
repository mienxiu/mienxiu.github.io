---
title: Dependency Injection and Dependency Inversion
tags: [oop, python, refactoring]
toc: true
toc_sticky: true
post_no: 25
---
Dependency injection and dependency inversion are two terms that often come together but serve distinct meanings and purposes.

## Definitions
The following definitions are sourced from Wikipedia.

Dependency Injection:
> In software engineering, dependency injection is a programming technique in which an object or function receives other objects or functions that it requires, as opposed to creating them internally.
> Dependency injection aims to separate the concerns of constructing objects and using them, leading to loosely coupled programs.

Dependency inversion (often referred to as DIP):
> In object-oriented design, the dependency inversion principle is a specific methodology for loosely coupled software modules.
> When following this principle, the conventional dependency relationships established from high-level, policy-setting modules to low-level, dependency modules are reversed, thus rendering high-level modules independent of the low-level module implementation details.

While numerous articles delve into explaining the concepts of dependency injection and dependency inversion, many of them tend to feel abstract, employing placeholder names like `Foo` or `Bar` for example classes, or lacking relevant context.
Recognizing this gap, I aim to fill it by providing straightforward examples closely related to real-world scenarios.
In this post, we'll explore **what they are, why they matter, and how they are related**.
I hope that after reading this post, you'll grasp the definitions provided.

Let's start with the context.

## Context
Imagine an online flight booking application.
This app handles flight reservations and processes payments through PayPal, a digital payment platform.
The example code for this app contains two classes - `PaypalPaymentProcessor` and `FlightBookingProcessor`, each responsible for different parts of the payment process and reservation.
```python
class PaypalPaymentProcessor:
    """
    A class that handles payment processing via PayPal.
    """

    def process_payment(self, amount: float) -> dict:
        """
        Process a payment via PayPal.
        """
        url = "https://api-m.sandbox.paypal.com/v2/payments"
        res = requests.post(url, json={"transactions": {"amount": amount}})
        return res.json()
```
```python
class FlightBookingProcessor:
    """
    A class that books a flight.
    """
    def __init__(self):
        self.payment_processor = PaypalPaymentProcessor()

    def book_flight(self, amount: float):
        """
        Book a flight.
        """
        res = self.payment_processor.process_payment(amount)
```
For clarity, the implementation details are simplified here.
But in reality, the `process_payment` method would handle the intricacies of interfacing with PayPal's API, sending the necessary payment information, and processing the response accordingly.
The `book_flight` method would orchestrate the booking process, including handling payment transactions with the returned dictionary value of the `process_payment` method.
In practice, both classes are often maintained by dedicated developer teams to separate concerns, allowing for modular development and easier maintenance of the codebase.
We will assume such scenario.

Before diving deeper, let's take a moment and look at what "dependency" is.
In this context, the `FlightBookingProcessor` acts as the *dependent* or *client*, while the `PaypalPaymentProcessor` serves as a *dependency* of the `FlightBookingProcessor` class.
More specifically, the `PaypalPaymentProcessor` is an *implicit* dependency.

The following diagram describes the relationship between these two classes:
![The relationship without DI](/assets/posts/25/relationship_diagram_without_di.png)

Now, suppose the organization behind this app decides to expand its business to another region.
And due to specific requirements in that region, it is required to integrate `Stripe` as the payment platform.
As a user of the `FlightBookingProcessor` class, there is no way to use `Stripe` instead of `Paypal` since they have no control over the dependency.
More specifically, the instantiation of the `PaypalPaymentProcessor` is abstracted away from the user of the `FlightBookingProcessor` class as follows:
```python
flight_booking_processor = FlightBookingProcessor()
flight_booking_processor.book_flight(amount=800)
```
To satisfy such requirements without dependency injection, both dev teams of the `PaypalPaymentProcessor` and the `FlightBookingProcessor` should modify their components.
What does that mean?

Let's say the dev team of payment service creates a new class for its clients to use `Stripe` as follows:
```python
class StripePaymentProcessor:
    """
    A class that handles payment processing via Stripe.
    """

    def process_payment(self, amount: float) -> dict:
        """
        Process a payment via Stripe.
        """
        url = "https://api.stripe.com/v2/payments"
        body = {"amount": amount}
        res = requests.post(url, json=body)
        return res.json()
```
Creating a new `StripePaymentProcessor` class, which is independent fo the `PaypalPaymentProcessor` class, exemplifies the Single Responsibility Principle (SRP) by adhering to a clear and focused purpose for each class, which is great so far.

However, the existing design of the flight booking application lacks flexibility when integrating a new payment platform.
This rigidity arises from the direct instantiation of the `PaypalPaymentProcessor` within the `FlightBookingProcessor` class, which tightly couples these two classes together.

Without dependency injection, the developers of `FlightBookingProcessor` should modify their code as well, for example:
For example:
```python
class FlightBookingProcessor:
    """
    A class that books a flight.
    """
    def __init__(self, payment_platform: str):
        if payment_platform == "paypal":
            self.payment_processor = PaypalPaymentProcessor()
        elif payment_platform == "paypal":
            self.payment_processor = StripePaymentProcessor()

    def book_flight(self, amount: float, payment_platform):
        """
        Book a flight.
        """
        res = self.payment_processor.process_payment(amount)
```
In this version, the `FlightBookingProcessor` class uses a conditional to instantiate the appropriate payment processor based on the `payment_platform` parameter.
This way, users can select the desired payment platform:
```python
# Use Paypal as a payment platform.
flight_booking_processor = FlightBookingProcessor(payment_platform="paypal")
flight_booking_processor.book_flight(amount=800)

# Use Stripe as a payment platform.
flight_booking_processor = FlightBookingProcessor(payment_platform="stripe")
flight_booking_processor.book_flight(amount=800)
```

While this approach technically satisfies the requirements, it still has design limitations:
- It violates the Single Responsibility Principle (SRP), which advocates for classes to have only one reason to change.
In this case, the `FlightBookingProcessor` class is now responsible for both booking flights and selecting the appropriate payment platform based on a string parameter.
- This design increases the degree of coupling, as the `FlightBookingProcessor` class now has a new dependency.
- Introducing a new payment platform or modifying an existing one would require developers to update the conditional logic in the constructor of the `FlightBookingProcessor` class, resulting in increased development cost and reduced readability.
Such design can lead to poor extensibility.

This poses another problem in terms of testability.
Since the `FlightBookingProcessor` class directly instantiates the payment processor objects internally, any unit tests for the `book_flight` method would inherently rely on the functionality of the actual payment processors.
This introduces dependencies on external systems, making unit tests difficult to isolate and control.
Additionally, testing different scenarios, such as error handling or edge cases, becomes cumbersome with this design.

So, how can we improve the design to minimize coupling and enhance both maintainability and testability?

## Dependency Injection
With dependency injection, we can effectively decouple dependent (the `FlightBookingProcessor` class) from its dependencies (the `PaypalPaymentProcessor` class), enhancing flexibility and testability within our codebase.
There are mainly two methods in Python for applying dependency injection - constructor injection and method injection.

### Constructor injection
Constructor injection is considered as the most common form of dependency injection.

The code example demonstrating constructor injection is as follows:
```python
class FlightBookingProcessor:
    """
    A class that books a flight.
    """
    
    def __init__(self, payment_processor):
        self.payment_processor = payment_processor

    def book_flight(self, amount: float):
        """
        Book a flight.
        """
        res = self.payment_processor.process_payment(amount)
```
With this version, the `FlightBookingProcessor` class is provided the dependency through the constructor instead of internally instantiating it:
```python
# Instantiate dependency
paypal_payment_processor = PaypalPaymentProcessor()
# Inject dependency to constructor
flight_booking_processor =  FlightBookingProcessor(payment_processor)
flight_booking_processor.book_flight(800)
```

The advantage of this approach is that it forces the injection of necessary dependencies in order to create the client.
Once dependencies are injected via the constructor, they are typically immutable for the lifetime of the object.
This immutability can help enforce the principle of encapsulation and prevent unintended modifications to dependencies.

### Method injection
Method injection is another form of dependency injection.

The code example demonstrating method injection is as follows:
```python
class FlightBookingProcessor:
    """
    A class that books a flight.
    """

    def book_flight(self, amount: float, payment_processor):
        """
        Book a flight.
        """
        res = payment_processor.process_payment(amount)
```
With this version, the `FlightBookingProcessor` class is provided the dependency through the method instead of internally instantiating it:
```python
# Instantiate dependency
paypal_payment_processor = PaypalPaymentProcessor()
flight_booking_processor =  FlightBookingProcessor()
# Inject dependency to method
flight_booking_processor.book_flight(amount=800, payment_processor=payment_processor)
```

The advantage of this approach is that it supports dynamic dependency injection, allowing clients to use different dependencies at runtime.
This flexibility can be beneficial in scenarios where dependencies need to be varied dynamically.

In comparison between two methods, constructor injection offers advantages such as explicit dependency declaration and immutability of dependencies.
On the other hand, method injection provides dynamic dependency injection.
When it comes to the question of which choice is better, it indeed depends on the specific requirements and design of the project.
While I use both methods interchangeably, my personal preference is method injection as it allows for better flexibility in managing dependencies over the lifecycle of an object.

Either way, the point is that they all aim to make implicit dependencies *explicit*.

### Advantages
With dependency injection, users of the `FlightBookingProcessor` gain the flexibly to choose whichever payment platforms they need to use, as demonstrated below:
```python
paypal_payment_processor = PaypalPaymentProcessor()
flight_booking_processor =  FlightBookingProcessor(paypal_payment_processor)
flight_booking_processor.book_flight(amount=800)
```
```python
sripe_payment_processor = StripePaymentProcessor()
flight_booking_processor =  FlightBookingProcessor(sripe_payment_processor)
flight_booking_processor.book_flight(amount=800)
```

This approach enhances the flexibility and maintainability of your code.
Adding a new component no longer necessitate modifications in its dependent components, as seen in the example without dependency injection provided earlier.

Dependency injection also greatly improves testability.
By injecting dependencies, you can easily substitute real dependencies with mock objects or stubs during testing.
For example, you can create a mock payment processor for testing purposes as follows:
```python
mock_payment_processor = MockPaymentProcessor()
flight_booking_processor =  FlightBookingProcessor(mock_payment_processor)
flight_booking_processor.book_flight(amount=800)
```
This decouples the `FlightBookingProcessor` from the implementation details of its dependencies, which would have otherwise been tightly bound without dependency injection applied.
As a result, we can write more focused and resilient testing.

### Limitations
> Dependency injection is a means, not an end.
> -- <cite>Daniel Somerfield</cite>

In essence, dependency injection is simply a technique for providing a dependent object with the dependencies it requires to function.
However, dependency injection alone may still lack robustness in design if the dependent relies on concrete implementations rather than abstractions.

In the example above, even with dependency injection applied, the `FlightBookingProcessor` class still depends on concrete implementations like the `PaypalPaymentProcessor` class (or the `StripePaymentProcessor` class).
The relationship between `FlightBookingProcessor` and `PaypalPaymentProcessor` remains unchanged.
Specifically, the `FlightBookingProcessor` class relies on the `process_payment` method of its injected dependency and the value returned by that method.
As a result, any changes to these implementations could potentially break the code.

Let's see some potential issues, especially in dynamically typed languages like Python.

For instance, imagine a scenario where the `process_payment` method is changed, perhaps to return a string value instead of the dictionary as it previously did:
```python
class PaypalPaymentProcessor:
    """
    A class that handles payment processing via PayPal.
    """

    def process_payment(self, amount: float) -> str:
        """
        Process a payment via PayPal.
        """
        url = "https://api-m.sandbox.paypal.com/v2/payments"
        res = requests.post(url, json={"transactions": {"amount": amount}})
        return res.json()["payment_id"]
```
In this scenario, the code would break since the `FlightBookingProcessor` was designed to work with the dictionary value returned from the `process_payment` method.

Another flaw in this design emerges when injecting dependencies that the dependent is not compatible with.
Consider a scenario where you need to add another payment method, such as `SquarePaymentProcessor`.
If the developer of this new processor is ignorant of the contract between it and its dependent, they might inadvertently design it without the `process_payment` method, as demonstrated below:
```python
class SquarePaymentProcessor:
    """
    A class that handles payment processing.
    """

    def process(self, amount: float) -> dict:
        url = "https://connect.squareup.com/v2/payments"
        body = {"amount_money": amount}
        res = requests.post(url, json=body)
        return res.json()
```
In this case, the code would break when attempting to call `process_payment` on an instance of `SquarePaymentProcessor` because `FlightBookingProcessor` expects it to have a specific method, process_payment."

These issues highlight the drawback of strict dependence on concrete implementations when injecting dependencies.
To address these challenges, we need to invert the dependencies.

## Dependency Inversion
The dependency inversion principle (DIP), which is one of the [SOLID](https://en.wikipedia.org/wiki/SOLID) principles, encourages abstraction and decoupling by ensuring that high-level modules do not directly depend on low-level modules.
Instead, both should depend on abstractions.
To clarify, a high-level module is responsible for managing the primary logic or main use cases of an application, while a low-level module contains implementation details like API interactions or payment processing.

In our context, the high-level module refers to `FlightBookingProcessor` while the low-level module refers to `PaypalPaymentProcessor`.
With that in mind, let's refactor our example code to depend on abstractions rather than concrete implementation by creating an abstract base class for all payment processors:
```python
from abc import ABC, abstractmethod

class PaymentProcessor(ABC):
    """
    An abstract base class that defines the interface for payment processing.
    """

    @abstractmethod
    def process_payment(self, amount: float) -> dict:
        """
        Process a payment and return a response.
        :param amount: The amount to be processed
        :return: A response dict representing the outcome of the payment
        """
        ...
```
In the example, the `PaymentProcessor` class provides an abstraction that ensures any payment processing implementation must define the `process_payment` method.
This abstract class acts as the base class upon which various payment processor implementations can be built.

It's also a good practice to indicate abstract components.
One such way is using an `I` prefix in their names, such as `IPaymentProcessor`.
{: .notice--info}

Next, we implement specific payment processors that inherit from `PaymentProcessor` and provide their own concrete implementations of `process_payment`.
Here's how `PaypalPaymentProcessor` is implemented:
```python
class PaypalPaymentProcessor(PaymentProcesor):
    """
    A class that handles payment processing via PayPal.
    """

    def process_payment(self, amount: float) -> dict:
        """
        Process a payment via PayPal.
        """
        url = "https://api-m.sandbox.paypal.com/v2/payments"
        res = requests.post(url, json={"transactions": {"amount": amount}})
        return res.json()
```
You can apply he same method to `StripePaymentProcessor` and `SquarePaymentProcessor` as well:
```python
class StripePaymentProcessor(PaymentProcesor):
    ...
```
```python
class SquarePaymentProcessor(PaymentProcesor):
    ...
```

Lastly, refactor the `FlightBookingProcessor` class depend on the abstraction `PaymentProcessor` rather than the concrete `PaypalPaymentProcessor`:
```python
class FlightBookingProcessor:
    """
    A class that books a flight.
    """
    
    def __init__(self, payment_processor: PaymentProcessor):
        self.payment_processor = payment_processor

    def book_flight(self, amount: float):
        """
        Book a flight.
        """
        res = self.payment_processor.process_payment(amount)
```
By depending on the abstract `PaymentProcessor`, `FlightBookingProcessor` can now utilize any payment processor implementation as long as it adheres to the `PaymentProcessor` interface.
As a result, both `FlightBookingProcessor` and `PaypalPaymentProcessor` now depend on the abstraction `PaymentProcessor`:
![The relationship with DI](/assets/posts/25/relationship_diagram_with_di.png)

One might argue that abstractions can also change, potentially breaking their dependents.
That's correct.
If the abstractions need to change, the high-level modules should indeed change accordingly.
However, the rationale behind this rule is that the abstractions rarely change compared to the concrete implementations.
Moreover, this approach can force developers to carefully design abstractions, ensuring they are well-structured and extensible.
This is why adhering to abstractions provides more stability and flexibility in the long run.

> All in all, it is not mandatory to define the abstract base class, but it is desirable in order to achieve a cleaner design.
> -- <cite>Mariano Ayana, Clean Code in Python</cite>

## Conclusion (Final thoughts about DIP)
Dependency injection and dependency inversion are both useful guidelines in software design.
Nevertheless, I want to point out that we shouldn't be overly fixated on these principles.
In our example, creating abstractions for different payment processors seems like an obvious way to ensure stability and flexibility in our design.
But there are situations where a simpler solution will suffice, especially if it's intended for one-time use and may never require future modification.
That is, the overhead of implementing complex abstractions may outweigh the benefits.

One of my favorite design philosophies is 'Keep It Simple, Stupid' (KISS), which encourages developers to focus on clear, straightforward solutions that fulfill requirements without unnecessary complexity.
While this idea sounds easy to follow, I think it's more challenging to apply in practice than simply adhering to the design principles I've covered in this post.
I also believe that experienced developers are more likely to understand the value of KISS and know how to write simple yet maintainable code, as they've likely encountered numerous scenarios where simplicity triumphed over complexity.
Remember, regardless of the design principle, keeping your code simple and straightforward ensures maintainability and provides enough room for easy refactoring whenever necessary.
