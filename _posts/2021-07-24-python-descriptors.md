---
title: Python Descriptors
tags: [python]
toc: true
toc_sticky: true
post_no: 5
---
A **descriptor** in Python is a class attribute which defines any of the special methods:
* `__get__(self, obj, owner=None) -> value`
* `__set__(self, obj, value) -> None`
* `__delete__(self, obj) -> None`

These methods are called *descriptor protocols*.
Descriptor protocols give an object the ability to override the default behavior upon being accessed as an attribute.

Well, the definition above is a bit unpleasant for first-timers to descriptors and there's actually a lot more behind it.
And I, not a first-timer, often forgot the exact usage just because I've rarely had to write descriptors myself.
With that being said, understanding descriptors can give you a deeper understanding of how Python works under the hood.
You will also notice that they are implemented in many widely used libraries and frameworks in Python, so if you are to develop a framework, descriptors should be a good skill to be equipped with.

I'm writing this post to summarize what I've obtained in order that anyone, including myself, can brush up on it at any time, and for first-timers to easily understand descriptors with simple examples.
I'm going to start with explaning what happens internally when an attribute is accessed.
This mechanism is important to know to understand the power of descriptors.

## Lookup chain
When an attribute is accessed with dot notation like `obj.attr`, the interpreter looks up the attribute in the following order:
1. Data descriptor
2. Instance dictionary
3. Non-data descriptor
4. Class dictionary
5. MRO

Let me elaborate it:
1. If there's any data descriptor named `attr`, its `__get__()` is called.
2. If there's no data descriptor, `obj.__dict__['attr']`, the value of instance dictionary, is returned.
3. If there's no `attr` in the instance dictionary, `__get__()` method of the non-data descriptor is called.
4. If there's no non-data descriptor, `type(obj).__dict__['attr']`, the value of class dictionary, is returned.
5. If there's no `attr` in the class dictionary, it looks up the attribute in the MRO([method resolution order](https://docs.python.org/3.9/glossary.html#term-method-resolution-order)) until `AttributeError` is raised:
    1. `type(obj).__base__.__dict__['attr']`
    2. `type(obj).__base__.__base__.__dict__['attr']`
    3. ...
    4. `AttributeError`

This is called the **lookup chain**. The key point to remember is that a data descriptor and a non-data descriptor are on different levels of the lookup chain.

The logic for this lookup chain is implemented in `__getattribute__()` method of an object.
Therefore, overriding `__getattribute__()` method can change the default lookup behavior.
{: .notice--info}

Let me first explain about instance and class dictionaries.

### Instance & class dictionaries
By default, any attribute that is defined in an object is stored in its object's dictionary which can be controlled via a built-in `__dict__` method.
Look at the following example:
```python
>>> class Example:
...     a = 1
...     def __init__(self, n):
...         self.b = n
...
>>> Example.__dict__['a']  # Get `a` from class dictionary.
1
>>> e = Example(2)
>>> e.__dict__['b']  # Get `b` from instance dictionary.
2
>>> e.__dict__['c'] = 3  # Set `c` into instance dictionary.
>>> e.__dict__
{'b': 2, 'c': 3}
>>> e.a
1
```
Note that `Example` has no descriptor in this code, thus setting a new attribute to an object is equivalent to storing an attribute to its *instance dictionary*.
In other words, `e.c = 3` is equivalent to `e.__dict__['c'] = 3`.
And calling `e.a` would find `a` in the *class dictionary* in the lookup chain since the object has no descriptor and `a` is not in the instance dictionary.

### Data descriptors
I mentioned about three descriptor protocols on the top of this page.
A data descriptor is just an object that implements `__set__()` or `__delete__()`.
Look at the following example:
```python
# data_desc.py
class Foo:
    def __get__(self, obj, owner=None):
        print("owner:", owner)
        return "bar"

    def __set__(eslf, obj, value):
        print("obj:", obj)
        print("value:", value)

    def __delete__(self, obj):
        print("self:", self)
        raise AttributeError("Cannot delete the value")
```
In this file, `Foo` defines both `__set__()` and `__delete__()`.
So, any class attribute of `Foo` is considered a data descriptor.

Let's examine how these methods are triggered with the interpreter.
First, I'm going to define a class named `Example` that has a data descriptor named `foo`, and instantiated an object of it:
```python
>>> from data_desc import Foo
>>> class Example:
...     foo = Foo()
...
>>> e = Example()
```
When you set a value to `foo`, `__set__()` is called:
```python
>>> e.foo = 'baz'
obj: <__main__.Example object at 0x10854b970>
value: baz
```
We can also notice that the argument named `obj` is an object that the `foo` was accessed through that is `e`, and `value` is just a value that is to set to `foo`.

Similarly, when you delete `foo`, `__delete__()` is called:
```python
>>> del e.foo
self: <data_desc.Foo object at 0x10854bb80>
Traceback (most recent call last):
  ...
AttributeError: Cannot delete the value
```
Because `AttributeError` is raised, deleting `foo` is not allowed in this case.

While `__get__()` is not a requirement for data descriptors, I defined it in `Foo` to demonstrate the following interesting behavior when accessing `e.foo`:
```python
>>> e.foo
owner: <class '__main__.Example'>
'bar'
```
What happens is that it calls `__get__()` as expected.
And `e.foo` returns `bar` even though we set `baz` to `e.foo`.
We can also see that `owner` is the type of `e`.
Remember that **data descriptors take priority over anything else in the lookup chain**, and we now understand what that means.

Overriding the default behavior of accessing an attribute in this way can be useful in some cases where it's tricky to implement the same behavior without data descriptors.
We'll see more about that in a moment.

### Non-data descriptors
A non-data descriptor is an object that only implements `__get__()`.
Loot at the following example:
```python
# nondata_desc.py
class Foo:
    def __get__(self, obj, owner=None):
        return "bar"
```
In this file, `Foo` only defines `__get__()`.
So, any class attribute of `Foo` is considered a non-data descriptor.

Once again, I define a class named `Example` that has a non-data descriptor named `foo`, and instantiated an object of it:
```python
>>> from nondata_desc import Foo
>>> class Example:
...     foo = Foo()
...
>>> e = Example()
```
This time, we will see how a non-data descriptor behaves differently from a data descriptor.
Here's what happens when you access `e.foo`:
```python
>>> e.foo
'bar'
```
Since `e` has no `foo` in its instance dictionary, `__get__()` method of `foo` is called because the non-data descriptor is the next namespace to look up after the instance dictionary.

Next, I'm going to set a new value to `e.foo` and then access it again:
```python
>>> e.foo = 'baz'
>>> e.foo
'baz'
```
`baz` is stored in `e.__dict__` and accessing `e.foo` returns `baz` from it without calling `__get__()`.
This is because `baz` was stored in the instance dictionary which takes priority over non-data descriptor of the lookup chain.

---

There's one more method that descriptors can have apart from the three descriptor protocols we've seen so far:
* `__set_name__(self, owner, name)`

This method is called at the time of the `owner` class is created.
Let's take a quick look at how it works:
```python
>>> class Foo:
...     def __set_name__(self, owner, name):
...         print("Setting the name:", name)
...         self.name = name
...     def __get__(self, obj, owner=None):
...         return obj.__dict__.get(self.name, 'bar')
...
>>> class Example:
...     foo = Foo()
...
Setting the name: foo
>>> e = Example()
>>> e.foo
'bar'
```
This is useful when you need to give a descriptor the name of class variable.

---

Here's what I've covered so far to understand what descriptors are:
* The lookup chain
* The descriptor protocols
* The difference between data descriptors and non-data descriptors

Now that we understand the concept of descriptors and their building blocks, let's see how they can be used from a practical perspective.

## Use cases
### Read-only attribute
It's one of the simplest use cases of descriptors.
Raising an `AttributeError` in `__set__()` makes a read-only data descriptor.
Here's an example:
```python
# car0.py
class Protected:
    def __set_name__(self, owner, name):
        self.name = name

    def __get__(self, obj, owner=None):
        return obj.__dict__.get(self.name)

    def __set__(self, obj, value):
        if obj.__dict__.get(self.name) is not None:
            raise AttributeError("Cannot set attribute")
        obj.__dict__[self.name] = value


class Car:
    body_style = Protected()

    def __init__(self, body_style: str):
        self.body_style = body_style

    def __repr__(self):
        return f"Body style: {self.body_style}"
```
Examine the code with the interpreter:
```python
>>> from car0 import Car
>>> car = Car('sedan')
>>> car
Body style: sedan
>>> car.body_style = 'suv'
Traceback (most recent call last):
  ...
AttributeError: Cannot set attribute
```
You can simply reuse `Protected` to other read-only attributes as well.

### Validator
You can implement custom validators using data descriptors.
For example, you can verify that a value to set is one of predefined options.
It's like an enum type, so to speak.
Take a look at the new version of `Car`:
```python
# car1.py
class Protected:
    def __set_name__(self, owner, name):
        self.name = name

    def __get__(self, obj, owner=None):
        return obj.__dict__.get(self.name)

    def __set__(self, obj, value):
        if obj.__dict__.get(self.name) is not None:
            raise AttributeError("Cannot set attribute")
        obj.__dict__[self.name] = value


class Enum:
    def __init__(self, *options):
        self.options = set(options)

    def __set_name__(self, owner, name):
        self.name = name

    def __get__(self, obj, owner=None):
        return obj.__dict__.get(self.name)

    def __set__(self, obj, value):
        if value not in self.options:
            raise ValueError(f"Invalid value (Not one of {self.options})")
        obj.__dict__[self.name] = value


class Car:
    body_style = Protected()
    color = Enum("white", "black", "blue")

    def __init__(self, body_style: str, color: str):
        self.body_style = body_style
        self.color = color

    def __repr__(self):
        return f"Body style: {self.body_style}, Color: {self.color}"
```
In the example above, `color` is a data descriptor that implements a validation logic in `__set__()` method.
The validation is run whenever you try to set a new value to the attribute.
Examine the validator with the interpreter:
```python
>>> from car1 import Car
>>> car = Car('sedan', 'white')
>>> car
Body style: sedan, Color: white
>>> car.color = 'black'
>>> car
Body style: sedan, Color: black
>>> car.color = 'red'
Traceback (most recent call last):
  ...
ValueError: Invalid value (Not one of {'white', 'black', 'blue'})
```
You can set `color` to `black`, but `red` is not allowed to set as it's not a valid option for `color`.

---

Meanwhile, we didn't need to explicitly pass the name of the attribute when the descriptors are initialized because `__set_name__()` handled it instead.
Otherwise, we would've had to write the code like this:
```python
class Protected:
    def __init__(self, name):
        self.name
    ...

class Enum:
    def __init__(self, name, *options):
        self.name = name
    ...

class Car:
    body_style = Protected("body_style")
    color = Enum("color", "white", "black", "blue")
    ...
```
This is redundant, especially when you need to reuse `Protected` or `Enum` to create other decriptors.

---

### Cached property
Using non-data descriptors, you can cache a result of the property that requires some heavy computations or I/O-bound tasks.
Here's a new version of `Car`:
```python
# car2.py
from time import sleep
from typing import Callable


class Protected:
    def __set_name__(self, owner, name):
        self.name = name

    def __get__(self, obj, owner=None):
        return obj.__dict__.get(self.name)

    def __set__(self, obj, value):
        if obj.__dict__.get(self.name) is not None:
            raise AttributeError("Cannot set attribute")
        obj.__dict__[self.name] = value


class Enum:
    def __init__(self, *options):
        self.options = set(options)

    def __set_name__(self, owner, name):
        self.name = name

    def __get__(self, obj, owner=None):
        return obj.__dict__.get(self.name)

    def __set__(self, obj, value):
        if value not in self.options:
            raise ValueError(f"Invalid value (Not one of {self.options})")
        obj.__dict__[self.name] = value


class CachedProperty:
    def __init__(self, function: Callable):
        self.function = function
        self.name = function.__name__

    def __get__(self, obj, owner=None):
        obj.__dict__[self.name] = self.function(obj)
        return obj.__dict__[self.name]


class Car:
    body_style = Protected()
    color = Enum("white", "black", "blue")

    def __init__(self, body_style: str, color: str):
        self.body_style = body_style
        self.color = color

    def __repr__(self):
        return f"Body style: {self.body_style}, Color: {self.color}"

    @CachedProperty
    def location(self) -> dict:
        print("Getting the location...")
        sleep(2)
        return {"lat": 37.392310, "lng": 126.639172}
```
In the example above, `CachedProperty` is used as a class decorator.
Take a look at how it works:
```python
>>> from car2 import Car
>>> car = Car('sedan', 'white')
>>> car.__dict__
{'body_style': 'suv', 'color': 'white'}
>>> car.location
Getting location...
{'lat': 37.39231, 'lng': 126.639172}
>>> car.__dict__
{'body_style': 'suv', 'color': 'white', 'location': {'lat': 37.39231, 'lng': 126.639172}}
>>> car.location
{'lat': 37.39231, 'lng': 126.639172}
```
The non-data descriptor of `CachedProperty` is initialized when `Car` is imported from the module `car2`.
A newly created object `car` has no `location` in its instance dictionary yet.
So, the first time `car.location` is invoked, `__get__()` method of the non-data descriptor is called since it's the next place to lookup after the instance dictionary.
It then retrieves the location and stores (or caches) the result into the instance dictionary.
The second time `car.location` is invoked, it directly returns `car.__dict__['location']` without having to retrieve the location again.

In fact, there's a built-in `functools.cached_property` that does the same as the example here.
The same code can be written as follows:
```python
from functools import cached_property

...

class Car:
    ...

    @cached_property
    def location(self) -> dict:
        print("Getting the location...")
        sleep(2)
        return {"lat": 37.392310, "lng": 126.639172}
```
`cached_property` is also implemented as a descriptor.
If you don't need some additional implementation of yours, this should suffice for this particular use case.

## In-depth understanding
From here on, I'm going to focus on Python's internals based on understanding of descriptors.
You will find out that descriptors are what methods and properties are built upon.

### Methods
Methods are different from functions in that they are bound to objects.
This is because functions in Python include a descriptor protocol `__get__()` that returns `MethodType()` like the following code:
```python
# A pure Python implementation of `types.MethodType`
class MethodType:
    "Emulate PyMethod_Type in Objects/classobject.c"
    def __init__(self, func, obj):
        self.__func__ = func
        self.__self__ = obj

    def __call__(self, *args, **kwargs):
        func = self.__func__
        obj = self.__self__
        return func(obj, *args, **kwargs)

class Function:
    ...
    def __get__(self, obj, objtype=None):
        "Simulate func_descr_get() in Objects/funcobject.c"
        if obj is None:
            return self  # Return function
        return MethodType(self, obj)  # Return method
```
That is, **methods are non-data descriptors**.

Let me elaborate it.
A function defined in a class is stored in the class dictionary as just a function not a method.
So, when this function is directly accessed from the class dictionary, it returns a regular function that is not bound to any object:
```python
>>> class Example:
...     def foo(self):
...         return "bar"
...
>>> Example.foo
<function Example.foo at 0x10d88f1f0>
```
But when it's accessed as an attribute of the object, it finds a non-data descriptor in the lookup chain and `__get__()` returns an object of `MethodType`:
```python
>>> e = Example()
>>> e.foo
<bound method Example.foo of <__main__.Example object at 0x107836340>>
```
This bound method, or an object of `MethodType`, has two attributes, `__func__` and `__self__`.
Considering what arguments passed to `MethodType`, these two statements turn out to be true:
```python
>>> e.foo.__func__ is Example.foo
True
>>> e.foo.__self__ is e
True
```
Note that `e.foo`, the non-data descriptor, is a callable object.
And what `e.foo()` does is that it returns a result of `e.foo.__func__` whose first argument is always `e.foo.__self__`.
Therefore, calling `e.foo()` is equivalent to calling `e.foo.__func__(e.foo.__self__)`:
```python
>>> e.foo.__func__(e.foo.__self__)
'bar'
```
This is how non-data descriptors turn functions into methods whose first argument `self` is indirectly reserved for the calling object.

### Static methods
Static methods return regular functions that are not bound to any object:
```python
>>> class Example:
...     @staticmethod
...     def foo():
...         return "bar"
... 
>>> e = Example()
>>> e.foo()
'bar'
```
Static methods are also non-data descriptors.
The following code is a pure Python of `staticmethod()`:
```python
class StaticMethod:
    "Emulate PyStaticMethod_Type() in Objects/funcobject.c"
    def __init__(self, f):
        self.f = f

    def __get__(self, obj, objtype=None):
        return self.f
```
As you see, it just returns the same underlying function when accessed as attributes.

### Class methods
Class methods return functions that are bound to the class:
```python
>>> class Example:
...     a = "bar"
...     @classmethod
...     def foo(cls):
...         return cls.a
... 
>>> Example.foo()
'bar'
>>> e = Example()
>>> e.foo()
'bar'
```
Class methods are also non-data descriptors, too.
The following code is a pure Python of `classmethod()`:
```python
class ClassMethod:
    "Emulate PyClassMethod_Type() in Objects/funcobject.c"
    def __init__(self, f):
        self.f = f

    def __get__(self, obj, cls=None):
        if cls is None:
            cls = type(obj)
        # Allow `classmethod()` to support chained decorators.
        if hasattr(type(self.f), '__get__'):
            return self.f.__get__(cls)
        return MethodType(self.f, cls)
```
`ClassMethod.__get__()` differs from `Function.__get__()` in that it passes `cls` instead of `obj`.

### Properties
Properties in Python are actually just descriptors.
The same descriptor of `body_style` in [the example above](#read-only-attribute) can be implemented as follows:
```python
class Car:
    def __init__(self, body_style: str):
        self._body_style = body_style

    @property
    def body_style(self):
        return self._body_style

    @body_style.setter
    def body_style(self, value):
        if self._body_style is not None:
            raise AttributeError("Cannot set attribute")
        self._body_style = value
```
Another way to write the same code is as follows:
```python
class Car:
    def __init__(self, body_style: str):
        self._body_style = body_style

    def getter(self):
        return self._body_style

    def setter(self, value):
        if self._body_style is not None:
            raise AttributeError("Cannot set attribute")
        self._body_style = value

    body_style = property(fget=getter, fset=setter)
```
The other descriptor protocols can also be replaced with the following ways:

|Descriptor protocols|Decorators|Parameters|
|-|-|-|
|`__get__()`|`getter`|`fget`|
|`__set__()`|`setter`|`fset`|
|`__delete__()`|`deleter`|`fdel`|

## Resources
* [Descriptor HowTo Guide](https://docs.python.org/3.9/howto/descriptor.html)
* [Implementing Descriptors](https://docs.python.org/3.9/reference/datamodel.html#implementing-descriptors)
* [Python Descriptors: An Introduction](https://realpython.com/python-descriptors/#why-use-python-descriptors)
