
obj/kern/kernel:     file format elf32-i386


Disassembly of section .text:

f0100000 <_start+0xeffffff4>:
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
	movw	$0x1234,0x472			# warm boot
f0100000:	02 b0 ad 1b 00 00    	add    0x1bad(%eax),%dh
f0100006:	00 00                	add    %al,(%eax)
f0100008:	fe 4f 52             	decb   0x52(%edi)
f010000b:	e4 66                	in     $0x66,%al

f010000c <entry>:
f010000c:	66 c7 05 72 04 00 00 	movw   $0x1234,0x472
f0100013:	34 12 
	# sufficient until we set up our real page table in mem_init
	# in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	movl	$(RELOC(entry_pgdir)), %eax
f0100015:	b8 00 00 11 00       	mov    $0x110000,%eax
	movl	%eax, %cr3
f010001a:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl	%cr0, %eax
f010001d:	0f 20 c0             	mov    %cr0,%eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
f0100020:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl	%eax, %cr0
f0100025:	0f 22 c0             	mov    %eax,%cr0

	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
	mov	$relocated, %eax
f0100028:	b8 2f 00 10 f0       	mov    $0xf010002f,%eax
	jmp	*%eax
f010002d:	ff e0                	jmp    *%eax

f010002f <relocated>:
relocated:

	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	movl	$0x0,%ebp			# nuke frame pointer
f010002f:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Set the stack pointer
	movl	$(bootstacktop),%esp
f0100034:	bc 00 00 11 f0       	mov    $0xf0110000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 02 00 00 00       	call   f0100040 <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <i386_init>:
#include <kern/kclock.h>


void
i386_init(void)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	83 ec 18             	sub    $0x18,%esp
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f0100046:	b8 40 29 11 f0       	mov    $0xf0112940,%eax
f010004b:	2d 00 23 11 f0       	sub    $0xf0112300,%eax
f0100050:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100054:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010005b:	00 
f010005c:	c7 04 24 00 23 11 f0 	movl   $0xf0112300,(%esp)
f0100063:	e8 4f 16 00 00       	call   f01016b7 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f0100068:	e8 a2 04 00 00       	call   f010050f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f010006d:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f0100074:	00 
f0100075:	c7 04 24 60 1b 10 f0 	movl   $0xf0101b60,(%esp)
f010007c:	e8 d6 0a 00 00       	call   f0100b57 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f0100081:	e8 42 09 00 00       	call   f01009c8 <mem_init>

	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
f0100086:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010008d:	e8 d8 07 00 00       	call   f010086a <monitor>
f0100092:	eb f2                	jmp    f0100086 <i386_init+0x46>

f0100094 <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f0100094:	55                   	push   %ebp
f0100095:	89 e5                	mov    %esp,%ebp
f0100097:	56                   	push   %esi
f0100098:	53                   	push   %ebx
f0100099:	83 ec 10             	sub    $0x10,%esp
f010009c:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f010009f:	83 3d 44 29 11 f0 00 	cmpl   $0x0,0xf0112944
f01000a6:	75 3d                	jne    f01000e5 <_panic+0x51>
		goto dead;
	panicstr = fmt;
f01000a8:	89 35 44 29 11 f0    	mov    %esi,0xf0112944

	// Be extra sure that the machine is in as reasonable state
	asm volatile("cli; cld");
f01000ae:	fa                   	cli    
f01000af:	fc                   	cld    

	va_start(ap, fmt);
f01000b0:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic at %s:%d: ", file, line);
f01000b3:	8b 45 0c             	mov    0xc(%ebp),%eax
f01000b6:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000ba:	8b 45 08             	mov    0x8(%ebp),%eax
f01000bd:	89 44 24 04          	mov    %eax,0x4(%esp)
f01000c1:	c7 04 24 7b 1b 10 f0 	movl   $0xf0101b7b,(%esp)
f01000c8:	e8 8a 0a 00 00       	call   f0100b57 <cprintf>
	vcprintf(fmt, ap);
f01000cd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01000d1:	89 34 24             	mov    %esi,(%esp)
f01000d4:	e8 4b 0a 00 00       	call   f0100b24 <vcprintf>
	cprintf("\n");
f01000d9:	c7 04 24 b7 1b 10 f0 	movl   $0xf0101bb7,(%esp)
f01000e0:	e8 72 0a 00 00       	call   f0100b57 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f01000e5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000ec:	e8 79 07 00 00       	call   f010086a <monitor>
f01000f1:	eb f2                	jmp    f01000e5 <_panic+0x51>

f01000f3 <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01000f3:	55                   	push   %ebp
f01000f4:	89 e5                	mov    %esp,%ebp
f01000f6:	53                   	push   %ebx
f01000f7:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01000fa:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01000fd:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100100:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100104:	8b 45 08             	mov    0x8(%ebp),%eax
f0100107:	89 44 24 04          	mov    %eax,0x4(%esp)
f010010b:	c7 04 24 93 1b 10 f0 	movl   $0xf0101b93,(%esp)
f0100112:	e8 40 0a 00 00       	call   f0100b57 <cprintf>
	vcprintf(fmt, ap);
f0100117:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010011b:	8b 45 10             	mov    0x10(%ebp),%eax
f010011e:	89 04 24             	mov    %eax,(%esp)
f0100121:	e8 fe 09 00 00       	call   f0100b24 <vcprintf>
	cprintf("\n");
f0100126:	c7 04 24 b7 1b 10 f0 	movl   $0xf0101bb7,(%esp)
f010012d:	e8 25 0a 00 00       	call   f0100b57 <cprintf>
	va_end(ap);
}
f0100132:	83 c4 14             	add    $0x14,%esp
f0100135:	5b                   	pop    %ebx
f0100136:	5d                   	pop    %ebp
f0100137:	c3                   	ret    
f0100138:	66 90                	xchg   %ax,%ax
f010013a:	66 90                	xchg   %ax,%ax
f010013c:	66 90                	xchg   %ax,%ax
f010013e:	66 90                	xchg   %ax,%ax

f0100140 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100140:	55                   	push   %ebp
f0100141:	89 e5                	mov    %esp,%ebp

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100143:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100148:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100149:	a8 01                	test   $0x1,%al
f010014b:	74 08                	je     f0100155 <serial_proc_data+0x15>
f010014d:	b2 f8                	mov    $0xf8,%dl
f010014f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100150:	0f b6 c0             	movzbl %al,%eax
f0100153:	eb 05                	jmp    f010015a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100155:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010015a:	5d                   	pop    %ebp
f010015b:	c3                   	ret    

f010015c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010015c:	55                   	push   %ebp
f010015d:	89 e5                	mov    %esp,%ebp
f010015f:	53                   	push   %ebx
f0100160:	83 ec 04             	sub    $0x4,%esp
f0100163:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100165:	eb 2a                	jmp    f0100191 <cons_intr+0x35>
		if (c == 0)
f0100167:	85 d2                	test   %edx,%edx
f0100169:	74 26                	je     f0100191 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010016b:	a1 24 25 11 f0       	mov    0xf0112524,%eax
f0100170:	8d 48 01             	lea    0x1(%eax),%ecx
f0100173:	89 0d 24 25 11 f0    	mov    %ecx,0xf0112524
f0100179:	88 90 20 23 11 f0    	mov    %dl,-0xfeedce0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010017f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100185:	75 0a                	jne    f0100191 <cons_intr+0x35>
			cons.wpos = 0;
f0100187:	c7 05 24 25 11 f0 00 	movl   $0x0,0xf0112524
f010018e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100191:	ff d3                	call   *%ebx
f0100193:	89 c2                	mov    %eax,%edx
f0100195:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100198:	75 cd                	jne    f0100167 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010019a:	83 c4 04             	add    $0x4,%esp
f010019d:	5b                   	pop    %ebx
f010019e:	5d                   	pop    %ebp
f010019f:	c3                   	ret    

f01001a0 <kbd_proc_data>:
f01001a0:	ba 64 00 00 00       	mov    $0x64,%edx
f01001a5:	ec                   	in     (%dx),%al
	int c;
	uint8_t stat, data;
	static uint32_t shift;

	stat = inb(KBSTATP);
	if ((stat & KBS_DIB) == 0)
f01001a6:	a8 01                	test   $0x1,%al
f01001a8:	0f 84 f7 00 00 00    	je     f01002a5 <kbd_proc_data+0x105>
		return -1;
	// Ignore data from mouse.
	if (stat & KBS_TERR)
f01001ae:	a8 20                	test   $0x20,%al
f01001b0:	0f 85 f5 00 00 00    	jne    f01002ab <kbd_proc_data+0x10b>
f01001b6:	b2 60                	mov    $0x60,%dl
f01001b8:	ec                   	in     (%dx),%al
f01001b9:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f01001bb:	3c e0                	cmp    $0xe0,%al
f01001bd:	75 0d                	jne    f01001cc <kbd_proc_data+0x2c>
		// E0 escape character
		shift |= E0ESC;
f01001bf:	83 0d 00 23 11 f0 40 	orl    $0x40,0xf0112300
		return 0;
f01001c6:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01001cb:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f01001cc:	55                   	push   %ebp
f01001cd:	89 e5                	mov    %esp,%ebp
f01001cf:	53                   	push   %ebx
f01001d0:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f01001d3:	84 c0                	test   %al,%al
f01001d5:	79 37                	jns    f010020e <kbd_proc_data+0x6e>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f01001d7:	8b 0d 00 23 11 f0    	mov    0xf0112300,%ecx
f01001dd:	89 cb                	mov    %ecx,%ebx
f01001df:	83 e3 40             	and    $0x40,%ebx
f01001e2:	83 e0 7f             	and    $0x7f,%eax
f01001e5:	85 db                	test   %ebx,%ebx
f01001e7:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01001ea:	0f b6 d2             	movzbl %dl,%edx
f01001ed:	0f b6 82 00 1d 10 f0 	movzbl -0xfefe300(%edx),%eax
f01001f4:	83 c8 40             	or     $0x40,%eax
f01001f7:	0f b6 c0             	movzbl %al,%eax
f01001fa:	f7 d0                	not    %eax
f01001fc:	21 c1                	and    %eax,%ecx
f01001fe:	89 0d 00 23 11 f0    	mov    %ecx,0xf0112300
		return 0;
f0100204:	b8 00 00 00 00       	mov    $0x0,%eax
f0100209:	e9 a3 00 00 00       	jmp    f01002b1 <kbd_proc_data+0x111>
	} else if (shift & E0ESC) {
f010020e:	8b 0d 00 23 11 f0    	mov    0xf0112300,%ecx
f0100214:	f6 c1 40             	test   $0x40,%cl
f0100217:	74 0e                	je     f0100227 <kbd_proc_data+0x87>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100219:	83 c8 80             	or     $0xffffff80,%eax
f010021c:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f010021e:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100221:	89 0d 00 23 11 f0    	mov    %ecx,0xf0112300
	}

	shift |= shiftcode[data];
f0100227:	0f b6 d2             	movzbl %dl,%edx
f010022a:	0f b6 82 00 1d 10 f0 	movzbl -0xfefe300(%edx),%eax
f0100231:	0b 05 00 23 11 f0    	or     0xf0112300,%eax
	shift ^= togglecode[data];
f0100237:	0f b6 8a 00 1c 10 f0 	movzbl -0xfefe400(%edx),%ecx
f010023e:	31 c8                	xor    %ecx,%eax
f0100240:	a3 00 23 11 f0       	mov    %eax,0xf0112300

	c = charcode[shift & (CTL | SHIFT)][data];
f0100245:	89 c1                	mov    %eax,%ecx
f0100247:	83 e1 03             	and    $0x3,%ecx
f010024a:	8b 0c 8d e0 1b 10 f0 	mov    -0xfefe420(,%ecx,4),%ecx
f0100251:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f0100255:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100258:	a8 08                	test   $0x8,%al
f010025a:	74 1b                	je     f0100277 <kbd_proc_data+0xd7>
		if ('a' <= c && c <= 'z')
f010025c:	89 da                	mov    %ebx,%edx
f010025e:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100261:	83 f9 19             	cmp    $0x19,%ecx
f0100264:	77 05                	ja     f010026b <kbd_proc_data+0xcb>
			c += 'A' - 'a';
f0100266:	83 eb 20             	sub    $0x20,%ebx
f0100269:	eb 0c                	jmp    f0100277 <kbd_proc_data+0xd7>
		else if ('A' <= c && c <= 'Z')
f010026b:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f010026e:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100271:	83 fa 19             	cmp    $0x19,%edx
f0100274:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100277:	f7 d0                	not    %eax
f0100279:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f010027b:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010027d:	f6 c2 06             	test   $0x6,%dl
f0100280:	75 2f                	jne    f01002b1 <kbd_proc_data+0x111>
f0100282:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100288:	75 27                	jne    f01002b1 <kbd_proc_data+0x111>
		cprintf("Rebooting!\n");
f010028a:	c7 04 24 ad 1b 10 f0 	movl   $0xf0101bad,(%esp)
f0100291:	e8 c1 08 00 00       	call   f0100b57 <cprintf>
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100296:	ba 92 00 00 00       	mov    $0x92,%edx
f010029b:	b8 03 00 00 00       	mov    $0x3,%eax
f01002a0:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f01002a1:	89 d8                	mov    %ebx,%eax
f01002a3:	eb 0c                	jmp    f01002b1 <kbd_proc_data+0x111>
	uint8_t stat, data;
	static uint32_t shift;

	stat = inb(KBSTATP);
	if ((stat & KBS_DIB) == 0)
		return -1;
f01002a5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01002aa:	c3                   	ret    
	// Ignore data from mouse.
	if (stat & KBS_TERR)
		return -1;
f01002ab:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01002b0:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01002b1:	83 c4 14             	add    $0x14,%esp
f01002b4:	5b                   	pop    %ebx
f01002b5:	5d                   	pop    %ebp
f01002b6:	c3                   	ret    

f01002b7 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f01002b7:	55                   	push   %ebp
f01002b8:	89 e5                	mov    %esp,%ebp
f01002ba:	57                   	push   %edi
f01002bb:	56                   	push   %esi
f01002bc:	53                   	push   %ebx
f01002bd:	83 ec 1c             	sub    $0x1c,%esp
f01002c0:	89 c7                	mov    %eax,%edi
f01002c2:	bb 01 32 00 00       	mov    $0x3201,%ebx

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01002c7:	be fd 03 00 00       	mov    $0x3fd,%esi
f01002cc:	b9 84 00 00 00       	mov    $0x84,%ecx
f01002d1:	eb 06                	jmp    f01002d9 <cons_putc+0x22>
f01002d3:	89 ca                	mov    %ecx,%edx
f01002d5:	ec                   	in     (%dx),%al
f01002d6:	ec                   	in     (%dx),%al
f01002d7:	ec                   	in     (%dx),%al
f01002d8:	ec                   	in     (%dx),%al
f01002d9:	89 f2                	mov    %esi,%edx
f01002db:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;

	for (i = 0;
f01002dc:	a8 20                	test   $0x20,%al
f01002de:	75 05                	jne    f01002e5 <cons_putc+0x2e>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f01002e0:	83 eb 01             	sub    $0x1,%ebx
f01002e3:	75 ee                	jne    f01002d3 <cons_putc+0x1c>
	     i++)
		delay();

	outb(COM1 + COM_TX, c);
f01002e5:	89 f8                	mov    %edi,%eax
f01002e7:	0f b6 c0             	movzbl %al,%eax
f01002ea:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01002ed:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01002f2:	ee                   	out    %al,(%dx)
f01002f3:	bb 01 32 00 00       	mov    $0x3201,%ebx

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01002f8:	be 79 03 00 00       	mov    $0x379,%esi
f01002fd:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100302:	eb 06                	jmp    f010030a <cons_putc+0x53>
f0100304:	89 ca                	mov    %ecx,%edx
f0100306:	ec                   	in     (%dx),%al
f0100307:	ec                   	in     (%dx),%al
f0100308:	ec                   	in     (%dx),%al
f0100309:	ec                   	in     (%dx),%al
f010030a:	89 f2                	mov    %esi,%edx
f010030c:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f010030d:	84 c0                	test   %al,%al
f010030f:	78 05                	js     f0100316 <cons_putc+0x5f>
f0100311:	83 eb 01             	sub    $0x1,%ebx
f0100314:	75 ee                	jne    f0100304 <cons_putc+0x4d>
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100316:	ba 78 03 00 00       	mov    $0x378,%edx
f010031b:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f010031f:	ee                   	out    %al,(%dx)
f0100320:	b2 7a                	mov    $0x7a,%dl
f0100322:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100327:	ee                   	out    %al,(%dx)
f0100328:	b8 08 00 00 00       	mov    $0x8,%eax
f010032d:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f010032e:	89 fa                	mov    %edi,%edx
f0100330:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100336:	89 f8                	mov    %edi,%eax
f0100338:	80 cc 07             	or     $0x7,%ah
f010033b:	85 d2                	test   %edx,%edx
f010033d:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f0100340:	89 f8                	mov    %edi,%eax
f0100342:	0f b6 c0             	movzbl %al,%eax
f0100345:	83 f8 09             	cmp    $0x9,%eax
f0100348:	74 78                	je     f01003c2 <cons_putc+0x10b>
f010034a:	83 f8 09             	cmp    $0x9,%eax
f010034d:	7f 0a                	jg     f0100359 <cons_putc+0xa2>
f010034f:	83 f8 08             	cmp    $0x8,%eax
f0100352:	74 18                	je     f010036c <cons_putc+0xb5>
f0100354:	e9 9d 00 00 00       	jmp    f01003f6 <cons_putc+0x13f>
f0100359:	83 f8 0a             	cmp    $0xa,%eax
f010035c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100360:	74 3a                	je     f010039c <cons_putc+0xe5>
f0100362:	83 f8 0d             	cmp    $0xd,%eax
f0100365:	74 3d                	je     f01003a4 <cons_putc+0xed>
f0100367:	e9 8a 00 00 00       	jmp    f01003f6 <cons_putc+0x13f>
	case '\b':
		if (crt_pos > 0) {
f010036c:	0f b7 05 28 25 11 f0 	movzwl 0xf0112528,%eax
f0100373:	66 85 c0             	test   %ax,%ax
f0100376:	0f 84 e5 00 00 00    	je     f0100461 <cons_putc+0x1aa>
			crt_pos--;
f010037c:	83 e8 01             	sub    $0x1,%eax
f010037f:	66 a3 28 25 11 f0    	mov    %ax,0xf0112528
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100385:	0f b7 c0             	movzwl %ax,%eax
f0100388:	66 81 e7 00 ff       	and    $0xff00,%di
f010038d:	83 cf 20             	or     $0x20,%edi
f0100390:	8b 15 2c 25 11 f0    	mov    0xf011252c,%edx
f0100396:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010039a:	eb 78                	jmp    f0100414 <cons_putc+0x15d>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010039c:	66 83 05 28 25 11 f0 	addw   $0x50,0xf0112528
f01003a3:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f01003a4:	0f b7 05 28 25 11 f0 	movzwl 0xf0112528,%eax
f01003ab:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f01003b1:	c1 e8 16             	shr    $0x16,%eax
f01003b4:	8d 04 80             	lea    (%eax,%eax,4),%eax
f01003b7:	c1 e0 04             	shl    $0x4,%eax
f01003ba:	66 a3 28 25 11 f0    	mov    %ax,0xf0112528
f01003c0:	eb 52                	jmp    f0100414 <cons_putc+0x15d>
		break;
	case '\t':
		cons_putc(' ');
f01003c2:	b8 20 00 00 00       	mov    $0x20,%eax
f01003c7:	e8 eb fe ff ff       	call   f01002b7 <cons_putc>
		cons_putc(' ');
f01003cc:	b8 20 00 00 00       	mov    $0x20,%eax
f01003d1:	e8 e1 fe ff ff       	call   f01002b7 <cons_putc>
		cons_putc(' ');
f01003d6:	b8 20 00 00 00       	mov    $0x20,%eax
f01003db:	e8 d7 fe ff ff       	call   f01002b7 <cons_putc>
		cons_putc(' ');
f01003e0:	b8 20 00 00 00       	mov    $0x20,%eax
f01003e5:	e8 cd fe ff ff       	call   f01002b7 <cons_putc>
		cons_putc(' ');
f01003ea:	b8 20 00 00 00       	mov    $0x20,%eax
f01003ef:	e8 c3 fe ff ff       	call   f01002b7 <cons_putc>
f01003f4:	eb 1e                	jmp    f0100414 <cons_putc+0x15d>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f01003f6:	0f b7 05 28 25 11 f0 	movzwl 0xf0112528,%eax
f01003fd:	8d 50 01             	lea    0x1(%eax),%edx
f0100400:	66 89 15 28 25 11 f0 	mov    %dx,0xf0112528
f0100407:	0f b7 c0             	movzwl %ax,%eax
f010040a:	8b 15 2c 25 11 f0    	mov    0xf011252c,%edx
f0100410:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100414:	66 81 3d 28 25 11 f0 	cmpw   $0x7cf,0xf0112528
f010041b:	cf 07 
f010041d:	76 42                	jbe    f0100461 <cons_putc+0x1aa>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010041f:	a1 2c 25 11 f0       	mov    0xf011252c,%eax
f0100424:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010042b:	00 
f010042c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100432:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100436:	89 04 24             	mov    %eax,(%esp)
f0100439:	e8 c6 12 00 00       	call   f0101704 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010043e:	8b 15 2c 25 11 f0    	mov    0xf011252c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100444:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100449:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010044f:	83 c0 01             	add    $0x1,%eax
f0100452:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100457:	75 f0                	jne    f0100449 <cons_putc+0x192>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100459:	66 83 2d 28 25 11 f0 	subw   $0x50,0xf0112528
f0100460:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100461:	8b 0d 30 25 11 f0    	mov    0xf0112530,%ecx
f0100467:	b8 0e 00 00 00       	mov    $0xe,%eax
f010046c:	89 ca                	mov    %ecx,%edx
f010046e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010046f:	0f b7 1d 28 25 11 f0 	movzwl 0xf0112528,%ebx
f0100476:	8d 71 01             	lea    0x1(%ecx),%esi
f0100479:	89 d8                	mov    %ebx,%eax
f010047b:	66 c1 e8 08          	shr    $0x8,%ax
f010047f:	89 f2                	mov    %esi,%edx
f0100481:	ee                   	out    %al,(%dx)
f0100482:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100487:	89 ca                	mov    %ecx,%edx
f0100489:	ee                   	out    %al,(%dx)
f010048a:	89 d8                	mov    %ebx,%eax
f010048c:	89 f2                	mov    %esi,%edx
f010048e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010048f:	83 c4 1c             	add    $0x1c,%esp
f0100492:	5b                   	pop    %ebx
f0100493:	5e                   	pop    %esi
f0100494:	5f                   	pop    %edi
f0100495:	5d                   	pop    %ebp
f0100496:	c3                   	ret    

f0100497 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100497:	80 3d 34 25 11 f0 00 	cmpb   $0x0,0xf0112534
f010049e:	74 11                	je     f01004b1 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f01004a0:	55                   	push   %ebp
f01004a1:	89 e5                	mov    %esp,%ebp
f01004a3:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f01004a6:	b8 40 01 10 f0       	mov    $0xf0100140,%eax
f01004ab:	e8 ac fc ff ff       	call   f010015c <cons_intr>
}
f01004b0:	c9                   	leave  
f01004b1:	f3 c3                	repz ret 

f01004b3 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f01004b3:	55                   	push   %ebp
f01004b4:	89 e5                	mov    %esp,%ebp
f01004b6:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f01004b9:	b8 a0 01 10 f0       	mov    $0xf01001a0,%eax
f01004be:	e8 99 fc ff ff       	call   f010015c <cons_intr>
}
f01004c3:	c9                   	leave  
f01004c4:	c3                   	ret    

f01004c5 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f01004c5:	55                   	push   %ebp
f01004c6:	89 e5                	mov    %esp,%ebp
f01004c8:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f01004cb:	e8 c7 ff ff ff       	call   f0100497 <serial_intr>
	kbd_intr();
f01004d0:	e8 de ff ff ff       	call   f01004b3 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f01004d5:	a1 20 25 11 f0       	mov    0xf0112520,%eax
f01004da:	3b 05 24 25 11 f0    	cmp    0xf0112524,%eax
f01004e0:	74 26                	je     f0100508 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01004e2:	8d 50 01             	lea    0x1(%eax),%edx
f01004e5:	89 15 20 25 11 f0    	mov    %edx,0xf0112520
f01004eb:	0f b6 88 20 23 11 f0 	movzbl -0xfeedce0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f01004f2:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f01004f4:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01004fa:	75 11                	jne    f010050d <cons_getc+0x48>
			cons.rpos = 0;
f01004fc:	c7 05 20 25 11 f0 00 	movl   $0x0,0xf0112520
f0100503:	00 00 00 
f0100506:	eb 05                	jmp    f010050d <cons_getc+0x48>
		return c;
	}
	return 0;
f0100508:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010050d:	c9                   	leave  
f010050e:	c3                   	ret    

f010050f <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f010050f:	55                   	push   %ebp
f0100510:	89 e5                	mov    %esp,%ebp
f0100512:	57                   	push   %edi
f0100513:	56                   	push   %esi
f0100514:	53                   	push   %ebx
f0100515:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f0100518:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f010051f:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100526:	5a a5 
	if (*cp != 0xA55A) {
f0100528:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f010052f:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100533:	74 11                	je     f0100546 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100535:	c7 05 30 25 11 f0 b4 	movl   $0x3b4,0xf0112530
f010053c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010053f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100544:	eb 16                	jmp    f010055c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100546:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010054d:	c7 05 30 25 11 f0 d4 	movl   $0x3d4,0xf0112530
f0100554:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100557:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}

	/* Extract cursor location */
	outb(addr_6845, 14);
f010055c:	8b 0d 30 25 11 f0    	mov    0xf0112530,%ecx
f0100562:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100567:	89 ca                	mov    %ecx,%edx
f0100569:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010056a:	8d 59 01             	lea    0x1(%ecx),%ebx

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010056d:	89 da                	mov    %ebx,%edx
f010056f:	ec                   	in     (%dx),%al
f0100570:	0f b6 f0             	movzbl %al,%esi
f0100573:	c1 e6 08             	shl    $0x8,%esi
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100576:	b8 0f 00 00 00       	mov    $0xf,%eax
f010057b:	89 ca                	mov    %ecx,%edx
f010057d:	ee                   	out    %al,(%dx)

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010057e:	89 da                	mov    %ebx,%edx
f0100580:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100581:	89 3d 2c 25 11 f0    	mov    %edi,0xf011252c

	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100587:	0f b6 d8             	movzbl %al,%ebx
f010058a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010058c:	66 89 35 28 25 11 f0 	mov    %si,0xf0112528
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100593:	be fa 03 00 00       	mov    $0x3fa,%esi
f0100598:	b8 00 00 00 00       	mov    $0x0,%eax
f010059d:	89 f2                	mov    %esi,%edx
f010059f:	ee                   	out    %al,(%dx)
f01005a0:	b2 fb                	mov    $0xfb,%dl
f01005a2:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f01005a7:	ee                   	out    %al,(%dx)
f01005a8:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f01005ad:	b8 0c 00 00 00       	mov    $0xc,%eax
f01005b2:	89 da                	mov    %ebx,%edx
f01005b4:	ee                   	out    %al,(%dx)
f01005b5:	b2 f9                	mov    $0xf9,%dl
f01005b7:	b8 00 00 00 00       	mov    $0x0,%eax
f01005bc:	ee                   	out    %al,(%dx)
f01005bd:	b2 fb                	mov    $0xfb,%dl
f01005bf:	b8 03 00 00 00       	mov    $0x3,%eax
f01005c4:	ee                   	out    %al,(%dx)
f01005c5:	b2 fc                	mov    $0xfc,%dl
f01005c7:	b8 00 00 00 00       	mov    $0x0,%eax
f01005cc:	ee                   	out    %al,(%dx)
f01005cd:	b2 f9                	mov    $0xf9,%dl
f01005cf:	b8 01 00 00 00       	mov    $0x1,%eax
f01005d4:	ee                   	out    %al,(%dx)

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005d5:	b2 fd                	mov    $0xfd,%dl
f01005d7:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01005d8:	3c ff                	cmp    $0xff,%al
f01005da:	0f 95 c1             	setne  %cl
f01005dd:	88 0d 34 25 11 f0    	mov    %cl,0xf0112534
f01005e3:	89 f2                	mov    %esi,%edx
f01005e5:	ec                   	in     (%dx),%al
f01005e6:	89 da                	mov    %ebx,%edx
f01005e8:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01005e9:	84 c9                	test   %cl,%cl
f01005eb:	75 0c                	jne    f01005f9 <cons_init+0xea>
		cprintf("Serial port does not exist!\n");
f01005ed:	c7 04 24 b9 1b 10 f0 	movl   $0xf0101bb9,(%esp)
f01005f4:	e8 5e 05 00 00       	call   f0100b57 <cprintf>
}
f01005f9:	83 c4 1c             	add    $0x1c,%esp
f01005fc:	5b                   	pop    %ebx
f01005fd:	5e                   	pop    %esi
f01005fe:	5f                   	pop    %edi
f01005ff:	5d                   	pop    %ebp
f0100600:	c3                   	ret    

f0100601 <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f0100601:	55                   	push   %ebp
f0100602:	89 e5                	mov    %esp,%ebp
f0100604:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f0100607:	8b 45 08             	mov    0x8(%ebp),%eax
f010060a:	e8 a8 fc ff ff       	call   f01002b7 <cons_putc>
}
f010060f:	c9                   	leave  
f0100610:	c3                   	ret    

f0100611 <getchar>:

int
getchar(void)
{
f0100611:	55                   	push   %ebp
f0100612:	89 e5                	mov    %esp,%ebp
f0100614:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f0100617:	e8 a9 fe ff ff       	call   f01004c5 <cons_getc>
f010061c:	85 c0                	test   %eax,%eax
f010061e:	74 f7                	je     f0100617 <getchar+0x6>
		/* do nothing */;
	return c;
}
f0100620:	c9                   	leave  
f0100621:	c3                   	ret    

f0100622 <iscons>:

int
iscons(int fdnum)
{
f0100622:	55                   	push   %ebp
f0100623:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100625:	b8 01 00 00 00       	mov    $0x1,%eax
f010062a:	5d                   	pop    %ebp
f010062b:	c3                   	ret    
f010062c:	66 90                	xchg   %ax,%ax
f010062e:	66 90                	xchg   %ax,%ax

f0100630 <mon_help>:
};

/***** Implementations of basic kernel monitor commands *****/
int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100630:	55                   	push   %ebp
f0100631:	89 e5                	mov    %esp,%ebp
f0100633:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < ARRAY_SIZE(commands); i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100636:	c7 44 24 08 00 1e 10 	movl   $0xf0101e00,0x8(%esp)
f010063d:	f0 
f010063e:	c7 44 24 04 1e 1e 10 	movl   $0xf0101e1e,0x4(%esp)
f0100645:	f0 
f0100646:	c7 04 24 23 1e 10 f0 	movl   $0xf0101e23,(%esp)
f010064d:	e8 05 05 00 00       	call   f0100b57 <cprintf>
f0100652:	c7 44 24 08 e4 1e 10 	movl   $0xf0101ee4,0x8(%esp)
f0100659:	f0 
f010065a:	c7 44 24 04 2c 1e 10 	movl   $0xf0101e2c,0x4(%esp)
f0100661:	f0 
f0100662:	c7 04 24 23 1e 10 f0 	movl   $0xf0101e23,(%esp)
f0100669:	e8 e9 04 00 00       	call   f0100b57 <cprintf>
f010066e:	c7 44 24 08 0c 1f 10 	movl   $0xf0101f0c,0x8(%esp)
f0100675:	f0 
f0100676:	c7 44 24 04 35 1e 10 	movl   $0xf0101e35,0x4(%esp)
f010067d:	f0 
f010067e:	c7 04 24 23 1e 10 f0 	movl   $0xf0101e23,(%esp)
f0100685:	e8 cd 04 00 00       	call   f0100b57 <cprintf>
	return 0;
}
f010068a:	b8 00 00 00 00       	mov    $0x0,%eax
f010068f:	c9                   	leave  
f0100690:	c3                   	ret    

f0100691 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100691:	55                   	push   %ebp
f0100692:	89 e5                	mov    %esp,%ebp
f0100694:	83 ec 18             	sub    $0x18,%esp
	extern char _start[], entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100697:	c7 04 24 3f 1e 10 f0 	movl   $0xf0101e3f,(%esp)
f010069e:	e8 b4 04 00 00       	call   f0100b57 <cprintf>
	cprintf("  _start                  %08x (phys)\n", _start);
f01006a3:	c7 44 24 04 0c 00 10 	movl   $0x10000c,0x4(%esp)
f01006aa:	00 
f01006ab:	c7 04 24 34 1f 10 f0 	movl   $0xf0101f34,(%esp)
f01006b2:	e8 a0 04 00 00       	call   f0100b57 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f01006b7:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f01006be:	00 
f01006bf:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01006c6:	f0 
f01006c7:	c7 04 24 5c 1f 10 f0 	movl   $0xf0101f5c,(%esp)
f01006ce:	e8 84 04 00 00       	call   f0100b57 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01006d3:	c7 44 24 08 47 1b 10 	movl   $0x101b47,0x8(%esp)
f01006da:	00 
f01006db:	c7 44 24 04 47 1b 10 	movl   $0xf0101b47,0x4(%esp)
f01006e2:	f0 
f01006e3:	c7 04 24 80 1f 10 f0 	movl   $0xf0101f80,(%esp)
f01006ea:	e8 68 04 00 00       	call   f0100b57 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01006ef:	c7 44 24 08 00 23 11 	movl   $0x112300,0x8(%esp)
f01006f6:	00 
f01006f7:	c7 44 24 04 00 23 11 	movl   $0xf0112300,0x4(%esp)
f01006fe:	f0 
f01006ff:	c7 04 24 a4 1f 10 f0 	movl   $0xf0101fa4,(%esp)
f0100706:	e8 4c 04 00 00       	call   f0100b57 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010070b:	c7 44 24 08 40 29 11 	movl   $0x112940,0x8(%esp)
f0100712:	00 
f0100713:	c7 44 24 04 40 29 11 	movl   $0xf0112940,0x4(%esp)
f010071a:	f0 
f010071b:	c7 04 24 c8 1f 10 f0 	movl   $0xf0101fc8,(%esp)
f0100722:	e8 30 04 00 00       	call   f0100b57 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		ROUNDUP(end - entry, 1024) / 1024);
f0100727:	b8 3f 2d 11 f0       	mov    $0xf0112d3f,%eax
f010072c:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
f0100731:	25 00 fc ff ff       	and    $0xfffffc00,%eax
	cprintf("  _start                  %08x (phys)\n", _start);
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100736:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f010073c:	85 c0                	test   %eax,%eax
f010073e:	0f 48 c2             	cmovs  %edx,%eax
f0100741:	c1 f8 0a             	sar    $0xa,%eax
f0100744:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100748:	c7 04 24 ec 1f 10 f0 	movl   $0xf0101fec,(%esp)
f010074f:	e8 03 04 00 00       	call   f0100b57 <cprintf>
		ROUNDUP(end - entry, 1024) / 1024);
	return 0;
}
f0100754:	b8 00 00 00 00       	mov    $0x0,%eax
f0100759:	c9                   	leave  
f010075a:	c3                   	ret    

f010075b <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f010075b:	55                   	push   %ebp
f010075c:	89 e5                	mov    %esp,%ebp
f010075e:	56                   	push   %esi
f010075f:	53                   	push   %ebx
f0100760:	83 ec 30             	sub    $0x30,%esp
	// Your code here.
  struct Eipdebuginfo info;
  int regebp = read_ebp();
  // Set a ebp pointor
  int *ebp = (int *)regebp; 
f0100763:	89 eb                	mov    %ebp,%ebx

  cprintf("Stack backtrace:\n");
f0100765:	c7 04 24 58 1e 10 f0 	movl   $0xf0101e58,(%esp)
f010076c:	e8 e6 03 00 00       	call   f0100b57 <cprintf>
    cprintf(" %08x",*(ebp+3));
    cprintf(" %08x",*(ebp+4));
    cprintf(" %08x",*(ebp+5));
    cprintf(" %08x\n",*(ebp+6));

    debuginfo_eip((int)(*(ebp+1)),&info);
f0100771:	8d 75 e0             	lea    -0x20(%ebp),%esi
  int regebp = read_ebp();
  // Set a ebp pointor
  int *ebp = (int *)regebp; 

  cprintf("Stack backtrace:\n");
  while( (int)ebp != 0x0 ){ 
f0100774:	e9 dd 00 00 00       	jmp    f0100856 <mon_backtrace+0xfb>
    cprintf("  ebp %08x",(int)ebp);
f0100779:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010077d:	c7 04 24 6a 1e 10 f0 	movl   $0xf0101e6a,(%esp)
f0100784:	e8 ce 03 00 00       	call   f0100b57 <cprintf>
    cprintf("  eip %08x",*(ebp+1));
f0100789:	8b 43 04             	mov    0x4(%ebx),%eax
f010078c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100790:	c7 04 24 75 1e 10 f0 	movl   $0xf0101e75,(%esp)
f0100797:	e8 bb 03 00 00       	call   f0100b57 <cprintf>
    cprintf("  args");
f010079c:	c7 04 24 80 1e 10 f0 	movl   $0xf0101e80,(%esp)
f01007a3:	e8 af 03 00 00       	call   f0100b57 <cprintf>
    cprintf(" %08x",*(ebp+2));
f01007a8:	8b 43 08             	mov    0x8(%ebx),%eax
f01007ab:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007af:	c7 04 24 6f 1e 10 f0 	movl   $0xf0101e6f,(%esp)
f01007b6:	e8 9c 03 00 00       	call   f0100b57 <cprintf>
    cprintf(" %08x",*(ebp+3));
f01007bb:	8b 43 0c             	mov    0xc(%ebx),%eax
f01007be:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007c2:	c7 04 24 6f 1e 10 f0 	movl   $0xf0101e6f,(%esp)
f01007c9:	e8 89 03 00 00       	call   f0100b57 <cprintf>
    cprintf(" %08x",*(ebp+4));
f01007ce:	8b 43 10             	mov    0x10(%ebx),%eax
f01007d1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007d5:	c7 04 24 6f 1e 10 f0 	movl   $0xf0101e6f,(%esp)
f01007dc:	e8 76 03 00 00       	call   f0100b57 <cprintf>
    cprintf(" %08x",*(ebp+5));
f01007e1:	8b 43 14             	mov    0x14(%ebx),%eax
f01007e4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007e8:	c7 04 24 6f 1e 10 f0 	movl   $0xf0101e6f,(%esp)
f01007ef:	e8 63 03 00 00       	call   f0100b57 <cprintf>
    cprintf(" %08x\n",*(ebp+6));
f01007f4:	8b 43 18             	mov    0x18(%ebx),%eax
f01007f7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007fb:	c7 04 24 87 1e 10 f0 	movl   $0xf0101e87,(%esp)
f0100802:	e8 50 03 00 00       	call   f0100b57 <cprintf>

    debuginfo_eip((int)(*(ebp+1)),&info);
f0100807:	89 74 24 04          	mov    %esi,0x4(%esp)
f010080b:	8b 43 04             	mov    0x4(%ebx),%eax
f010080e:	89 04 24             	mov    %eax,(%esp)
f0100811:	e8 38 04 00 00       	call   f0100c4e <debuginfo_eip>
    cprintf("      %s:%d:",info.eip_file,info.eip_line);
f0100816:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100819:	89 44 24 08          	mov    %eax,0x8(%esp)
f010081d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100820:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100824:	c7 04 24 8e 1e 10 f0 	movl   $0xf0101e8e,(%esp)
f010082b:	e8 27 03 00 00       	call   f0100b57 <cprintf>
    cprintf(" %.*s+%d\n",info.eip_fn_namelen,info.eip_fn_name,(int)(*(ebp+1))-info.eip_fn_addr);
f0100830:	8b 43 04             	mov    0x4(%ebx),%eax
f0100833:	2b 45 f0             	sub    -0x10(%ebp),%eax
f0100836:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010083a:	8b 45 e8             	mov    -0x18(%ebp),%eax
f010083d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100841:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0100844:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100848:	c7 04 24 9b 1e 10 f0 	movl   $0xf0101e9b,(%esp)
f010084f:	e8 03 03 00 00       	call   f0100b57 <cprintf>
    ebp = (int *)(*ebp);
f0100854:	8b 1b                	mov    (%ebx),%ebx
  int regebp = read_ebp();
  // Set a ebp pointor
  int *ebp = (int *)regebp; 

  cprintf("Stack backtrace:\n");
  while( (int)ebp != 0x0 ){ 
f0100856:	85 db                	test   %ebx,%ebx
f0100858:	0f 85 1b ff ff ff    	jne    f0100779 <mon_backtrace+0x1e>
    cprintf("      %s:%d:",info.eip_file,info.eip_line);
    cprintf(" %.*s+%d\n",info.eip_fn_namelen,info.eip_fn_name,(int)(*(ebp+1))-info.eip_fn_addr);
    ebp = (int *)(*ebp);
  }
	return 0;
}
f010085e:	b8 00 00 00 00       	mov    $0x0,%eax
f0100863:	83 c4 30             	add    $0x30,%esp
f0100866:	5b                   	pop    %ebx
f0100867:	5e                   	pop    %esi
f0100868:	5d                   	pop    %ebp
f0100869:	c3                   	ret    

f010086a <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f010086a:	55                   	push   %ebp
f010086b:	89 e5                	mov    %esp,%ebp
f010086d:	57                   	push   %edi
f010086e:	56                   	push   %esi
f010086f:	53                   	push   %ebx
f0100870:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f0100873:	c7 04 24 18 20 10 f0 	movl   $0xf0102018,(%esp)
f010087a:	e8 d8 02 00 00       	call   f0100b57 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f010087f:	c7 04 24 3c 20 10 f0 	movl   $0xf010203c,(%esp)
f0100886:	e8 cc 02 00 00       	call   f0100b57 <cprintf>


	while (1) {
		buf = readline("K> ");
f010088b:	c7 04 24 a5 1e 10 f0 	movl   $0xf0101ea5,(%esp)
f0100892:	e8 c9 0b 00 00       	call   f0101460 <readline>
f0100897:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100899:	85 c0                	test   %eax,%eax
f010089b:	74 ee                	je     f010088b <monitor+0x21>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f010089d:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f01008a4:	be 00 00 00 00       	mov    $0x0,%esi
f01008a9:	eb 0a                	jmp    f01008b5 <monitor+0x4b>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f01008ab:	c6 03 00             	movb   $0x0,(%ebx)
f01008ae:	89 f7                	mov    %esi,%edi
f01008b0:	8d 5b 01             	lea    0x1(%ebx),%ebx
f01008b3:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f01008b5:	0f b6 03             	movzbl (%ebx),%eax
f01008b8:	84 c0                	test   %al,%al
f01008ba:	74 63                	je     f010091f <monitor+0xb5>
f01008bc:	0f be c0             	movsbl %al,%eax
f01008bf:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008c3:	c7 04 24 a9 1e 10 f0 	movl   $0xf0101ea9,(%esp)
f01008ca:	e8 ab 0d 00 00       	call   f010167a <strchr>
f01008cf:	85 c0                	test   %eax,%eax
f01008d1:	75 d8                	jne    f01008ab <monitor+0x41>
			*buf++ = 0;
		if (*buf == 0)
f01008d3:	80 3b 00             	cmpb   $0x0,(%ebx)
f01008d6:	74 47                	je     f010091f <monitor+0xb5>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f01008d8:	83 fe 0f             	cmp    $0xf,%esi
f01008db:	75 16                	jne    f01008f3 <monitor+0x89>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f01008dd:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f01008e4:	00 
f01008e5:	c7 04 24 ae 1e 10 f0 	movl   $0xf0101eae,(%esp)
f01008ec:	e8 66 02 00 00       	call   f0100b57 <cprintf>
f01008f1:	eb 98                	jmp    f010088b <monitor+0x21>
			return 0;
		}
		argv[argc++] = buf;
f01008f3:	8d 7e 01             	lea    0x1(%esi),%edi
f01008f6:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
f01008fa:	eb 03                	jmp    f01008ff <monitor+0x95>
		while (*buf && !strchr(WHITESPACE, *buf))
			buf++;
f01008fc:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f01008ff:	0f b6 03             	movzbl (%ebx),%eax
f0100902:	84 c0                	test   %al,%al
f0100904:	74 ad                	je     f01008b3 <monitor+0x49>
f0100906:	0f be c0             	movsbl %al,%eax
f0100909:	89 44 24 04          	mov    %eax,0x4(%esp)
f010090d:	c7 04 24 a9 1e 10 f0 	movl   $0xf0101ea9,(%esp)
f0100914:	e8 61 0d 00 00       	call   f010167a <strchr>
f0100919:	85 c0                	test   %eax,%eax
f010091b:	74 df                	je     f01008fc <monitor+0x92>
f010091d:	eb 94                	jmp    f01008b3 <monitor+0x49>
			buf++;
	}
	argv[argc] = 0;
f010091f:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100926:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100927:	85 f6                	test   %esi,%esi
f0100929:	0f 84 5c ff ff ff    	je     f010088b <monitor+0x21>
f010092f:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100934:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < ARRAY_SIZE(commands); i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100937:	8b 04 85 80 20 10 f0 	mov    -0xfefdf80(,%eax,4),%eax
f010093e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100942:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100945:	89 04 24             	mov    %eax,(%esp)
f0100948:	e8 cf 0c 00 00       	call   f010161c <strcmp>
f010094d:	85 c0                	test   %eax,%eax
f010094f:	75 24                	jne    f0100975 <monitor+0x10b>
			return commands[i].func(argc, argv, tf);
f0100951:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100954:	8b 55 08             	mov    0x8(%ebp),%edx
f0100957:	89 54 24 08          	mov    %edx,0x8(%esp)
f010095b:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f010095e:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100962:	89 34 24             	mov    %esi,(%esp)
f0100965:	ff 14 85 88 20 10 f0 	call   *-0xfefdf78(,%eax,4)


	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f010096c:	85 c0                	test   %eax,%eax
f010096e:	78 25                	js     f0100995 <monitor+0x12b>
f0100970:	e9 16 ff ff ff       	jmp    f010088b <monitor+0x21>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < ARRAY_SIZE(commands); i++) {
f0100975:	83 c3 01             	add    $0x1,%ebx
f0100978:	83 fb 03             	cmp    $0x3,%ebx
f010097b:	75 b7                	jne    f0100934 <monitor+0xca>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f010097d:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100980:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100984:	c7 04 24 cb 1e 10 f0 	movl   $0xf0101ecb,(%esp)
f010098b:	e8 c7 01 00 00       	call   f0100b57 <cprintf>
f0100990:	e9 f6 fe ff ff       	jmp    f010088b <monitor+0x21>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100995:	83 c4 5c             	add    $0x5c,%esp
f0100998:	5b                   	pop    %ebx
f0100999:	5e                   	pop    %esi
f010099a:	5f                   	pop    %edi
f010099b:	5d                   	pop    %ebp
f010099c:	c3                   	ret    

f010099d <nvram_read>:
// Detect machine's physical memory setup.
// --------------------------------------------------------------

static int
nvram_read(int r)
{
f010099d:	55                   	push   %ebp
f010099e:	89 e5                	mov    %esp,%ebp
f01009a0:	56                   	push   %esi
f01009a1:	53                   	push   %ebx
f01009a2:	83 ec 10             	sub    $0x10,%esp
f01009a5:	89 c3                	mov    %eax,%ebx
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01009a7:	89 04 24             	mov    %eax,(%esp)
f01009aa:	e8 38 01 00 00       	call   f0100ae7 <mc146818_read>
f01009af:	89 c6                	mov    %eax,%esi
f01009b1:	83 c3 01             	add    $0x1,%ebx
f01009b4:	89 1c 24             	mov    %ebx,(%esp)
f01009b7:	e8 2b 01 00 00       	call   f0100ae7 <mc146818_read>
f01009bc:	c1 e0 08             	shl    $0x8,%eax
f01009bf:	09 f0                	or     %esi,%eax
}
f01009c1:	83 c4 10             	add    $0x10,%esp
f01009c4:	5b                   	pop    %ebx
f01009c5:	5e                   	pop    %esi
f01009c6:	5d                   	pop    %ebp
f01009c7:	c3                   	ret    

f01009c8 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f01009c8:	55                   	push   %ebp
f01009c9:	89 e5                	mov    %esp,%ebp
f01009cb:	56                   	push   %esi
f01009cc:	53                   	push   %ebx
f01009cd:	83 ec 10             	sub    $0x10,%esp
{
	size_t basemem, extmem, ext16mem, totalmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	basemem = nvram_read(NVRAM_BASELO);
f01009d0:	b8 15 00 00 00       	mov    $0x15,%eax
f01009d5:	e8 c3 ff ff ff       	call   f010099d <nvram_read>
f01009da:	89 c3                	mov    %eax,%ebx
	extmem = nvram_read(NVRAM_EXTLO);
f01009dc:	b8 17 00 00 00       	mov    $0x17,%eax
f01009e1:	e8 b7 ff ff ff       	call   f010099d <nvram_read>
f01009e6:	89 c6                	mov    %eax,%esi
	ext16mem = nvram_read(NVRAM_EXT16LO) * 64;
f01009e8:	b8 34 00 00 00       	mov    $0x34,%eax
f01009ed:	e8 ab ff ff ff       	call   f010099d <nvram_read>
f01009f2:	c1 e0 06             	shl    $0x6,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (ext16mem)
f01009f5:	85 c0                	test   %eax,%eax
f01009f7:	74 07                	je     f0100a00 <mem_init+0x38>
		totalmem = 16 * 1024 + ext16mem;
f01009f9:	05 00 40 00 00       	add    $0x4000,%eax
f01009fe:	eb 0b                	jmp    f0100a0b <mem_init+0x43>
	else if (extmem)
		totalmem = 1 * 1024 + extmem;
f0100a00:	8d 86 00 04 00 00    	lea    0x400(%esi),%eax
f0100a06:	85 f6                	test   %esi,%esi
f0100a08:	0f 44 c3             	cmove  %ebx,%eax
	else
		totalmem = basemem;

	npages = totalmem / (PGSIZE / 1024);
f0100a0b:	89 c2                	mov    %eax,%edx
f0100a0d:	c1 ea 02             	shr    $0x2,%edx
f0100a10:	89 15 48 29 11 f0    	mov    %edx,0xf0112948
	npages_basemem = basemem / (PGSIZE / 1024);
f0100a16:	89 da                	mov    %ebx,%edx
f0100a18:	c1 ea 02             	shr    $0x2,%edx
f0100a1b:	89 15 3c 25 11 f0    	mov    %edx,0xf011253c

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0100a21:	89 c2                	mov    %eax,%edx
f0100a23:	29 da                	sub    %ebx,%edx
f0100a25:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100a29:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0100a2d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a31:	c7 04 24 a4 20 10 f0 	movl   $0xf01020a4,(%esp)
f0100a38:	e8 1a 01 00 00       	call   f0100b57 <cprintf>

	// Find out how much memory the machine has (npages & npages_basemem).
	i386_detect_memory();

	// Remove this line when you're ready to test this function.
	panic("mem_init: This function is not finished\n");
f0100a3d:	c7 44 24 08 e0 20 10 	movl   $0xf01020e0,0x8(%esp)
f0100a44:	f0 
f0100a45:	c7 44 24 04 80 00 00 	movl   $0x80,0x4(%esp)
f0100a4c:	00 
f0100a4d:	c7 04 24 0c 21 10 f0 	movl   $0xf010210c,(%esp)
f0100a54:	e8 3b f6 ff ff       	call   f0100094 <_panic>

f0100a59 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100a59:	55                   	push   %ebp
f0100a5a:	89 e5                	mov    %esp,%ebp
f0100a5c:	53                   	push   %ebx
f0100a5d:	8b 1d 38 25 11 f0    	mov    0xf0112538,%ebx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100a63:	b8 00 00 00 00       	mov    $0x0,%eax
f0100a68:	eb 22                	jmp    f0100a8c <page_init+0x33>
f0100a6a:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f0100a71:	89 d1                	mov    %edx,%ecx
f0100a73:	03 0d 50 29 11 f0    	add    0xf0112950,%ecx
f0100a79:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100a7f:	89 19                	mov    %ebx,(%ecx)
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100a81:	83 c0 01             	add    $0x1,%eax
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0100a84:	89 d3                	mov    %edx,%ebx
f0100a86:	03 1d 50 29 11 f0    	add    0xf0112950,%ebx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100a8c:	3b 05 48 29 11 f0    	cmp    0xf0112948,%eax
f0100a92:	72 d6                	jb     f0100a6a <page_init+0x11>
f0100a94:	89 1d 38 25 11 f0    	mov    %ebx,0xf0112538
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
	}
}
f0100a9a:	5b                   	pop    %ebx
f0100a9b:	5d                   	pop    %ebp
f0100a9c:	c3                   	ret    

f0100a9d <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct PageInfo *
page_alloc(int alloc_flags)
{
f0100a9d:	55                   	push   %ebp
f0100a9e:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return 0;
}
f0100aa0:	b8 00 00 00 00       	mov    $0x0,%eax
f0100aa5:	5d                   	pop    %ebp
f0100aa6:	c3                   	ret    

f0100aa7 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct PageInfo *pp)
{
f0100aa7:	55                   	push   %ebp
f0100aa8:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	// Hint: You may want to panic if pp->pp_ref is nonzero or
	// pp->pp_link is not NULL.
}
f0100aaa:	5d                   	pop    %ebp
f0100aab:	c3                   	ret    

f0100aac <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct PageInfo* pp)
{
f0100aac:	55                   	push   %ebp
f0100aad:	89 e5                	mov    %esp,%ebp
f0100aaf:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0100ab2:	66 83 68 04 01       	subw   $0x1,0x4(%eax)
		page_free(pp);
}
f0100ab7:	5d                   	pop    %ebp
f0100ab8:	c3                   	ret    

f0100ab9 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that manipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0100ab9:	55                   	push   %ebp
f0100aba:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return NULL;
}
f0100abc:	b8 00 00 00 00       	mov    $0x0,%eax
f0100ac1:	5d                   	pop    %ebp
f0100ac2:	c3                   	ret    

f0100ac3 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct PageInfo *pp, void *va, int perm)
{
f0100ac3:	55                   	push   %ebp
f0100ac4:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return 0;
}
f0100ac6:	b8 00 00 00 00       	mov    $0x0,%eax
f0100acb:	5d                   	pop    %ebp
f0100acc:	c3                   	ret    

f0100acd <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct PageInfo *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0100acd:	55                   	push   %ebp
f0100ace:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return NULL;
}
f0100ad0:	b8 00 00 00 00       	mov    $0x0,%eax
f0100ad5:	5d                   	pop    %ebp
f0100ad6:	c3                   	ret    

f0100ad7 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f0100ad7:	55                   	push   %ebp
f0100ad8:	89 e5                	mov    %esp,%ebp
	// Fill this function in
}
f0100ada:	5d                   	pop    %ebp
f0100adb:	c3                   	ret    

f0100adc <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0100adc:	55                   	push   %ebp
f0100add:	89 e5                	mov    %esp,%ebp
}

static inline void
invlpg(void *addr)
{
	asm volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0100adf:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100ae2:	0f 01 38             	invlpg (%eax)
	// Flush the entry only if we're modifying the current address space.
	// For now, there is only one address space, so always invalidate.
	invlpg(va);
}
f0100ae5:	5d                   	pop    %ebp
f0100ae6:	c3                   	ret    

f0100ae7 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0100ae7:	55                   	push   %ebp
f0100ae8:	89 e5                	mov    %esp,%ebp
f0100aea:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100aee:	ba 70 00 00 00       	mov    $0x70,%edx
f0100af3:	ee                   	out    %al,(%dx)

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100af4:	b2 71                	mov    $0x71,%dl
f0100af6:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0100af7:	0f b6 c0             	movzbl %al,%eax
}
f0100afa:	5d                   	pop    %ebp
f0100afb:	c3                   	ret    

f0100afc <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0100afc:	55                   	push   %ebp
f0100afd:	89 e5                	mov    %esp,%ebp
f0100aff:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100b03:	ba 70 00 00 00       	mov    $0x70,%edx
f0100b08:	ee                   	out    %al,(%dx)
f0100b09:	b2 71                	mov    $0x71,%dl
f0100b0b:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100b0e:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0100b0f:	5d                   	pop    %ebp
f0100b10:	c3                   	ret    

f0100b11 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0100b11:	55                   	push   %ebp
f0100b12:	89 e5                	mov    %esp,%ebp
f0100b14:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0100b17:	8b 45 08             	mov    0x8(%ebp),%eax
f0100b1a:	89 04 24             	mov    %eax,(%esp)
f0100b1d:	e8 df fa ff ff       	call   f0100601 <cputchar>
	*cnt++;
}
f0100b22:	c9                   	leave  
f0100b23:	c3                   	ret    

f0100b24 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0100b24:	55                   	push   %ebp
f0100b25:	89 e5                	mov    %esp,%ebp
f0100b27:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0100b2a:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0100b31:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100b34:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100b38:	8b 45 08             	mov    0x8(%ebp),%eax
f0100b3b:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100b3f:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0100b42:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b46:	c7 04 24 11 0b 10 f0 	movl   $0xf0100b11,(%esp)
f0100b4d:	e8 ac 04 00 00       	call   f0100ffe <vprintfmt>
	return cnt;
}
f0100b52:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100b55:	c9                   	leave  
f0100b56:	c3                   	ret    

f0100b57 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0100b57:	55                   	push   %ebp
f0100b58:	89 e5                	mov    %esp,%ebp
f0100b5a:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0100b5d:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0100b60:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b64:	8b 45 08             	mov    0x8(%ebp),%eax
f0100b67:	89 04 24             	mov    %eax,(%esp)
f0100b6a:	e8 b5 ff ff ff       	call   f0100b24 <vcprintf>
	va_end(ap);

	return cnt;
}
f0100b6f:	c9                   	leave  
f0100b70:	c3                   	ret    

f0100b71 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0100b71:	55                   	push   %ebp
f0100b72:	89 e5                	mov    %esp,%ebp
f0100b74:	57                   	push   %edi
f0100b75:	56                   	push   %esi
f0100b76:	53                   	push   %ebx
f0100b77:	83 ec 10             	sub    $0x10,%esp
f0100b7a:	89 c6                	mov    %eax,%esi
f0100b7c:	89 55 e8             	mov    %edx,-0x18(%ebp)
f0100b7f:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f0100b82:	8b 7d 08             	mov    0x8(%ebp),%edi
	int l = *region_left, r = *region_right, any_matches = 0;
f0100b85:	8b 1a                	mov    (%edx),%ebx
f0100b87:	8b 01                	mov    (%ecx),%eax
f0100b89:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100b8c:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)

	while (l <= r) {
f0100b93:	eb 77                	jmp    f0100c0c <stab_binsearch+0x9b>
		int true_m = (l + r) / 2, m = true_m;
f0100b95:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100b98:	01 d8                	add    %ebx,%eax
f0100b9a:	b9 02 00 00 00       	mov    $0x2,%ecx
f0100b9f:	99                   	cltd   
f0100ba0:	f7 f9                	idiv   %ecx
f0100ba2:	89 c1                	mov    %eax,%ecx

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0100ba4:	eb 01                	jmp    f0100ba7 <stab_binsearch+0x36>
			m--;
f0100ba6:	49                   	dec    %ecx

	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0100ba7:	39 d9                	cmp    %ebx,%ecx
f0100ba9:	7c 1d                	jl     f0100bc8 <stab_binsearch+0x57>
f0100bab:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0100bae:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100bb3:	39 fa                	cmp    %edi,%edx
f0100bb5:	75 ef                	jne    f0100ba6 <stab_binsearch+0x35>
f0100bb7:	89 4d ec             	mov    %ecx,-0x14(%ebp)
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0100bba:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0100bbd:	8b 54 16 08          	mov    0x8(%esi,%edx,1),%edx
f0100bc1:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0100bc4:	73 18                	jae    f0100bde <stab_binsearch+0x6d>
f0100bc6:	eb 05                	jmp    f0100bcd <stab_binsearch+0x5c>

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0100bc8:	8d 58 01             	lea    0x1(%eax),%ebx
			continue;
f0100bcb:	eb 3f                	jmp    f0100c0c <stab_binsearch+0x9b>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0100bcd:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100bd0:	89 0b                	mov    %ecx,(%ebx)
			l = true_m + 1;
f0100bd2:	8d 58 01             	lea    0x1(%eax),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100bd5:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100bdc:	eb 2e                	jmp    f0100c0c <stab_binsearch+0x9b>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0100bde:	39 55 0c             	cmp    %edx,0xc(%ebp)
f0100be1:	73 15                	jae    f0100bf8 <stab_binsearch+0x87>
			*region_right = m - 1;
f0100be3:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0100be6:	48                   	dec    %eax
f0100be7:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100bea:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100bed:	89 01                	mov    %eax,(%ecx)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100bef:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100bf6:	eb 14                	jmp    f0100c0c <stab_binsearch+0x9b>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0100bf8:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100bfb:	8b 5d ec             	mov    -0x14(%ebp),%ebx
f0100bfe:	89 18                	mov    %ebx,(%eax)
			l = m;
			addr++;
f0100c00:	ff 45 0c             	incl   0xc(%ebp)
f0100c03:	89 cb                	mov    %ecx,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100c05:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;

	while (l <= r) {
f0100c0c:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0100c0f:	7e 84                	jle    f0100b95 <stab_binsearch+0x24>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0100c11:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
f0100c15:	75 0d                	jne    f0100c24 <stab_binsearch+0xb3>
		*region_right = *region_left - 1;
f0100c17:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100c1a:	8b 00                	mov    (%eax),%eax
f0100c1c:	48                   	dec    %eax
f0100c1d:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100c20:	89 07                	mov    %eax,(%edi)
f0100c22:	eb 22                	jmp    f0100c46 <stab_binsearch+0xd5>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100c24:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c27:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0100c29:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100c2c:	8b 0b                	mov    (%ebx),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100c2e:	eb 01                	jmp    f0100c31 <stab_binsearch+0xc0>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
f0100c30:	48                   	dec    %eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100c31:	39 c1                	cmp    %eax,%ecx
f0100c33:	7d 0c                	jge    f0100c41 <stab_binsearch+0xd0>
f0100c35:	6b d0 0c             	imul   $0xc,%eax,%edx
		     l > *region_left && stabs[l].n_type != type;
f0100c38:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100c3d:	39 fa                	cmp    %edi,%edx
f0100c3f:	75 ef                	jne    f0100c30 <stab_binsearch+0xbf>
		     l--)
			/* do nothing */;
		*region_left = l;
f0100c41:	8b 7d e8             	mov    -0x18(%ebp),%edi
f0100c44:	89 07                	mov    %eax,(%edi)
	}
}
f0100c46:	83 c4 10             	add    $0x10,%esp
f0100c49:	5b                   	pop    %ebx
f0100c4a:	5e                   	pop    %esi
f0100c4b:	5f                   	pop    %edi
f0100c4c:	5d                   	pop    %ebp
f0100c4d:	c3                   	ret    

f0100c4e <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0100c4e:	55                   	push   %ebp
f0100c4f:	89 e5                	mov    %esp,%ebp
f0100c51:	57                   	push   %edi
f0100c52:	56                   	push   %esi
f0100c53:	53                   	push   %ebx
f0100c54:	83 ec 3c             	sub    $0x3c,%esp
f0100c57:	8b 75 08             	mov    0x8(%ebp),%esi
f0100c5a:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0100c5d:	c7 03 18 21 10 f0    	movl   $0xf0102118,(%ebx)
	info->eip_line = 0;
f0100c63:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
	info->eip_fn_name = "<unknown>";
f0100c6a:	c7 43 08 18 21 10 f0 	movl   $0xf0102118,0x8(%ebx)
	info->eip_fn_namelen = 9;
f0100c71:	c7 43 0c 09 00 00 00 	movl   $0x9,0xc(%ebx)
	info->eip_fn_addr = addr;
f0100c78:	89 73 10             	mov    %esi,0x10(%ebx)
	info->eip_fn_narg = 0;
f0100c7b:	c7 43 14 00 00 00 00 	movl   $0x0,0x14(%ebx)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0100c82:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f0100c88:	76 12                	jbe    f0100c9c <debuginfo_eip+0x4e>
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100c8a:	b8 c3 7f 10 f0       	mov    $0xf0107fc3,%eax
f0100c8f:	3d f5 63 10 f0       	cmp    $0xf01063f5,%eax
f0100c94:	0f 86 cd 01 00 00    	jbe    f0100e67 <debuginfo_eip+0x219>
f0100c9a:	eb 1c                	jmp    f0100cb8 <debuginfo_eip+0x6a>
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
	} else {
		// Can't search for user-level addresses yet!
  	        panic("User address");
f0100c9c:	c7 44 24 08 22 21 10 	movl   $0xf0102122,0x8(%esp)
f0100ca3:	f0 
f0100ca4:	c7 44 24 04 7f 00 00 	movl   $0x7f,0x4(%esp)
f0100cab:	00 
f0100cac:	c7 04 24 2f 21 10 f0 	movl   $0xf010212f,(%esp)
f0100cb3:	e8 dc f3 ff ff       	call   f0100094 <_panic>
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100cb8:	80 3d c2 7f 10 f0 00 	cmpb   $0x0,0xf0107fc2
f0100cbf:	0f 85 a9 01 00 00    	jne    f0100e6e <debuginfo_eip+0x220>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.

	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0100cc5:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0100ccc:	b8 f4 63 10 f0       	mov    $0xf01063f4,%eax
f0100cd1:	2d 50 23 10 f0       	sub    $0xf0102350,%eax
f0100cd6:	c1 f8 02             	sar    $0x2,%eax
f0100cd9:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f0100cdf:	83 e8 01             	sub    $0x1,%eax
f0100ce2:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0100ce5:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100ce9:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0100cf0:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0100cf3:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0100cf6:	b8 50 23 10 f0       	mov    $0xf0102350,%eax
f0100cfb:	e8 71 fe ff ff       	call   f0100b71 <stab_binsearch>
	if (lfile == 0)
f0100d00:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100d03:	85 c0                	test   %eax,%eax
f0100d05:	0f 84 6a 01 00 00    	je     f0100e75 <debuginfo_eip+0x227>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0100d0b:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0100d0e:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100d11:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0100d14:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100d18:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0100d1f:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0100d22:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100d25:	b8 50 23 10 f0       	mov    $0xf0102350,%eax
f0100d2a:	e8 42 fe ff ff       	call   f0100b71 <stab_binsearch>

	if (lfun <= rfun) {
f0100d2f:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0100d32:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0100d35:	39 d0                	cmp    %edx,%eax
f0100d37:	7f 3d                	jg     f0100d76 <debuginfo_eip+0x128>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0100d39:	6b c8 0c             	imul   $0xc,%eax,%ecx
f0100d3c:	8d b9 50 23 10 f0    	lea    -0xfefdcb0(%ecx),%edi
f0100d42:	89 7d c4             	mov    %edi,-0x3c(%ebp)
f0100d45:	8b 89 50 23 10 f0    	mov    -0xfefdcb0(%ecx),%ecx
f0100d4b:	bf c3 7f 10 f0       	mov    $0xf0107fc3,%edi
f0100d50:	81 ef f5 63 10 f0    	sub    $0xf01063f5,%edi
f0100d56:	39 f9                	cmp    %edi,%ecx
f0100d58:	73 09                	jae    f0100d63 <debuginfo_eip+0x115>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0100d5a:	81 c1 f5 63 10 f0    	add    $0xf01063f5,%ecx
f0100d60:	89 4b 08             	mov    %ecx,0x8(%ebx)
		info->eip_fn_addr = stabs[lfun].n_value;
f0100d63:	8b 7d c4             	mov    -0x3c(%ebp),%edi
f0100d66:	8b 4f 08             	mov    0x8(%edi),%ecx
f0100d69:	89 4b 10             	mov    %ecx,0x10(%ebx)
		addr -= info->eip_fn_addr;
f0100d6c:	29 ce                	sub    %ecx,%esi
		// Search within the function definition for the line number.
		lline = lfun;
f0100d6e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		rline = rfun;
f0100d71:	89 55 d0             	mov    %edx,-0x30(%ebp)
f0100d74:	eb 0f                	jmp    f0100d85 <debuginfo_eip+0x137>
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0100d76:	89 73 10             	mov    %esi,0x10(%ebx)
		lline = lfile;
f0100d79:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100d7c:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		rline = rfile;
f0100d7f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100d82:	89 45 d0             	mov    %eax,-0x30(%ebp)
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0100d85:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0100d8c:	00 
f0100d8d:	8b 43 08             	mov    0x8(%ebx),%eax
f0100d90:	89 04 24             	mov    %eax,(%esp)
f0100d93:	e8 03 09 00 00       	call   f010169b <strfind>
f0100d98:	2b 43 08             	sub    0x8(%ebx),%eax
f0100d9b:	89 43 0c             	mov    %eax,0xc(%ebx)
	// Hint:
	//	There's a particular stabs type used for line numbers.
	//	Look at the STABS documentation and <inc/stab.h> to find
	//	which one.
	// Your code here.
  stab_binsearch(stabs, &lline, &rline, N_SLINE, addr);
f0100d9e:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100da2:	c7 04 24 44 00 00 00 	movl   $0x44,(%esp)
f0100da9:	8d 4d d0             	lea    -0x30(%ebp),%ecx
f0100dac:	8d 55 d4             	lea    -0x2c(%ebp),%edx
f0100daf:	b8 50 23 10 f0       	mov    $0xf0102350,%eax
f0100db4:	e8 b8 fd ff ff       	call   f0100b71 <stab_binsearch>
  if( lline <= rline ){
f0100db9:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0100dbc:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0100dbf:	0f 8f b7 00 00 00    	jg     f0100e7c <debuginfo_eip+0x22e>
    info->eip_line = stabs[rline].n_desc;
f0100dc5:	6b c0 0c             	imul   $0xc,%eax,%eax
f0100dc8:	0f b7 80 56 23 10 f0 	movzwl -0xfefdcaa(%eax),%eax
f0100dcf:	89 43 04             	mov    %eax,0x4(%ebx)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100dd2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100dd5:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0100dd8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100ddb:	6b d0 0c             	imul   $0xc,%eax,%edx
f0100dde:	81 c2 50 23 10 f0    	add    $0xf0102350,%edx
f0100de4:	eb 06                	jmp    f0100dec <debuginfo_eip+0x19e>
f0100de6:	83 e8 01             	sub    $0x1,%eax
f0100de9:	83 ea 0c             	sub    $0xc,%edx
f0100dec:	89 c6                	mov    %eax,%esi
f0100dee:	39 45 c4             	cmp    %eax,-0x3c(%ebp)
f0100df1:	7f 33                	jg     f0100e26 <debuginfo_eip+0x1d8>
	       && stabs[lline].n_type != N_SOL
f0100df3:	0f b6 4a 04          	movzbl 0x4(%edx),%ecx
f0100df7:	80 f9 84             	cmp    $0x84,%cl
f0100dfa:	74 0b                	je     f0100e07 <debuginfo_eip+0x1b9>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0100dfc:	80 f9 64             	cmp    $0x64,%cl
f0100dff:	75 e5                	jne    f0100de6 <debuginfo_eip+0x198>
f0100e01:	83 7a 08 00          	cmpl   $0x0,0x8(%edx)
f0100e05:	74 df                	je     f0100de6 <debuginfo_eip+0x198>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0100e07:	6b f6 0c             	imul   $0xc,%esi,%esi
f0100e0a:	8b 86 50 23 10 f0    	mov    -0xfefdcb0(%esi),%eax
f0100e10:	ba c3 7f 10 f0       	mov    $0xf0107fc3,%edx
f0100e15:	81 ea f5 63 10 f0    	sub    $0xf01063f5,%edx
f0100e1b:	39 d0                	cmp    %edx,%eax
f0100e1d:	73 07                	jae    f0100e26 <debuginfo_eip+0x1d8>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0100e1f:	05 f5 63 10 f0       	add    $0xf01063f5,%eax
f0100e24:	89 03                	mov    %eax,(%ebx)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100e26:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100e29:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100e2c:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100e31:	39 ca                	cmp    %ecx,%edx
f0100e33:	7d 53                	jge    f0100e88 <debuginfo_eip+0x23a>
		for (lline = lfun + 1;
f0100e35:	8d 42 01             	lea    0x1(%edx),%eax
f0100e38:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100e3b:	89 c2                	mov    %eax,%edx
f0100e3d:	6b c0 0c             	imul   $0xc,%eax,%eax
f0100e40:	05 50 23 10 f0       	add    $0xf0102350,%eax
f0100e45:	89 ce                	mov    %ecx,%esi
f0100e47:	eb 04                	jmp    f0100e4d <debuginfo_eip+0x1ff>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
f0100e49:	83 43 14 01          	addl   $0x1,0x14(%ebx)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0100e4d:	39 d6                	cmp    %edx,%esi
f0100e4f:	7e 32                	jle    f0100e83 <debuginfo_eip+0x235>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100e51:	0f b6 48 04          	movzbl 0x4(%eax),%ecx
f0100e55:	83 c2 01             	add    $0x1,%edx
f0100e58:	83 c0 0c             	add    $0xc,%eax
f0100e5b:	80 f9 a0             	cmp    $0xa0,%cl
f0100e5e:	74 e9                	je     f0100e49 <debuginfo_eip+0x1fb>
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100e60:	b8 00 00 00 00       	mov    $0x0,%eax
f0100e65:	eb 21                	jmp    f0100e88 <debuginfo_eip+0x23a>
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0100e67:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100e6c:	eb 1a                	jmp    f0100e88 <debuginfo_eip+0x23a>
f0100e6e:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100e73:	eb 13                	jmp    f0100e88 <debuginfo_eip+0x23a>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0100e75:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100e7a:	eb 0c                	jmp    f0100e88 <debuginfo_eip+0x23a>
	// Your code here.
  stab_binsearch(stabs, &lline, &rline, N_SLINE, addr);
  if( lline <= rline ){
    info->eip_line = stabs[rline].n_desc;
  }else{
    return -1;
f0100e7c:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100e81:	eb 05                	jmp    f0100e88 <debuginfo_eip+0x23a>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100e83:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100e88:	83 c4 3c             	add    $0x3c,%esp
f0100e8b:	5b                   	pop    %ebx
f0100e8c:	5e                   	pop    %esi
f0100e8d:	5f                   	pop    %edi
f0100e8e:	5d                   	pop    %ebp
f0100e8f:	c3                   	ret    

f0100e90 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0100e90:	55                   	push   %ebp
f0100e91:	89 e5                	mov    %esp,%ebp
f0100e93:	57                   	push   %edi
f0100e94:	56                   	push   %esi
f0100e95:	53                   	push   %ebx
f0100e96:	83 ec 3c             	sub    $0x3c,%esp
f0100e99:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0100e9c:	89 d7                	mov    %edx,%edi
f0100e9e:	8b 45 08             	mov    0x8(%ebp),%eax
f0100ea1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100ea4:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100ea7:	89 c3                	mov    %eax,%ebx
f0100ea9:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100eac:	8b 45 10             	mov    0x10(%ebp),%eax
f0100eaf:	8b 75 14             	mov    0x14(%ebp),%esi
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0100eb2:	b9 00 00 00 00       	mov    $0x0,%ecx
f0100eb7:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0100eba:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0100ebd:	39 d9                	cmp    %ebx,%ecx
f0100ebf:	72 05                	jb     f0100ec6 <printnum+0x36>
f0100ec1:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0100ec4:	77 69                	ja     f0100f2f <printnum+0x9f>
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0100ec6:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0100ec9:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0100ecd:	83 ee 01             	sub    $0x1,%esi
f0100ed0:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0100ed4:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100ed8:	8b 44 24 08          	mov    0x8(%esp),%eax
f0100edc:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0100ee0:	89 c3                	mov    %eax,%ebx
f0100ee2:	89 d6                	mov    %edx,%esi
f0100ee4:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0100ee7:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0100eea:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100eee:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0100ef2:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100ef5:	89 04 24             	mov    %eax,(%esp)
f0100ef8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100efb:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100eff:	e8 bc 09 00 00       	call   f01018c0 <__udivdi3>
f0100f04:	89 d9                	mov    %ebx,%ecx
f0100f06:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0100f0a:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0100f0e:	89 04 24             	mov    %eax,(%esp)
f0100f11:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100f15:	89 fa                	mov    %edi,%edx
f0100f17:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100f1a:	e8 71 ff ff ff       	call   f0100e90 <printnum>
f0100f1f:	eb 1b                	jmp    f0100f3c <printnum+0xac>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0100f21:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100f25:	8b 45 18             	mov    0x18(%ebp),%eax
f0100f28:	89 04 24             	mov    %eax,(%esp)
f0100f2b:	ff d3                	call   *%ebx
f0100f2d:	eb 03                	jmp    f0100f32 <printnum+0xa2>
f0100f2f:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0100f32:	83 ee 01             	sub    $0x1,%esi
f0100f35:	85 f6                	test   %esi,%esi
f0100f37:	7f e8                	jg     f0100f21 <printnum+0x91>
f0100f39:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0100f3c:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100f40:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0100f44:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100f47:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100f4a:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100f4e:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100f52:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100f55:	89 04 24             	mov    %eax,(%esp)
f0100f58:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100f5b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100f5f:	e8 8c 0a 00 00       	call   f01019f0 <__umoddi3>
f0100f64:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100f68:	0f be 80 3d 21 10 f0 	movsbl -0xfefdec3(%eax),%eax
f0100f6f:	89 04 24             	mov    %eax,(%esp)
f0100f72:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100f75:	ff d0                	call   *%eax
}
f0100f77:	83 c4 3c             	add    $0x3c,%esp
f0100f7a:	5b                   	pop    %ebx
f0100f7b:	5e                   	pop    %esi
f0100f7c:	5f                   	pop    %edi
f0100f7d:	5d                   	pop    %ebp
f0100f7e:	c3                   	ret    

f0100f7f <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0100f7f:	55                   	push   %ebp
f0100f80:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0100f82:	83 fa 01             	cmp    $0x1,%edx
f0100f85:	7e 0e                	jle    f0100f95 <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0100f87:	8b 10                	mov    (%eax),%edx
f0100f89:	8d 4a 08             	lea    0x8(%edx),%ecx
f0100f8c:	89 08                	mov    %ecx,(%eax)
f0100f8e:	8b 02                	mov    (%edx),%eax
f0100f90:	8b 52 04             	mov    0x4(%edx),%edx
f0100f93:	eb 22                	jmp    f0100fb7 <getuint+0x38>
	else if (lflag)
f0100f95:	85 d2                	test   %edx,%edx
f0100f97:	74 10                	je     f0100fa9 <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f0100f99:	8b 10                	mov    (%eax),%edx
f0100f9b:	8d 4a 04             	lea    0x4(%edx),%ecx
f0100f9e:	89 08                	mov    %ecx,(%eax)
f0100fa0:	8b 02                	mov    (%edx),%eax
f0100fa2:	ba 00 00 00 00       	mov    $0x0,%edx
f0100fa7:	eb 0e                	jmp    f0100fb7 <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f0100fa9:	8b 10                	mov    (%eax),%edx
f0100fab:	8d 4a 04             	lea    0x4(%edx),%ecx
f0100fae:	89 08                	mov    %ecx,(%eax)
f0100fb0:	8b 02                	mov    (%edx),%eax
f0100fb2:	ba 00 00 00 00       	mov    $0x0,%edx
}
f0100fb7:	5d                   	pop    %ebp
f0100fb8:	c3                   	ret    

f0100fb9 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0100fb9:	55                   	push   %ebp
f0100fba:	89 e5                	mov    %esp,%ebp
f0100fbc:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0100fbf:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0100fc3:	8b 10                	mov    (%eax),%edx
f0100fc5:	3b 50 04             	cmp    0x4(%eax),%edx
f0100fc8:	73 0a                	jae    f0100fd4 <sprintputch+0x1b>
		*b->buf++ = ch;
f0100fca:	8d 4a 01             	lea    0x1(%edx),%ecx
f0100fcd:	89 08                	mov    %ecx,(%eax)
f0100fcf:	8b 45 08             	mov    0x8(%ebp),%eax
f0100fd2:	88 02                	mov    %al,(%edx)
}
f0100fd4:	5d                   	pop    %ebp
f0100fd5:	c3                   	ret    

f0100fd6 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0100fd6:	55                   	push   %ebp
f0100fd7:	89 e5                	mov    %esp,%ebp
f0100fd9:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0100fdc:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0100fdf:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100fe3:	8b 45 10             	mov    0x10(%ebp),%eax
f0100fe6:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100fea:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100fed:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ff1:	8b 45 08             	mov    0x8(%ebp),%eax
f0100ff4:	89 04 24             	mov    %eax,(%esp)
f0100ff7:	e8 02 00 00 00       	call   f0100ffe <vprintfmt>
	va_end(ap);
}
f0100ffc:	c9                   	leave  
f0100ffd:	c3                   	ret    

f0100ffe <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0100ffe:	55                   	push   %ebp
f0100fff:	89 e5                	mov    %esp,%ebp
f0101001:	57                   	push   %edi
f0101002:	56                   	push   %esi
f0101003:	53                   	push   %ebx
f0101004:	83 ec 3c             	sub    $0x3c,%esp
f0101007:	8b 7d 0c             	mov    0xc(%ebp),%edi
f010100a:	8b 5d 10             	mov    0x10(%ebp),%ebx
f010100d:	eb 14                	jmp    f0101023 <vprintfmt+0x25>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f010100f:	85 c0                	test   %eax,%eax
f0101011:	0f 84 b3 03 00 00    	je     f01013ca <vprintfmt+0x3cc>
				return;
			putch(ch, putdat);
f0101017:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010101b:	89 04 24             	mov    %eax,(%esp)
f010101e:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0101021:	89 f3                	mov    %esi,%ebx
f0101023:	8d 73 01             	lea    0x1(%ebx),%esi
f0101026:	0f b6 03             	movzbl (%ebx),%eax
f0101029:	83 f8 25             	cmp    $0x25,%eax
f010102c:	75 e1                	jne    f010100f <vprintfmt+0x11>
f010102e:	c6 45 d8 20          	movb   $0x20,-0x28(%ebp)
f0101032:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0101039:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0101040:	c7 45 dc ff ff ff ff 	movl   $0xffffffff,-0x24(%ebp)
f0101047:	ba 00 00 00 00       	mov    $0x0,%edx
f010104c:	eb 1d                	jmp    f010106b <vprintfmt+0x6d>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010104e:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0101050:	c6 45 d8 2d          	movb   $0x2d,-0x28(%ebp)
f0101054:	eb 15                	jmp    f010106b <vprintfmt+0x6d>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101056:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;

		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0101058:	c6 45 d8 30          	movb   $0x30,-0x28(%ebp)
f010105c:	eb 0d                	jmp    f010106b <vprintfmt+0x6d>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f010105e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101061:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0101064:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010106b:	8d 5e 01             	lea    0x1(%esi),%ebx
f010106e:	0f b6 0e             	movzbl (%esi),%ecx
f0101071:	0f b6 c1             	movzbl %cl,%eax
f0101074:	83 e9 23             	sub    $0x23,%ecx
f0101077:	80 f9 55             	cmp    $0x55,%cl
f010107a:	0f 87 2a 03 00 00    	ja     f01013aa <vprintfmt+0x3ac>
f0101080:	0f b6 c9             	movzbl %cl,%ecx
f0101083:	ff 24 8d cc 21 10 f0 	jmp    *-0xfefde34(,%ecx,4)
f010108a:	89 de                	mov    %ebx,%esi
f010108c:	b9 00 00 00 00       	mov    $0x0,%ecx
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0101091:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0101094:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0101098:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f010109b:	8d 58 d0             	lea    -0x30(%eax),%ebx
f010109e:	83 fb 09             	cmp    $0x9,%ebx
f01010a1:	77 36                	ja     f01010d9 <vprintfmt+0xdb>
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f01010a3:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
				ch = *fmt;
				if (ch < '0' || ch > '9')
					break;
			}
f01010a6:	eb e9                	jmp    f0101091 <vprintfmt+0x93>
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f01010a8:	8b 45 14             	mov    0x14(%ebp),%eax
f01010ab:	8d 48 04             	lea    0x4(%eax),%ecx
f01010ae:	89 4d 14             	mov    %ecx,0x14(%ebp)
f01010b1:	8b 00                	mov    (%eax),%eax
f01010b3:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01010b6:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f01010b8:	eb 22                	jmp    f01010dc <vprintfmt+0xde>
f01010ba:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01010bd:	85 c9                	test   %ecx,%ecx
f01010bf:	b8 00 00 00 00       	mov    $0x0,%eax
f01010c4:	0f 49 c1             	cmovns %ecx,%eax
f01010c7:	89 45 dc             	mov    %eax,-0x24(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01010ca:	89 de                	mov    %ebx,%esi
f01010cc:	eb 9d                	jmp    f010106b <vprintfmt+0x6d>
f01010ce:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f01010d0:	c7 45 e0 01 00 00 00 	movl   $0x1,-0x20(%ebp)
			goto reswitch;
f01010d7:	eb 92                	jmp    f010106b <vprintfmt+0x6d>
f01010d9:	89 4d d4             	mov    %ecx,-0x2c(%ebp)

		process_precision:
			if (width < 0)
f01010dc:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f01010e0:	79 89                	jns    f010106b <vprintfmt+0x6d>
f01010e2:	e9 77 ff ff ff       	jmp    f010105e <vprintfmt+0x60>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f01010e7:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01010ea:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f01010ec:	e9 7a ff ff ff       	jmp    f010106b <vprintfmt+0x6d>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f01010f1:	8b 45 14             	mov    0x14(%ebp),%eax
f01010f4:	8d 50 04             	lea    0x4(%eax),%edx
f01010f7:	89 55 14             	mov    %edx,0x14(%ebp)
f01010fa:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01010fe:	8b 00                	mov    (%eax),%eax
f0101100:	89 04 24             	mov    %eax,(%esp)
f0101103:	ff 55 08             	call   *0x8(%ebp)
			break;
f0101106:	e9 18 ff ff ff       	jmp    f0101023 <vprintfmt+0x25>

		// error message
		case 'e':
			err = va_arg(ap, int);
f010110b:	8b 45 14             	mov    0x14(%ebp),%eax
f010110e:	8d 50 04             	lea    0x4(%eax),%edx
f0101111:	89 55 14             	mov    %edx,0x14(%ebp)
f0101114:	8b 00                	mov    (%eax),%eax
f0101116:	99                   	cltd   
f0101117:	31 d0                	xor    %edx,%eax
f0101119:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f010111b:	83 f8 06             	cmp    $0x6,%eax
f010111e:	7f 0b                	jg     f010112b <vprintfmt+0x12d>
f0101120:	8b 14 85 24 23 10 f0 	mov    -0xfefdcdc(,%eax,4),%edx
f0101127:	85 d2                	test   %edx,%edx
f0101129:	75 20                	jne    f010114b <vprintfmt+0x14d>
				printfmt(putch, putdat, "error %d", err);
f010112b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010112f:	c7 44 24 08 55 21 10 	movl   $0xf0102155,0x8(%esp)
f0101136:	f0 
f0101137:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010113b:	8b 45 08             	mov    0x8(%ebp),%eax
f010113e:	89 04 24             	mov    %eax,(%esp)
f0101141:	e8 90 fe ff ff       	call   f0100fd6 <printfmt>
f0101146:	e9 d8 fe ff ff       	jmp    f0101023 <vprintfmt+0x25>
			else
				printfmt(putch, putdat, "%s", p);
f010114b:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010114f:	c7 44 24 08 5e 21 10 	movl   $0xf010215e,0x8(%esp)
f0101156:	f0 
f0101157:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010115b:	8b 45 08             	mov    0x8(%ebp),%eax
f010115e:	89 04 24             	mov    %eax,(%esp)
f0101161:	e8 70 fe ff ff       	call   f0100fd6 <printfmt>
f0101166:	e9 b8 fe ff ff       	jmp    f0101023 <vprintfmt+0x25>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010116b:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010116e:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0101171:	89 45 d0             	mov    %eax,-0x30(%ebp)
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0101174:	8b 45 14             	mov    0x14(%ebp),%eax
f0101177:	8d 50 04             	lea    0x4(%eax),%edx
f010117a:	89 55 14             	mov    %edx,0x14(%ebp)
f010117d:	8b 30                	mov    (%eax),%esi
				p = "(null)";
f010117f:	85 f6                	test   %esi,%esi
f0101181:	b8 4e 21 10 f0       	mov    $0xf010214e,%eax
f0101186:	0f 44 f0             	cmove  %eax,%esi
			if (width > 0 && padc != '-')
f0101189:	80 7d d8 2d          	cmpb   $0x2d,-0x28(%ebp)
f010118d:	0f 84 97 00 00 00    	je     f010122a <vprintfmt+0x22c>
f0101193:	83 7d d0 00          	cmpl   $0x0,-0x30(%ebp)
f0101197:	0f 8e 9b 00 00 00    	jle    f0101238 <vprintfmt+0x23a>
				for (width -= strnlen(p, precision); width > 0; width--)
f010119d:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01011a1:	89 34 24             	mov    %esi,(%esp)
f01011a4:	e8 9f 03 00 00       	call   f0101548 <strnlen>
f01011a9:	8b 55 d0             	mov    -0x30(%ebp),%edx
f01011ac:	29 c2                	sub    %eax,%edx
f01011ae:	89 55 d0             	mov    %edx,-0x30(%ebp)
					putch(padc, putdat);
f01011b1:	0f be 45 d8          	movsbl -0x28(%ebp),%eax
f01011b5:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01011b8:	89 75 d8             	mov    %esi,-0x28(%ebp)
f01011bb:	8b 75 08             	mov    0x8(%ebp),%esi
f01011be:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01011c1:	89 d3                	mov    %edx,%ebx
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f01011c3:	eb 0f                	jmp    f01011d4 <vprintfmt+0x1d6>
					putch(padc, putdat);
f01011c5:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01011c9:	8b 45 dc             	mov    -0x24(%ebp),%eax
f01011cc:	89 04 24             	mov    %eax,(%esp)
f01011cf:	ff d6                	call   *%esi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f01011d1:	83 eb 01             	sub    $0x1,%ebx
f01011d4:	85 db                	test   %ebx,%ebx
f01011d6:	7f ed                	jg     f01011c5 <vprintfmt+0x1c7>
f01011d8:	8b 75 d8             	mov    -0x28(%ebp),%esi
f01011db:	8b 55 d0             	mov    -0x30(%ebp),%edx
f01011de:	85 d2                	test   %edx,%edx
f01011e0:	b8 00 00 00 00       	mov    $0x0,%eax
f01011e5:	0f 49 c2             	cmovns %edx,%eax
f01011e8:	29 c2                	sub    %eax,%edx
f01011ea:	89 7d 0c             	mov    %edi,0xc(%ebp)
f01011ed:	89 d7                	mov    %edx,%edi
f01011ef:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f01011f2:	eb 50                	jmp    f0101244 <vprintfmt+0x246>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f01011f4:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
f01011f8:	74 1e                	je     f0101218 <vprintfmt+0x21a>
f01011fa:	0f be d2             	movsbl %dl,%edx
f01011fd:	83 ea 20             	sub    $0x20,%edx
f0101200:	83 fa 5e             	cmp    $0x5e,%edx
f0101203:	76 13                	jbe    f0101218 <vprintfmt+0x21a>
					putch('?', putdat);
f0101205:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101208:	89 44 24 04          	mov    %eax,0x4(%esp)
f010120c:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0101213:	ff 55 08             	call   *0x8(%ebp)
f0101216:	eb 0d                	jmp    f0101225 <vprintfmt+0x227>
				else
					putch(ch, putdat);
f0101218:	8b 55 0c             	mov    0xc(%ebp),%edx
f010121b:	89 54 24 04          	mov    %edx,0x4(%esp)
f010121f:	89 04 24             	mov    %eax,(%esp)
f0101222:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101225:	83 ef 01             	sub    $0x1,%edi
f0101228:	eb 1a                	jmp    f0101244 <vprintfmt+0x246>
f010122a:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010122d:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0101230:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101233:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0101236:	eb 0c                	jmp    f0101244 <vprintfmt+0x246>
f0101238:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010123b:	8b 7d dc             	mov    -0x24(%ebp),%edi
f010123e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101241:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0101244:	83 c6 01             	add    $0x1,%esi
f0101247:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f010124b:	0f be c2             	movsbl %dl,%eax
f010124e:	85 c0                	test   %eax,%eax
f0101250:	74 27                	je     f0101279 <vprintfmt+0x27b>
f0101252:	85 db                	test   %ebx,%ebx
f0101254:	78 9e                	js     f01011f4 <vprintfmt+0x1f6>
f0101256:	83 eb 01             	sub    $0x1,%ebx
f0101259:	79 99                	jns    f01011f4 <vprintfmt+0x1f6>
f010125b:	89 f8                	mov    %edi,%eax
f010125d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0101260:	8b 75 08             	mov    0x8(%ebp),%esi
f0101263:	89 c3                	mov    %eax,%ebx
f0101265:	eb 1a                	jmp    f0101281 <vprintfmt+0x283>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0101267:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010126b:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0101272:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0101274:	83 eb 01             	sub    $0x1,%ebx
f0101277:	eb 08                	jmp    f0101281 <vprintfmt+0x283>
f0101279:	89 fb                	mov    %edi,%ebx
f010127b:	8b 75 08             	mov    0x8(%ebp),%esi
f010127e:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0101281:	85 db                	test   %ebx,%ebx
f0101283:	7f e2                	jg     f0101267 <vprintfmt+0x269>
f0101285:	89 75 08             	mov    %esi,0x8(%ebp)
f0101288:	8b 5d 10             	mov    0x10(%ebp),%ebx
f010128b:	e9 93 fd ff ff       	jmp    f0101023 <vprintfmt+0x25>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0101290:	83 fa 01             	cmp    $0x1,%edx
f0101293:	7e 16                	jle    f01012ab <vprintfmt+0x2ad>
		return va_arg(*ap, long long);
f0101295:	8b 45 14             	mov    0x14(%ebp),%eax
f0101298:	8d 50 08             	lea    0x8(%eax),%edx
f010129b:	89 55 14             	mov    %edx,0x14(%ebp)
f010129e:	8b 50 04             	mov    0x4(%eax),%edx
f01012a1:	8b 00                	mov    (%eax),%eax
f01012a3:	89 45 e0             	mov    %eax,-0x20(%ebp)
f01012a6:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f01012a9:	eb 32                	jmp    f01012dd <vprintfmt+0x2df>
	else if (lflag)
f01012ab:	85 d2                	test   %edx,%edx
f01012ad:	74 18                	je     f01012c7 <vprintfmt+0x2c9>
		return va_arg(*ap, long);
f01012af:	8b 45 14             	mov    0x14(%ebp),%eax
f01012b2:	8d 50 04             	lea    0x4(%eax),%edx
f01012b5:	89 55 14             	mov    %edx,0x14(%ebp)
f01012b8:	8b 30                	mov    (%eax),%esi
f01012ba:	89 75 e0             	mov    %esi,-0x20(%ebp)
f01012bd:	89 f0                	mov    %esi,%eax
f01012bf:	c1 f8 1f             	sar    $0x1f,%eax
f01012c2:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01012c5:	eb 16                	jmp    f01012dd <vprintfmt+0x2df>
	else
		return va_arg(*ap, int);
f01012c7:	8b 45 14             	mov    0x14(%ebp),%eax
f01012ca:	8d 50 04             	lea    0x4(%eax),%edx
f01012cd:	89 55 14             	mov    %edx,0x14(%ebp)
f01012d0:	8b 30                	mov    (%eax),%esi
f01012d2:	89 75 e0             	mov    %esi,-0x20(%ebp)
f01012d5:	89 f0                	mov    %esi,%eax
f01012d7:	c1 f8 1f             	sar    $0x1f,%eax
f01012da:	89 45 e4             	mov    %eax,-0x1c(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f01012dd:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01012e0:	8b 55 e4             	mov    -0x1c(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f01012e3:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f01012e8:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01012ec:	0f 89 80 00 00 00    	jns    f0101372 <vprintfmt+0x374>
				putch('-', putdat);
f01012f2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01012f6:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f01012fd:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f0101300:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101303:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0101306:	f7 d8                	neg    %eax
f0101308:	83 d2 00             	adc    $0x0,%edx
f010130b:	f7 da                	neg    %edx
			}
			base = 10;
f010130d:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0101312:	eb 5e                	jmp    f0101372 <vprintfmt+0x374>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0101314:	8d 45 14             	lea    0x14(%ebp),%eax
f0101317:	e8 63 fc ff ff       	call   f0100f7f <getuint>
			base = 10;
f010131c:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f0101321:	eb 4f                	jmp    f0101372 <vprintfmt+0x374>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			num = getuint(&ap, lflag);
f0101323:	8d 45 14             	lea    0x14(%ebp),%eax
f0101326:	e8 54 fc ff ff       	call   f0100f7f <getuint>
      base = 8;
f010132b:	b9 08 00 00 00       	mov    $0x8,%ecx
      goto number;
f0101330:	eb 40                	jmp    f0101372 <vprintfmt+0x374>

		// pointer
		case 'p':
			putch('0', putdat);
f0101332:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101336:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f010133d:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f0101340:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101344:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f010134b:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f010134e:	8b 45 14             	mov    0x14(%ebp),%eax
f0101351:	8d 50 04             	lea    0x4(%eax),%edx
f0101354:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0101357:	8b 00                	mov    (%eax),%eax
f0101359:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f010135e:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0101363:	eb 0d                	jmp    f0101372 <vprintfmt+0x374>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0101365:	8d 45 14             	lea    0x14(%ebp),%eax
f0101368:	e8 12 fc ff ff       	call   f0100f7f <getuint>
			base = 16;
f010136d:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0101372:	0f be 75 d8          	movsbl -0x28(%ebp),%esi
f0101376:	89 74 24 10          	mov    %esi,0x10(%esp)
f010137a:	8b 75 dc             	mov    -0x24(%ebp),%esi
f010137d:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0101381:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101385:	89 04 24             	mov    %eax,(%esp)
f0101388:	89 54 24 04          	mov    %edx,0x4(%esp)
f010138c:	89 fa                	mov    %edi,%edx
f010138e:	8b 45 08             	mov    0x8(%ebp),%eax
f0101391:	e8 fa fa ff ff       	call   f0100e90 <printnum>
			break;
f0101396:	e9 88 fc ff ff       	jmp    f0101023 <vprintfmt+0x25>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f010139b:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010139f:	89 04 24             	mov    %eax,(%esp)
f01013a2:	ff 55 08             	call   *0x8(%ebp)
			break;
f01013a5:	e9 79 fc ff ff       	jmp    f0101023 <vprintfmt+0x25>

		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f01013aa:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01013ae:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f01013b5:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f01013b8:	89 f3                	mov    %esi,%ebx
f01013ba:	eb 03                	jmp    f01013bf <vprintfmt+0x3c1>
f01013bc:	83 eb 01             	sub    $0x1,%ebx
f01013bf:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f01013c3:	75 f7                	jne    f01013bc <vprintfmt+0x3be>
f01013c5:	e9 59 fc ff ff       	jmp    f0101023 <vprintfmt+0x25>
				/* do nothing */;
			break;
		}
	}
}
f01013ca:	83 c4 3c             	add    $0x3c,%esp
f01013cd:	5b                   	pop    %ebx
f01013ce:	5e                   	pop    %esi
f01013cf:	5f                   	pop    %edi
f01013d0:	5d                   	pop    %ebp
f01013d1:	c3                   	ret    

f01013d2 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f01013d2:	55                   	push   %ebp
f01013d3:	89 e5                	mov    %esp,%ebp
f01013d5:	83 ec 28             	sub    $0x28,%esp
f01013d8:	8b 45 08             	mov    0x8(%ebp),%eax
f01013db:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f01013de:	89 45 ec             	mov    %eax,-0x14(%ebp)
f01013e1:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f01013e5:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f01013e8:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f01013ef:	85 c0                	test   %eax,%eax
f01013f1:	74 30                	je     f0101423 <vsnprintf+0x51>
f01013f3:	85 d2                	test   %edx,%edx
f01013f5:	7e 2c                	jle    f0101423 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f01013f7:	8b 45 14             	mov    0x14(%ebp),%eax
f01013fa:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01013fe:	8b 45 10             	mov    0x10(%ebp),%eax
f0101401:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101405:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0101408:	89 44 24 04          	mov    %eax,0x4(%esp)
f010140c:	c7 04 24 b9 0f 10 f0 	movl   $0xf0100fb9,(%esp)
f0101413:	e8 e6 fb ff ff       	call   f0100ffe <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0101418:	8b 45 ec             	mov    -0x14(%ebp),%eax
f010141b:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f010141e:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101421:	eb 05                	jmp    f0101428 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0101423:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0101428:	c9                   	leave  
f0101429:	c3                   	ret    

f010142a <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f010142a:	55                   	push   %ebp
f010142b:	89 e5                	mov    %esp,%ebp
f010142d:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0101430:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0101433:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101437:	8b 45 10             	mov    0x10(%ebp),%eax
f010143a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010143e:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101441:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101445:	8b 45 08             	mov    0x8(%ebp),%eax
f0101448:	89 04 24             	mov    %eax,(%esp)
f010144b:	e8 82 ff ff ff       	call   f01013d2 <vsnprintf>
	va_end(ap);

	return rc;
}
f0101450:	c9                   	leave  
f0101451:	c3                   	ret    
f0101452:	66 90                	xchg   %ax,%ax
f0101454:	66 90                	xchg   %ax,%ax
f0101456:	66 90                	xchg   %ax,%ax
f0101458:	66 90                	xchg   %ax,%ax
f010145a:	66 90                	xchg   %ax,%ax
f010145c:	66 90                	xchg   %ax,%ax
f010145e:	66 90                	xchg   %ax,%ax

f0101460 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0101460:	55                   	push   %ebp
f0101461:	89 e5                	mov    %esp,%ebp
f0101463:	57                   	push   %edi
f0101464:	56                   	push   %esi
f0101465:	53                   	push   %ebx
f0101466:	83 ec 1c             	sub    $0x1c,%esp
f0101469:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010146c:	85 c0                	test   %eax,%eax
f010146e:	74 10                	je     f0101480 <readline+0x20>
		cprintf("%s", prompt);
f0101470:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101474:	c7 04 24 5e 21 10 f0 	movl   $0xf010215e,(%esp)
f010147b:	e8 d7 f6 ff ff       	call   f0100b57 <cprintf>

	i = 0;
	echoing = iscons(0);
f0101480:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101487:	e8 96 f1 ff ff       	call   f0100622 <iscons>
f010148c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010148e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0101493:	e8 79 f1 ff ff       	call   f0100611 <getchar>
f0101498:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010149a:	85 c0                	test   %eax,%eax
f010149c:	79 17                	jns    f01014b5 <readline+0x55>
			cprintf("read error: %e\n", c);
f010149e:	89 44 24 04          	mov    %eax,0x4(%esp)
f01014a2:	c7 04 24 40 23 10 f0 	movl   $0xf0102340,(%esp)
f01014a9:	e8 a9 f6 ff ff       	call   f0100b57 <cprintf>
			return NULL;
f01014ae:	b8 00 00 00 00       	mov    $0x0,%eax
f01014b3:	eb 6d                	jmp    f0101522 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f01014b5:	83 f8 7f             	cmp    $0x7f,%eax
f01014b8:	74 05                	je     f01014bf <readline+0x5f>
f01014ba:	83 f8 08             	cmp    $0x8,%eax
f01014bd:	75 19                	jne    f01014d8 <readline+0x78>
f01014bf:	85 f6                	test   %esi,%esi
f01014c1:	7e 15                	jle    f01014d8 <readline+0x78>
			if (echoing)
f01014c3:	85 ff                	test   %edi,%edi
f01014c5:	74 0c                	je     f01014d3 <readline+0x73>
				cputchar('\b');
f01014c7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f01014ce:	e8 2e f1 ff ff       	call   f0100601 <cputchar>
			i--;
f01014d3:	83 ee 01             	sub    $0x1,%esi
f01014d6:	eb bb                	jmp    f0101493 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f01014d8:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f01014de:	7f 1c                	jg     f01014fc <readline+0x9c>
f01014e0:	83 fb 1f             	cmp    $0x1f,%ebx
f01014e3:	7e 17                	jle    f01014fc <readline+0x9c>
			if (echoing)
f01014e5:	85 ff                	test   %edi,%edi
f01014e7:	74 08                	je     f01014f1 <readline+0x91>
				cputchar(c);
f01014e9:	89 1c 24             	mov    %ebx,(%esp)
f01014ec:	e8 10 f1 ff ff       	call   f0100601 <cputchar>
			buf[i++] = c;
f01014f1:	88 9e 40 25 11 f0    	mov    %bl,-0xfeedac0(%esi)
f01014f7:	8d 76 01             	lea    0x1(%esi),%esi
f01014fa:	eb 97                	jmp    f0101493 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f01014fc:	83 fb 0d             	cmp    $0xd,%ebx
f01014ff:	74 05                	je     f0101506 <readline+0xa6>
f0101501:	83 fb 0a             	cmp    $0xa,%ebx
f0101504:	75 8d                	jne    f0101493 <readline+0x33>
			if (echoing)
f0101506:	85 ff                	test   %edi,%edi
f0101508:	74 0c                	je     f0101516 <readline+0xb6>
				cputchar('\n');
f010150a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0101511:	e8 eb f0 ff ff       	call   f0100601 <cputchar>
			buf[i] = 0;
f0101516:	c6 86 40 25 11 f0 00 	movb   $0x0,-0xfeedac0(%esi)
			return buf;
f010151d:	b8 40 25 11 f0       	mov    $0xf0112540,%eax
		}
	}
}
f0101522:	83 c4 1c             	add    $0x1c,%esp
f0101525:	5b                   	pop    %ebx
f0101526:	5e                   	pop    %esi
f0101527:	5f                   	pop    %edi
f0101528:	5d                   	pop    %ebp
f0101529:	c3                   	ret    
f010152a:	66 90                	xchg   %ax,%ax
f010152c:	66 90                	xchg   %ax,%ax
f010152e:	66 90                	xchg   %ax,%ax

f0101530 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0101530:	55                   	push   %ebp
f0101531:	89 e5                	mov    %esp,%ebp
f0101533:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0101536:	b8 00 00 00 00       	mov    $0x0,%eax
f010153b:	eb 03                	jmp    f0101540 <strlen+0x10>
		n++;
f010153d:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0101540:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0101544:	75 f7                	jne    f010153d <strlen+0xd>
		n++;
	return n;
}
f0101546:	5d                   	pop    %ebp
f0101547:	c3                   	ret    

f0101548 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0101548:	55                   	push   %ebp
f0101549:	89 e5                	mov    %esp,%ebp
f010154b:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010154e:	8b 55 0c             	mov    0xc(%ebp),%edx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0101551:	b8 00 00 00 00       	mov    $0x0,%eax
f0101556:	eb 03                	jmp    f010155b <strnlen+0x13>
		n++;
f0101558:	83 c0 01             	add    $0x1,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010155b:	39 d0                	cmp    %edx,%eax
f010155d:	74 06                	je     f0101565 <strnlen+0x1d>
f010155f:	80 3c 01 00          	cmpb   $0x0,(%ecx,%eax,1)
f0101563:	75 f3                	jne    f0101558 <strnlen+0x10>
		n++;
	return n;
}
f0101565:	5d                   	pop    %ebp
f0101566:	c3                   	ret    

f0101567 <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f0101567:	55                   	push   %ebp
f0101568:	89 e5                	mov    %esp,%ebp
f010156a:	53                   	push   %ebx
f010156b:	8b 45 08             	mov    0x8(%ebp),%eax
f010156e:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0101571:	89 c2                	mov    %eax,%edx
f0101573:	83 c2 01             	add    $0x1,%edx
f0101576:	83 c1 01             	add    $0x1,%ecx
f0101579:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f010157d:	88 5a ff             	mov    %bl,-0x1(%edx)
f0101580:	84 db                	test   %bl,%bl
f0101582:	75 ef                	jne    f0101573 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0101584:	5b                   	pop    %ebx
f0101585:	5d                   	pop    %ebp
f0101586:	c3                   	ret    

f0101587 <strcat>:

char *
strcat(char *dst, const char *src)
{
f0101587:	55                   	push   %ebp
f0101588:	89 e5                	mov    %esp,%ebp
f010158a:	53                   	push   %ebx
f010158b:	83 ec 08             	sub    $0x8,%esp
f010158e:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0101591:	89 1c 24             	mov    %ebx,(%esp)
f0101594:	e8 97 ff ff ff       	call   f0101530 <strlen>
	strcpy(dst + len, src);
f0101599:	8b 55 0c             	mov    0xc(%ebp),%edx
f010159c:	89 54 24 04          	mov    %edx,0x4(%esp)
f01015a0:	01 d8                	add    %ebx,%eax
f01015a2:	89 04 24             	mov    %eax,(%esp)
f01015a5:	e8 bd ff ff ff       	call   f0101567 <strcpy>
	return dst;
}
f01015aa:	89 d8                	mov    %ebx,%eax
f01015ac:	83 c4 08             	add    $0x8,%esp
f01015af:	5b                   	pop    %ebx
f01015b0:	5d                   	pop    %ebp
f01015b1:	c3                   	ret    

f01015b2 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f01015b2:	55                   	push   %ebp
f01015b3:	89 e5                	mov    %esp,%ebp
f01015b5:	56                   	push   %esi
f01015b6:	53                   	push   %ebx
f01015b7:	8b 75 08             	mov    0x8(%ebp),%esi
f01015ba:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01015bd:	89 f3                	mov    %esi,%ebx
f01015bf:	03 5d 10             	add    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f01015c2:	89 f2                	mov    %esi,%edx
f01015c4:	eb 0f                	jmp    f01015d5 <strncpy+0x23>
		*dst++ = *src;
f01015c6:	83 c2 01             	add    $0x1,%edx
f01015c9:	0f b6 01             	movzbl (%ecx),%eax
f01015cc:	88 42 ff             	mov    %al,-0x1(%edx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f01015cf:	80 39 01             	cmpb   $0x1,(%ecx)
f01015d2:	83 d9 ff             	sbb    $0xffffffff,%ecx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f01015d5:	39 da                	cmp    %ebx,%edx
f01015d7:	75 ed                	jne    f01015c6 <strncpy+0x14>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f01015d9:	89 f0                	mov    %esi,%eax
f01015db:	5b                   	pop    %ebx
f01015dc:	5e                   	pop    %esi
f01015dd:	5d                   	pop    %ebp
f01015de:	c3                   	ret    

f01015df <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f01015df:	55                   	push   %ebp
f01015e0:	89 e5                	mov    %esp,%ebp
f01015e2:	56                   	push   %esi
f01015e3:	53                   	push   %ebx
f01015e4:	8b 75 08             	mov    0x8(%ebp),%esi
f01015e7:	8b 55 0c             	mov    0xc(%ebp),%edx
f01015ea:	8b 4d 10             	mov    0x10(%ebp),%ecx
f01015ed:	89 f0                	mov    %esi,%eax
f01015ef:	8d 5c 0e ff          	lea    -0x1(%esi,%ecx,1),%ebx
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f01015f3:	85 c9                	test   %ecx,%ecx
f01015f5:	75 0b                	jne    f0101602 <strlcpy+0x23>
f01015f7:	eb 1d                	jmp    f0101616 <strlcpy+0x37>
		while (--size > 0 && *src != '\0')
			*dst++ = *src++;
f01015f9:	83 c0 01             	add    $0x1,%eax
f01015fc:	83 c2 01             	add    $0x1,%edx
f01015ff:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0101602:	39 d8                	cmp    %ebx,%eax
f0101604:	74 0b                	je     f0101611 <strlcpy+0x32>
f0101606:	0f b6 0a             	movzbl (%edx),%ecx
f0101609:	84 c9                	test   %cl,%cl
f010160b:	75 ec                	jne    f01015f9 <strlcpy+0x1a>
f010160d:	89 c2                	mov    %eax,%edx
f010160f:	eb 02                	jmp    f0101613 <strlcpy+0x34>
f0101611:	89 c2                	mov    %eax,%edx
			*dst++ = *src++;
		*dst = '\0';
f0101613:	c6 02 00             	movb   $0x0,(%edx)
	}
	return dst - dst_in;
f0101616:	29 f0                	sub    %esi,%eax
}
f0101618:	5b                   	pop    %ebx
f0101619:	5e                   	pop    %esi
f010161a:	5d                   	pop    %ebp
f010161b:	c3                   	ret    

f010161c <strcmp>:

int
strcmp(const char *p, const char *q)
{
f010161c:	55                   	push   %ebp
f010161d:	89 e5                	mov    %esp,%ebp
f010161f:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101622:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0101625:	eb 06                	jmp    f010162d <strcmp+0x11>
		p++, q++;
f0101627:	83 c1 01             	add    $0x1,%ecx
f010162a:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f010162d:	0f b6 01             	movzbl (%ecx),%eax
f0101630:	84 c0                	test   %al,%al
f0101632:	74 04                	je     f0101638 <strcmp+0x1c>
f0101634:	3a 02                	cmp    (%edx),%al
f0101636:	74 ef                	je     f0101627 <strcmp+0xb>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0101638:	0f b6 c0             	movzbl %al,%eax
f010163b:	0f b6 12             	movzbl (%edx),%edx
f010163e:	29 d0                	sub    %edx,%eax
}
f0101640:	5d                   	pop    %ebp
f0101641:	c3                   	ret    

f0101642 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0101642:	55                   	push   %ebp
f0101643:	89 e5                	mov    %esp,%ebp
f0101645:	53                   	push   %ebx
f0101646:	8b 45 08             	mov    0x8(%ebp),%eax
f0101649:	8b 55 0c             	mov    0xc(%ebp),%edx
f010164c:	89 c3                	mov    %eax,%ebx
f010164e:	03 5d 10             	add    0x10(%ebp),%ebx
	while (n > 0 && *p && *p == *q)
f0101651:	eb 06                	jmp    f0101659 <strncmp+0x17>
		n--, p++, q++;
f0101653:	83 c0 01             	add    $0x1,%eax
f0101656:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0101659:	39 d8                	cmp    %ebx,%eax
f010165b:	74 15                	je     f0101672 <strncmp+0x30>
f010165d:	0f b6 08             	movzbl (%eax),%ecx
f0101660:	84 c9                	test   %cl,%cl
f0101662:	74 04                	je     f0101668 <strncmp+0x26>
f0101664:	3a 0a                	cmp    (%edx),%cl
f0101666:	74 eb                	je     f0101653 <strncmp+0x11>
		n--, p++, q++;
	if (n == 0)
		return 0;
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0101668:	0f b6 00             	movzbl (%eax),%eax
f010166b:	0f b6 12             	movzbl (%edx),%edx
f010166e:	29 d0                	sub    %edx,%eax
f0101670:	eb 05                	jmp    f0101677 <strncmp+0x35>
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
		n--, p++, q++;
	if (n == 0)
		return 0;
f0101672:	b8 00 00 00 00       	mov    $0x0,%eax
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
}
f0101677:	5b                   	pop    %ebx
f0101678:	5d                   	pop    %ebp
f0101679:	c3                   	ret    

f010167a <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f010167a:	55                   	push   %ebp
f010167b:	89 e5                	mov    %esp,%ebp
f010167d:	8b 45 08             	mov    0x8(%ebp),%eax
f0101680:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f0101684:	eb 07                	jmp    f010168d <strchr+0x13>
		if (*s == c)
f0101686:	38 ca                	cmp    %cl,%dl
f0101688:	74 0f                	je     f0101699 <strchr+0x1f>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f010168a:	83 c0 01             	add    $0x1,%eax
f010168d:	0f b6 10             	movzbl (%eax),%edx
f0101690:	84 d2                	test   %dl,%dl
f0101692:	75 f2                	jne    f0101686 <strchr+0xc>
		if (*s == c)
			return (char *) s;
	return 0;
f0101694:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0101699:	5d                   	pop    %ebp
f010169a:	c3                   	ret    

f010169b <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f010169b:	55                   	push   %ebp
f010169c:	89 e5                	mov    %esp,%ebp
f010169e:	8b 45 08             	mov    0x8(%ebp),%eax
f01016a1:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f01016a5:	eb 07                	jmp    f01016ae <strfind+0x13>
		if (*s == c)
f01016a7:	38 ca                	cmp    %cl,%dl
f01016a9:	74 0a                	je     f01016b5 <strfind+0x1a>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f01016ab:	83 c0 01             	add    $0x1,%eax
f01016ae:	0f b6 10             	movzbl (%eax),%edx
f01016b1:	84 d2                	test   %dl,%dl
f01016b3:	75 f2                	jne    f01016a7 <strfind+0xc>
		if (*s == c)
			break;
	return (char *) s;
}
f01016b5:	5d                   	pop    %ebp
f01016b6:	c3                   	ret    

f01016b7 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01016b7:	55                   	push   %ebp
f01016b8:	89 e5                	mov    %esp,%ebp
f01016ba:	57                   	push   %edi
f01016bb:	56                   	push   %esi
f01016bc:	53                   	push   %ebx
f01016bd:	8b 7d 08             	mov    0x8(%ebp),%edi
f01016c0:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f01016c3:	85 c9                	test   %ecx,%ecx
f01016c5:	74 36                	je     f01016fd <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f01016c7:	f7 c7 03 00 00 00    	test   $0x3,%edi
f01016cd:	75 28                	jne    f01016f7 <memset+0x40>
f01016cf:	f6 c1 03             	test   $0x3,%cl
f01016d2:	75 23                	jne    f01016f7 <memset+0x40>
		c &= 0xFF;
f01016d4:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f01016d8:	89 d3                	mov    %edx,%ebx
f01016da:	c1 e3 08             	shl    $0x8,%ebx
f01016dd:	89 d6                	mov    %edx,%esi
f01016df:	c1 e6 18             	shl    $0x18,%esi
f01016e2:	89 d0                	mov    %edx,%eax
f01016e4:	c1 e0 10             	shl    $0x10,%eax
f01016e7:	09 f0                	or     %esi,%eax
f01016e9:	09 c2                	or     %eax,%edx
f01016eb:	89 d0                	mov    %edx,%eax
f01016ed:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f01016ef:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f01016f2:	fc                   	cld    
f01016f3:	f3 ab                	rep stos %eax,%es:(%edi)
f01016f5:	eb 06                	jmp    f01016fd <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f01016f7:	8b 45 0c             	mov    0xc(%ebp),%eax
f01016fa:	fc                   	cld    
f01016fb:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f01016fd:	89 f8                	mov    %edi,%eax
f01016ff:	5b                   	pop    %ebx
f0101700:	5e                   	pop    %esi
f0101701:	5f                   	pop    %edi
f0101702:	5d                   	pop    %ebp
f0101703:	c3                   	ret    

f0101704 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0101704:	55                   	push   %ebp
f0101705:	89 e5                	mov    %esp,%ebp
f0101707:	57                   	push   %edi
f0101708:	56                   	push   %esi
f0101709:	8b 45 08             	mov    0x8(%ebp),%eax
f010170c:	8b 75 0c             	mov    0xc(%ebp),%esi
f010170f:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;

	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0101712:	39 c6                	cmp    %eax,%esi
f0101714:	73 35                	jae    f010174b <memmove+0x47>
f0101716:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0101719:	39 d0                	cmp    %edx,%eax
f010171b:	73 2e                	jae    f010174b <memmove+0x47>
		s += n;
		d += n;
f010171d:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0101720:	89 d6                	mov    %edx,%esi
f0101722:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101724:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010172a:	75 13                	jne    f010173f <memmove+0x3b>
f010172c:	f6 c1 03             	test   $0x3,%cl
f010172f:	75 0e                	jne    f010173f <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0101731:	83 ef 04             	sub    $0x4,%edi
f0101734:	8d 72 fc             	lea    -0x4(%edx),%esi
f0101737:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f010173a:	fd                   	std    
f010173b:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010173d:	eb 09                	jmp    f0101748 <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f010173f:	83 ef 01             	sub    $0x1,%edi
f0101742:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0101745:	fd                   	std    
f0101746:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0101748:	fc                   	cld    
f0101749:	eb 1d                	jmp    f0101768 <memmove+0x64>
f010174b:	89 f2                	mov    %esi,%edx
f010174d:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f010174f:	f6 c2 03             	test   $0x3,%dl
f0101752:	75 0f                	jne    f0101763 <memmove+0x5f>
f0101754:	f6 c1 03             	test   $0x3,%cl
f0101757:	75 0a                	jne    f0101763 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0101759:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f010175c:	89 c7                	mov    %eax,%edi
f010175e:	fc                   	cld    
f010175f:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101761:	eb 05                	jmp    f0101768 <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0101763:	89 c7                	mov    %eax,%edi
f0101765:	fc                   	cld    
f0101766:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0101768:	5e                   	pop    %esi
f0101769:	5f                   	pop    %edi
f010176a:	5d                   	pop    %ebp
f010176b:	c3                   	ret    

f010176c <memcpy>:
}
#endif

void *
memcpy(void *dst, const void *src, size_t n)
{
f010176c:	55                   	push   %ebp
f010176d:	89 e5                	mov    %esp,%ebp
f010176f:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0101772:	8b 45 10             	mov    0x10(%ebp),%eax
f0101775:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101779:	8b 45 0c             	mov    0xc(%ebp),%eax
f010177c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101780:	8b 45 08             	mov    0x8(%ebp),%eax
f0101783:	89 04 24             	mov    %eax,(%esp)
f0101786:	e8 79 ff ff ff       	call   f0101704 <memmove>
}
f010178b:	c9                   	leave  
f010178c:	c3                   	ret    

f010178d <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f010178d:	55                   	push   %ebp
f010178e:	89 e5                	mov    %esp,%ebp
f0101790:	56                   	push   %esi
f0101791:	53                   	push   %ebx
f0101792:	8b 55 08             	mov    0x8(%ebp),%edx
f0101795:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0101798:	89 d6                	mov    %edx,%esi
f010179a:	03 75 10             	add    0x10(%ebp),%esi
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f010179d:	eb 1a                	jmp    f01017b9 <memcmp+0x2c>
		if (*s1 != *s2)
f010179f:	0f b6 02             	movzbl (%edx),%eax
f01017a2:	0f b6 19             	movzbl (%ecx),%ebx
f01017a5:	38 d8                	cmp    %bl,%al
f01017a7:	74 0a                	je     f01017b3 <memcmp+0x26>
			return (int) *s1 - (int) *s2;
f01017a9:	0f b6 c0             	movzbl %al,%eax
f01017ac:	0f b6 db             	movzbl %bl,%ebx
f01017af:	29 d8                	sub    %ebx,%eax
f01017b1:	eb 0f                	jmp    f01017c2 <memcmp+0x35>
		s1++, s2++;
f01017b3:	83 c2 01             	add    $0x1,%edx
f01017b6:	83 c1 01             	add    $0x1,%ecx
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01017b9:	39 f2                	cmp    %esi,%edx
f01017bb:	75 e2                	jne    f010179f <memcmp+0x12>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f01017bd:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01017c2:	5b                   	pop    %ebx
f01017c3:	5e                   	pop    %esi
f01017c4:	5d                   	pop    %ebp
f01017c5:	c3                   	ret    

f01017c6 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f01017c6:	55                   	push   %ebp
f01017c7:	89 e5                	mov    %esp,%ebp
f01017c9:	8b 45 08             	mov    0x8(%ebp),%eax
f01017cc:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	const void *ends = (const char *) s + n;
f01017cf:	89 c2                	mov    %eax,%edx
f01017d1:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f01017d4:	eb 07                	jmp    f01017dd <memfind+0x17>
		if (*(const unsigned char *) s == (unsigned char) c)
f01017d6:	38 08                	cmp    %cl,(%eax)
f01017d8:	74 07                	je     f01017e1 <memfind+0x1b>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f01017da:	83 c0 01             	add    $0x1,%eax
f01017dd:	39 d0                	cmp    %edx,%eax
f01017df:	72 f5                	jb     f01017d6 <memfind+0x10>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f01017e1:	5d                   	pop    %ebp
f01017e2:	c3                   	ret    

f01017e3 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f01017e3:	55                   	push   %ebp
f01017e4:	89 e5                	mov    %esp,%ebp
f01017e6:	57                   	push   %edi
f01017e7:	56                   	push   %esi
f01017e8:	53                   	push   %ebx
f01017e9:	8b 55 08             	mov    0x8(%ebp),%edx
f01017ec:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f01017ef:	eb 03                	jmp    f01017f4 <strtol+0x11>
		s++;
f01017f1:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f01017f4:	0f b6 0a             	movzbl (%edx),%ecx
f01017f7:	80 f9 09             	cmp    $0x9,%cl
f01017fa:	74 f5                	je     f01017f1 <strtol+0xe>
f01017fc:	80 f9 20             	cmp    $0x20,%cl
f01017ff:	74 f0                	je     f01017f1 <strtol+0xe>
		s++;

	// plus/minus sign
	if (*s == '+')
f0101801:	80 f9 2b             	cmp    $0x2b,%cl
f0101804:	75 0a                	jne    f0101810 <strtol+0x2d>
		s++;
f0101806:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0101809:	bf 00 00 00 00       	mov    $0x0,%edi
f010180e:	eb 11                	jmp    f0101821 <strtol+0x3e>
f0101810:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0101815:	80 f9 2d             	cmp    $0x2d,%cl
f0101818:	75 07                	jne    f0101821 <strtol+0x3e>
		s++, neg = 1;
f010181a:	8d 52 01             	lea    0x1(%edx),%edx
f010181d:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0101821:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0101826:	75 15                	jne    f010183d <strtol+0x5a>
f0101828:	80 3a 30             	cmpb   $0x30,(%edx)
f010182b:	75 10                	jne    f010183d <strtol+0x5a>
f010182d:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0101831:	75 0a                	jne    f010183d <strtol+0x5a>
		s += 2, base = 16;
f0101833:	83 c2 02             	add    $0x2,%edx
f0101836:	b8 10 00 00 00       	mov    $0x10,%eax
f010183b:	eb 10                	jmp    f010184d <strtol+0x6a>
	else if (base == 0 && s[0] == '0')
f010183d:	85 c0                	test   %eax,%eax
f010183f:	75 0c                	jne    f010184d <strtol+0x6a>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0101841:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0101843:	80 3a 30             	cmpb   $0x30,(%edx)
f0101846:	75 05                	jne    f010184d <strtol+0x6a>
		s++, base = 8;
f0101848:	83 c2 01             	add    $0x1,%edx
f010184b:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f010184d:	bb 00 00 00 00       	mov    $0x0,%ebx
f0101852:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0101855:	0f b6 0a             	movzbl (%edx),%ecx
f0101858:	8d 71 d0             	lea    -0x30(%ecx),%esi
f010185b:	89 f0                	mov    %esi,%eax
f010185d:	3c 09                	cmp    $0x9,%al
f010185f:	77 08                	ja     f0101869 <strtol+0x86>
			dig = *s - '0';
f0101861:	0f be c9             	movsbl %cl,%ecx
f0101864:	83 e9 30             	sub    $0x30,%ecx
f0101867:	eb 20                	jmp    f0101889 <strtol+0xa6>
		else if (*s >= 'a' && *s <= 'z')
f0101869:	8d 71 9f             	lea    -0x61(%ecx),%esi
f010186c:	89 f0                	mov    %esi,%eax
f010186e:	3c 19                	cmp    $0x19,%al
f0101870:	77 08                	ja     f010187a <strtol+0x97>
			dig = *s - 'a' + 10;
f0101872:	0f be c9             	movsbl %cl,%ecx
f0101875:	83 e9 57             	sub    $0x57,%ecx
f0101878:	eb 0f                	jmp    f0101889 <strtol+0xa6>
		else if (*s >= 'A' && *s <= 'Z')
f010187a:	8d 71 bf             	lea    -0x41(%ecx),%esi
f010187d:	89 f0                	mov    %esi,%eax
f010187f:	3c 19                	cmp    $0x19,%al
f0101881:	77 16                	ja     f0101899 <strtol+0xb6>
			dig = *s - 'A' + 10;
f0101883:	0f be c9             	movsbl %cl,%ecx
f0101886:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f0101889:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f010188c:	7d 0f                	jge    f010189d <strtol+0xba>
			break;
		s++, val = (val * base) + dig;
f010188e:	83 c2 01             	add    $0x1,%edx
f0101891:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f0101895:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f0101897:	eb bc                	jmp    f0101855 <strtol+0x72>
f0101899:	89 d8                	mov    %ebx,%eax
f010189b:	eb 02                	jmp    f010189f <strtol+0xbc>
f010189d:	89 d8                	mov    %ebx,%eax

	if (endptr)
f010189f:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01018a3:	74 05                	je     f01018aa <strtol+0xc7>
		*endptr = (char *) s;
f01018a5:	8b 75 0c             	mov    0xc(%ebp),%esi
f01018a8:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f01018aa:	f7 d8                	neg    %eax
f01018ac:	85 ff                	test   %edi,%edi
f01018ae:	0f 44 c3             	cmove  %ebx,%eax
}
f01018b1:	5b                   	pop    %ebx
f01018b2:	5e                   	pop    %esi
f01018b3:	5f                   	pop    %edi
f01018b4:	5d                   	pop    %ebp
f01018b5:	c3                   	ret    
f01018b6:	66 90                	xchg   %ax,%ax
f01018b8:	66 90                	xchg   %ax,%ax
f01018ba:	66 90                	xchg   %ax,%ax
f01018bc:	66 90                	xchg   %ax,%ax
f01018be:	66 90                	xchg   %ax,%ax

f01018c0 <__udivdi3>:
f01018c0:	55                   	push   %ebp
f01018c1:	57                   	push   %edi
f01018c2:	56                   	push   %esi
f01018c3:	83 ec 0c             	sub    $0xc,%esp
f01018c6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01018ca:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01018ce:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f01018d2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01018d6:	85 c0                	test   %eax,%eax
f01018d8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01018dc:	89 ea                	mov    %ebp,%edx
f01018de:	89 0c 24             	mov    %ecx,(%esp)
f01018e1:	75 2d                	jne    f0101910 <__udivdi3+0x50>
f01018e3:	39 e9                	cmp    %ebp,%ecx
f01018e5:	77 61                	ja     f0101948 <__udivdi3+0x88>
f01018e7:	85 c9                	test   %ecx,%ecx
f01018e9:	89 ce                	mov    %ecx,%esi
f01018eb:	75 0b                	jne    f01018f8 <__udivdi3+0x38>
f01018ed:	b8 01 00 00 00       	mov    $0x1,%eax
f01018f2:	31 d2                	xor    %edx,%edx
f01018f4:	f7 f1                	div    %ecx
f01018f6:	89 c6                	mov    %eax,%esi
f01018f8:	31 d2                	xor    %edx,%edx
f01018fa:	89 e8                	mov    %ebp,%eax
f01018fc:	f7 f6                	div    %esi
f01018fe:	89 c5                	mov    %eax,%ebp
f0101900:	89 f8                	mov    %edi,%eax
f0101902:	f7 f6                	div    %esi
f0101904:	89 ea                	mov    %ebp,%edx
f0101906:	83 c4 0c             	add    $0xc,%esp
f0101909:	5e                   	pop    %esi
f010190a:	5f                   	pop    %edi
f010190b:	5d                   	pop    %ebp
f010190c:	c3                   	ret    
f010190d:	8d 76 00             	lea    0x0(%esi),%esi
f0101910:	39 e8                	cmp    %ebp,%eax
f0101912:	77 24                	ja     f0101938 <__udivdi3+0x78>
f0101914:	0f bd e8             	bsr    %eax,%ebp
f0101917:	83 f5 1f             	xor    $0x1f,%ebp
f010191a:	75 3c                	jne    f0101958 <__udivdi3+0x98>
f010191c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0101920:	39 34 24             	cmp    %esi,(%esp)
f0101923:	0f 86 9f 00 00 00    	jbe    f01019c8 <__udivdi3+0x108>
f0101929:	39 d0                	cmp    %edx,%eax
f010192b:	0f 82 97 00 00 00    	jb     f01019c8 <__udivdi3+0x108>
f0101931:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101938:	31 d2                	xor    %edx,%edx
f010193a:	31 c0                	xor    %eax,%eax
f010193c:	83 c4 0c             	add    $0xc,%esp
f010193f:	5e                   	pop    %esi
f0101940:	5f                   	pop    %edi
f0101941:	5d                   	pop    %ebp
f0101942:	c3                   	ret    
f0101943:	90                   	nop
f0101944:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101948:	89 f8                	mov    %edi,%eax
f010194a:	f7 f1                	div    %ecx
f010194c:	31 d2                	xor    %edx,%edx
f010194e:	83 c4 0c             	add    $0xc,%esp
f0101951:	5e                   	pop    %esi
f0101952:	5f                   	pop    %edi
f0101953:	5d                   	pop    %ebp
f0101954:	c3                   	ret    
f0101955:	8d 76 00             	lea    0x0(%esi),%esi
f0101958:	89 e9                	mov    %ebp,%ecx
f010195a:	8b 3c 24             	mov    (%esp),%edi
f010195d:	d3 e0                	shl    %cl,%eax
f010195f:	89 c6                	mov    %eax,%esi
f0101961:	b8 20 00 00 00       	mov    $0x20,%eax
f0101966:	29 e8                	sub    %ebp,%eax
f0101968:	89 c1                	mov    %eax,%ecx
f010196a:	d3 ef                	shr    %cl,%edi
f010196c:	89 e9                	mov    %ebp,%ecx
f010196e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0101972:	8b 3c 24             	mov    (%esp),%edi
f0101975:	09 74 24 08          	or     %esi,0x8(%esp)
f0101979:	89 d6                	mov    %edx,%esi
f010197b:	d3 e7                	shl    %cl,%edi
f010197d:	89 c1                	mov    %eax,%ecx
f010197f:	89 3c 24             	mov    %edi,(%esp)
f0101982:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0101986:	d3 ee                	shr    %cl,%esi
f0101988:	89 e9                	mov    %ebp,%ecx
f010198a:	d3 e2                	shl    %cl,%edx
f010198c:	89 c1                	mov    %eax,%ecx
f010198e:	d3 ef                	shr    %cl,%edi
f0101990:	09 d7                	or     %edx,%edi
f0101992:	89 f2                	mov    %esi,%edx
f0101994:	89 f8                	mov    %edi,%eax
f0101996:	f7 74 24 08          	divl   0x8(%esp)
f010199a:	89 d6                	mov    %edx,%esi
f010199c:	89 c7                	mov    %eax,%edi
f010199e:	f7 24 24             	mull   (%esp)
f01019a1:	39 d6                	cmp    %edx,%esi
f01019a3:	89 14 24             	mov    %edx,(%esp)
f01019a6:	72 30                	jb     f01019d8 <__udivdi3+0x118>
f01019a8:	8b 54 24 04          	mov    0x4(%esp),%edx
f01019ac:	89 e9                	mov    %ebp,%ecx
f01019ae:	d3 e2                	shl    %cl,%edx
f01019b0:	39 c2                	cmp    %eax,%edx
f01019b2:	73 05                	jae    f01019b9 <__udivdi3+0xf9>
f01019b4:	3b 34 24             	cmp    (%esp),%esi
f01019b7:	74 1f                	je     f01019d8 <__udivdi3+0x118>
f01019b9:	89 f8                	mov    %edi,%eax
f01019bb:	31 d2                	xor    %edx,%edx
f01019bd:	e9 7a ff ff ff       	jmp    f010193c <__udivdi3+0x7c>
f01019c2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f01019c8:	31 d2                	xor    %edx,%edx
f01019ca:	b8 01 00 00 00       	mov    $0x1,%eax
f01019cf:	e9 68 ff ff ff       	jmp    f010193c <__udivdi3+0x7c>
f01019d4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01019d8:	8d 47 ff             	lea    -0x1(%edi),%eax
f01019db:	31 d2                	xor    %edx,%edx
f01019dd:	83 c4 0c             	add    $0xc,%esp
f01019e0:	5e                   	pop    %esi
f01019e1:	5f                   	pop    %edi
f01019e2:	5d                   	pop    %ebp
f01019e3:	c3                   	ret    
f01019e4:	66 90                	xchg   %ax,%ax
f01019e6:	66 90                	xchg   %ax,%ax
f01019e8:	66 90                	xchg   %ax,%ax
f01019ea:	66 90                	xchg   %ax,%ax
f01019ec:	66 90                	xchg   %ax,%ax
f01019ee:	66 90                	xchg   %ax,%ax

f01019f0 <__umoddi3>:
f01019f0:	55                   	push   %ebp
f01019f1:	57                   	push   %edi
f01019f2:	56                   	push   %esi
f01019f3:	83 ec 14             	sub    $0x14,%esp
f01019f6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01019fa:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01019fe:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0101a02:	89 c7                	mov    %eax,%edi
f0101a04:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101a08:	8b 44 24 30          	mov    0x30(%esp),%eax
f0101a0c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0101a10:	89 34 24             	mov    %esi,(%esp)
f0101a13:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101a17:	85 c0                	test   %eax,%eax
f0101a19:	89 c2                	mov    %eax,%edx
f0101a1b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101a1f:	75 17                	jne    f0101a38 <__umoddi3+0x48>
f0101a21:	39 fe                	cmp    %edi,%esi
f0101a23:	76 4b                	jbe    f0101a70 <__umoddi3+0x80>
f0101a25:	89 c8                	mov    %ecx,%eax
f0101a27:	89 fa                	mov    %edi,%edx
f0101a29:	f7 f6                	div    %esi
f0101a2b:	89 d0                	mov    %edx,%eax
f0101a2d:	31 d2                	xor    %edx,%edx
f0101a2f:	83 c4 14             	add    $0x14,%esp
f0101a32:	5e                   	pop    %esi
f0101a33:	5f                   	pop    %edi
f0101a34:	5d                   	pop    %ebp
f0101a35:	c3                   	ret    
f0101a36:	66 90                	xchg   %ax,%ax
f0101a38:	39 f8                	cmp    %edi,%eax
f0101a3a:	77 54                	ja     f0101a90 <__umoddi3+0xa0>
f0101a3c:	0f bd e8             	bsr    %eax,%ebp
f0101a3f:	83 f5 1f             	xor    $0x1f,%ebp
f0101a42:	75 5c                	jne    f0101aa0 <__umoddi3+0xb0>
f0101a44:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0101a48:	39 3c 24             	cmp    %edi,(%esp)
f0101a4b:	0f 87 e7 00 00 00    	ja     f0101b38 <__umoddi3+0x148>
f0101a51:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0101a55:	29 f1                	sub    %esi,%ecx
f0101a57:	19 c7                	sbb    %eax,%edi
f0101a59:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101a5d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101a61:	8b 44 24 08          	mov    0x8(%esp),%eax
f0101a65:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0101a69:	83 c4 14             	add    $0x14,%esp
f0101a6c:	5e                   	pop    %esi
f0101a6d:	5f                   	pop    %edi
f0101a6e:	5d                   	pop    %ebp
f0101a6f:	c3                   	ret    
f0101a70:	85 f6                	test   %esi,%esi
f0101a72:	89 f5                	mov    %esi,%ebp
f0101a74:	75 0b                	jne    f0101a81 <__umoddi3+0x91>
f0101a76:	b8 01 00 00 00       	mov    $0x1,%eax
f0101a7b:	31 d2                	xor    %edx,%edx
f0101a7d:	f7 f6                	div    %esi
f0101a7f:	89 c5                	mov    %eax,%ebp
f0101a81:	8b 44 24 04          	mov    0x4(%esp),%eax
f0101a85:	31 d2                	xor    %edx,%edx
f0101a87:	f7 f5                	div    %ebp
f0101a89:	89 c8                	mov    %ecx,%eax
f0101a8b:	f7 f5                	div    %ebp
f0101a8d:	eb 9c                	jmp    f0101a2b <__umoddi3+0x3b>
f0101a8f:	90                   	nop
f0101a90:	89 c8                	mov    %ecx,%eax
f0101a92:	89 fa                	mov    %edi,%edx
f0101a94:	83 c4 14             	add    $0x14,%esp
f0101a97:	5e                   	pop    %esi
f0101a98:	5f                   	pop    %edi
f0101a99:	5d                   	pop    %ebp
f0101a9a:	c3                   	ret    
f0101a9b:	90                   	nop
f0101a9c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101aa0:	8b 04 24             	mov    (%esp),%eax
f0101aa3:	be 20 00 00 00       	mov    $0x20,%esi
f0101aa8:	89 e9                	mov    %ebp,%ecx
f0101aaa:	29 ee                	sub    %ebp,%esi
f0101aac:	d3 e2                	shl    %cl,%edx
f0101aae:	89 f1                	mov    %esi,%ecx
f0101ab0:	d3 e8                	shr    %cl,%eax
f0101ab2:	89 e9                	mov    %ebp,%ecx
f0101ab4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101ab8:	8b 04 24             	mov    (%esp),%eax
f0101abb:	09 54 24 04          	or     %edx,0x4(%esp)
f0101abf:	89 fa                	mov    %edi,%edx
f0101ac1:	d3 e0                	shl    %cl,%eax
f0101ac3:	89 f1                	mov    %esi,%ecx
f0101ac5:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101ac9:	8b 44 24 10          	mov    0x10(%esp),%eax
f0101acd:	d3 ea                	shr    %cl,%edx
f0101acf:	89 e9                	mov    %ebp,%ecx
f0101ad1:	d3 e7                	shl    %cl,%edi
f0101ad3:	89 f1                	mov    %esi,%ecx
f0101ad5:	d3 e8                	shr    %cl,%eax
f0101ad7:	89 e9                	mov    %ebp,%ecx
f0101ad9:	09 f8                	or     %edi,%eax
f0101adb:	8b 7c 24 10          	mov    0x10(%esp),%edi
f0101adf:	f7 74 24 04          	divl   0x4(%esp)
f0101ae3:	d3 e7                	shl    %cl,%edi
f0101ae5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101ae9:	89 d7                	mov    %edx,%edi
f0101aeb:	f7 64 24 08          	mull   0x8(%esp)
f0101aef:	39 d7                	cmp    %edx,%edi
f0101af1:	89 c1                	mov    %eax,%ecx
f0101af3:	89 14 24             	mov    %edx,(%esp)
f0101af6:	72 2c                	jb     f0101b24 <__umoddi3+0x134>
f0101af8:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f0101afc:	72 22                	jb     f0101b20 <__umoddi3+0x130>
f0101afe:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0101b02:	29 c8                	sub    %ecx,%eax
f0101b04:	19 d7                	sbb    %edx,%edi
f0101b06:	89 e9                	mov    %ebp,%ecx
f0101b08:	89 fa                	mov    %edi,%edx
f0101b0a:	d3 e8                	shr    %cl,%eax
f0101b0c:	89 f1                	mov    %esi,%ecx
f0101b0e:	d3 e2                	shl    %cl,%edx
f0101b10:	89 e9                	mov    %ebp,%ecx
f0101b12:	d3 ef                	shr    %cl,%edi
f0101b14:	09 d0                	or     %edx,%eax
f0101b16:	89 fa                	mov    %edi,%edx
f0101b18:	83 c4 14             	add    $0x14,%esp
f0101b1b:	5e                   	pop    %esi
f0101b1c:	5f                   	pop    %edi
f0101b1d:	5d                   	pop    %ebp
f0101b1e:	c3                   	ret    
f0101b1f:	90                   	nop
f0101b20:	39 d7                	cmp    %edx,%edi
f0101b22:	75 da                	jne    f0101afe <__umoddi3+0x10e>
f0101b24:	8b 14 24             	mov    (%esp),%edx
f0101b27:	89 c1                	mov    %eax,%ecx
f0101b29:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0101b2d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0101b31:	eb cb                	jmp    f0101afe <__umoddi3+0x10e>
f0101b33:	90                   	nop
f0101b34:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101b38:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0101b3c:	0f 82 0f ff ff ff    	jb     f0101a51 <__umoddi3+0x61>
f0101b42:	e9 1a ff ff ff       	jmp    f0101a61 <__umoddi3+0x71>
