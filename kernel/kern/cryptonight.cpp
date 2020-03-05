#include <stdint.h>
#include <stdio.h>

const uint32_t size = 0x200000;
uint32_t memory[size / sizeof(uint32_t)];

int main() {
  uint32_t iter = 524288;
  uint32_t mask = 0x1FFFFC;
  uint32_t rand = 1;

  for (int i = 0; i < size / sizeof(uint32_t); i++) {
    memory[i] = rand;
    rand ^= rand << 13;
    rand ^= rand >> 17;
    rand ^= rand << 5;
  }

  uint32_t last = 0;
  for (int j = 0; j < iter; j++) {
    uint32_t cur = memory[(rand % size) / 4];
    rand ^= rand << 13;
    rand ^= rand >> 17;
    rand ^= rand << 5;
    cur ^= last;
    memory[(rand % size) / 4] = cur;
    rand ^= rand << 13;
    rand ^= rand >> 17;
    rand ^= rand << 5;
    last = cur;
  }
  printf("Result: %08x\n", last);

  return 0;
}