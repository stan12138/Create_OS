struct Info
{
	int width;
	int height;

	int pixel_size;
	int *base;
};

struct Info screen = {800, 600, 4, (int *)0xffff800000a00000};


void pixel(int x, int y, char r, char g, char b)
{
	int *addr = screen.base;
	addr += x*screen.width+y;
	*((char *)addr+0) = b;
	*((char *)addr+1) = g;
	*((char *)addr+2) = r;
	*((char *)addr+3) = (char)0x00;
}



void line(int x1, int y1, int x2, int y2)
{
	int dx = x2-x1;
	int dy = y2-y1;
	//double k = (double)dy/dx;
	int k = 1;
	int y = y1;
	int x = 0;
	// for(x=x1; x<=x2; x++)
	// {
	// 	if(x<800 && y<600) pixel(x, y, 255, 0, 0);
	// 	//y = (int)(k+y+0.5);
	// }
	for(x=100; x<300; x++)
	{
		pixel(x, 100, 255, 0, 0);
	}
	

}



void rect(int x1, int y1, int width, int height)
{
	
	for(int i=y1; i<y1+height; i++)
	{
		for(int j=x1; j<x1+width; j++)
		{
			pixel(i, j, 255, 0, 0);
			// int *addr = screen.base;
			// addr += i*screen.width+j;
			// *((char *)addr+0)=(char)0x00;
			// *((char *)addr+1)=(char)0x00;
			// *((char *)addr+2)=(char)0xff;
			// *((char *)addr+3)=(char)0x00;		
		}
	}
}





void Start_Kernel(void)
{
	float a;

	rect(300, 200, 200, 200);

	line(100, 100, 300, 300);

	while(1)
		;
}
