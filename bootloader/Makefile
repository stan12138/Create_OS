OUTPUT_DIR = ../output/

all: $(OUTPUT_DIR)boot.bin $(OUTPUT_DIR)loader.bin 
	echo "compile done"

$(OUTPUT_DIR)boot.bin:	boot.asm
	nasm boot.asm -o $(OUTPUT_DIR)boot.bin

$(OUTPUT_DIR)loader.bin:	loader.asm
	nasm loader.asm -o $(OUTPUT_DIR)loader.bin