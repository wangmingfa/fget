///|
async fn main {
  let args = @env.args()[1:]
  // println("args: \{args}")
  if args.length() < 1 {
    println("用法: fget.exe <url> [file_name]")
    return
  }
  @async.with_task_group(async fn(root) {
    let exit = Ref::new(false)
    let signal_task = root.spawn(async fn() {
      @lib.wait_signal(@lib.Signal::CTRL_C, exit)
    })
    let download_task = root.spawn(async fn() {
      let (url, file_name) = (args[0], args.get(1))
      let result = @lib.get(url, file_name)
      if result is Some(result) {
        let success = @lib.green("下载完成")
        println(
          "\{success}: \{result.file_path}, 大小：\{result.get_readable_size_with_unit()}，平均速度: \{result.get_readable_speed_with_unit()}，耗时: \{result.get_readable_time_with_unit()}，下载链接：\{result.url}",
        )
      } else {
        let fail = @lib.red("下载失败")
        println("\{fail}: \{url}")
      }
    })
    while true {
      if signal_task.try_wait() is Some(_) {
        // 按下了ctrl c，取消任务
        download_task.cancel()
        break
      }
      if download_task.try_wait() is Some(_) {
        // 下载完了
        exit.val = true
        break
      }
      @async.sleep(100)
    }
  }) catch {
    e =>
      match e.to_string() {
        "Cancelled" => ()
        _ => println("错误：\{e}")
      }
  }
}
