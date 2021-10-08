#include "types.h"
#include "stat.h"
#include "user.h"
#include "fs.h"
#include "fcntl.h"

#define OPSIZE 16
#define TIMES 32
#define MINTICKS 250
#define OUTPUT_FILENAME "iobench_output.txt"
#define AMOUNT_MEASUREMENTS 70

static char path[] = "12iops";
static char data[OPSIZE];

int
main(int argc, char *argv[])
{
  int rfd, wfd, file;
  int pid = getpid();
  int i;
  int measurement;

  path[0] = '0' + (pid / 10);
  path[1] = '0' + (pid % 10);

  memset(data, 'a', sizeof(data));

  int start = uptime();
  int ops = 0;
  file = open(OUTPUT_FILENAME, O_CREATE | O_WRONLY);
  for(int iter = 0; iter < AMOUNT_MEASUREMENTS;) {
    int end = uptime();
    int elapsed = end - start;
    if (elapsed >= MINTICKS) {
        measurement = (int) (ops * MINTICKS / elapsed);
        printf(file, "%d\t\t\t\t\t%d: %d IOP%dT\n", measurement, pid, measurement, MINTICKS);
        printf(1, "%d measurements remaining...\n", AMOUNT_MEASUREMENTS-iter);
        iter++;

        start = end;
        ops = 0;
    }

    wfd = open(path, O_CREATE | O_WRONLY);
    rfd = open(path, O_RDONLY);

    for(i = 0; i < TIMES; ++i) {
      write(wfd, data, OPSIZE);
    }
    for(i = 0; i < TIMES; ++i) {
      read(rfd, data, OPSIZE);
    }
    close(wfd);
    close(rfd);
    ops += 2 * TIMES;
  }
  close(file);
  exit();
  return 0;
}




