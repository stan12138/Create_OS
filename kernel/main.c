#include "lib.h"
#include "show.h"



void Start_Kernel(void)
{
	int position_x[16] = {400, 450, 500, 500, 500, 500, 500, 450, 400, 350, 300, 300, 300, 300, 300, 350};
	int position_y[16] = {200, 200, 200, 250, 300, 350, 400, 400, 400, 400, 400, 350, 300, 250, 200, 200};

	for(int i=2; i<7; i++)
	{
		line(400, 300, position_x[i], position_y[i]);
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
	line(100, 100, 700, 100);
	line(400, 300, 600, 200);
	line(400, 300, 500, 100);
	while(1)
		;
}
