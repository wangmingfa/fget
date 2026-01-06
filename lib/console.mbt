///|
const RESET = "\u{001B}[0m"

///|
const RED = "\u{001B}[31m"

///|
const GREEN = "\u{001B}[32m"

///|
const YELLOW = "\u{001B}[33m"

///|
pub fn[T : Show] red(text : T) -> String {
  "\{RED}\{text}\{RESET}"
}

///|
pub fn[T : Show] green(text : T) -> String {
  "\{GREEN}\{text}\{RESET}"
}

///|
pub fn[T : Show] yellow(text : T) -> String {
  "\{YELLOW}\{text}\{RESET}"
}
