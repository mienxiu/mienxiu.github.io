---
title: Property Based Testing with Hypothesis
tags: [python, testing]
toc: true
toc_sticky: true
post_no: 20
---
## What is Property Based Testing?
*Property based testing*, which is known to be originated by [QuickCheck](https://en.wikipedia.org/wiki/QuickCheck), is a testing technique which randomly generates test cases for test suites to check that a program abides by its property.
(The randomization part seems somewhat debatable, yet that's what QuickCheck does and I assume that it is a core part of property based testing and greatly improves the efficacy of it.)

But what is "property"?
<!-- In mathematics, a property is any characteristic that applies to a given set. -->
In software engineering, a property of a software (or a function) is something that should always hold true for every pair of input and output.

*Fuzzing* is another term that is worth brief explanation when it comes to property based testing.
It is a testing technique that automatically generates a large number of invalid or random data as test inputs to SUTs.
This can be done by a component called a *fuzzer*.

One important distinction between property based testing and fuzzing (or fuzz testing) is the familiarity with their SUTs.
Fuzzers are basically not familiar with their SUTs and produce fairly all types of inputs to find any possible failures or crashes.
On the other hand, property based testing requires a more specific guidance on how to generate test cases so as to reduce the test run time compared to demanding fuzz testing.

With all that in mind, a property-based testing library is just a tool that facilitates making property-based tests using the fuzzer to randomly generate a specific range of test inputs.
*Hypothesis* is such implementation.

## Hypothesis
Hypothesis is a property-based testing library that helps you write property-based tests, as explained above.

The following snippet describes how it works in detail:
> It works by generating arbitrary data matching your specification and checking that your guarantee still holds in that case. If it finds an example where it doesn’t, it takes that example and cuts it down to size, simplifying it until it finds a much smaller example that still causes the problem. It then saves that example for later, so that once it has found a problem with your code it will not forget it in the future. ([Hypothesis docs](https://hypothesis.readthedocs.io/en/latest/))

We are going to absorb this description with an example.

### Example
Hypothesis can be installed with:
```sh
pip install hypothesis
```

The example code we will use is an implementation of Caesar Cipher:
```python
def encrypt(text: str, shift: int) -> str:
    result = ""
    for c in text:
        result += chr(ord(c) + shift)
    return result


def decrypt(text: str, shift: int) -> str:
    result = ""
    for c in text:
        result += chr(ord(c) - shift)
    return result
```

Without Hypothesis, you would write a unit test something like this:
```python
def test_caesar_cipher():
    plaintext = "smells like teen spirit"
    shift = 10
    assert decrypt(encrypt(plaintext, shift), shift) == plaintext
```

This test is what you think to be valid and will simply pass as expected and give you *false confidence* because our code actually has some edge cases as you will see in a moment.

With Hypothesis, here is how you would write a test for our example:
```python
from hypothesis import given, strategies as st


@given(plaintext=st.text(), shift=st.integers())
def test_caesar_cipher(plaintext, shift):
    assert decrypt(encrypt(plaintext, shift), shift) == plaintext
```

What's different from the previous unit test is that we use `@given` decorator and let it handle the test with its internal fuzzer.
We also give specific guidance on the types of the input arguments, `text()` and `integers()` respectively, and pass them into `@given` from `strategies`.
(The `@given` decorator doesn't really require keyword arguments, but I prefer providing with them to be more explicit.)

Let's run this test with `pytest`, one of the most general testing tools in the Python community:
```python
...

text = '0', shift = -49

    def encrypt(text: str, shift: int) -> str:
        result = ""
        for c in text:
>           result += chr(ord(c) + shift)
E           ValueError: chr() arg not in range(0x110000)
E           Falsifying example: test(
E               plaintext='0',
E               shift=-49,
E           )

...
```

What happened is that Hypothesis presents `0` and `-49` as an example that causes the error because the Unicode code point for `0` is 48 so you can't encrypt a character `0` with a left shift of 49.

Hypothesis knows that `-48` is the marginal value for `0` by cutting the example down to size.
Specifically, the `integers` function generates integer values which by default shrink towards zero.
Therefore, it does not show you just some random counter-examples such as `encrypt(text='hello', shift=-123)` but `encrypt(text='0', shift=-49)` as a much smaller example of invalid inputs, for the sake of simplicity.

Note that you can constrain the range of integers by passing the arguments like `integers(min_value=-48, max_value=99999)`.

In addition to displaying the simplest possible example to your tests, Hypothesis supports caching by using its example database to remember such information and reproduce it after fixing a bug, which can help you have higher confidence.
(By default, it creates a directory named `.hypotheis` in your current working directory, and stores information in `.hypothesis/examples`.)

### Supported Strategies
Other than `text` and `integers` in the previous example, Hypothesis provides a variety of strategies:
- `binary`
- `booleans`
- `datetimes`
- `floats`
- `lists`
- `randoms`
- `permutations`
- ...

For more information, refer to the page [What you can generate and how](https://hypothesis.readthedocs.io/en/latest/data.html).

Now that you know the basics of Hypothesis, let's see some of the examples where it can be of great help.
And we are also going to look at how some other functions of the `strategies` are used through the examples.

## Use Cases
### Inverse Function
The inverse function undoes the operation of the original function.

Here is an example that converts between `datetime` objects and strings:
```python
from datetime import datetime


def datetime_to_kor(datetime_obj: datetime) -> str:
    """Convert datetime object to Korean"""
    return datetime_obj.strftime("%Y년 %m월 %d일 %H시 %M분 %S.%f초")


def kor_to_datetime(datetime_str: str) -> datetime:
    """Convert Korean to datetime object"""
    return datetime.strptime(datetime_str, "%Y년 %m월 %d일 %I시 %M분 %S.%f초")
```

Without Hypothesis, you would write a unit test as follows:
```python
def test():
    datetime_obj = datetime(2023, 5, 24, 8, 30, 0)
    assert kor_to_datetime(datetime_to_kor(datetime_obj=datetime_obj)) == datetime_obj
```

This test finds no bug in the code.

With Hypothesis, we use the `datetimes` function to generate datetime objects:
```python
from datetime import datetime

from hypothesis import given, strategies as st


@given(datetime_obj=st.datetimes())
def test(datetime_obj: datetime):
    assert kor_to_datetime(datetime_to_kor(datetime_obj=datetime_obj)) == datetime_obj
```

This time, Hypothesis finds a bug and gives you an invalid example which you would not have thought of:
```python
...

>           raise ValueError("time data %r does not match format %r" %
                             (data_string, format))
E           ValueError: time data '2000년 01월 01일 00시 00분 00.000000초' does not match format '%Y년 %m월 %d일 %I시 %M분 %S.%f초'
E           Falsifying example: test(
E               datetime_obj=datetime.datetime(2000, 1, 1, 0, 0),
E           )

...
```

FYI, this bug is due to using different format codes to parse and format "hour" part - `%H` is 24-hour clock based and `%I` is 12-hour clock based.

Some other examples in this category are such as "serialize and deserialize" and "encode and decode".
Caesar cipher implementation, which we have already seen in the previous example, can also counts as inverse functions.

### Idempotence
> Idempotence is the property of certain operations in mathematics and computer science whereby they can be applied multiple times without changing the result beyond the initial application. ([wikipedia](https://en.wikipedia.org/wiki/Idempotence))

For example, a function that is idempotent is as follows:
```python
def remove_duplicates_and_sort(array: list[int]) -> list[int]:
    array = list(set(array))
    array.sort()
    return array
```

The function does two operations to an array of integers just as its name indicates what it does:
1. remove duplicates from the array
2. sort the array

And the output should be the same no matter how many times you apply this function.

With Hypothesis, you don't have to come up with input values to test this code.
We only use the `lists` function and pass the `integers` function as an argument for `elements` of `lists` to generate lists of integers:
```python
from hypothesis import given, strategies as st


@given(array=st.lists(elements=st.integers()))
def test(array: list[int]):
    # You may apply this function as many times as you want.
    assert (
        remove_duplicates_and_sort(array)
        == remove_duplicates_and_sort(remove_duplicates_and_sort(array))
        == remove_duplicates_and_sort(remove_duplicates_and_sort(remove_duplicates_and_sort(array)))
    )
```

This test will pass and we can be sure that the function abides by its property.

### Commutative Property
A function has a commutative property if the result remains the same even if the order of the operations change.

Let's see an example that is not commutative.
We change the order of the operations of `remove_duplicates_and_sort` in the previous example and name it `sort_and_remove_duplicates`:
```python
def sort_and_remove_duplicates(array: list[int]) -> list[int]:
    array.sort()
    array = list(set(array))
    return array
```

Here is a test for this code:
```python
from hypothesis import given, strategies as st


@given(array=st.lists(elements=st.integers()))
def test(array: list[int]):
    assert remove_duplicates_and_sort(array) == sort_and_remove_duplicates(array)
```

This test informs us that the result does not remain the same if we change the order of the function:
```python
...

array = [-1, 0]

    @given(array=st.lists(elements=st.integers()))
    def test(array: list[int]):
>       assert remove_duplicates_and_sort(array) == sort_and_remove_duplicates(array)
E       assert [-1, 0] == [0, -1]
E         At index 0 diff: -1 != 0
E         Use -v to get more diff
E       Falsifying example: test(
E           array=[0, -1],
E       )

...
```

It's because `set()` does not preserve the order.
To fix this function to satisfy commutative property, you may modify the code as follows:
```python
def remove_duplicates_and_sort(array: list[int]) -> list[int]:
    array = list(dict.fromkeys(array))
    array.sort()
    return array


def sort_and_remove_duplicates(array: list[int]) -> list[int]:
    array.sort()
    array = list(dict.fromkeys(array))
    return array
```

Now that it has become commutative, the test will pass.

---

There might be a lot more we can apply in practice.
I encourage you to discover more examples in your code where it can be applicable.

## Conclusion
Traditional example-based testing are not perfect as the process of writing test cases are all done by human.
You are likely to miss edge cases that will break your code even if you write the test for it.
Moreover, you often have to waste time worrying about how to provide inputs to thoroughly test your code.

With a property-based testing tool like Hypothesis, you can compensate for this limitation and improve not only your test coverage but also development productivity by letting a machine generate inputs.
