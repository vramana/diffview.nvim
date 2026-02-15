local helpers = require("diffview.tests.helpers")

local eq = helpers.eq

describe("diffview.scene.file_entry", function()
  local FileEntry = require("diffview.scene.file_entry").FileEntry

  it("forwards force flag to contained files when destroyed", function()
    local seen = {}
    local layout_destroyed = false

    local layout = {
      files = function()
        return {
          {
            destroy = function(_, force)
              seen[#seen + 1] = force
            end,
          },
          {
            destroy = function(_, force)
              seen[#seen + 1] = force
            end,
          },
        }
      end,
      destroy = function()
        layout_destroyed = true
      end,
    }

    local entry = FileEntry({
      adapter = { ctx = { toplevel = "/tmp" } },
      path = "a.txt",
      oldpath = nil,
      revs = {},
      layout = layout,
      status = "M",
      stats = {},
      kind = "working",
    })

    entry:destroy(true)

    eq({ true, true }, seen)
    eq(true, layout_destroyed)
  end)
end)
