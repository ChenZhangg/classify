h = { "d" => 100, "a" => 200, "v" => 300, "e" => 400 }
k=h.keys
h.delete("a") # => 200
p [:a,:b] == [:b, :a]
p [:a,:b] == [:a, :b]