///|
#borrow(text)
extern "c" fn console_overwrite(text : Bytes) -> Unit = "console_overwrite"

///|
pub extern "c" fn console_clear_line() -> Unit = "console_clear_line"

///|
pub fn overwrite_line(text : String) -> Unit {
  console_overwrite(@encoding/utf8.encode(text))
}
