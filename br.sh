nasm -f elf32 -o snake.o snake.asm
ld -m elf_i386 snake.o -o snake
./snake