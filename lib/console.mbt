///|
const RESET = "\u{001B}[0m"

///|
const RED = "\u{001B}[31m"

///|
const GREEN = "\u{001B}[32m"

///|
const YELLOW = "\u{001B}[33m"

///|
pub fn red(text : String) -> String {
  "\{RED}\{text}\{RESET}"
}

///|
pub fn green(text : String) -> String {
  "\{GREEN}\{text}\{RESET}"
}

///|
pub fn yellow(text : String) -> String {
  "\{YELLOW}\{text}\{RESET}"
}
