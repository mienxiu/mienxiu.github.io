---
title: Operating System Overview
tags: [os]
toc: true
toc_sticky: true
post_no: 8
---
## Definition
An operating system, or OS, is just a software that abstracts and arbitrates the underlying hardware components in computer systems.

![os-definition](/assets/images/8-os-overview0.png)

In temrs of "abstracts", the OS hides the hardware complexity from the applications.
It means that, for example, the application developers don't have to worry about disk sectors or blocks to write a file to a disk, or composing packets to use network devices to send HTTP responses to clients for a web server application.

In terms of "arbitrates", the OS manages the hardware resources on behalf of the running applications or processes.
It means that the OS controls and allocates all types of resources for each application to use.
For example, it ensures that multiple applications on the same hardware do not access each other's memory space.

## OS Elements
An operating system supports some higher-level **abstractions** and **mechanims** to achieve its goal:

|type|abstractions|mechanisms|
|--|--|--|
|applications|process, thread|create, schedule|
|hardware|file, socket, memory page|open, write, allocate|

and some **policies**:
* least-recently used (LRU)
* earliest deadline first (EDF)
* random

For example, the OS can allow a **process** to access the physical memory by **allocating** a **memory page** in some addressable region of DRAM of some fixed size and **mapping** that page into the address piece of that process. And it **swaps** the page to disk based on **LRU** algorithm when it needs more memory for some other content.

![os-elements](/assets/images/8-os-overview1.png)

## Protection Boundary
To protect any application from directly accessing to the hardware resources, most modern hardware platforms support two modes:
* user mode (unprivileged)
* kernel mode (privileged)

![system-call](/assets/images/8-os-overview2.png)

Because hardware access can be performed only from kernel mode by the OS kernel, attempts to perform privileged operations from applications in user mode will cause a **trap**:
1. The application causes a trap and is interrupted.
2. The hardware will switch the control to the OS.
3. The OS decides if it should grant the access or terminate that illegal process.

Otherwise, the applications can make **system calls** when it needs some hardware access:
1. The application makes a system call.
2. Control is passed to the OS in kernel mode.
3. The OS executes the requested operation on behalf of the application and returns the results to the process.

Some examples of system calls are:
* open (file)
* send (socket)
* malloc (memory)

This user/kernel transition or context switch is not cheap as it takes a number of instructions and is likely to replace the application content in the hardware cache with the content the OS needs.
For example, it takes about 50 to 100 nanoseconds on a 2GHz machine running Linux.
{: .notice--info}

## OS Services
The OS incorporates a number of services to provide applications and application developers with a number of useful functionalities.
And they are available via system calls.

Some system call examples in Unix-like systems are:

|service|system calls|
|--|--|
|process control|`fork`, `wait`, `exit`|
|file management|`open`, `read`, `write`, `close`|
|device management|`ioctl`, `read`, `write`|
|information management|`getpid`, `alarm`, `sleep`|
|communication|`pipe`, `shmget`, `mmap`|
|protection|`chmod`, `umask`, `chown`|

## OS Architectures
### Monolithic Kernel
The traditional OS architecture is a monolithic design where all services are built in the OS.
* pros
    * everything included
    * compile-time optimizations
* cons
    * customization
    * portability
    * manageability
    * memory footprint
    * performance
### Modular OS
Modular OS has some basic services already built in it and the other services can be added as modules by implementing certain interfaces that the OS specifies.

For example, we can install a random file access file system module for the database applications.
* pros
    * maintainability
    * smaller footprint
    * less resource needs
* cons
    * indirection can impact performance
    * maintenance can still be an issue

Modular OS is more common today than the monolithic one.
### Microkernel
Microkernel only provides the most basic services and the other ones can be run at user level.
Because it requires lots of inter-process interactions, the microkernel supports IPC as one of its core abstractions and mechanisms.
* pros
    * small size
    * verifiability
* cons
    * portability
    * complexity of software development
    * cost of user/kernel crossing
