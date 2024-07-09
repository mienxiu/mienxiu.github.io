---
title: "Book Review: Code Simplicity by Max Kanat-Alexander"
tags: [review]
toc: true
toc_sticky: true
post_no: 26
---
[Code Simplicity by Max Kanat-Alexander](https://www.oreilly.com/library/view/code-simplicity/9781449314750/) is an ambitious effort to define a set of principles, rules, and laws for software development.
In my opinion, this is a bold attempt, considering that software development is too complex and dynamic to establish fixed rules and laws.
Yet, what Max tries to achieve is commendable and thought-provoking, as having general rules and laws could indeed help guide developers towards creating more maintainable and efficient code.

I actually read this book a year ago, and I have since tried to apply some of the rules and laws it presents.
Now, I think it's a good time to write a review.
This review will cover some topics I found particularly interesting and include some of my favorite quotes from the book.

## Good Programmers and Bad Programers
In "Code Simplicity", Max starts by distinguishing between good programmers and bad programmers:
> The difference between a bad programmer and a good programmer is *understanding*.
> That is, bad programmers don’t understand what they are doing, and good programmers do.

These two lines are the very first lines of the book.
While I am not entirely sure if I agree with the statement, as I believe there are many factors that define whether a programmer is good or bad, they remain the most memorable ones after reading the book.

Over the past year, I have deliberately tried to examine if I truly understand what I am doing in my work.
More specifically, I have tried to understand the problems I am solving and to consider alternative ways of addressing these problems with simpler designs.
This process of understanding undeniably helps in making better design decisions.

However, achieving simpler design cannot be accomplished solely by understanding one's own actions; it also requires a degree of comprehension of the trade-offs associated with various technologies and design methods.
This understanding allows for more informed and balanced decision-making.

I think the importance of understanding what I am doing extends beyond individual capability.
It enhances communication with colleagues, leading to improved productivity for the entire team, considering that software development is pretty much a team endeavor.

Here are some additional lines about good programmers and bad programmers:
> So, a "good programmer" should do everything in his power to make what he writes as simple as possible to other programmers.
> A good programmer creates things that are easy to understand, so that it’s really easy to shake out all the bugs.

> Programmers who don’t fully understand their work tend to develop complex systems.

If so, why should a good programmer prioritize simplicity?
To answer that, we need to understand the purpose of software and its nature stated in the book:
> The purpose of software is to help people.

> The longer your program exists, the more probable it is that any piece of it will have to change.

It is obvious that the more complex the system, the more difficult it becomes to make changes, and the higher the likelihood of bugs occurring.
A complex system with bugs and a rigid design can fail to meet user needs, become a burden for developers, and ultimately lead to its own obsolescence.
This is bad software that won't help people.

From all these rules and laws, we can deduce the following relationship:
```
bad programmer ~= complexity ~= bugs, cost ~= bad software ~= won't help people
```

Conversely, we can assert:
```
good programmer ~= simplicity ~= fewer bugs, less cost ~= good software ~= help people
```

Therefore, we conclude:
```
good programmer ~= help people
```

While I initially questioned my agreement with the opening statements of the book, I would highly agree with this equivalence.

Accordingly, I would redefine a good programmer as follows:
"A good programmer efficiently solves problems without needlessly complicating solutions."

I also want to note that a good programmer should balance input from others with their own understanding and judgment.
The following quotes emphasize the balance between collaboration and individual responsibility in decision-making within a team:
> A designer should always be willing to listen to suggestions and feedback, because programmers are usually smart people who have good ideas.
> But after considering all the data, *any given decision must be made by an individual, not by a group of people*.

I've had an experience where I prioritized major feedback over trusting my initial decision regarding my own task. (My design was simpler, so to speak.)
Later on, I confirmed my initial choice was indeed the better path forward, as those who initially offered contrary feedback eventually supported my decision after encountering a perplexing problem arising from unncessary complexity in the design.
It's not that those who offered feedback weren't good programmers, rather, it's just that I was the one responsible for the task and understood what I was doing the most.
After all, this aligns with a key qualitity of a good programmer: understanding.

## The Equation of Software Design
The following equation describes the desirability of a change:
```
D = (Vn + Vf) / (Ei + Em)
```
where each term stands for:
- `D`: the desirability of a change
- `Vn`: the value now
- `Vf`: the future value
- `Ei`: the effort of implementation
- `Em`: the effort of maintenance

Max especially points out the effect of effort of maintenance:
> It is more important to reduce the effort of maintenance than it is to reduce the effort of implementation.

This is because maintenance effort accumulates over the lifespan of a system, leading to significant long-term costs and potential complications, whereas implementation effort is a one-time cost.

Then how do we reduce the maintenance cost?
It all comes down to simplicity again.
Among all the terms in the equation above, what simplicity truly solves the most is the effort of maintenance (`Em`).
And this is why we should strive for simplicity in our code and system designs.

And we know the priority equation in terms of value and cost.
```
priority = value / cost
```

The following graph represents the priority equation with each value ranging from 0 to 10, for example:
![Feature request priority based on cost and value](/assets/posts/26/feature_request_priority_based_on_cost_and_value.png)

This is a fundamental concept for making strategic decisions in business and project management, which is very obvious.

The problem is that we sometimes fall into the mistake of spending higher effort for lower value.
This can happen when we prioritize tasks based on perceived urgency or complexity without a careful evaluation.
We all have such experiences where a task initially seemed complex, only to find that as we progressed, its actual complexity did not align with our initial perception.
The risk of misallocating priority due to misperceiving complexity would have been reduced if the design were simpler.

Then how do we measure the value of a change?
I think measuring the value of a change is relatively more difficult than measuring the cost of a change.
However, there are several ways to measure the value of a change:
- Key Performance Indicators (KPIs)
- User Feedback
- A/B Testing

These methods can provide insights into a change's value, helping to solve the priority equation effectively.

## Incremental Development and Design
> The most common and disastrous error that programmers make is predicting something about the future when in fact they cannot know.

Here are the three flaws that go against the principles of simplicity:
- YAGNI (You Aren't Gonna Need It)
    - Don’t write code until you actually need it, and remove any code that isn’t being used.
- Rigid design
    - Code should be designed based on what you know now, not on what you think will happen in the future.
- Overengineering
    - Be only as generic as you know you need to be right now.

These patterns all increase the probability of project failure in that they add "unnecessary" complexity, making the codebase harder to maintain, understand, and extend.

The "necessary" complexity is the inherent complexity that naturally arises from solving a given problem within its specific context and requirements.
It includes the essential features and logic needed to achieve the desired functionality without adding any superfluous elements.

Max presents "incremental development and design" as a way to avoid all three of these pitfalls.
It's about developing only essential features in a small and simple manner, and incrementally adding to them.
This approach is similar to the concept of MVP (Minimum Viable Product).

So, what exactly is developing only essential features bit by bit?
It can be understood by contrasting it with the opposite approach: speculative development.
It goes like this:

"Let's include this feature, and that feature might be necessary too, and in the future, it might evolve like this, so it would be good to develop this in advance, and having that would also be beneficial..."

From my experience, this is one of the most practical methods to avoid unnecessary complexity.
If you start by developing only the absolutely necessary features in a small and simple manner, even if it turns out that certain features are actually needed in the future, it won't be difficult to add them later.
In fact, modifying what you've already built at that time can incur much higher costs.

One point of contention I found in the book is Max's somewhat negative stance on rewriting programs to cope with complexity.
While he argues that rewriting programs is generally not advisable, in my experience, there have been times when rewriting has been successful.
With proper planning and strategy, this approach can be particularly useful in microservices architecture, where restructuring a service can be achieved without significant cost.

## How simple do we have to be?
> Stupid, Dumb Simple.

## Conclusion
I think any *designer* like me who appreciates the value of simplicity would empathize with many parts of this book.
While many things may just seem obvious, it was a good read to bolster the importance of simplicity through the experiences of one brilliant software architect.

![Book Cover](/assets/posts/26/book_cover.jpeg)
