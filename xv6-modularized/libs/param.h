#define NPROC        64  // Maximum number of processes
#define PRIORITYBOOST 100 // Time between priority boost
#define NPRIO         3  // Total levels of scheduler priority
#define KSTACKSIZE 4096  // Size of per-process kernel stack
#define NCPU          8  // Maximum number of CPUs
#define NOFILE       16  // Open files per process
#define NFILE       100  // Open files per system
#define NINODE       50  // Maximum number of active i-nodes
#define NDEV         10  // Maximum major device number
#define ROOTDEV       1  // Device number of file system root disk
#define MAXARG       32  // Max exec arguments
#define MAXOPBLOCKS  10  // Max # of blocks any FS op writes
#define LOGSIZE      (MAXOPBLOCKS*3)  // Max data blocks in on-disk log
#define NBUF         (MAXOPBLOCKS*3)  // Size of disk block cache
#define FSSIZE       1000  // Size of file system in blocks

