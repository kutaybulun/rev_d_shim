#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

//////////////////// Mapped Memory Definitions ////////////////////

// Addresses are defined in the hardware design Tcl file
#define AXI_CFG  (uint32_t) 0x40000000

#define CFG_SIZE        (uint32_t) 64 / 8 // Size of the configuration register in bytes


//////////////////// Function Prototypes ////////////////////

// Print out the available commands
void print_help();
// Set a single interrupt
void set_interrupt(volatile void *cfg, uint32_t interrupt_num, uint32_t value);
// Set multiple interrupts with an 8-bit mask
void set_interrupt_mask(volatile void *cfg, uint8_t mask);
// Clear a single interrupt (on the PS side)
void clear_interrupt(volatile void *cfg, uint32_t interrupt_num);
// Clear multiple interrupts with an 8-bit mask (on the PS side)
void clear_interrupt_mask(volatile void *cfg, uint8_t mask);
// Clear all interrupts (on the PS side)
void clear_all_interrupts(volatile void *cfg);

//////////////////// Main ////////////////////
int main()
{

  //////////////////// 1. Setup ////////////////////
  printf("Test program for PS/PL interrupts\n");
  printf("Setup:\n");

  int fd; // File descriptor
  volatile void *cfg; // CFG register AXI interface

  // Open the device file
  fd = open("/dev/axi_interrupt", O_RDWR);
  if(fd < 0) {
    perror("Failed to open device file");
    return EXIT_FAILURE;
  }
  printf("Device file opened successfully.\n");

  // Get the page size for memory mapping
  long pagesize = sysconf(_SC_PAGE_SIZE);
  if(pagesize < 0) {
    perror("Failed to get page size");
    close(fd);
    return EXIT_FAILURE;
  }
  printf("System page size: %ld bytes\n", pagesize);

  // Map the CFG register
  uint32_t cfg_page_count = (CFG_SIZE - 1) / pagesize + 1; // Calculate number of pages needed for CFG
  cfg = mmap(NULL, cfg_page_count * pagesize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, AXI_CFG);
  if(cfg == MAP_FAILED) {
    perror("Failed to map CFG register");
    close(fd);
    return EXIT_FAILURE;
  }
  printf("CFG register mapped to address: %p\n", cfg);

  //////////////////// 2. Command Loop ////////////////////
  print_help(); // Print available commands
  while(1) {
    printf("Enter command: ");
    char command[256]; // Buffer for user input
    char *num_endptr; // Pointer for strtoul, will mark the end of numerals
    fgets(command, sizeof(command), stdin); // Read user input string
    command[strcspn(command, "\n")] = 0; // Remove newline character
    char *token = strtok(command, " "); // Get the first token

    // No command entered
    if(token == NULL) continue;
    
    // Help command
    if(strcmp(token, "help") == 0) { 
      print_help();

    } else if(strcmp(token, "set") == 0) { // Set a single interrupt
      // 1st token is interrupt number
      token = strtok(NULL, " ");
      if(token == NULL) { printf("Please specify an interrupt number (0-7).\n"); continue; } // Check for interrupt number
      uint32_t interrupt_num = strtoul(token, &num_endptr, 10); // Convert string to unsigned long
      if(num_endptr == token || interrupt_num > 7) { printf("Invalid interrupt number specified: %s\n", token); continue; } // Check for valid interrupt number
      // 2nd token is value (0 to disable, 1 to enable)
      token = strtok(NULL, " ");
      if(token == NULL) { printf("Please specify a value (0 to disable, 1 to enable).\n"); continue; } // Check for value
      uint32_t value = strtoul(token, &num_endptr, 10); // Convert string to unsigned long
      if(num_endptr == token || (value != 0 && value != 1)) { printf("Invalid value specified: %s\n", token); continue; } // Check for valid value
      set_interrupt(cfg, interrupt_num, value); // Set the interrupt
    
    } else if(strcmp(token, "set_mask") == 0) { // Set multiple interrupts with an 8-bit mask
      token = strtok(NULL, " ");
      if(token == NULL) { printf("Please specify an 8-bit mask (e.g., 0b00001111).\n"); continue; } // Check for mask
      uint32_t mask = strtoul(token, &num_endptr, 2); // Convert string to unsigned long in base 2
      if(num_endptr == token || mask > 0xFF) { printf("Invalid mask specified: %s\n", token); continue; } // Check for valid mask
      set_interrupt_mask(cfg, (uint8_t)mask); // Set the interrupt mask

    } else if(strcmp(token, "clear") == 0) { // Clear a single interrupt
      token = strtok(NULL, " ");
      if(token == NULL) { printf("Please specify an interrupt number to clear (0-7).\n"); continue; } // Check for interrupt number
      uint32_t interrupt_num = strtoul(token, &num_endptr, 10); // Convert string to unsigned long
      if(num_endptr == token || interrupt_num > 7) { printf("Invalid interrupt number specified: %s\n", token); continue; } // Check for valid interrupt number
      clear_interrupt(cfg, interrupt_num); // Clear the interrupt

    } else if(strcmp(token, "clear_mask") == 0) { // Clear multiple interrupts with an 8-bit mask
      token = strtok(NULL, " ");
      if(token == NULL) { printf("Please specify an 8-bit mask to clear (e.g., 0b00001111).\n"); continue; } // Check for mask
      uint32_t mask = strtoul(token, &num_endptr, 2); // Convert string to unsigned long in base 2
      if(num_endptr == token || mask > 0xFF) { printf("Invalid mask specified: %s\n", token); continue; } // Check for valid mask
      clear_interrupt_mask(cfg, (uint8_t)mask); // Clear the interrupt mask

    } else if(strcmp(token, "clear_all") == 0) { // Clear all interrupts
      clear_all_interrupts(cfg); // Clear all interrupts

    } else if(strcmp(token, "exit") == 0) { // Exit command
      break; // Exit the loop

    } else { // Unknown command
      printf("Unknown command: %s\n", token);
      print_help(); // Print help message
    }
  } // End of command loop

  // Unmap memory
  printf("Unmapping memory...\n");
  if(munmap((void *)cfg, cfg_page_count * pagesize) < 0) {
    perror("Failed to unmap CFG register");
  }
  close(fd);
  printf("Exiting program.\n");

  return EXIT_SUCCESS;
}

/////////////////////// Functions ////////////////////

// Set a single interrupt
// interrupt_num: 0-7, value: 0 to disable, 1 to enable
void set_interrupt(volatile void *cfg, uint32_t interrupt_num, uint32_t value)
{
  if(interrupt_num > 7) {
    printf("Invalid interrupt number: %u. Must be between 0 and 7.\n", interrupt_num);
    return;
  }
  uint32_t *cfg_reg = (uint32_t *)cfg;
  if(value) {
    *cfg_reg |= (1 << interrupt_num); // Set the bit to enable the interrupt
  } else {
    *cfg_reg &= ~(1 << interrupt_num); // Clear the bit to disable the interrupt
  }
  printf("Interrupt %u set to %u.\n", interrupt_num, value);
}

// Set multiple interrupts with an 8-bit mask
void set_interrupt_mask(volatile void *cfg, uint8_t mask)
{
  uint32_t *cfg_reg = (uint32_t *)cfg;
  *cfg_reg = (*cfg_reg & ~0xFF) | (mask & 0xFF); // Set the lower 8 bits
  printf("Interrupt mask set to: 0x%02X\n", mask);
}

// Clear a single interrupt (on the PS side)
void clear_interrupt(volatile void *cfg, uint32_t interrupt_num)
{
  // TODO
}

// Clear multiple interrupts with an 8-bit mask (on the PS side)
void clear_interrupt_mask(volatile void *cfg, uint8_t mask)
{
  // TODO
}

// Clear all interrupts (on the PS side)
void clear_all_interrupts(volatile void *cfg)
{
  // TODO
}

// Print out the available commands
void print_help()
{
  printf("Available commands:\n");
  printf("help - Show this help message\n");
  printf("set <interrupt_num> <value> - Set a single interrupt (0-7, value: 0 to disable, 1 to enable)\n");
  printf("set_mask <mask> - Set multiple interrupts with an 8-bit binary mask (e.g., 0b00001111)\n");
  printf("clear <interrupt_num> - Clear (on the PS side) a single interrupt (0-7)\n");
  printf("clear_mask <mask> - Clear (on the PS side) multiple interrupts with an 8-bit binary mask\n");
  printf("clear_all - Clear (on the PS side) all interrupts\n");
  printf("exit - Exit the program\n");
}


