#ifndef SHOW_H
#define SHOW_H

#include "lib.h"
#include <stdarg.h>

// typedef struct Colors
// {
// 	char r;
// 	char g;
// 	char b;
// } Color;

// extern Color Black  ;
// extern Color White  ;
// extern Color Red    ;
// extern Color Green  ;
// extern Color Blue   ;
// extern Color Gray   ;
// extern Color Cyan   ;
// extern Color Yellow ;
// extern Color Magenta;
// extern Color Brown  ;

enum Colors
{
	Black=0, White, Red, Green, Blue, Gray, Cyan, Yellow, Magenta, Brown
};
typedef enum Colors Color;

void pixel(int x, int y, char r, char g, char b);
void pixel_ptr(int *position, unsigned char r, unsigned char g, unsigned char b);
void print_char(int *position, char character, Color character_color, Color back_color);

char *int2str(int num);
void format(char *template, char *buffer, va_list var_list);
void h_print(char *template, ...);
void color_print(Color character_color, Color back_color, char *template, ...);

void line(int x1, int y1, int x2, int y2, Color line_color);
void circle(int x1, int y1, int r);
void rect(int x1, int y1, int width, int height);

#endif