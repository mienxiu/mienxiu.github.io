---
title: Win 1st Place at AWS GameDay 2023 in Seoul
tags: [aws]
toc: true
toc_sticky: true
post_no: 19
---
On April 14, my teammates and I participated in AWS GameDay 2023 and took 1st place.
(team name: justintime [@buzzni](https://github.com/buzzni))

![GameDay awarding](/assets/images/19/awarding.jpg)

Meet our winners:
- [Mickey](https://github.com/mienxiu) (software engineer)
- James (data engineer)
- [Parker](https://github.com/Junryeol) (MLOps engineer)
- [Tony](https://github.com/cheyuni) (software engineer)
- [Charlie](https://github.com/eunchong) (software engineer)

## About AWS GameDay
> GameDay is a collaborative learning exercise that tests skills in implementing AWS solutions to solve real-world problems in a gamified, risk-free environment. This is a completely hands-on opportunity for technical professionals to explore AWS services, architecture patterns, best practices, and group cooperation. ([source](https://aws.amazon.com/gameday/))

![preview](/assets/images/19/preview.png)

Amazon created GameDay in the early 2000s and the events are held in many countries of the world today and participants come from various fields including software engineering, system administration, DevOps engineering, and more.

The purpose is to improve the capability of dealing with unexpected yet possible failures that can happen to cloud infrastructure.
This is also known as *chaos engineering*, a process to improve the system's resilience by continuously injecting an infrastructure level of faults into your system.

During the process, a tool for chaos engineering intentionally disables infrastructure components to simulate failures in the given system.
(Chaos Monkey is one such tool.)
The types of the faults may vary from instance shutdown to ground-level disruptions that affect the network.

The game starts with a scenario in which players are employees of an imaginary company named Unicorn Rentals and expected to maintain its infrastructure during the CTO's absence.

## Scoring
The goal was to serve incoming requests as reliable as possible with the minimum cost available.
That is, the more reliable we handle requests and the less cost we spend, the higher the score becomes.
And understandably, the trend can go negative if we use too much resources or fail too many requests.

![scoreboard](/assets/images/19/scoreboard.png)

Here are some of the checklist we, as Unicorn Rental's cloud administrators, constantly needed to monitor to maximize profit:
- Is service working normally?
- Are there any queued requests?
- Are there any idle resources?
- Is there any improvement we can make to better serve the requests?

After all, it all comes down to building teamwork to solve all of these problems simultaneously.

## Group Cooperation
One of the key success factors in the game is indeed teamwork.

![teamwork](/assets/images/19/teamwork.png)

At the beginning of the game, there were not much disruption.
But as time passes, the participants started to encounter situations where something has gone wrong.

We started to find the cause of the failure and gradually started to distribute the roles.

In order to quickly deal with failures and handle fluctuating requests in a more efficient way, we separated the responsibilities like the following:
- maintaining core infrastructure
- root cause analysis
- system monitoring
- service optimization

Each one of our team took one or two responsibilities with their own expertise so that we could collaboratively support each other in every corner.
This flexible cooperation helped us build a more resilient infrastructure while focusing on each role as much as possible.

I particularly took the responsibility of provisioning a fault-tolerant infrastructure from a multi-zone VPC to an Auto Scaling Group, and monitor if any failure or malicious attacks occur.
In addition to that, I also worked on disaster recovery plan for all resources in case of major outages.
In my case, familiarity with AWS CloudFormation was a huge help to satisfy my responsibilities.

When it comes to optimization, we could think of several approaches with a variety of AWS services.
But at the same time, we also had to weigh the trade-offs between the value and the cost and make a quick decision on which way we should go for in a limited amount of time.

---

AWS GameDay is all about real-world problem solving with teamwork.
It was fun and challenging.

I highly recommend you grap it if you ever get a chance to join AWS GameDay!

![award](/assets/images/19/award.png)

*This post is translated into Korean and republished on [buzzni's blog](https://buzzni.com/blog/363)*.
