
f = open("puzzle1.data")
s = f.readlines()
f.close()

l1 = []
l2 = []

for line in s:
	comps = line.split(" ")
	c1 = int(comps[0])
	c2 = int(comps[3].strip())
	l1.append(c1)
	l2.append(c2)

print(l1)
