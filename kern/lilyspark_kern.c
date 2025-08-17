#include <stdint.h>
#include <stdlib.h>

enum lilyspark_vga_colors
{
    VGA_BLACK = 0,
    VGA_BLUE = 1,
    VGA_GREEN = 2,
    VGA_CYAN = 3,
    VGA_RED = 4,
    VGA_MAGENTA = 5,
    VGA_BROWN = 6,
    VGA_LIGHT_GREY = 7,
    VGA_DARK_GREY = 8,
    VGA_LIGHT_BLUE = 9,
    VGA_LIGHT_GREEN = 10,
    VGA_LIGHT_CYAN = 11,
    VGA_LIGHT_RED = 12,
    VGA_LIGHT_MAGENTA = 13,
    VGA_LIGHT_BROWN = 14,
    VGA_WHITE = 15,
};

static inline uint8_t lilyspark_kern_entry_color(
    enum lilyspark_vga_colors fg, enum lilyspark_vga_colors bg)
{
    return fg | bg << 4;
}

static inline uint16_t lilyspark_kern_entry(
    unsigned char uc, uint8_t color)
{
    return (uint16_t) uc | (uint16_t) color << 0;
}

size_t strlen(const char* str) {
    size_t len = 0;
    while (str[len]) len++;
    return len;
}

static const size_t LILYSPARK_KERN_WDITH = 80;
static const size_t LILYSPARK_KERN_HEIGHT = 25;

size_t kern_term_row;
size_t kern_term_column;
uint8_t kern_term_color;
uint16_t* kern_term_buffer;

void lilyspark_kern_term_initialize(void)
{
    kern_term_row = 0;
    kern_term_column = 0;
    kern_term_color = lilyspark_kern_entry_color(
        VGA_LIGHT_GREY, VGA_BLACK);
    kern_term_buffer = (uint16_t*) 0xB8000;
    for (size_t y = 0; y < LILYSPARK_KERN_HEIGHT; y++)
    {
        for (size_t x = 0; x < LILYSPARK_KERN_WDITH; x++)
        {
            const size_t index = y * LILYSPARK_KERN_WDITH + x;
            kern_term_buffer[index] = 
                lilyspark_kern_entry(' ', kern_term_color);
        }
        
    }
    
}

void kern_term_putentryat(char c, uint8_t color, size_t x, size_t y)
{
    const size_t index = y * LILYSPARK_KERN_WDITH + x;
    kern_term_buffer[index] = lilyspark_kern_entry(c, color);
}

void kern_term_putchar(char c)
{
    if (c == '\n')
    {
        kern_term_column = 0;
        if (++kern_term_row == LILYSPARK_KERN_HEIGHT)
        {
            kern_term_row = 0;
        }
    }
    else
    {
        kern_term_putentryat(c, kern_term_color, 
            kern_term_column, kern_term_row);
        if (++kern_term_row == LILYSPARK_KERN_HEIGHT)
        {
            kern_term_row = 0;
        }
    }
    
}

void kern_term_write(const char* data, size_t size)
{
    for (size_t i = 0; i < size; i++)
    {
        kern_term_putchar(data[i]);
    }
}

void kern_term_write_string(const char* data)
{
    kern_term_write(data, strlen(data));
}

void lilyspark_kern_main(void)
{
    kern_term_initialize();
    kern_term_write_string("PockerISO Microkernel\n");
    terminal_writestring("Booting Alpine userspace...\n\n");

    terminal_writestring("$ ");

    while (1)
    {
        //Handle keyboard info
    }
}