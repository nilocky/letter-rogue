extends Node
## Tier 1 hint service: brute-force combination/permutation word finding for small hand sizes.

func find_basic_word(letters: Array[String]) -> String:
	for n in range(3, letters.size() + 1):
		var result := _find_word_of_length(letters, n)
		if result != "":
			return result
	return ""


func _find_word_of_length(letters: Array[String], n: int) -> String:
	var indices := range(letters.size())
	var combos := _combinations(indices, n)
	for combo in combos:
		var chosen_letters: Array[String] = []
		for i in combo:
			chosen_letters.append(letters[i])
		var perms := _permutations(chosen_letters)
		for p in perms:
			var word := _join_string(p)
			if WordService.is_word(word):
				return word
	return ""


func _combinations(items: Array, k: int) -> Array[Array]:
	if k == 0:
		return [[]]
	if items.is_empty():
		return []
	var first := items[0]
	var rest := items.slice(1)
	var with_first := _combinations(rest, k - 1)
	for c in with_first:
		c.insert(0, first)
	var without_first := _combinations(rest, k)
	with_first.append_array(without_first)
	return with_first


func _permutations(items: Array) -> Array[Array]:
	if items.size() <= 1:
		return [items.duplicate()]
	var result: Array[Array] = []
	for i in range(items.size()):
		var item := items[i]
		var left := items.slice(0, i)
		var right := items.slice(i + 1)
		for p in _permutations(left + right):
			p.insert(0, item)
			result.append(p)
	var seen: Dictionary = {}
	var unique: Array[Array] = []
	for p in result:
		var key := _join_string(p)
		if not seen.has(key):
			seen[key] = true
			unique.append(p)
	return unique


func _join_string(arr: Array[String]) -> String:
	var out := ""
	for s in arr:
		out += s
	return out
