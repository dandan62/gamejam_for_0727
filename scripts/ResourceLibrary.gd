extends RefCounted
class_name ResourceLibrary
## res:// 以下のフォルダから .tres リソースを読み込むユーティリティ（状態なし）。
## カード/イベント/敵の読み込み方法を変えたいときはここだけ触ればよい。

static func load_dir(path: String) -> Array:
	var results := []
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("フォルダが見つかりません: %s" % path)
		return results
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# エクスポート時は "card_01.tres.remap" のような名前で列挙される
			if file_name.ends_with(".remap") or file_name.ends_with(".import"):
				file_name = file_name.get_basename()
			if file_name.ends_with(".tres"):
				var res := load(path.path_join(file_name))
				if res != null:
					results.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results
