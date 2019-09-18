#include "lib.h"
#include "font.h"
#include <stdarg.h>


static Info screen = {SCREEN_WIDTH, SCREEN_HEIGHT, PIXEL_SIZE, (int *)MEM_LOC};  //屏幕相关信息

static unsigned char color_table[10][3] = {
	{0, 0, 0},
	{255, 255, 255},
	{255, 0, 0},
	{0, 255, 0},
	{0, 0, 255},
	{192, 192, 192},
	{0, 255, 255},
	{255, 255, 0},
	{255, 0, 255},
	{128, 128, 128}
};


static char character_buffer[BUFFER_SIZE] = {0};                              //要显示的字符内容的缓冲区

static int *char_position = (int *)MEM_LOC;                 //记录当前光标的位置
static int num_in_one_line = 0;                                        //记录当前行已经占用的字符数目


void pixel(int x, int y, char r, char g, char b)                //将对应坐标位置的像素显示为指定颜色
{
	int *addr = screen.base;
	addr += y*screen.width+x;
	*((char *)addr+0) = b;
	*((char *)addr+1) = g;
	*((char *)addr+2) = r;
	*((char *)addr+3) = (char)0x00;
}

static void pixel_ptr(int *position, unsigned char r, unsigned char g, unsigned char b)          //设置像素的颜色，像素坐标使用内存地址表示
{
	*((char *)position+0) = b;
	*((char *)position+1) = g;
	*((char *)position+2) = r;
	*((char *)position+3) = (char)0x00;
}

static void print_char(int *position, char character, Color character_color, Color back_color)                //显示一个字符， position指定字符最左上角的像素的内存地址
{
	for(int i=0; i<16; i++)
	{
		unsigned char one_byte = font_ascii[character][i];
		for(int j=0; j<8; j++)
		{
			if(one_byte & (0x80>>j)) pixel_ptr(position+i*screen.width+j, color_table[character_color][0], color_table[character_color][1], color_table[character_color][2]);
			else pixel_ptr(position+i*screen.width+j, color_table[back_color][0], color_table[back_color][1], color_table[back_color][2]);
		}
	}
}


static char *int2str(int num)  //将整数转换为字符串，并返回
{
	char record[32] = {0};
	static char res[32] = {0};
	char length = 0, res_len=0;
	if(num<0)
	{
		res[0] = '-';
		res_len++;
		num *= -1;
	}
	else if(num==0)
	{
		res[0] = '0';
		return res;
	}

	while(num>0)
	{
		record[length] = '0'+num%10;
		num /= 10;
		length++;
	}

	while(length>0)
	{
		length--;
		res[res_len] = record[length];
		res_len++;
	}

	return res;
}

static void format(char *template, char *buffer, va_list var_list)   //将字符串格式化，需要给定原始模板，完成之后存储的缓存区，以及以不定参数给出的填充内容
{                                                             //现在只支持最简单的%s, %d两种格式化方式，不能指定任何其余参数
	while(*template != 0)
	{
		if(*template != '%') *buffer++ = *template++;
		else
		{
			template++;
			if(*template == 'd')
			{
				int num = va_arg(var_list, int);
				char *num_str = int2str(num);
				while(*num_str!=0) 
				{
					*buffer++ = *num_str;
					*num_str = 0;
					num_str++;
				}
			}
			else if(*template == 's')
			{
				char *content = va_arg(var_list, char*);
				while(*content!=0) 
				{
					*buffer++ = *content;
					*content = 0;
					content++;
				}

			}
			template++;
		}
	}
}


void h_print(char *template, ...)      //与标准printf对标的输出函数，但是功能比较弱，格式化只支持%s,%d，转义字符支持\r,\n,\b,\t
{
	char *buffer = character_buffer;
	va_list var_list;
	va_start(var_list, template);

	format(template, buffer, var_list);

	va_end(var_list);


	while(*buffer != 0)
	{
		if(*buffer == '\n')
		{
			char_position = char_position + (100-num_in_one_line)*one_character + one_line;
			num_in_one_line = 0;
		}
		else if(*buffer == '\t')
		{
			num_in_one_line += 4;
			char_position += 32;
		}
		else if(*buffer == '\r')
		{
			char_position -= num_in_one_line*one_character;
			num_in_one_line = 0;
		}
		else if(*buffer == '\b')
		{
			char_position = char_position-16*screen.width;
		}
		else
		{
			print_char(char_position, *buffer, Red, Black);
			*buffer = 0; //此处很重要，每个字符输出过了之后必须清空buffer的这个位置，否则下次还会被输出，如果没覆盖的话
			num_in_one_line ++;
			char_position += one_character;
			if(num_in_one_line%100 == 0)
			{
				num_in_one_line = 0;
				char_position += one_line;
			}
		}

		buffer++;
	}
}



void color_print(Color character_color, Color back_color, char *template, ...)
{
	char *buffer = character_buffer;
	va_list var_list;
	va_start(var_list, template);

	format(template, buffer, var_list);

	va_end(var_list);

	//h_print("%d", character_color);

	while(*buffer != 0)
	{
		if(*buffer == '\n')
		{
			char_position = char_position + (100-num_in_one_line)*one_character + one_line;
			num_in_one_line = 0;
		}
		else if(*buffer == '\t')
		{
			num_in_one_line += 4;
			char_position += 32;
		}
		else if(*buffer == '\r')
		{
			char_position -= num_in_one_line*one_character;
			num_in_one_line = 0;
		}
		else if(*buffer == '\b')
		{
			char_position = char_position-16*screen.width;
		}
		else
		{
			print_char(char_position, *buffer, character_color, back_color);
			*buffer = 0; //此处很重要，每个字符输出过了之后必须清空buffer的这个位置，否则下次还会被输出，如果没覆盖的话
			num_in_one_line ++;
			char_position += one_character;
			if(num_in_one_line%100 == 0)
			{
				num_in_one_line = 0;
				char_position += one_line;
			}
		}

		buffer++;
	}	
}




void line(int x1, int y1, int x2, int y2, Color line_color)   //使用Bresenham直线算法的直线绘制方法，单像素宽度，但是有问题，还没调试好
{
	int dx = x2-x1;
	int dy = y2-y1;
	if(dx<0) dx = -dx;
	if(dy<0) dy = -dy;

	if(dx>=dy)        //沿x方向延展
	{
		if(x2<x1)  //x2应该大于x1，否则交换两点的顺序
		{
			int a = x1;
			x1 = x2;
			x2 = a;

			a = y1;
			y1 = y2;
			y2 = a;
		}
		int step_y = y2>y1?1:-1;
		int error = -dx;
		int y = y1;
		int dy2 = dy*2;
		int dx2 = (x2-x1)*2;
		for(int x=x1; x<=x2; x++)
		{
			pixel(x, y, color_table[line_color][0], color_table[line_color][1], color_table[line_color][2]);
			error += dy2;
			if(error>0)
			{
				y += step_y;
				error-=dx2;
			}
		}
	}
	else
	{
		if(y2<y1)  //x2应该大于x1，否则交换两点的顺序
		{
			int a = x1;
			x1 = x2;
			x2 = a;

			a = y1;
			y1 = y2;
			y2 = a;
		}
		int step_x = x2>x1?1:-1;
		int error = -dy;
		int x = x1;
		int dx2 = dx*2;
		int dy2 = (y2-y1)*2;
		for(int y=y1; y<=y2; y++)
		{
			pixel(x, y, color_table[line_color][0], color_table[line_color][1], color_table[line_color][2]);
			error += dx2;
			if(error>0)
			{
				x += step_x;
				error-=dy2;
			}
		}
	}


}

void circle(int x1, int y1, int r)    //中点画圆算法，代码也是抄的， 无填充，单像素边缘
{
	int x = 0, y = r;
	int d = 1-r;

	while(y>x)
	{
		pixel(x+x1, y+y1, 255, 0, 0);
		pixel(y+x1, x+y1, 255, 0, 0);
		pixel(-x+x1, y+y1, 255, 0, 0);
		pixel(-y+x1, x+y1, 255, 0, 0);
		pixel(-x+x1, -y+y1, 255, 0, 0);
		pixel(-y+x1, -x+y1, 255, 0, 0);
		pixel(x+x1, -y+y1, 255, 0, 0);
		pixel(y+x1, -x+y1, 255, 0, 0);
		if(d<0) d = d+2*x+3;
		else 
		{
			d = d+2*(x-y)+5;
			y--;
		}
		x++;
	}

}


void rect(int x1, int y1, int width, int height)   //矩形绘制函数，有填充
{
	
	for(int i=y1; i<y1+height; i++)
	{
		for(int j=x1; j<x1+width; j++)
		{
			pixel(j, i, 255, 0, 0);		
		}
	}
}