--!nocheck
-- RebuildAll.luau — reconstrói o mapa inteiro na ordem certa, sem cache de require.
-- Command Bar (modo Edit):
--   require(game.ServerStorage.MapGen.RebuildAll:Clone()).Run()
local ServerStorage = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")

local M = {}

local function step(name, fn)
	local t0 = os.clock()
	local ok, err = pcall(fn)
	if ok then
		print(("[Rebuild] OK  %s (%.1fs)"):format(name, os.clock() - t0))
	else
		warn(("[Rebuild] ERRO em %s: %s"):format(name, tostring(err)))
	end
	return ok
end

-- apaga só o que veio do BuildVillage antigo (vila quadrada com mesas)
local function removeOldVillage()
	local n = 0
	for _, f in { workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Village"), workspace:FindFirstChild("Plots"), workspace:FindFirstChild("Stalls"), workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Markers") } do
		if f then
			for _, c in f:GetChildren() do
				if c:GetAttribute("Gen") == "Village32" then c:Destroy() n += 1 end
			end
		end
	end
	local old = workspace:FindFirstChild("Nature")
	if old then old:Destroy() end
	print("[Rebuild] vila antiga removida: " .. n .. " objetos; Nature limpa")
end

function M.Run(opts)
	opts = opts or {}
	local src = ServerStorage:WaitForChild("MapGen")
	local gen = src:Clone() -- cópia nova = sem cache, sempre o código atual do Rojo
	gen.Name = "MapGen_Run"
	gen.Parent = ServerStorage

	local cfg = require(gen.MapConfig)
	local tg = require(gen.TerrainGen)
	if cfg.Version ~= 2 or tg.Version ~= 2 or not cfg.Village.Radius then
		warn("[Rebuild] MapConfig/TerrainGen DESATUALIZADOS no Studio. Confira o Rojo (versões: " .. tostring(cfg.Version) .. "/" .. tostring(tg.Version) .. ")")
		gen:Destroy()
		return
	end

	step("limpeza", removeOldVillage)
	local okBase = step("terreno (BuildBase)", function()
		require(gen.BuildBase).Run({ terrain = opts.terrain })
	end)
	if okBase then
		step("vila (VillageBuilder)", function()
			local vb = SSS:FindFirstChild("VillageBuilder", true)
			assert(vb, "VillageBuilder não encontrado em ServerScriptService")
			require(vb:Clone()).Build()
		end)
		step("natureza (BuildNature)", function()
			require(gen.BuildNature).Run()
		end)
	end
	gen:Destroy()
	pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Rebuild All") end)
	print("[Rebuild] fim. Salve o place (Ctrl+S).")
end

return M
