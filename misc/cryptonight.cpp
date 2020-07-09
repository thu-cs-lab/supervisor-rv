#include <stdint.h>
#include <stdio.h>

const uint32_t size = 0x200000;
const uint32_t iter = 524288;
const uint32_t mask = 0x1FFFFC;
const uint32_t init_rand = 1;
uint32_t memory[size / sizeof(uint32_t)];

void bits32() {
  uint32_t rand = init_rand;

  for (int i = 0; i < size / sizeof(uint32_t); i++) {
    memory[i] = rand;
    rand ^= rand << 13;
    rand ^= rand >> 17;
    rand ^= rand << 5;
  }

  uint32_t last = 0;
  for (int j = 0; j < iter; j++) {
    uint32_t cur = memory[(rand % size) / 4];
    cur ^= last;
    rand ^= cur;
    rand ^= rand << 13;
    rand ^= rand >> 17;
    rand ^= rand << 5;
    memory[(rand % size) / 4] = cur;
    rand ^= rand << 13;
    rand ^= rand >> 17;
    rand ^= rand << 5;
    last = cur;
  }
  printf("32bit Result: %08x\n", last);
}

void bits64() {
  uint64_t rand = init_rand;

  for (int i = 0; i < size / sizeof(uint32_t); i++) {
    memory[i] = rand;
    rand ^= rand << 13;
    rand ^= rand >> 17;
    rand ^= rand << 5;
  }

  uint64_t last = 0;
  for (int j = 0; j < iter; j++) {
    uint64_t cur = memory[(rand % size) / 4];
    cur ^= last;
    // RISC-V use sign extension
    rand ^= (int32_t)cur;
    rand ^= rand << 13;
    rand ^= rand >> 17;
    rand ^= rand << 5;
    memory[(rand % size) / 4] = cur;
    rand ^= rand << 13;
    rand ^= rand >> 17;
    rand ^= rand << 5;
    last = cur;
  }
  // RISC-V use sign extension
  printf("64bit Result: %016llx\n", (uint64_t)(int32_t)last);
}

int main() {
  bits32();
  bits64();
  return 0;
}