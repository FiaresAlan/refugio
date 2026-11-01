--!nocheck
-- BuildNature.luau  (ModuleScript em ServerStorage/MapGen)
-- Rodar na Command Bar do Studio (modo Edit):
--   local N = require(game.ServerStorage.MapGen.BuildNature); N.Run()
-- Ou por partes: N.Walls() / N.Forest() / N.Bridges() / N.Clear()
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local M = {}

local CFG = {
	Seed = 7421,
	HalfSize = 1024,        -- metade do tamanho do mapa (studs). Ajuste se precisar.
	VillageRadius = 150,    -- raio do muro
	GateAngles = { 0 },     -- graus; 0 = lado +X, 90 = lado +Z, 180 = -X, 270 = -Z
	GateWidth = 26,
	WallHeight = 20,
	SegLen = 12,
	TowerEvery = 6,
	ForestGrid = 26,
	MaxTrees = 1800,
	MaxDetails = 2200,
	MaxBridges = 4,
	GiantChance = 0.02,    -- chance de arvore GIGANTE (110-170 studs)
	TallChance = 0.17,      -- chance de arvore alta (50-80 studs)
}

local BLOCK = {}
for _, m in ipairs({
	Enum.Material.Water, Enum.Material.Mud, Enum.Material.Ground, Enum.Material.Rock,
	Enum.Material.Slate, Enum.Material.Basalt, Enum.Material.Sand, Enum.Material.Cobblestone,
	Enum.Material.Pavement, Enum.Material.Asphalt, Enum.Material.Concrete, Enum.Material.Salt,
	Enum.Material.Limestone,
}) do BLOCK[m] = true end

local S = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function ground(x, z)
    local r = Workspace:Raycast(Vector3.new(x, 1500, z), Vector3.new(0, -3000, 0), params)
    if r then return r.Position, r.Material, r.Normal, r.Instance end
    return nil
end

local function okGround(x, z, maxSlope)
    local pos, mat, nrm, inst = ground(x, z)
    if not pos then return nil, "vazio" end
    if inst ~= Workspace.Terrain then return nil, "nao-terreno" end
    if BLOCK[mat] then return nil, mat.Name end
    if nrm.Y < (maxSlope or 0.8) then return nil, "inclinado" end
    return pos
end


local function freshFolder(name)
	local root = S.root
	local old = root:FindFirstChild(name)
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

local function setup(opts)
	if opts then for k, v in pairs(opts) do CFG[k] = v end end
	local ok, cfg = pcall(function() return require(script.Parent:WaitForChild("MapConfig", 3)) end)
	if ok and type(cfg) == "table" and not (opts and opts.HalfSize) then
		local s = cfg.MapSize or cfg.Size or cfg.WorldSize or cfg.TerrainSize
		if typeof(s) == "number" then CFG.HalfSize = s / 2
		elseif typeof(s) == "Vector3" then CFG.HalfSize = math.max(s.X, s.Z) / 2 end
	end
	local vc = Workspace:FindFirstChild("VillageCenter")
	S.center = Vector3.zero
	if vc then
		S.center = vc:IsA("BasePart") and vc.Position or vc:GetPivot().Position
		local r = vc:GetAttribute("Radius")
		if type(r) == "number" and not (opts and opts.VillageRadius) then CFG.VillageRadius = r end
	end
	S.R = CFG.VillageRadius
	S.half = CFG.HalfSize
	S.rng = Random.new(CFG.Seed)
	local root = Workspace:FindFirstChild("Nature")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Nature"
		root.Parent = Workspace
	end
	S.root = root
	params.FilterDescendantsInstances = { root }
	local assets = ServerStorage:FindFirstChild("Assets")
	S.assets = assets and assets:FindFirstChild("Nature")
	print(("[Nature] centro=%s raio=%d metade-do-mapa=%d"):format(tostring(S.center), S.R, S.half))
end

local function pool(prefixes, exclude)
	local list = {}
	if not S.assets then return list end
	for _, a in ipairs(S.assets:GetChildren()) do
		for _, p in ipairs(prefixes) do
			if a.Name:sub(1, #p) == p and not (exclude and a.Name:find(exclude)) then
				table.insert(list, a)
				break
			end
		end
	end
	return list
end

local function pick(list) return list[S.rng:NextInteger(1, #list)] end

local function sizeOf(i)
	if i:IsA("Model") then return i:GetExtentsSize() end
	return i.Size
end

local function prep(inst, shadow)
	local parts = inst:IsA("BasePart") and { inst } or inst:GetDescendants()
	for _, d in ipairs(parts) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = shadow
		end
	end
end

-- coloca um asset no chao, escalando para uma altura (ou maior dimensao) alvo
local function put(asset, pos, target, parent, useMax, shadow)
	local c = asset:Clone()
	local s = sizeOf(c)
	local ref = useMax and math.max(s.X, s.Y, s.Z) or s.Y
	local k = target / math.max(ref, 0.01)
	local yaw = S.rng:NextNumber(0, math.pi * 2)
	if c:IsA("Model") then
		c:ScaleTo(c:GetScale() * k)
		prep(c, shadow)
		c:PivotTo(CFrame.Angles(0, yaw, 0))
		local cf, size = c:GetBoundingBox()
		local delta = Vector3.new(pos.X - cf.X, (pos.Y - 0.3) - (cf.Y - size.Y / 2), pos.Z - cf.Z)
		c:PivotTo(c:GetPivot() + delta)
	else
		c.Size = c.Size * k
		prep(c, shadow)
		c.CFrame = CFrame.new(pos.X, pos.Y - 0.3 + c.Size.Y / 2, pos.Z) * CFrame.Angles(0, yaw, 0)
	end
	c.Parent = parent
	return c
end

local function nearGate(x, z, dist)
	local off = Vector3.new(x - S.center.X, 0, z - S.center.Z)
	if off.Magnitude < 1 then return false end
	for _, deg in ipairs(CFG.GateAngles) do
		local g = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
		if off.Unit:Dot(g) > 0.96 and off.Magnitude < S.R + dist then return true end
	end
	return false
end

local function naVila(x, z, margem)
    local dx, dz = math.abs(x - S.center.X), math.abs(z - S.center.Z)
    local box = math.max(dx, dz) < 110 + margem
    local circ = Vector3.new(dx, 0, dz).Magnitude < S.R + margem
    return box or circ
end

----------------------------------------------------------------- FLORESTA
function M.Forest()
	if not S.root then setup() end
	if not S.assets then warn("[Nature] ServerStorage/Assets/Nature nao encontrado") return end
	local trees = freshFolder("Trees")
	local details = freshFolder("Details")
	local c, R, half = S.center, S.R, S.half

	local conifers = pool({ "tree_pine" })
	local tallPines = pool({ "tree_pineTall" })
	local broad = pool({ "tree_oak", "tree_default", "tree_fat", "tree_detailed", "tree_blocks", "tree_cone" }, "fall")
	local fall = pool({ "tree_oak", "tree_default", "tree_fat", "tree_detailed", "tree_blocks" })
	local fallOnly = {}
	for _, a in ipairs(fall) do if a.Name:find("fall") then table.insert(fallOnly, a) end end
	if #conifers == 0 then conifers = broad end
	if #broad == 0 then broad = conifers end
	if #tallPines == 0 then tallPines = conifers end
	if #conifers == 0 then warn("[Nature] nenhuma arvore (tree_*) em Assets/Nature") return end

	local rej, placed = {}, 0
	local giants, talls = 0, 0
	local n = 0
	for gx = -half, half, CFG.ForestGrid do
		for gz = -half, half, CFG.ForestGrid do
			if placed >= CFG.MaxTrees then break end
			n += 1
			if n % 150 == 0 then task.wait() end
			local x = gx + S.rng:NextNumber(-12, 12)
			local z = gz + S.rng:NextNumber(-12, 12)
			local d = Vector3.new(x - c.X, 0, z - c.Z).Magnitude
			local density = 0.5 + math.noise(x / 280, z / 280, 3.3) * 1.2
			local skip = false
			if naVila(x, z, 10) or nearGate(x, z, 60) then continue end

			if nearGate(x, z, 220) then density = 0 end
			density = math.clamp(density, 0, 0.95)
			if S.rng:NextNumber() < density then
				local pos, why = okGround(x, z)
				if pos then
					for _, o in ipairs({ { 6, 0 }, { -6, 0 }, { 0, 6 }, { 0, -6 } }) do
						local _, m = ground(x + o[1], z + o[2])
						if m and BLOCK[m] then pos = nil why = "perto de trilha/agua" break end
					end
				end
				if not pos then
					rej[why or "?"] = (rej[why or "?"] or 0) + 1
				else
					local inside = d < R
					local roll = S.rng:NextNumber()
					local h, asset
					local conifer = math.noise(x / 400, z / 400, 9.1) > -0.05
					if not inside and d > R + 120 and roll < CFG.GiantChance then
						h = S.rng:NextNumber(110, 170); asset = pick(tallPines); giants += 1
					elseif not inside and roll < CFG.TallChance then
						h = S.rng:NextNumber(50, 80); asset = pick(conifer and conifers or broad); talls += 1
					else
						h = S.rng:NextNumber(22, 42)
						if inside then h = S.rng:NextNumber(18, 30) end
						if #fallOnly > 0 and math.noise(x / 160, z / 160, 5.5) > 0.3 then
							asset = pick(fallOnly)
						else
							asset = pick(conifer and conifers or broad)
						end
					end
					local t = put(asset, pos, h, trees, false, h > 30)
					placed += 1
					if h >= 45 then
						local col = Instance.new("Part")
						col.Name = "Trunk"
						col.Anchored = true
						col.Transparency = 1
						col.CanQuery = false
						col.CanTouch = false
						col.Size = Vector3.new(h * 0.07, h * 0.4, h * 0.07)
						col.CFrame = CFrame.new(pos + Vector3.new(0, h * 0.2, 0))
						col.Parent = t
					end
				end
			end
		end
	end
	print(("[Nature] arvores=%d (gigantes=%d, altas=%d)"):format(placed, giants, talls))
	for k, v in pairs(rej) do print("   rejeitado por " .. k .. ": " .. v) end

	-- detalhes: flores, arbustos, pedras, troncos, cogumelos
	local flowers, bushes = pool({ "flower" }), pool({ "plant_bush", "bush" })
	local rocksS, rocksL = pool({ "rock_small" }), pool({ "rock_large" })
	local logs, stumps, mush = pool({ "log" }), pool({ "stump" }), pool({ "mushroom" })
	local count = 0
	local m = 0
	for gx = -half, half, 15 do
		for gz = -half, half, 15 do
			if count >= CFG.MaxDetails then break end
			m += 1
			if m % 250 == 0 then task.wait() end
			local x = gx + S.rng:NextNumber(-6, 6)
			local z = gz + S.rng:NextNumber(-6, 6)
			local d = Vector3.new(x - c.X, 0, z - c.Z).Magnitude
			local inVillage = d < R - 8
			if (d < R - 8 and d < R * 0.7) or (d >= R - 8 and d <= R + 8) or nearGate(x, z, 60) then continue end
			if S.rng:NextNumber() > 0.55 then continue end
			local pos = okGround(x, z, 0.7)
			if not pos then continue end
			local r = S.rng:NextNumber()
			if r < 0.30 and #flowers > 0 then
				for _ = 1, S.rng:NextInteger(5, 9) do
					local fx, fz = x + S.rng:NextNumber(-5, 5), z + S.rng:NextNumber(-5, 5)
					local fp = okGround(fx, fz, 0.7)
					if fp then put(pick(flowers), fp, S.rng:NextNumber(1.6, 3), details, false, false) count += 1 end
				end
			elseif r < 0.55 and #bushes > 0 then
				put(pick(bushes), pos, S.rng:NextNumber(4, 8), details, true, false) count += 1
			elseif inVillage then
				continue
			elseif r < 0.72 and #rocksS > 0 then
				put(pick(rocksS), pos, S.rng:NextNumber(2.5, 6), details, true, false) count += 1
			elseif r < 0.80 and #rocksL > 0 and d > R + 80 then
				put(pick(rocksL), pos, S.rng:NextNumber(8, 22), details, true, true) count += 1
			elseif r < 0.88 and #logs > 0 then
				put(pick(logs), pos, S.rng:NextNumber(9, 16), details, true, false) count += 1
			elseif r < 0.94 and #stumps > 0 then
				put(pick(stumps), pos, S.rng:NextNumber(3, 5), details, true, false) count += 1
			elseif #mush > 0 then
				put(pick(mush), pos, S.rng:NextNumber(1.5, 4), details, true, false) count += 1
			end
		end
	end
	print("[Nature] detalhes=" .. count)
end

----------------------------------------------------------------- MURO
local function block(parent, size, cf, color, mat)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function lantern(parent, pos, range)
	local l = Instance.new("Part")
	l.Shape = Enum.PartType.Ball
	l.Size = Vector3.new(1.6, 1.6, 1.6)
	l.Position = pos
	l.Anchored = true
	l.CanCollide = false
	l.CanQuery = false
	l.Material = Enum.Material.Neon
	l.Color = Color3.fromRGB(255, 200, 110)
	local pl = Instance.new("PointLight")
	pl.Range = range or 26
	pl.Brightness = 1.6
	pl.Color = Color3.fromRGB(255, 185, 95)
	pl.Shadows = false
	pl.Parent = l
	l.Parent = parent
end

function M.Walls()
	if not S.root then setup() end
	local f = freshFolder("Walls")
	local c, R, H = S.center, S.R, CFG.WallHeight
	local stone = Color3.fromRGB(128, 122, 110)
	local wood = Color3.fromRGB(122, 52, 40)
	local N = math.floor(2 * math.pi * R / CFG.SegLen)
	local function ring(i)
		local a = (i / N) * math.pi * 2
		local x, z = c.X + math.cos(a) * R, c.Z + math.sin(a) * R
		local p = ground(x, z)
		return Vector3.new(x, p and p.Y or c.Y, z)
	end
	local gates = {}
	for _, deg in ipairs(CFG.GateAngles) do
		local a = math.rad(deg)
		local x, z = c.X + math.cos(a) * R, c.Z + math.sin(a) * R
		local p = ground(x, z)
		table.insert(gates, { pos = Vector3.new(x, p and p.Y or c.Y, z), tan = Vector3.new(-math.sin(a), 0, math.cos(a)) })
	end
	local pts = {}
	for i = 0, N do pts[i] = ring(i % N) end
	for i = 0, N - 1 do
		if i % 20 == 0 then task.wait() end
		local a, b = pts[i], pts[i + 1]
		local mid = (a + b) / 2
		local skip = false
		for _, g in ipairs(gates) do
			if (Vector3.new(mid.X, 0, mid.Z) - Vector3.new(g.pos.X, 0, g.pos.Z)).Magnitude < CFG.GateWidth / 2 + 4 then skip = true end
		end
		if not skip then
			local h = math.max(a.Y, b.Y)
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local len = flat.Magnitude
			local base = Vector3.new(mid.X, h + H / 2 - 3, mid.Z)
			local look = CFrame.lookAt(base, base + flat.Unit)
			block(f, Vector3.new(3.6, H, len + 0.8), look, stone, Enum.Material.Cobblestone)
			block(f, Vector3.new(5, 1.2, len + 1), look * CFrame.new(0, H / 2 + 0.6, 0), Color3.fromRGB(100, 96, 88), Enum.Material.Slate)
			for k = -1, 1, 2 do
				block(f, Vector3.new(1.4, 2.2, 2.6), look * CFrame.new(k * 1.8, H / 2 + 2.3, len * 0.25), stone, Enum.Material.Cobblestone)
			end
			if i % 3 == 0 then
				lantern(f, Vector3.new(mid.X, h + H - 1, mid.Z), 24)
			end
		end
		if i % CFG.TowerEvery == 0 then
			local p = pts[i]
			local th = H + 12
			local bp = Vector3.new(p.X, p.Y + th / 2 - 3, p.Z)
			block(f, Vector3.new(10, th, 10), CFrame.new(bp), stone, Enum.Material.Cobblestone)
			block(f, Vector3.new(13, 2, 13), CFrame.new(p.X, p.Y + th - 2, p.Z), wood, Enum.Material.WoodPlanks)
			local roof = block(f, Vector3.new(11, 6, 11), CFrame.new(p.X, p.Y + th + 1.5, p.Z) * CFrame.Angles(0, math.pi / 4, 0), wood, Enum.Material.Wood)
			roof.Shape = Enum.PartType.Block
			lantern(f, Vector3.new(p.X, p.Y + th - 5, p.Z) + (c - p).Unit * 6 * Vector3.new(1, 0, 1), 34)
		end
	end
	for _, g in ipairs(gates) do
		local base = g.pos
		local gh = H + 10
		for k = -1, 1, 2 do
			local pp = base + g.tan * k * (CFG.GateWidth / 2 + 3)
			block(f, Vector3.new(7, gh, 7), CFrame.new(pp.X, pp.Y + gh / 2 - 3, pp.Z), stone, Enum.Material.Cobblestone)
			lantern(f, Vector3.new(pp.X, pp.Y + gh - 3, pp.Z) - g.tan * k * 4.5, 32)
		end
		local look = CFrame.lookAt(Vector3.new(base.X, base.Y + gh - 1, base.Z), Vector3.new(base.X, base.Y + gh - 1, base.Z) + g.tan)
		block(f, Vector3.new(4, 4, CFG.GateWidth + 14), look, wood, Enum.Material.Wood)
	end
	print("[Nature] muro com " .. N .. " segmentos, " .. #gates .. " portao(oes)")
end

----------------------------------------------------------------- PONTES
local function beam(parent, a, b, w, t, color, mat)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = mat
	p.Color = color
	p.Size = Vector3.new(w, t, (b - a).Magnitude + 0.15)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = parent
	return p
end

local function buildBridge(parent, A, B)
	local dirH = Vector3.new(B.X - A.X, 0, B.Z - A.Z)
	local len = dirH.Magnitude
	local dir = dirH.Unit
	A -= dir * 5
	B += dir * 5
	len += 10
	local side = dir:Cross(Vector3.yAxis).Unit
	local baseY = math.max(A.Y, B.Y) + 1.6
	local arch = math.clamp(len * 0.06, 1.5, 4)
	local steps = math.max(8, math.floor(len / 5))
	local W = 9
	local wood = Color3.fromRGB(139, 94, 60)
	local dark = Color3.fromRGB(92, 58, 38)
	local nodes = {}
	for i = 0, steps do
		local t = i / steps
		local flat = A:Lerp(B, t)
		nodes[i] = Vector3.new(flat.X, baseY + arch * math.sin(math.pi * t), flat.Z)
	end
	for i = 0, steps - 1 do
		local a, b = nodes[i], nodes[i + 1]
		beam(parent, a, b, W, 1, wood, Enum.Material.WoodPlanks)
		for k = -1, 1, 2 do
			beam(parent, a + side * k * (W / 2) + Vector3.new(0, 2.4, 0), b + side * k * (W / 2) + Vector3.new(0, 2.4, 0), 0.5, 0.5, dark, Enum.Material.Wood)
			beam(parent, a + side * k * (W / 2) + Vector3.new(0, 1.3, 0), b + side * k * (W / 2) + Vector3.new(0, 1.3, 0), 0.4, 0.4, dark, Enum.Material.Wood)
		end
	end
	for i = 0, steps do
		local n = nodes[i]
		for k = -1, 1, 2 do
			local post = Instance.new("Part")
			post.Anchored = true
			post.Material = Enum.Material.Wood
			post.Color = dark
			post.Size = Vector3.new(0.8, 3.4, 0.8)
			post.Position = n + side * k * (W / 2) + Vector3.new(0, 1.5, 0)
			post.Parent = parent
		end
		if i % 2 == 0 then
			local g = ground(n.X, n.Z)
			local bottom = (g and g.Y or n.Y - 10) - 6
			local h = n.Y - bottom
			local pil = Instance.new("Part")
			pil.Anchored = true
			pil.Material = Enum.Material.Wood
			pil.Color = dark
			pil.Size = Vector3.new(1.6, h, 1.6)
			pil.Position = Vector3.new(n.X, bottom + h / 2, n.Z) + side * (W / 2 - 1)
			pil.Parent = parent
			local pil2 = pil:Clone()
			pil2.Position = Vector3.new(n.X, bottom + h / 2, n.Z) - side * (W / 2 - 1)
			pil2.Parent = parent
		end
	end
	for _, e in ipairs({ { 0, 1 }, { steps, -1 } }) do
		local n = nodes[e[1]]
		for k = -1, 1, 2 do
			lantern(parent, n + side * k * (W / 2) + Vector3.new(0, 4.6, 0), 28)
		end
	end
end

function M.Bridges()
	if not S.root then setup() end
	local f = freshFolder("Bridges")
	local half = S.half
	local waters = {}
	local n = 0
	for x = -half, half, 24 do
		for z = -half, half, 24 do
			n += 1
			if n % 300 == 0 then task.wait() end
			local _, m = ground(x, z)
			if m == Enum.Material.Water then table.insert(waters, Vector3.new(x, 0, z)) end
		end
	end
	print("[Nature] pontos de agua encontrados: " .. #waters)
	for i = #waters, 2, -1 do
		local j = S.rng:NextInteger(1, i)
		waters[i], waters[j] = waters[j], waters[i]
	end
	local built = {}
	local tries = 0
	for _, w in ipairs(waters) do
		if #built >= CFG.MaxBridges then break end
		tries += 1
		if tries % 20 == 0 then task.wait() end
		local tooClose = false
		for _, b in ipairs(built) do if (b - w).Magnitude < 170 then tooClose = true end end
		if (Vector3.new(w.X, 0, w.Z) - Vector3.new(S.center.X, 0, S.center.Z)).Magnitude < S.R + 40 then tooClose = true end
		if tooClose then continue end
		local best
		for deg = 0, 165, 15 do
			local dir = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
			local samples = {}
			for k = -12, 12 do
				local p, m, nrm = ground(w.X + dir.X * k * 4, w.Z + dir.Z * k * 4)
				samples[k] = { p = p, water = (m == Enum.Material.Water), up = nrm and nrm.Y or 0 }
			end
			if samples[0].water then
				local lo, hi = 0, 0
				while samples[lo - 1] and samples[lo - 1].water do lo -= 1 end
				while samples[hi + 1] and samples[hi + 1].water do hi += 1 end
				local a, b = samples[lo - 1], samples[hi + 1]
				if a and b and a.p and b.p and a.up > 0.7 and b.up > 0.7 and math.abs(a.p.Y - b.p.Y) < 8 then
					local L = (b.p - a.p).Magnitude
					if L > 12 and L < 70 and (not best or L < best.L) then
						best = { L = L, A = a.p, B = b.p }
					end
				end
			end
		end
		if best then
			buildBridge(f, best.A, best.B)
			table.insert(built, w)
			print(("[Nature] ponte em %s (vao %.0f studs)"):format(tostring(best.A), best.L))
		end
	end
	if #built == 0 then warn("[Nature] nenhuma ponte possivel; rio largo/estreito demais? Ajuste L (12-70) no codigo") end
end

----------------------------------------------------------------- GERAL
function M.Clear()
	local r = Workspace:FindFirstChild("Nature")
	if r then r:Destroy() end
end

function M.Run(opts)
	setup(opts)
	M.Walls()
	M.Bridges()
	M.Forest()
	print("[Nature] pronto. Pecas em Workspace/Nature.")
end

return M
