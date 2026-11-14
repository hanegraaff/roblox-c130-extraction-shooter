--!strict
-- P13 A2: pure building/registry acceptance and rejection. Engine traversal is separate.
type Panel = { id: string, story: number, roof: boolean, interior: boolean?, pivot: { number } }
type Building = {
    id: string,
    width: number,
    depth: number,
    stories: number,
    stairSteps: number,
    stepRise: number,
    stepRun: number,
    panels: { Panel },
    panelLayoutVersion: number?,
}
type API = { validate: ({ Building }) -> (boolean, string?) }
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local Layout = candidate :: API
    local function fixture(): { Building }
        local buildings: { Building } = {}
        for i = 1, 3 do
            local panels: { Panel } = {}
            local width = if i < 3 then 64 else 32
            local wallCount = 2 * (width / 16 + 48 / 16)
            local serial = 0
            for story = 1, 2 do
                for _ = 1, wallCount - (if story == 1 then 1 else 0) do
                    serial += 1
                    table.insert(panels, {
                        id = tostring(i) .. "_" .. tostring(serial),
                        story = story,
                        roof = false,
                        pivot = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
                    })
                end
            end
            if width == 64 then
                for story = 1, 2 do
                    for _ = 1, 2 do
                        serial += 1
                        table.insert(panels, {
                            id = tostring(i) .. "_" .. tostring(serial),
                            story = story,
                            roof = false,
                            interior = true,
                            pivot = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
                        })
                    end
                end
            end
            for _ = 1, (width / 16) * 3 do
                serial += 1
                table.insert(panels, {
                    id = tostring(i) .. "_" .. tostring(serial),
                    story = 2,
                    roof = true,
                    pivot = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
                })
            end
            table.insert(buildings, {
                id = "Building" .. tostring(i),
                width = if i < 3 then 64 else 32,
                depth = 48,
                stories = 2,
                stairSteps = 16,
                stepRise = 0.625,
                stepRun = 2,
                panels = panels,
            })
        end
        return buildings
    end
    test("BuildingLayout accepts two larger and one smaller two-story panel registry", function()
        assert(Layout.validate(fixture()))
    end)
    test(
        "P17OutpostReconstruction layout migration requires exactly the additional ground partition",
        function()
            local buildings = fixture()
            local outpost = buildings[3]
            outpost.id = "Outpost"
            outpost.panelLayoutVersion = 2
            assert(not Layout.validate(buildings), "missing migrated partition accepted")
            table.insert(outpost.panels, {
                id = "Outpost_v2_Interior01",
                story = 1,
                roof = false,
                interior = true,
                pivot = { 151, 4.125, 148, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
            })
            assert(Layout.validate(buildings))
            outpost.panels[#outpost.panels].story = 2
            assert(not Layout.validate(buildings), "partition moved to upper story")
            outpost.panels[#outpost.panels].story = 1
            outpost.panelLayoutVersion = 3
            assert(not Layout.validate(buildings), "unknown migration accepted")
            outpost.panelLayoutVersion = 2
            outpost.id = "Other"
            assert(not Layout.validate(buildings), "migration applied to a different building")
        end
    )
    test("BuildingLayout rejects missing buildings stories stairs and size distinctions", function()
        local missing = fixture()
        table.remove(missing)
        assert(not Layout.validate(missing), "missing building accepted")
        for _, key in { "width", "depth", "stories", "stairSteps", "stepRise", "stepRun" } do
            local value = fixture()
            local target = (value[1] :: unknown) :: { [string]: unknown }
            target[key] = 0 / 0
            assert(not Layout.validate(value), key)
        end
        local value = fixture()
        value[3].width = 64
        assert(not Layout.validate(value), "three large buildings accepted")
    end)
    test("BuildingLayout rejects duplicated IDs invalid pivots and missing story roof coverage", function()
        for _, change in { "duplicate", "pivot", "story", "roof" } do
            local value = fixture()
            if change == "duplicate" then
                value[2].panels[1].id = value[1].panels[1].id
            elseif change == "pivot" then
                value[1].panels[1].pivot[1] = math.huge
            elseif change == "story" then
                value[1].panels[1].story = 2
            else
                value[1].panels[#value[1].panels].roof = false
            end
            assert(not Layout.validate(value), change)
        end
    end)
end
