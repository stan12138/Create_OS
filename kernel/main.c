#include "lib.h"

void Start_Kernel(void)
{
	int position_x[16] = {400, 450, 500, 500, 500, 500, 500, 450, 400, 350, 300, 300, 300, 300, 300, 350};
	int position_y[16] = {200, 200, 200, 250, 300, 350, 400, 400, 400, 400, 400, 350, 300, 250, 200, 200};

	for(int i=0; i<16; i++)
	{
		line(400, 300, position_x[i], position_y[i], Green);
	}
	//line(400, 300, 500, 250);
	char *mess = "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL";
	char *wtf =  "abcdefghijk";

	h_print("%s, this is %d", wtf, 111);
	char *me = "hello, stan";
	h_print(me);
	h_print("%d", 99);
	h_print("xx");
	// int a = (int) Black;
	// h_print("%d\n", a);
	// a = (int) White;
	// h_print("%d\n", a);
	color_print(Magenta, Black, "this is color stan");
	for(int i=0; i<200; i++)
	{
		line(4*i, 0, 4*i, 599, Green);
	}
	for(int i=0; i<150; i++)
	{
		line(0, 4*i, 799, 4*i, Red);
	}
	line(300, 200, 500, 200, Magenta);
	line(500, 200, 500, 400, Magenta);
	line(500, 400, 300, 400, Magenta);
	line(300, 400, 300, 200, Magenta);
	while(1)
		;
}
