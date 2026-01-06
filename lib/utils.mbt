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
test "test_get_from_map_ignore_case" {
  let map = { "Content-Type": "application/json", "content-length": "1234" }
  inspect(
    get_from_map_ignore_case(map, "Content-Type"),
    content=(
      #|Some("application/json")
    ),
  )
  inspect(
    get_from_map_ignore_case(map, "CONTENT-LENGTH"),
    content=(
      #|Some("1234")
    ),
  )
  inspect(get_from_map_ignore_case(map, "Non-Existent"), content="None")
}

///|
pub fn round_to(value : Double, digits? : Int = 2) -> Double {
  let factor = (10.0 : Double).pow(digits.to_double())
  (value * factor).round() / factor
}

///|
test "test_round_to" {
  inspect(round_to(3.14159), content="3.14")
  inspect(round_to(1.005, digits=2), content="1")
  inspect(round_to(2.71828, digits=3), content="2.718")
  inspect(round_to(-1.2345123, digits=4), content="-1.2345")
  inspect(round_to(0.0), content="0")
  inspect(round_to(1.2, digits=3), content="1.2")
}

///|
pub fn[T] push_all(arr : Array[T], items : Array[T]) -> Unit {
  for item in items {
    arr.push(item)
  }
}

///|
test "test_push_all" {
  let arr = [1, 2, 3]
  push_all(arr, [4, 5, 6])
  inspect(arr, content="[1, 2, 3, 4, 5, 6]")
}

///|
pub async fn[T, K] async_map(arr : Array[T], f : async (T) -> K) -> Array[K] {
  let new_arr = []
  for a in arr {
    new_arr.push(f(a))
  }
  new_arr
}
