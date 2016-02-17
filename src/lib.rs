#![feature(lang_items)]
#![feature(const_fn)] // new
#![feature(unique)] // new
#![no_std]

extern crate rlibc;

mod vga_buffer;

#[no_mangle]
pub extern  fn rust_main() {
    // let x = ["Hello", " ", "World", "!"];
    // let test = (0..3).flat_map(|x| 0..x).zip(0..);
    // let mut a = ("hello", 42);
    // a.1 += 1;
    raw_printing_test();
    vga_buffer::print_something();

//    loop {}
}

pub extern fn raw_printing_test () {
    
    let hello = b"Hello World!";
    let color_byte = 0x1f; // white foreground, blue background

    let mut hello_colored = [color_byte; 24];
    for (i, char_byte) in hello.into_iter().enumerate() {
        hello_colored[i*2] = *char_byte;
    }
    // write "Hello World!" to the centre of the VGA text buffer
    let buffer_ptr = (0xb8000 + 1988) as *mut _;
    unsafe { *buffer_ptr = hello_colored };

}


#[lang = "eh_personality"] extern fn eh_personality() {}
#[lang = "panic_fmt"] extern fn panic_fmt() -> ! {loop{}}
