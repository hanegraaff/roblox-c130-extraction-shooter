"""Build a fresh native world-load acceptance probe for the existing Studio session.

Run from any directory after setup.py. Outputs stay in ignored build/. Execute the
printed Luau probe through Studio MCP in Edit mode; it deserializes the generated
Rojo binary world, compares source geometry and exercises production MapService.
It owns/restores its temporary model and terrain. It never launches Studio, publishes
assets or substitutes a clone of the live map for serialized-source interpretation.
"""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def world_expectations(world: dict) -> dict:
    """Describe every authored node and primitive's canonical engine contract."""
    parts, nodes = [], []

    def walk(node: dict, path: list[str]) -> None:
        nodes.append({"path": path, "className": node["ClassName"]})
        if node["ClassName"] in {"Part", "SpawnLocation"}:
            properties = node["Properties"]
            parts.append({"path": path, "pose": properties["CFrame"], "size": properties["Size"],
                          "shape": properties.get("Shape", "Block"), "className": node["ClassName"],
                          "flags": {name: properties.get(name, True) for name in
                                    ("Anchored", "CanCollide", "CanQuery", "CanTouch")}})
        for child in node.get("Children", []):
            walk(child, path + [child["Name"]])

    walk(world, [])
    return {"parts": parts, "nodes": nodes}


PROBE_TEMPLATE = r'''--!strict
local encoded = {BINARY}
local data = buffer.create(#encoded)
for index, value in encoded do buffer.writeu8(data, index-1, value) end
local source = game:GetService("HttpService"):JSONDecode([==[EXPECTED]==])
local loaded
local loadedOK, loadedError = pcall(function()
    loaded = game:GetService("SerializationService"):DeserializeInstancesAsync(data)
end)
if not loadedOK then return {passed=false,stage="native-load",detail=tostring(loadedError)} end
local container, owner, heartbeat, savedTerrain
local outsideRegion = Region3.new(Vector3.new(696,16,-4),Vector3.new(704,24,4)):ExpandToGrid(4)
local terrain = workspace.Terrain
local oldMaterials, oldOccupancies = terrain:ReadVoxels(outsideRegion,4)
local report = {cases={},artifacts=1,worldParts=0,worldNodes=0,version=version(),sampleHistory={}}
local function check(name, callback)
    local ok, failure = pcall(callback)
    table.insert(report.cases,{name=name,passed=ok,detail=not ok and tostring(failure) or nil})
    assert(ok,tostring(failure))
end
local function find(root, path)
    local current = root
    for _, name in path do current = current and current:FindFirstChild(name) end
    return current
end
local function verifyMap(map)
    assert(#map:GetDescendants()+1==#source.nodes,"fresh node count mismatch")
    for _, item in source.nodes do
        local instance = find(map,item.path)
        assert(instance and instance.ClassName==item.className,"fresh node identity/class mismatch")
        assert(not instance:IsA("LuaSourceContainer"),"unexpected executable world content")
    end
    local maximumError=0
    for _, item in source.parts do
        local part=find(map,item.path)
        assert(part and part:IsA("BasePart"),"fresh authored part missing")
        local pose={part.CFrame:GetComponents()}
        local size={part.Size.X,part.Size.Y,part.Size.Z}
        for index, expected in item.pose do
            maximumError=math.max(maximumError,math.abs(pose[index]-expected))
            assert(math.abs(pose[index]-expected)<=.001,"fresh loaded CFrame mismatch: "..part.Name)
        end
        for index, expected in item.size do assert(math.abs(size[index]-expected)<=.001,"fresh loaded size mismatch") end
        for name, expected in item.flags do assert(part[name]==expected,"fresh loaded flag mismatch") end
        if part:IsA("Part") then assert(part.Shape.Name==item.shape,"fresh loaded shape mismatch") end
    end
    report.worldParts=#source.parts
    report.worldNodes=#source.nodes
    report.maximumCFrameComponentError=math.max(report.maximumCFrameComponentError or 0,maximumError)
end
local function terrainSample(recipe)
    local hills={}
    for _,hill in recipe:GetChildren() do if hill:IsA("Part") and hill.Name~="TerrainBounds" then table.insert(hills,hill) end end
    table.sort(hills,function(a,b)return a.Name<b.Name end)
    local entries, apices={},{}
    local samples=0
    local rays=RaycastParams.new()
    rays.FilterType=Enum.RaycastFilterType.Include
    rays.FilterDescendantsInstances={terrain}
    for _,hill in hills do
        local center=hill.Position+Vector3.new(0,hill.Size.Y/2-8,0)
        local region=Region3.new(center-Vector3.new(8,16,8),center+Vector3.new(8,16,8)):ExpandToGrid(4)
        local materials,occupancies=terrain:ReadVoxels(region,4)
        table.insert(entries,hill.Name)
        for x=1,#materials do for y=1,#materials[x] do for z=1,#materials[x][y] do
            table.insert(entries,materials[x][y][z].Name..":"..string.format("%.9g",occupancies[x][y][z]));samples+=1
        end end end
        local hit=workspace:Raycast(Vector3.new(hill.Position.X,80,hill.Position.Z),Vector3.new(0,-150,0),rays)
        assert(hit and hit.Material==hill.Material and math.abs(hit.Position.Y-16)<=3,"fresh terrain elevation/material not ready")
        table.insert(apices,{name=hill.Name,material=hit.Material.Name,y=hit.Position.Y})
    end
    local value=table.concat(entries,"|")
    local a,b=1,0
    for index=1,#value do a=(a+string.byte(value,index))%65521;b=(b+a)%65521 end
    return {sampleCount=samples,hillCount=#hills,bytes=#value,adler32=b*65536+a,apices=apices}
end
local function readySample(recipe)
    local deadline=os.clock()+5
    local ok, result
    repeat ok,result=pcall(terrainSample,recipe);if not ok then task.wait(.05) end until ok or os.clock()>=deadline
    assert(ok,tostring(result))
    assert(result.sampleCount==1152 and result.bytes==9513 and result.adler32==2054186319,"fresh terrain differs from original live-sync sample")
    table.insert(report.sampleHistory,result)
    return result
end
local ok, failure = pcall(function()
    check("Fresh native binary world load matches all authored identities and geometry",function()
        assert(#loaded==1 and loaded[1]:IsA("Model"),"unexpected native artifact roots")
        container=loaded[1]
        assert(container.Parent==nil,"native loader unexpectedly parented artifact")
        verifyMap(container.World.Battlefield)
        savedTerrain=terrain:CopyRegion(Region3int16.new(Vector3int16.new(-92,-28,-92),Vector3int16.new(91,7,91)))
        container.Name="P13AcceptanceFreshWorld"
        assert(not workspace:FindFirstChild(container.Name),"another fresh-world fixture exists")
        container.Parent=workspace
        task.wait()
        heartbeat=Instance.new("BindableEvent")
        local reason
        owner,reason=require(game.ServerScriptService.Server.MapService).new(container.World,{characters=function()return {} end,heartbeat=heartbeat.Event})
        assert(owner,reason)
        local started,startReason=owner.start();assert(started,startReason)
    end)
    check("Fresh source-built terrain matches original eight-hill sample",function()
        readySample(container.World.Battlefield.TerrainRecipe)
    end)
    terrain:FillBlock(CFrame.new(700,20,0),Vector3.new(8,8,8),Enum.Material.Sand)
    local preservedMaterials,preservedOccupancies=terrain:ReadVoxels(outsideRegion,4)
    for rebuild=1,2 do
        check("Fresh world perturbed rebuild "..rebuild.." restores geometry terrain and unrelated voxels",function()
            local map=container.World.Battlefield
            map.Buildings.Foundry.Foundry_Panels:GetChildren()[1]:Destroy()
            local debris=Instance.new("Part");debris.Name="AcceptanceTransient";debris.Anchored=true;debris.Parent=map
            terrain:FillBall(Vector3.new(-260,20,-140),12,Enum.Material.Sand)
            local rebuilt,why=owner.rebuild();assert(rebuilt,why)
            verifyMap(container.World.Battlefield)
            assert(not container.World.Battlefield:FindFirstChild("AcceptanceTransient"),"transient survived fresh rebuild")
            readySample(container.World.Battlefield.TerrainRecipe)
            local materials,occupancies=terrain:ReadVoxels(outsideRegion,4)
            for x=1,#materials do for y=1,#materials[x] do for z=1,#materials[x][y] do
                assert(materials[x][y][z]==preservedMaterials[x][y][z] and occupancies[x][y][z]==preservedOccupancies[x][y][z],"unrelated terrain changed")
            end end end
        end)
    end
    check("Fresh loaded world idempotent teardown restores pristine model",function()
        owner.destroy();owner.destroy();verifyMap(container.World.Battlefield)
    end)
end)
local cleanupErrors={}
local function cleanup(callback)
    local cleaned,why=pcall(callback)
    if not cleaned then table.insert(cleanupErrors,tostring(why)) end
end
if owner then cleanup(function()owner.destroy()end) end
if heartbeat then cleanup(function()heartbeat:Destroy()end) end
for _,root in loaded do cleanup(function()root:Destroy()end) end
if savedTerrain then
    cleanup(function()terrain:PasteRegion(savedTerrain,Vector3int16.new(-92,-28,-92),true);savedTerrain:Destroy()end)
end
cleanup(function()terrain:WriteVoxels(outsideRegion,4,oldMaterials,oldOccupancies)end)
report.passed=ok and #cleanupErrors==0
report.detail=not ok and tostring(failure) or nil
report.cleanupErrors=cleanupErrors
report.fixtureRemoved=workspace:FindFirstChild("P13AcceptanceFreshWorld")==nil
return report
'''


def main() -> None:
    """Build with pinned Rojo and emit the complete MCP probe plus source/hash metadata."""
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    source_path = ROOT / "assets/world/Battlefield.model.json"
    source_bytes = source_path.read_bytes()
    expected = world_expectations(json.loads(source_bytes))
    prefix = build / "studio-world-probe"
    project = prefix.with_suffix(".project.json")
    project.write_text(json.dumps({"name": "P13FreshWorld", "tree": {"$className": "Model", "World": {
        "$className": "Folder", "Battlefield": {"$path": "../assets/world/Battlefield.model.json"}}}}, indent=2) + "\n")
    binary = prefix.with_suffix(".rbxm")
    subprocess.run([str(Path.home() / ".rokit/bin/rojo"), "build", str(project), "--output", str(binary)], cwd=ROOT, check=True)
    payload = binary.read_bytes()
    code = PROBE_TEMPLATE.replace("BINARY", ",".join(str(value) for value in payload)).replace("EXPECTED", json.dumps(expected))
    probe = prefix.with_suffix(".luau")
    probe.write_text(code)
    prefix.with_suffix(".expected.json").write_text(json.dumps(expected, indent=2) + "\n")
    metadata = {"sourceCommit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "worldSource": str(source_path.relative_to(ROOT)), "worldSourceSha256": hashlib.sha256(source_bytes).hexdigest(),
                "binarySha256": hashlib.sha256(payload).hexdigest(), "binaryBytes": len(payload),
                "worldParts": len(expected["parts"]), "worldNodes": len(expected["nodes"]),
                "probe": str(probe.relative_to(ROOT)), "probeSha256": hashlib.sha256(code.encode()).hexdigest(),
                "procedure": "Native in-process world load; separate runtime baseline required; no fresh-place boot claim"}
    prefix.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
