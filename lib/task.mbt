///|
async fn[T] pick_fatest(
  dispatcher : async (TaskStatus) -> Unit,
  tasks : FixedArray[async (Int, TaskStatus) -> T?],
) -> T? {
  if tasks.is_empty() {
    raise StringError("任务不能为空")
  }
  @async.with_task_group(fn(root) -> T? {
    let task_count = tasks.length()
    let states = FixedArray::make(task_count, 0L)
    let task_status = TaskStatus::{
      check_continue: false,
      states,
      stopped_ids: [],
    }
    let invoke_tasks = []
    for index, task in tasks {
      invoke_tasks.push(root.spawn(fn() { task(index, task_status) }))
    }
    // dispatcher必须放到最后，因为states的下标与tasks的下标对应
    invoke_tasks.push(
      root.spawn(fn() {
        dispatcher(task_status)
        None
      }),
    )
    let dispatcher_id = invoke_tasks.length() - 1
    println("等待任务完成---------------")
    let complete_ids = []
    while true {
      for id, task in invoke_tasks {
        if complete_ids.contains(id) {
          continue
        }
        // println("尝试等待：\{id}...")
        let res = task.try_wait() catch {
          e => {
            println("错误: \{e}")
            None
          }
        }
        guard res is Some(res) else { continue }
        complete_ids.push(id)
        if id == dispatcher_id {
          // dispatcher任务，无需走后续逻辑
          continue
        }
        if res is Some(res) {
          if complete_ids.contains(dispatcher_id) {
            println("任务 \{id} 完成")
          } else {
            println("任务 \{id} 提前完成")
          }
          // 停止其他任务
          task_status.stop_others(id)
          return Some(res)
        } else {
          task_status.stop(id)
          println("任务 \{id} 终止")
        }
      }
      @async.pause()
      if invoke_tasks.length() == complete_ids.length() {
        break
      }
    }
    println("所有任务完成=================")
    None
  })
}

///|
struct TaskStatus {
  // 是否需要检查任务继续执行
  mut check_continue : Bool
  // 下标值作为id，每个项的值作为任务进度
  states : FixedArray[Int64]
  // 已经暂停的id
  stopped_ids : Array[Int]
}

///|
pub fn TaskStatus::start_check(self : TaskStatus) -> Unit {
  self.check_continue = true
}

///|
/// 设置任务状态值
fn TaskStatus::set(self : TaskStatus, id : Int, value : Int64) -> Unit {
  self.states[id] = value
}

///|
/// 停止任务
fn TaskStatus::stop(self : TaskStatus, id : Int) -> Unit {
  if id < 0 || id > self.states.length() {
    return
  }
  self.stopped_ids.push(id)
}

///|
/// 停止其他任务
fn TaskStatus::stop_others(self : TaskStatus, id : Int) -> Unit {
  for other_id, _ in self.states {
    if other_id != id && !self.stopped_ids.contains(other_id) {
      self.stopped_ids.push(other_id)
    }
  }
}

///|
/// 判断任务是否继续执行
fn TaskStatus::is_continue(self : TaskStatus, id : Int) -> Bool {
  if self.stopped_ids.contains(id) {
    return false
  }
  if self.check_continue {
    let current_value = self.states[id]
    for other_id, other_value in self.states {
      // 跳过自己、已经停止的
      if id == other_id || self.stopped_ids.contains(other_id) {
        continue
      }
      // 如果有其他任务的值更大，并且排在自己前面，则停止执行
      if other_value > current_value ||
        (other_value == current_value && other_id < id) {
        self.stop(id)
        return false
      }
    }
  }
  true
}

///|
/// 是否只有当前任务在运行
pub fn TaskStatus::only_current_running(self : TaskStatus, id : Int) -> Bool {
  !self.stopped_ids.contains(id) &&
  self.states.length() - self.stopped_ids.length() == 1
}

///|
type RaceFn[T] = async () -> T?

///|
pub async fn[T] race(tasks : FixedArray[RaceFn[T]]) -> T? {
  let mut race_result = None
  @async.with_task_group(async fn(root) {
    let tasks = tasks.map(task => root.spawn(async fn() { task() }))
    while true {
      for index, task in tasks {
        if task.try_wait() is Some(res) {
          // 取消其他任务
          for other_index, other_task in tasks {
            if index != other_index {
              other_task.cancel()
            }
          }
          race_result = res
          return None
        }
      }
      @async.pause()
    }
    None
  }) catch {
    e =>
      match e.to_string() {
        "Cancelled" => race_result
        _ => {
          println("错误：\{e}")
          None
        }
      }
  }
}

///|
pub async fn[T] race_with_ctrl_c(tasks : FixedArray[RaceFn[T]]) -> T? {
  let tasks = Array::from_fixed_array(tasks)
  tasks.push(async fn() {
    wait_signal(Signal::CTRL_C)
    None
  })
  race(FixedArray::from_array(tasks))
}

///|
/// 异步死循环，f函数返回(false, T)则终止循环
pub async fn[T] async_infinite_loop(f : async () -> (Bool, T)) -> T {
  while true {
    if f() is (false, res) {
      return res
    }
    @async.pause()
  }
  fail("async_infinite_loop出现异常")
}

///|
pub fn[T] get_async_infinite_loop(f : async () -> (Bool, T)) -> async () -> T {
  async fn() { async_infinite_loop(f) }
}
