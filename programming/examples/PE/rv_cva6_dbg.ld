OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY {
    ICCM    : ORIGIN = 0x00005000, LENGTH = 0x2000
    DCCM    : ORIGIN = 0x00007000, LENGTH = 0x2000
}

SECTIONS
{
	.text.init : {
			* (.text.init);
	} > ICCM
	.text : {
	      * (.text);
	} > ICCM
	.data : {
	      * (.data);
	} > DCCM
	.srodata : {
	      * (.srodata);
	} > DCCM
	.rodata : {
	      * (.rodata);
	} > DCCM
	.bss : {
	     * (.bss);
	} > DCCM
}