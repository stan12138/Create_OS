#ifndef MAIN_SHOW_
#define MAIN_SHOW_

#include <stdarg.h>

#define one_character 8
#define one_line 12000
#define BUFFER_SIZE 4096
#define SCREEN_WIDTH 800
#define SCREEN_HEIGHT 600
#define MEM_LOC 0xffff800000a00000
#define PIXEL_SIZE 4


struct Info
{
	int width;
	int height;

	int pixel_size;
	int *base;
};

enum Colors
{
	Black=0, White, Red, Green, Blue, Gray, Cyan, Yellow, Magenta, Brown
};

typedef enum Colors Color;

typedef struct Info Info;

extern void pixel(int x, int y, char r, char g, char b);

extern void h_print(char *template, ...);
extern void color_print(Color character_color, Color back_color, char *template, ...);

extern void line(int x1, int y1, int x2, int y2, Color line_color);
extern void circle(int x1, int y1, int r);
extern void rect(int x1, int y1, int width, int height);

#endif