///|
async fn main {
  let args = @env.args()[1:]
  // println("args: \{args}")
  if args.length() < 1 {
    println("用法: fget.exe <url> [file_name]")
    return
  }
  let (url, file_name) = (args[0], args.get(1))
  let result = @lib.race_with_ctrl_c([async fn() { @lib.get(url, file_name) }])
  if result is Some(result) {
    let success = @lib.green("下载完成")
    println(
      "\{success}: \{result.file_path}, 大小：\{result.get_readable_size_with_unit()}，平均速度: \{result.get_readable_speed_with_unit()}，耗时: \{result.get_readable_time_with_unit()}，下载链接：\{result.url}",
    )
  } else {
    let fail = @lib.red("下载失败")
    println("\{fail}: \{url}")
  }
}
