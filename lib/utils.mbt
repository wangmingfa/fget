///|
#borrow(text)
extern "c" fn console_overwrite(text : Bytes) -> Unit = "console_overwrite"

///|
pub extern "c" fn console_clear_line() -> Unit = "console_clear_line"

///|
pub fn overwrite_line(text : String) -> Unit {
  console_overwrite(@encoding/utf8.encode(text))
}

///|
pub fn get_from_map_ignore_case(
  map : Map[String, String],
  key : String,
) -> String? {
  let lower_key = key.to_lower()
  for k in map.keys() {
    if k.to_lower() == lower_key {
      return map.get(k)
    }
  }
  return None
}

///|
pub fn round_to(value : Double, digits? : Int = 2) -> Double {
  let factor = (10.0 : Double).pow(digits.to_double())
  (value * factor).round() / factor
}

///|
pub fn[T] push_all(arr : Array[T], items : Array[T]) -> Unit {
  for item in items {
    arr.push(item)
  }
}

///|
/// filename*=UTF-8''...
const PATTERN_STAR = "filename\\*=[Uu][Tt][Ff]-8''(?<name>[^;\\r\\n]+)"

///|
/// filename="..."
const PATTERN_PLAIN = "filename=\"*(?<name>[^\"]+)\"*"

///|
pub fn get_file_name(url : String, headers : Map[String, String]) -> String {
  // 先从content-disposition中获取文件名
  if get_from_map_ignore_case(headers, "Content-Disposition")
    is Some(disposition) &&
    disposition.contains("filename") {
    for pattern in [PATTERN_STAR, PATTERN_PLAIN] {
      let regexp = @regexp.compile(pattern) catch {
        _ =>
          // println("正则表达式编译错误: \{pattern}")
          continue
      }
      guard regexp.match_(disposition) is Some(result) else {
        // println("未匹配到文件名，尝试下一个模式...")
        continue
      }
      if result.results().get(1) is Some(file_name) &&
        file_name is Some(file_name) {
        return file_name.to_string()
      }
    }
  }
  // 否则从URL中提取文件名
  // println("从URL中提取文件名...")
  let arr = url.split("/").collect()
  return arr[arr.length() - 1].to_string()
}

///|
test "test_get_file_name" {
  let url = "http://example.com/files/testfile.txt"
  let headers1 = {
    "Content-Disposition": "attachment; filename=\"example.txt\"",
  }
  let headers2 = {
    "Content-Disposition": "attachment; filename*=UTF-8''example2.txt",
  }
  let headers3 = {
    "Content-Disposition": "attachment;filename=PixPin_2025-12-15_20-42-53.png",
  }
  let headers4 = {}
  inspect(get_file_name(url, headers1), content="example.txt")
  inspect(get_file_name(url, headers2), content="example2.txt")
  inspect(
    get_file_name(url, headers3),
    content="PixPin_2025-12-15_20-42-53.png",
  )
  inspect(get_file_name(url, headers4), content="testfile.txt")
}
