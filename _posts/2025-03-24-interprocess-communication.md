---
title: "Interprocess Communication"
tags: [c, os]
toc: true
toc_sticky: true
post_no: 34
---
A process is either independent or cooperating:
- independent: if it cannot affect or be affected by the other processes, and does not share data with any other processes
- cooperating: if it can affect or be affected by the other processes, and shares data with other processes

There are several benefits to provide a system where processes can work together:
- Information sharing. Since several users may be interested in the same piece of information (for instance, a shared file), we must provide an environment to allow concurrent access to such information.
- Computation speedup. If we want a particular task to run faster, we must break it into subtasks, each of which will be executing in parallel with the others. Notice that such a speedup can be achieved only if the computer has multiple processing cores.
- Modularity. We may want to construct the system in a modular fashion, dividing the system functions into separate processes or threads, as we discussed in Chapter 2.
- Convenience. Even an individual user may work on many tasks at the same time. For instance, a user may be editing, listening to music, and compiling in parallel.

## Interprocess Communication
Interprocess Communication (IPC) is a set of methods that the operating system provides to allow multiple processes to communicate and work together.

![Two models of IPC](/assets/posts/34/two_models_of_ipc.png)

There are two fundamental models that enable interprocess communication:
- message passing model: communication takes place by means of messages exchanged between the cooperating processes via sockets, pipes, message queues.
- shared memory model: a region of memory that is shared by cooperating processes is established. Processes can then exchange information by reading and writing data to the shared region

Message passing is useful for exchanging small amounts of data because it avoids conflicts and is easier to implement in distributed systems compared to shared memory.
However, shared memory can be faster since message passing relies on system calls, which require more time due to kernel involvement.

While shared memory can be faster because it bypasses system calls and kernel intervention, recent research on multi-core systems suggests that message passing often outperforms shared memory in such environments.
{: notice--info}

## Message-Passing Systems
In message-passing systems, processes create messages and then send or receive these messages through a communication channel.
This communication channel may be implemented as a buffer or a FIFO queue.

For message-based ICP, the operating system kernel is responsible for:
- setting up and managing the communication channel
- handling the actual message transfers by providing an interface that enables processes to send and receive messages
- ensuring synchronization

![Message-passing](/assets/posts/34/message_passing.png)

The basic mechanism is as follows:
1. Establishing a Communication Channel: The OS creates a communication channel between processes.
2. Sending a Message: The sending process sends data into a port via a system call (`send()`).
3. Transmitting the Message: The OS transfers the message through the channel to the destination.
4. Receiving a Message: The receiving process receives the message by reading from a port via system call (`recv()`).

Advantages:
- simplicity: The OS kernel abstracts the complexities of direct process communication and synchronization.
- safety: The OS kernel enforces access control and isolation, preventing unauthorized access and ensuring data integrity.

Disadvantages:
- overheads: Crossing the kernel boundary and copying data in and out of the kernel introduce performance overheads, especially in high-frequency messaging scenarios.

There are three primary methods of message-based IPC: pipes, message queues, and sockets.
Below is a table that outlines the key differences and characteristics of each method:

| IPC Method    | Data Structure           | Communication Scope           | API/Standards         | Key Characteristics                                              |
|---------------|--------------------------|-------------------------------|-----------------------|------------------------------------------------------------------|
| Pipes         | stream of bytes          | two endpoints (one-to-one)    | POSIX                 | simple, unidirectional                                           |
| Message queues| discrete messages        | multiple processes supported  | POSIX, System V       | supports message formatting, prioritization, and scheduling      |
| Sockets       | message-based / stream   | local and networked processes | socket API (TCP/IP)   | uses socket abstraction as ports (`socket()`, `send()`, `recv()`)|

## Shared-Memory Systems
In shared-memory systems, multiple processes can read from and write to a common memory region.
Typically, the process that creates the shared memory segment allocates it within its own address space, and any other process that needs to communicate through this segment must attach it to its address space.

The operating system maps specific physical pages into the virtual address spaces of all cooperating processes.
As a result, even though each process's virtual address space may place the shared memory at different locations, they all reference the same physical memory.
This arrangement ensures that while the underlying physical memory is shared, each process maintains an independent virtual address layout.

Advantages:
- Reduced OS overheads: Once the physical memory is mapped into the processes' address spaces, the operating system plays no further role in data transfers, as system calls are only required during the initial setup.
- Minimized data copying: Processes can directly access only the necessary information in the shared memory without the overhead of copying entire datasets.

Disadvantages:
- Explicit synchronization: Because multiple processes can concurrently access the shared memory area, explicit synchronization mechanisms are required to prevent race conditions.
- Communication protocol design: Programmers are responsible to establish the communication protocol, determining how messages are formatted and exchanged.
- Shared buffer management: The allocation and management of the shared memory buffer are also the responsibility of the programmer, including decisions on when and which process can access the buffer.

In Unix-based systems, including Linux, the System V API and POSIX API are the most common interfaces for managing shared memory.

## Message-based vs Shared memory-based
Below is a table comparing message-based IPC and shared memory-based IPC:

| Feature | Message-based IPC | Shared memory-based IPC |
|---------|-------------------|-------------------------|
| Data Transfer | Data is transferred via a communication channel (port). | Both processes share a region of memory for direct access. |
| Data Copying | The CPU copies data into the port, then into the target process. | The CPU maps physical memory into the address spaces of both processes. |
| Efficiency for Large Data | Less efficient, as multiple copies are required.  | More efficient, as fewer copies are needed. |

In summary, message-based IPC consumes more CPU cycles, particularly when dealing with large data.
On the other hand, while shared memory-based IPC can be initially costly due to memory mapping, it proves to be more efficient for transferring large amounts of data.
Therefore, the best IPC method depends on the size of the data and performance requirements, with shared memory being more efficient for larger data transfers.

In practice, systems like Windows uses a hybrid approach, also called as Local Procedure Calls (LPC), choosing the best method based on the data size:
- For small data, message passing is used.
- For large data, shared memory mapping is employed for efficiency.

## Shared Memory APIs
Below are the key high-level operations for managing shared memory in IPC:
1. Create: Allocates physical memory for a shared memory segment (or a communication channel), and returns an unique identifier (key) for any other processes to refer to the segment.
2. Attach: Allows a process to connect to the shared memory segment by using the key, establishing mappings between virtual addresses and physical memory addresses of the segment.
3. Detach: Disconnects a process from the shared memory segment by invalidating the address mappings.
4. Destroy: Deallocates the shared memory segment when no longer needed, preventing memory leaks and freeing system resources.

Note that a shared memory segment can be repeatedly attached and detached by multiple processes until it is explicitly destroyed.
This is in contrast to regular, non-shared memory, which is automatically freed when the process that allocated it exits.

There are two primary standards for implementing IPC on Unix-like systems: System V IPC and POSIX IPC.
While both standards offer similar functionality, their system calls differ in naming and implementation.

The following table summarizes the system calls for shared memory operations in each standard:

| Operation | System V   | POSIX          |
|-----------|------------|----------------|
| Create    | `shmget()` | `shm_open()`   |
| Attach    | `shmat()`  | `mmap()`       |
| Detach    | `shmdt()`  | `munmap()`     |
| Destroy   | `shmctl()` | `shm_unlink()` |

### System V IPC
<!-- Ref: https://tldp.org/LDP/lpg/node21.html -->
System V IPC is a set of communication mechanisms that were originally introduced in the UNIX System V operating system.
While System V IPC is not widely used today, it laid the foundation for later IPC methods and is still supported in many UNIX-like systems for backward compatibility.

The following examples demonstrate the basic usage of System V shared memory.

For creating and writing to shared memory:
```c
// create_and_write.c
#include <stdio.h>   // for printf()
#include <sys/ipc.h> // for ftok()
#include <sys/shm.h> // for shmget(), shmat(), shmdt()
#include <string.h>  // for strcpy()

int main()
{
    key_t key = ftok("shmfile", 65);                 // generate unique key for System V IPC
    int shmid = shmget(key, 1024, 0666 | IPC_CREAT); // create shared memory segment
    char *str = (char *)shmat(shmid, (void *)0, 0);  // attach shared memory segment to the process's address space

    strcpy(str, "Hello from System V shared memory!"); // write data to shared memory
    printf("Data written: %s\n", str);

    shmdt(str); // detach shared memory segment from the process's address space

    return 0;
}
```

Detailed explanations:
- `key_t key = ftok("shmfile", 65);`: generates a key of type `key_t` based on the file's inode (`"shmfile"`) and the provided integer (`65`, which is just an arbitrary number). This key uniquely identifies the shared memory segment.
- `int shmid = shmget(key, 1024, 0666 | IPC_CREAT);`: uses the key generated earlier. The second parameter, `1024`, specifies the size of the memory segment in bytes. The third parameter, `0666|IPC_CREAT`, sets the permissions (read and write for everyone) and tells the system to create the segment if it doesn't already exist.
- `char *str = (char *)shmat(shmid, (void *)0, 0);`: returns a pointer to the shared memory. The first parameter is the shared memory ID obtained from `shmget()`. The second parameter is set to `(void*)0`, which lets the operating system choose the attach address. The third parameter is `0`, which means no special flags are used during attachment.
- `shmdt(str);`: releases the memory region previously attached with `shmat()`, ensuring that the process no longer accesses the shared memory.

Complie and run:
```sh
gcc create_and_write.c -o create_and_write
./create_and_write
```

Output:
```
Data written: Hello from System V shared memory!
```

For reading and destroying the shared memory:
```c
// read_and_destroy.c
#include <stdio.h>
#include <sys/ipc.h>
#include <sys/shm.h>

int main()
{
    key_t key = ftok("shmfile", 65);
    int shmid = shmget(key, 1024, 0666 | IPC_CREAT); // access shared memory segment
    char *str = (char *)shmat(shmid, (void *)0, 0);  // attach shared memory segment to the process's address space

    printf("Data read: %s\n", str);

    shmdt(str); // detach shared memory segment from the process's address space

    shmctl(shmid, IPC_RMID, NULL); // destroy shared memory segment
    printf("Shared memory destroyed.\n");

    return 0;
}
```

Detailed explanations:
- `int shmid = shmget(key, 1024, 0666 | IPC_CREAT);`: accesses the exsiting shared memory segment. Note that it does not create the shared memory as it already exists.
- `shmctl(shmid, IPC_RMID, NULL);`: destroys (or marks for deletion) the shared memory segment. The command `IPC_RMID` tells the system to remove the shared memory segment. The third parameter is `NULL` because no additional options or data structures are needed for this operation.

Complie and run:
```sh
gcc read_and_destroy.c -o read_and_destroy
./read_and_destroy
```

Output:
```
Data read: Hello from System V shared memory!
Shared memory destroyed.
```

As demonstrated here, even after a process exits, the shared memory remains allocated until it is explicitly removed, allowing other processes to access the data if needed.

### POSIX IPC
<!-- Ref: https://man7.org/linux/man-pages/man7/shm_overview.7.html -->
POSIX shared memory is a modern and widely-used inter-process communication (IPC) mechanism standardized in POSIX-compliant systems.

The following examples demonstrate the basic usage of POSIX shared memory.

For creating and writing to shared memory:
```c
// create_and_write.c
#include <stdio.h>    // for printf()
#include <fcntl.h>    // for O_CREAT, O_RDWR
#include <sys/mman.h> // for shm_open(), mmap()
#include <unistd.h>   // for ftruncate()
#include <string.h>   // for strcpy()

int main()
{
    int shm_fd = shm_open("/posix_shm", O_CREAT | O_RDWR, 0666); // create POSIX shared memory object
    ftruncate(shm_fd, 1024);                                     // set size of shared memory segment

    char *ptr = mmap(0, 1024, PROT_WRITE, MAP_SHARED, shm_fd, 0); // map shared memory segment to process address space

    strcpy(ptr, "Hello from POSIX shared memory!"); // write data to shared memory
    printf("Data written: %s\n", ptr);

    munmap(ptr, 1024); // unmap shared memory segment
    close(shm_fd);     // close file descriptor

    return 0;
}
```

Detailed explanations:
- `shm_open("/posix_shm", O_CREAT | O_RDWR, 0666);`: creates a POSIX shared memory object named `/posix_shm`. `O_CREAT` flag instructs `shm_open()` to create a new shared memory object if one does not already exist. If the object exists, it is opened. `O_RDWR` flag grants read and write access to the shared memory object. The permissions `0666` allow read/write access to everyone.
- `ftruncate(shm_fd, 1024);`: resizes the shared memory segment to 1024 bytes. This is necessary as shared memory objects don't automatically have a defined size when created.
- `mmap(0, 1024, PROT_WRITE, MAP_SHARED, shm_fd, 0);`: maps the shared memory into the calling process's address space with write permissions. Passing `0` lets the system choose the address. `1024` is the length of the memory to map, which is 1024 bytes in this case. `PROT_WRITE` flag allows the process to write to the mapped memory. `PROT_READ` can be added if reading is also needed. `shm_fd` is the file descriptor returned by `shm_open()`, which identifies the shared memory object to be mapped. The last `0` is the offset within the shared memory object at which the mapping should start.
- `munmap(ptr, 1024);`: unmaps the previously mapped shared memory region from the process's address space.
- `close(shm_fd)`: closes the file descriptor `shm_fd` to ensure that the file system resources are properly freed and prevents memory leaks.

Compile and run:
```sh
gcc create_and_write.c -o create_and_write
./create_and_write
```

Output:
```
Data written: Hello from POSIX shared memory!
```

For reading and destroying the shared memory:
```c
// read_and_destroy.c
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <sys/stat.h>

int main()
{
    int shm_fd = shm_open("/posix_shm", O_RDONLY, 0666); // open existing shared memory object

    struct stat shm_stat;
    // prevent segmentation fault if shared memory object does not exist
    if (fstat(shm_fd, &shm_stat) == -1)
    { // get size of shared memory
        perror("fstat failed");
        close(shm_fd);
        return 1;
    }

    char *ptr = mmap(0, shm_stat.st_size, PROT_READ, MAP_SHARED, shm_fd, 0); // map shared memory segment for reading

    printf("Data read: %s\n", ptr);

    munmap(ptr, shm_stat.st_size); // unmap shared memory segment
    close(shm_fd);                 // close file descriptor

    shm_unlink("/posix_shm"); // destroy shared memory segment
    printf("Shared memory destroyed.\n");

    return 0;
}
```

Detailed explanations:
- `shm_open("/posix_shm", O_RDONLY, 0666);`: opens an existing shared memory object named `/posix_shm` in read-only mode (`O_RDONLY`).
- `fstat(shm_fd, &shm_stat);`: obtains the size of the shared memory object. The `&shm_stat` is a pointer to a `struct stat` where the metadata (like the size of the shared memory) will be stored. The relevant field here is `st_size`, which holds the size of the shared memory object.
- `shm_unlink("/posix_shm");`: destroys the shared memory object `/posix_shm` from the system.

Compile and run:
```sh
gcc read_and_destroy.c -o read_and_destroy
./read_and_destroy
```

Output:
```
Data read: Hello from POSIX shared memory!
Shared memory destroyed.
```

Just like System V shared memory, POSIX shared memory also remains available to other processes until explicitly removed using `shm_unlink()`.

## Design Considerations
When using shared memory, the operating system provides the shared memory area but imposes no restrictions on how the memory is used.
This means that it is the programmer's responsibility to manage data passing and synchronization effectively.

![segment consideration](/assets/posts/34/segment_consideration.png)

A key design consideration is determining how many memory segments for communication.
There are two primary options:
- One large segment
- Multiple smaller segments

Using a single large segment simplifies memory management since there is only one shared area to allocate and free.
This reduces the complexity associated with managing multiple segments.
However, it still requires careful memory management to allocate and free memory for threads from different processes.

On the other hand, using multiple smaller segments often involves pre-allocating a pool of segments to minimize the overhead of segment creation.
In addition, the programmer must implement a mechanism, such as a queue, to allow threads to determine which available segment to use for communication.
After all, it adds some additional complexity to the design.

Another consideration is determining how large a shared memory segment should be.
Fixed-size segments work well if the data size is known and static, however, it limits flexibility since data sizes might not be static.
For dynamic data, transferring in rounds is an option, where data is split across multiple rounds.
The programmer needs to implement some protocol to track progress, using a data structure that includes the buffer, synchronization, and flags.
