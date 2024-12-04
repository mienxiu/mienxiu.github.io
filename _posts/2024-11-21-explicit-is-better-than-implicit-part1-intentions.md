---
title: "Explicit is Better than Implicit - Part 1: Intentions"
tags: [python, refactoring]
toc: true
toc_sticky: true
post_no: 30
---
"Explicit is better than implicit" is one of my favorite lines from [the Zen of Python](https://peps.python.org/pep-0020/).
In essence, this guiding principle encourages clarity in code by favoring straightforward and easily comprehensible designs over ones that are hidden or implied.

In this series, I'll explore why explicit designs matter, focusing on two dimensions: **intentions** and **behaviors**.

In [*Part 1: Intentions*](/explicit-is-better-than-implicit-part1-intentions), we'll discuss the downsides and potential risks of unclear intentions in code.
I will also illustrate how making intentions explicit not only enhances readability but also contributes to better reliability.

In [*Part 2: Behaviors*](/explicit-is-better-than-implicit-part2-behaviors), we'll discuss how implicit behaviors can lead to unexpected outcomes through some commonly used programming paradigms and techniques.
I will also focus on balancing implicit behavior with explicit clarity.

## Names
Naming in programming plays a fundamental role in making intentions clear.
Well-chosen names can make the intent and purpose of the code immediately understandable, reducing the cognitive load on developers.
Poor naming, on the other hand, can lead to confusion, errors, and increased time spent debugging or onboarding new team members.

Let's have a look at the code snippet with implicit function and variable names:
```python
def get_data(id: int) -> Product:
    ...
    return data

def calc(value: int, rate: float) -> float:
    return value * (1 - rate)

def process(id: int) -> float:
    data = get_data(id)
    rate = 0.2
    result = calc(data.price, rate)
    return result
```
At first glance, neither the variables nor the function names clearly convey their purpose.
For example, the function `calc()` is too vague—what exactly is being calculated?
Similarly, `process()` gives no hint of what kind of "processing" is happening.

This lack of clarity forces readers to spend extra time deciphering the intent of the code to understand what it actually does.
We might be able to infer that the `get_data` function retrieves product information by looking at its return type, which is a `Product` object.
But, what is the `rate` for?
Without additional context or documentation, the code leaves readers to make guesses at best.

However, we should note that guesswork is a dangerous practice in software development.
What if you assume the `rate` represents a discount rate, but it actually refers to a tax rate?
Such a misunderstanding could result in unexpected bugs.
To avoid these dangers, it's better to seek clarification or make the code more explicit rather than making guesses.

We can improve the code by using more descriptive function and variable names:
```python
def get_product(id: int) -> Product:
    ...
    return product

def calculate_discounted_price(original_price: int, discount_rate: float) -> float:
    return original_price * (1 - discount_rate)

def get_discounted_price(product_id: int) -> float:
    product = get_product(product_id)
    discount_rate = 0.2
    discounted_price = calculate_discounted_price(product.price, discount_rate)
    return discounted_price
```
Now, the intentions are made explicit.
Even someone unfamiliar with the code can understand what it does at a glance.
What's more valuable of this improvement is that **it eliminates the risk of guesswork for readers**.

### Abbreviations
Let's take another example that illustrates a different type of potential risk caused by the use of implicit names.

Consider this code snippet:
```python
# Get price
p = product["price"]

...

make_transaction(amount=p)
```
In this code, the product's price is stored in a variable named `p`, and a transaction is made further down the code using this variable.

Now, imagine that the program requirements change so that a reward point should be added to the user based on the product price.
A developer might implement this new requirement as follows, not knowing how `p` is used later in the code:
```python
# Get price
p = product["price"]

...

p = calculate_reward_point(product["price"])  # Accidentally reusing 'p'
user.reward_point += p  # Add reward point

...

make_transaction(amount=p)  # BUG: Make transaction with reward point, not price
```
In this modified version, `p` is accidentally overriden with the reward point instead of maintaining the product price.
As a result, the `make_transaction` function mistakenly uses the reward point in place of the actual price, causing a significant bug.

To avoid this issue, more descriptive and intentional naming could help clarify the purpose of each variable:
```python
# Get price
price = product["price"]

...

reward_point = calculate_reward_point(price)
user.reward_point += reward_point  # Add reward point

...

make_transaction(amount=price)
```
By using explicit names like `price` and `reward_point`, the code not only makes each variable's purpose clear, but also prevents accidental reuse or modification.

Excessive abbreviations also make developers hard to follow the code.
For instance, naming a variable for "creation datetime" as `crtndt` is not immediately understandable.
While *concise is better than verbose*, excessive abbreviations only distract and confuse readers.
A better choice would be `creation_datetime` (using snake_case, for example), which clearly conveys its meaning.

Here are some other examples:

|implicit|explicit(snake_case)|
|-|-|
|lctn|location|
|fxno|fax_number|
|rgstdt|registration_date|
|crno|corporate_registration_number|

Meanwhile, not all abbreviations need to be avoided.
For example, universally understood abbreviations like `url` for "Uniform Resource Locator" are perfectly fine.
These terms are widely recognized and also improve readability.

The principles we've discussed so far also apply to class names.

### Generic Terms
Naming classes with overly generic terms like `Service` or `Manager` can also be problematic.
It is often considered an anti-pattern for two main reasons:
- They don't provide enough information about what the class specifically does, making it harder for developers to understand its purpose at a glance.
- They are likely to have too many responsibilities (also called *god object*), leaving the code difficult to maintain, test, and extend.

To improve clarity and maintainability, it's better to distribute responsibilities across multiple, more focused classes and give them names that clearly reflect their intentions.
For example, a `TransactionService` class could be split into `TransactionProcessor`, `TransactionValidator`, and `TransactionLogger`.
This approach eliminates the ambiguity of the original class name, making the roles of the individual classes much more apparent and easier to work with.

Like so, coming up with specific names does more than just improve the readability of the code—it also enhances the overall design.

Distributing responsibilities across multiple classes is generally encouraged by so-called single responsibility principle (SRP).
This principle states that a software module (or class) should have only one responsibility.
For a deeper understanding about SRP, you may refer to [this post](/srp).
{: .notice--info}

### Tests
Naming test cases is an often-overlooked but critical aspect of writing maintainable and effective tests.

Consider the following example, where test cases are designed to validate a flight service:
```python
def test_flight0():
    ...

def test_flight2():
    ...

def test_flight1():
    ...
```
While it's evident that these tests are related to flights, the actual purpose of each test is hidden.
To understand what is being tested, you'd have to look into the implementation details of each test.
This lack of clarity can become a pain point when debugging or analyzing test results.

To make matters worse, depending on your testing framework, unclear names may lead to vague test results when something fails—unless verbose output is enabled.
For instance, consider the output when `test_flight1` fails:
```
FAILED test.py::test_flight1 - ...
```
This tells you almost nothing about what went wrong.
Was it a booking failure? A cancellation bug? Something else?

Here's an improved version with explicit naming:
```python
def test_book_flight():
    ...

def test_reschedule_flight():
    ...

def test_cancel_flight():
    ...
```
With these descriptive names, you know precisely what is being tested at a glance.
This clarity extends to test results as well.
For example, if the `test_cancel_flight` test fails, the output becomes self-explanatory:
```
FAILED test.py::test_cancel_flight - ...
```

## Parameters
Often, some functions demand complex objects as inputs when all they truly need are a few specific attributes or values.
This forces clients to provide overly detailed inputs, potentially leading to unnecessary coupling and bloated test setups.

Consider the following example:
```python
product = Product(
    id=1,
    original_price=1000,
    discount_rate=0.1,
    name="Apple",
    status="Available",
    main_image="https://example.com/",
    ...
)

def calculate_discounted_price(product: Product) -> float:
    return product.original_price * (1 - product.discount_rate)
```
Here, the `calculate_discounted_price` function takes an entire `Product` object as input, even though it only uses two attributes: `original_price` and `discount_rate`.

I have to say that this approach is not necessarily bad.

However, there are several benefits if we improve the code by explicitly specifying the required inputs like below:
```python
def calculate_discounted_price(original_price: int, discount_rate: float) -> float:
    return original_price * (1 - discount_rate)
```

First, testing becomes straightforward.
When the `calculate_discounted_price` function requires a `Product` object, you're forced to construct a `Product` object, which may include unnecessary fields or mocked data:
```python
product = Product(
    id=1,
    original_price=1000,
    discount_rate=0.1,
    # ... include just enough to prevent errors
)

assert calculate_discounted_price(product) == 900
```

But now, you no longer need to create a `Product` object to test the function, as the `calculate_discounted_price` now focuses on its own responsibility without depending on the `Product` object.
For example:
```python
assert calculate_discounted_price(original_price=1000, discount_rate=0.1) == 900
```

Also, this approach allows the same logic to be reused in different contexts.
For example, you can now apply the discount calculation to entirely different entities, like movie tickets:
```python
calculate_discounted_price(movie_ticket.original_price, movie_ticket.discount_rate)
```

Additionally, explicit parameters help make the function's intent clearer.
Anyone reading the code knows exactly what inputs are required, without having to dig into the `Product` class definition.

## Magic Numbers
In programming, magic numbers refer to numerical or text values with unexplained meaning or multiple occurrences.

Let's explore an example that illustrates the risks of magic numbers.
Consider this code snippet:
```python
# Calculate the future value of the investment
future_value = principal * (1 + 0.05) ** periods

# Calculate the Effective Annual Rate (EAR)
ear = (1 + 0.05 / periods) ** periods - 1
```
This code performs two calculations-the future value of the investment and the Effective Annual Rate (EAR).

What's not obvious is the value `0.05`, which, in fact, represents the interest rate.
Developers could reveal its meaning by having a closer look at the context, which is okay-ish.
However, there's still a room for human mistakes.
Imagine the interest rate changes to `0.04`.
A developer, tasked with updating the rate, might modify only the value in the `future_value` calculation, unaware that the same value is also used in the ear formula.
This oversight could lead to serious bugs because they might assume the two instances of `0.05` are unrelated.

The risk of errors introduced by magic numbers can be effectively handled by replacing them with meaningful constants.
Here's a more clarified version:
```python
INTEREST_RATE = 0.05

# Calculate the future value of the investment
future_value = principal * (1 + INTEREST_RATE) ** periods

# Calculate the Effective Annual Rate (EAR)    
ear = (1 + INTEREST_RATE / periods) ** periods - 1
```
In this version, the magic number `0.05` is replaced with a constant, `INTEREST_RATE`.
Now, anyone reading it immediately understands what the number represents, and making changes is centralized and straightforward.

Not all numbers in code are considered "magic."
In some contexts, numbers are universally understood and don't require further explanation.
Let's consider this example:
```python
if month == 1:
    ...
elif month == 2:
    ...
elif month == 3:
    ...
...
```
In this snippet, the numbers 1, 2, and 3 are used to represent months.
This is a standard convention, and most developers will instantly recognize their meaning (e.g., 1 for January, 2 for February, etc.).
In cases like this, the use of these numbers is justified and does not obscure the intent of the code.

Attempting to replace these values with constants might actually cause unnecessary verbosity:
```python
JANUARY = 1
FEBRUARY = 2
MARCH = 3
...

if month == JANUARY:
    ...
elif month == FEBRUARY:
    ...
elif month == MARCH:
    ...
...
```
While technically correct, this approach possibly degrade the overall readability of the codebase.

## Exceptions
Using overly generic exceptions for error handling can be problematic, as they hide the underlying cause of the issues for both developers and users.

Take this example:
```python
try:
    make_transaction(amount)
except Exception:
    raise Exception("An error occured.")
```
In this code, no matter what actually goes wrong, the error message will say "An error occurred.".

As a result, if the system encounters an issue, developers may spend more time debugging.
And users may struggle to understand what went wrong, making it difficult to take appropriate action.

To improve this, developers should catch specific exceptions and provide meaningful error messages that give both developers and users actionable information.
When doing so, consider the potential scenarios that could cause failure.
For instance, the `make_transaction` function might fail due to an invalid transaction amount, or a failure of an external payment service.
Here's an improved, more specified version:
```python
try:
    make_transaction(amount)
except ValueError as error:
    raise error("The transaction amount is invalid. Please pass a positive value.")
except ConnectionError as error:
    raise error("The payment service went wrong. Please try again later.")
```
With this approach, you make it easier to debug and provide a much better experience for users.

## Comments
Encouraging explicit intentions applies not only to code but also to comments.
Comments are particularly useful for explaining what isn't immediately obvious from the code.
However, vague or unclear comments don't offer much help to readers, often leaving them guessing about the code's purpose or functionality.

For instance:
```python
try:
    # Wait for 1 second.
    response = requests.get(url="https://example.com", timeout=1)
except requests.exceptions.Timeout as error:
    ...
```
This comment doesn't explain *why* we're waiting for 1 second, leaving readers with unanswered questions.
It might appear to be an arbitrary choice.

But what if, in reality, there was a Service Level Agreement (SLA) that mandates a specific timeout threshold?
Without this context, someone might later increase the timeout to 2 seconds, thinking, "1 second is too short" or "why not 2 seconds?".
This is a potential risk posed by lack of clarity about the intention.

Here's an improved, more explicit version:
```python
try:
    # Wait for 1 second at most to adhere to the SLA.
    response = requests.get(url="https://example.com", timeout=1)
except requests.exceptions.Timeout as error:
    ...
```
Providing this context helps prevent unintentional changes that could lead to violations of important requirements or expectations.

As a side note for this particular example, if it feels like a magic number, another option is to replace comment with a named constant like below:
```python
SLA_TIMEOUT = 1
try:
    response = requests.get(url="https://example.com", timeout=SLA_TIMEOUT)
except requests.exceptions.Timeout as error:
    ...
```
Both approaches make the intention more explicit.

Meanwhile, redundant comments can degrade the overall readability.
It's essential to strike a balance—write comments that add value by explaining why a piece of code exists or operates in a certain way, rather than stating the obvious.

## Conclusion
When intentions are not clear, it forces other developers and even the original author to spend extra time understanding, maintaining, or modifying the code.
Worse yet, it can lead developers to do guesswork, potentially introducing unintended bugs.
When intentions are explicit, on the other hand, it becomes easier for developers to understand the purpose behind the code and helps prevent unexpected errors.

Excessive explicitness can sometimes reduce readability rather than enhance it.
Therefore, being explicit means focusing on delivering the intention without overloading the reader.

When it comes to how explicit the code should be, it's helpful to remember that code you find clear might still seem implicit to others.
Just like good writers understand their audience, good developers who understand others' perspectives create better software.
