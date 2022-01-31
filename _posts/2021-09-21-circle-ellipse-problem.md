---
title: Circle-ellipse Problem
tags: [OOP, python]
toc: true
toc_sticky: true
post_no: 6
featured: true
---
The **circle-ellipse problem**, or square–rectangle problem, illustrates a limitation of OOP (object-oriented programming).
Specifically, it violates the *Liskov substitution principle* (LSP) of the [SOLID](https://en.wikipedia.org/wiki/SOLID) principles.

I found this problem interesting when learning the SOLID principles and have commonly encountered it when doing OOP.
I'm not going to cover all principles in SOLID in this post.
But to better understand why this is a pitfall in object modelling, we first need to know what the LSP is.

## Liskov Substitution Principle
The Liskov Substitution Principle (LSP) was introduced by Barbara Liskov in 1987.
The formal definition of LSP is '*If S is a subtype of T, then objects of type T may be replaced with objects of type S*'.
I'd like to provide one more important statement to the definition - '*Each instance of a subclass is automatically an instance of superclass*` (Rumbaugh et al., 1991).
In other words, any objects should be replaceable with objects of their subtypes without compromising the expected behavior.

Look at the following code that violates the LSP:
```python
# bird_hunter.py
from random import random

class Bird:
    def __init__(self, name):
        self.name = name

    def fly(self) -> int:
        # Return the distance flown in meters.
        ...

class Sparrow(Bird):
    def fly(self) -> int:
        distance = 10
        return distance

class Magpie(Bird):
    def fly(self, destination: str) -> int:
        print(f"Flying to {destination}...")
        distance = 20
        return distance

class Ostrich(Bird):
    def fly(self):
        raise RuntimeError("Cannot fly.")

class BirdHunter:
    def __init__(self, accuracy: float = 0):
        self.accuracy = accuracy

    def shoot(self, bird: Bird):
        if random() < self.accuracy:
            print(f"Catched '{bird.name}'!")
        else:
            distance = bird.fly()
            print(f"'{bird.name}' has flown away {distance} meters!")
```
This code violates the LSP in two ways:
1. The signature of `fly` in `Magpie` takes a parameter.
2. The signature of `fly` in `Ostrich` does not return any integer value but always raises an exception.

Therefore, both `Magpie` and `Ostrich` are not replaceable with supertype `Bird`.
These violations break the program because `BirdHunter` does not expect the objects of `Bird` to behave differently from what's descibed in its signature (The type of the parameter `bird` of `shoot()` is hinted as `Bird`):
```python
>>> from bird_hunter import *
>>> hunter = BirdHunter()
>>> hunter.shoot(Sparrow('sparrow'))
'sparrow' has flown away 10 meters!
>>> hunter.shoot(Magpie('magpie'))
Traceback (most recent call last):
  ...
TypeError: fly() missing 1 required positional argument: 'destination'
>>> hunter.shoot(Ostrich('ostrich'))
Traceback (most recent call last):
  ...
RuntimeError: Cannot fly.
```
One possible way to follow the LSP would be defining a default value to `destination` and returning `0` to indicate that `Ostrich` can't fly:
```python
class Magpie(Bird):
    def fly(self, destination: str = "somewhere") -> int:
        print(f"Flying to {destination}...")
        distance = 20
        return distance

class Ostrich(Bird):
    def fly(self) -> int:
        return 0
```
This solution can safely preserve the properties of `Bird`, and any objects of `Bird` are now able to be replaced with objects of `Magpie` or `Ostrich`.

Another possible solution to the `Ostrich` problem in particular is extending the class hierarchy:
```python
class Bird:
    def __init__(self, name):
        self.name = name

class FlightedBird(Bird):
    def fly(self) -> int:
        ...

class FlightlessBird(Bird):
    ...

class Sparrow(FlightedBird):
    ...

class Magpie(FlightedBird):
    ...

class Ostrich(FlightlessBird):
    ...

class BirdHunter:
    ...
    def shoot(self, bird: FlightedBird):
        ...
```
Although this solution may require the orginal author of `Bird` to alter the class by removing `fly`, the LSP is put in place and the application can run without compromising the expected behavior.

In summary, the goal of the LSP is to preserve software reliability by correct subtype polymorphism.

## Circle-ellips Problem
Let's talk about the relationship between a circle and an ellipse.
Mathematically, a circle is a special case of an ellipse where the diameter in both the x and y direction are the same.
Therefore, the set of circles is a subset of the set of ellipses.
In other words, a circle **is an** ellipse, but not vice versa.
In terms of object-oriented modeling, `Circle` inherits from `Ellipse`.

Here's the implementation written in Python:
```python
from math import pi

class Ellipse:
    def __init__(self, x: float, y: float):
        self.x = x
        self.y = y
    
    @property
    def area(self) -> float:
        return pi * self.x * self.y

    def set_x(self, x: float):
        self.x = x
    
    def set_y(self, y: float):
        self.y = y

class Circle(Ellipse):
    ...
```
In this example, the super-class `Ellipse` defines two mutator methods, `set_x` and `set_y`.
The subclass `Circle` must also implement those methods to follow the LSP.

You might have already noticed the problem here.
If an object of `Circle` invokes any of the two mutator methods, it would be changed into something that is not a circle.
This mutated object is considered *illegal* because it does not represent the intended model.

Again, this problem illustrates a limitation of OOP.
And there are actually many cases in real world that are tricky to be defined in the object-oriented way.

Let's see some of the possible solutions to this problem.

## Possible Solutions
Note that the solutions listed below are solely based on OOP so that they require to change the model.
### Return the result
This solution requires that the mutator methods return the result of their operations.
The client can use this result and safely take follow-up measures.
```python
class Ellipse:
    ...
    def set_x(self, x: float) -> bool:
        self.x = x
        return True
        
class Circle(Ellipse):
    def set_x(self, x: float) -> bool:
        return False
```
### Raise an exception
This is an alternative and stricter solution to the above.
```python
class Circle(Ellipse):
    def set_x(self, x: float):
        raise CannotStretchError()
```
### Impose preconditions on modifiers
With defining a new property for preconditions, `stretchable` for example, the client can prepare for the exception in advance.
```python
class Ellipse:
    stretchable = True

    def __init__(self, x: float, y: float):
        self.x = x
        self.y = y

    @property
    def area(self) -> float:
        return pi * self.x * self.y

    def set_x(self, x: float):
        if not self.stretchable:
            raise CannotStretchError()
        self.x = x
    
    def set_y(self, y: float):
        if not self.stretchable:
            raise CannotStretchError()
        self.y = y

class Circle(Ellipse):
    stretchable = False
    ...
```
### Allow for a weaker contract on Ellipse
This solution modifies both `x` and `y` by weakening the contract for `Ellipse` that it allows other properties to be modified.
In other words, if the contract does not allow the changes to other properties, this is not an option.
```python
class Circle(Ellipse):
    def set_x(self, x: float):
        self.x = x
        self.y = x

    def set_y(self, y: float):
        self.x = y
        self.y = y
```
### Drop all inheritance relationships
I think this approach is somewhat radical yet powerful as it removes all the LSP constraints.
Any common interfaces can be defined into mixin classes.
```python
class AreaMixin:
    @property
    def area(self) -> float:
        return pi * self.x * self.y

class Ellipse(AreaMixin):
    ...

class Circle(AreaMixin):
    ...
```
### Inverse inheritance
This solution was proposed by Kazimir Majorinc in 1998.
The idea is to change the rules of inheritance as follows:
1. Selectors should be inherited from a superclass to a subclass automatically.
2. Assignors should be inherited from a subclass to a superclass automatically.
3. Modifiers and others can be inherited from any class that contains the same members.

Some programming languages that support multiple inheritance and abstract classes can also implement this model.
```python
from abc import ABC
from math import pi

class Data:
    def __init__(self, x: float, y: float):
        self.x = x
        self.y = y

class GetEllipse(ABC, Data):
    @property
    def area(self):
        return pi * self.x * self.y

class GetCircle(GetEllipse):
    @property
    def radius(self):
        return self.x

class SetCircle(ABC, Data):
    def set_radius(self, r: float):
        self.x = r
        self.y = r

class SetEllipse(SetCircle):
    def set_x(self, x: float):
        self.x = x

    def set_y(self, y: float):
        self.y = y

class Ellipse(SetEllipse, GetEllipse):
    ...

class Circle(SetCircle, GetCircle):
    ...
```

## Conclusion
* OOP, the most widely used programming paradigm, also has its own limitations and we need to be aware of it so as to cope with its pitfalls.
* When there are multiple options to a problem, we have to choose carefully which is the most suitable solution to that problem.

## References
* [Circle-ellipse problem from Wikipedia](https://en.wikipedia.org/wiki/Circle%E2%80%93ellipse_problem)
* [Ellipse-Circle dilemma and inverse inheritance by Kazimir Majorinc](https://kazimirmajorinc.com/Documents/1998,-Majorinc,-Ellipse-circle-dilemma-and-inverse-inheritance.pdf)