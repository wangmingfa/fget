///|
async fn main {
  let args = @env.args()[1:]
  // println("args: \{args}")
  if args.length() < 1 {
    println("用法: fget.exe <url> [file_name]")
    return
  }
  // 检查gzip
  if !check_gzip() {
    println("请先安装 gzip，例如：")
    println("  Linux/macOS: sudo apt install gzip 或 brew install gzip")
    println(
      "  Windows: 使用 Git Bash 或 在Powershell中运行 winget install GnuWin32.Gzip 安装 Gzip",
    )
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

///|
async fn check_gzip() -> Bool {
  let status = @process.run("gzip", ["--version"]) catch { _ => return false }
  return status == 0
}

///|
async test "test_gzip" {
  let success = check_gzip()
  let msg = if success {
    @lib.green("安装了")
  } else {
    @lib.red("没有安装")
  }
  println(msg + "gzip")
}
